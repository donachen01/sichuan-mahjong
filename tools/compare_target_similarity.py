#!/usr/bin/env python3
"""四川麻将 UI 目标图"眯眼"接近度比对工具（辅助信号，非唯一门槛）。

验收标准不是逐像素一致（麻将每局牌面不同，逐像素是伪命题），而是：
整体风格一致 / 各区域位置与目标图接近 / 整体完成度高。

本工具用"眯眼对比"提供客观辅助信号：把两图重度降采样再比对，
牌面上的具体牌被模糊掉，留下整体构图、区域块布局和配色氛围。输出：
  1. 眯眼接近率（降采样后 1 - 归一化平均差），对牌面差异鲁棒
  2. 分区接近率（切网格，定位构图差异集中在哪块）
  3. 主色调对比（各自主导配色的接近度）
  4. 差异热力图 PNG（在降采样域，越亮=构图差异越大），供评审师查看

最终 PASS/FAIL 由独立评审子代理综合三条标准判定，本数字仅作参考。

用法：
  python3 tools/compare_target_similarity.py \
      --target <目标图.png> --render <运行截图.png> \
      --out <输出目录> [--squint 64x36] [--grid 8x4]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops


def _load_rgb(path: Path, size: tuple[int, int] | None) -> Image.Image:
    with Image.open(path) as src:
        image = src.convert("RGB")
    if size is not None and image.size != size:
        image = image.resize(size, Image.LANCZOS)
    return image


def _parse_grid(text: str) -> tuple[int, int]:
    cols, rows = text.lower().split("x")
    return int(cols), int(rows)


def _squint(image: Image.Image, squint: tuple[int, int]) -> Image.Image:
    """重度降采样：模糊掉牌面细节，保留构图与配色。"""
    return image.resize(squint, Image.LANCZOS)


def _mean_diff(diff: Image.Image) -> float:
    """返回平均像素差 0-255（三通道取最坏）。"""
    pixels = list(diff.getdata())
    total = max(1, len(pixels))
    diff_sum = sum(max(r, g, b) for r, g, b in pixels)
    return diff_sum / total


def _palette(image: Image.Image, k: int = 6) -> list[tuple[int, tuple[int, int, int]]]:
    """返回主色调 [(占比千分数, (r,g,b)), ...]，按占比降序。"""
    small = image.resize((64, 64), Image.LANCZOS).convert(
        "P", palette=Image.ADAPTIVE, colors=k
    )
    pal = small.getpalette() or []
    counts = small.getcolors() or []
    total = max(1, sum(c for c, _ in counts))
    result = []
    for count, idx in sorted(counts, reverse=True):
        rgb = (pal[idx * 3], pal[idx * 3 + 1], pal[idx * 3 + 2])
        result.append((round(1000 * count / total), rgb))
    return result


def _palette_similarity(a: Image.Image, b: Image.Image) -> float:
    """两图主色调接近度 0-1：目标每个主色在对方中找最近色的加权匹配。"""
    pa, pb = _palette(a), _palette(b)
    if not pa or not pb:
        return 0.0
    score = 0.0
    weight = 0.0
    for share, rgb in pa:
        nearest = min(
            (sum((c1 - c2) ** 2 for c1, c2 in zip(rgb, rgb2)) ** 0.5 for _, rgb2 in pb)
        )
        # 441 = sqrt(3*255^2)，最大可能色距
        score += share * (1.0 - nearest / 441.0)
        weight += share
    return score / max(1.0, weight)


def _region_report(
    diff: Image.Image, grid: tuple[int, int]
) -> list[dict]:
    cols, rows = grid
    width, height = diff.size
    regions: list[dict] = []
    for ry in range(rows):
        for rx in range(cols):
            box = (
                rx * width // cols,
                ry * height // rows,
                (rx + 1) * width // cols,
                (ry + 1) * height // rows,
            )
            mean_diff, within_ratio = _channel_diff_stats(diff.crop(box), tolerance)
            regions.append(
                {
                    "col": rx,
                    "row": ry,
                    "box": list(box),
                    "similarity": round(1.0 - mean_diff / 255.0, 4),
                    "within_tolerance_ratio": round(within_ratio, 4),
                }
            )
    return regions


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--render", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--squint", default="64x36")
    parser.add_argument("--grid", default="8x4")
    args = parser.parse_args()

    target_path = Path(args.target).expanduser().resolve()
    render_path = Path(args.render).expanduser().resolve()
    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    target = _load_rgb(target_path, None)
    render = _load_rgb(render_path, target.size)
    squint = _parse_grid(args.squint)
    grid = _parse_grid(args.grid)

    # 眯眼域：重度降采样后比对，对牌面差异鲁棒
    t_sq = _squint(target, squint)
    r_sq = _squint(render, squint)
    diff = ImageChops.difference(t_sq, r_sq)
    overall_similarity = round(1.0 - _mean_diff(diff) / 255.0, 4)
    palette_similarity = round(_palette_similarity(target, render), 4)

    regions = _region_report(diff, grid)
    worst = sorted(regions, key=lambda r: r["similarity"])[:5]

    # 差异热力图：在眯眼域放大差异，再拉回原尺寸便于人眼定位
    heatmap = diff.point(lambda v: min(255, v * 3)).resize(target.size, Image.NEAREST)
    heatmap.save(out_dir / "diff_heatmap.png")

    report = {
        "target": str(target_path),
        "render": str(render_path),
        "resolution": list(target.size),
        "squint": args.squint,
        "grid": args.grid,
        "squint_similarity": overall_similarity,
        "palette_similarity": palette_similarity,
        "target_palette": _palette(target),
        "render_palette": _palette(render),
        "worst_regions": worst,
        "regions": regions,
        "note": "辅助信号，最终 PASS/FAIL 由独立评审师按三维度标准判定",
    }
    (out_dir / "similarity_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print(f"分辨率: {target.size[0]}x{target.size[1]}  眯眼域: {args.squint}")
    print(f"眯眼接近率(构图+配色): {overall_similarity:.2%}")
    print(f"主色调接近率: {palette_similarity:.2%}")
    print("构图差异最大的 5 个分区:")
    for r in worst:
        print(f"  区({r['col']},{r['row']}) 接近率={r['similarity']:.2%} box={r['box']}")
    print(f"热力图与报告已写入: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
