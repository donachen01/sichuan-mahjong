#!/usr/bin/env python3
"""Create a standard evidence folder for real-table regression fixes."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


DEFAULT_ROOT = Path("测试数据统计")


def create_evidence_package(title: str, source_files: list[Path], output_root: Path = DEFAULT_ROOT, slug: str | None = None) -> Path:
    safe_slug = slug or datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_title = sanitize_title(title)
    package_dir = output_root / f"回归证据_{safe_slug}_{safe_title}"
    package_dir.mkdir(parents=True, exist_ok=True)
    copied_files = copy_sources(source_files, package_dir)
    write_readme(package_dir, title, copied_files)
    write_changed_files(package_dir)
    write_checksums(package_dir)
    return package_dir


def sanitize_title(title: str) -> str:
    cleaned = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in title.strip())
    return cleaned.strip("_") or "未命名问题"


def copy_sources(source_files: list[Path], package_dir: Path) -> list[Path]:
    copied: list[Path] = []
    source_dir = package_dir / "source"
    source_dir.mkdir(exist_ok=True)
    for source in source_files:
        if not source.exists():
            raise FileNotFoundError(source)
        target = source_dir / source.name
        if source.resolve() != target.resolve():
            shutil.copy2(source, target)
        copied.append(target)
    return copied


def write_readme(package_dir: Path, title: str, copied_files: list[Path]) -> None:
    lines = [
        f"# 回归证据 - {title}",
        "",
        f"- Created at: {datetime.now().isoformat(timespec='seconds')}",
        "- Status: pending_review",
        "",
        "## Required Evidence Checklist",
        "",
        "- [ ] Real table source data is included.",
        "- [ ] Same-type extension case is included.",
        "- [ ] Test command and output are included.",
        "- [ ] Before/after score or state comparison is included.",
        "- [ ] Changed files are listed.",
        "",
        "## Source Files",
    ]
    if copied_files:
        lines.extend(f"- `source/{path.name}`" for path in copied_files)
    else:
        lines.append("- None supplied yet.")
    lines.extend(
        [
            "",
            "## Commands",
            "",
            "Add the exact verification commands and outputs before marking this evidence package complete.",
            "",
        ]
    )
    (package_dir / "README.md").write_text("\n".join(lines), encoding="utf-8")


def write_changed_files(package_dir: Path) -> None:
    status = run_git(["git", "status", "--short"])
    diff_stat = run_git(["git", "diff", "--stat"])
    content = "\n".join(
        [
            "# Changed Files",
            "",
            "## git status --short",
            "",
            "```text",
            status.strip(),
            "```",
            "",
            "## git diff --stat",
            "",
            "```text",
            diff_stat.strip(),
            "```",
            "",
        ]
    )
    (package_dir / "changed_files.md").write_text(content, encoding="utf-8")


def run_git(command: list[str]) -> str:
    result = subprocess.run(command, check=False, text=True, capture_output=True)
    return result.stdout if result.returncode == 0 else result.stderr


def write_checksums(package_dir: Path) -> None:
    lines: list[str] = []
    for path in sorted(p for p in package_dir.rglob("*") if p.is_file() and p.name != "SHA256SUMS.txt"):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(package_dir)}")
    (package_dir / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a standard regression evidence package.")
    parser.add_argument("title")
    parser.add_argument("--source", type=Path, action="append", default=[])
    parser.add_argument("--output-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--slug", default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    package_dir = create_evidence_package(args.title, args.source, args.output_root, args.slug)
    print(f"package_dir={package_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

