#!/usr/bin/env python3
"""Render the entire video inventory as a front-of-task Markdown checklist."""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from collections import Counter
from pathlib import Path


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def marker(item: dict, active_id: str) -> tuple[str, str]:
    if str(item.get("video_id", "")) == active_id:
        return "[ ]", "▶ 当前前台执行"
    status = item.get("learning_status")
    if status == "verified":
        return "[x]", "✅ 已验证"
    if status == "needs_review":
        return "[ ]", "🔁 历史降级待复核"
    if status == "awaiting_calibration":
        return "[ ]", "🧪 语义已验证，等待多来源校准"
    if item.get("screening_status") == "excluded":
        return "[ ]", "⊘ 已排除"
    return "[ ]", "⏳ 待学习"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    cfg = parser.parse_args()

    inventory = read_json(cfg.inventory)
    state = read_json(cfg.state) if cfg.state.exists() else {}
    active = state.get("active") if isinstance(state.get("active"), dict) else {}
    active_id = str(active.get("video_id", ""))
    items = sorted(inventory.get("items", []), key=lambda item: int(item.get("order", 10**9)))
    statuses = Counter(str(item.get("learning_status", "unknown")) for item in items)

    lines = [
        "# 潇老师四川麻将视频：前台复核与 AI 应用清单",
        "",
        "此文件由库存与学习状态自动生成；每次前台推进或完成一条后刷新。",
        "",
        "## 完成门禁",
        "",
        "- [ ] 原片、元数据和逐帧 SHA-256 一致",
        "- [ ] 精确帧、公开时间线、知识单元、语义复现、反事实与迁移盲测通过",
        "- [ ] 低流量门禁通过：原片仅复用一次、1 FPS 基线、必要才升级精确帧、字幕与画面交叉核验",
        "- [ ] 每个决策节点完成无透视 AI 映射，含冲突消解、聚焦测试与真实 C# runtime 证据",
        "- [ ] `validation-report.json` 的 `ok`、`semantic_mastery`、`low_traffic_gate`、`ai_application_gate` 均为 true",
        "",
        "## 实时总览",
        "",
        f"- 总条目：{len(items)}",
        f"- 已验证：{statuses['verified']}",
        f"- 历史降级待复核：{statuses['needs_review']}",
        f"- 等待多来源校准：{statuses['awaiting_calibration']}",
        f"- 待学习：{statuses['not_started']}",
        f"- 当前前台条目：#{active.get('order', '无')} {active.get('title', '无')}",
        f"- 当前阶段：{active.get('stage', 'idle')}",
        "",
        "## 全量清单",
        "",
        "标记说明：`[x]` 已通过全部门禁；`▶` 当前前台执行；`🔁` 历史降级待复核；`🧪` 语义已验证但尚未应用；`⏳` 未学习。",
        "",
    ]
    for item in items:
        box, label = marker(item, active_id)
        order = item.get("order", "?")
        title = str(item.get("title", "")).replace("\n", " ").strip()
        video_id = item.get("video_id", "")
        lines.append(f"- {box} #{order} — {label} — {title} (`{video_id}`)")
    lines.append("")
    write_atomic(cfg.output, "\n".join(lines))
    print(json.dumps({"ok": True, "items": len(items), "output": str(cfg.output)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
