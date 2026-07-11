#!/usr/bin/env python3
"""Compare hell-training summaries from two replay/calibration runs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)
    if not isinstance(data, dict):
        raise ValueError(f"Expected JSON object in {path}")
    return data


def resolve_summary_path(path: Path, project_root: Path | None = None) -> Path:
    if path.is_file():
        data = load_json(path)
        if "summary_path" in data:
            candidate = resolve_godot_path(str(data["summary_path"]), project_root or Path.cwd())
            if not candidate.is_absolute() and not candidate.exists():
                candidate = path.parent / candidate.name
            if candidate.exists():
                return candidate
        return path
    raise FileNotFoundError(path)


def resolve_godot_path(raw_path: str, project_root: Path) -> Path:
    if raw_path.startswith("res://"):
        return project_root / raw_path.removeprefix("res://")
    if raw_path.startswith("user://"):
        return Path(raw_path)
    return Path(raw_path)


def compare_summaries(before_path: Path, after_path: Path, project_root: Path | None = None) -> dict[str, Any]:
    before = load_json(resolve_summary_path(before_path, project_root))
    after = load_json(resolve_summary_path(after_path, project_root))
    return {
        "before": compact_summary(before, before_path),
        "after": compact_summary(after, after_path),
        "decision_delta": int(after.get("decision_count", 0)) - int(before.get("decision_count", 0)),
        "marked_delta": int(after.get("marked_count", 0)) - int(before.get("marked_count", 0)),
        "category_delta": diff_counts(before.get("category_counts", {}), after.get("category_counts", {})),
        "severity_delta": diff_counts(before.get("severity_counts", {}), after.get("severity_counts", {})),
    }


def compact_summary(summary: dict[str, Any], source_path: Path) -> dict[str, Any]:
    return {
        "source_path": str(source_path),
        "session_id": summary.get("session_id", ""),
        "decision_count": int(summary.get("decision_count", 0)),
        "marked_count": int(summary.get("marked_count", 0)),
        "round_index": int(summary.get("round_index", 0)),
        "category_counts": dict(summary.get("category_counts", {})),
        "severity_counts": dict(summary.get("severity_counts", {})),
    }


def diff_counts(before: Any, after: Any) -> dict[str, dict[str, int]]:
    before_counts = before if isinstance(before, dict) else {}
    after_counts = after if isinstance(after, dict) else {}
    keys = sorted(set(before_counts.keys()) | set(after_counts.keys()))
    return {
        str(key): {
            "before": int(before_counts.get(key, 0)),
            "after": int(after_counts.get(key, 0)),
            "delta": int(after_counts.get(key, 0)) - int(before_counts.get(key, 0)),
        }
        for key in keys
    }


def write_compare_report(result: dict[str, Any], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.suffix.lower() == ".json":
        output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        output_path.write_text(build_markdown_report(result), encoding="utf-8")


def build_markdown_report(result: dict[str, Any]) -> str:
    before = result["before"]
    after = result["after"]
    lines = [
        "# Hell Replay Compare",
        "",
        f"- Before: `{before['session_id']}` decisions={before['decision_count']} marked={before['marked_count']}",
        f"- After: `{after['session_id']}` decisions={after['decision_count']} marked={after['marked_count']}",
        f"- Decision delta: {result['decision_delta']}",
        f"- Marked delta: {result['marked_delta']}",
        "",
        "## Category Delta",
        "| Key | Before | After | Delta |",
        "|---|---:|---:|---:|",
    ]
    lines.extend(format_delta_rows(result["category_delta"]))
    lines.append("")
    lines.append("## Severity Delta")
    lines.append("| Key | Before | After | Delta |")
    lines.append("|---|---:|---:|---:|")
    lines.extend(format_delta_rows(result["severity_delta"]))
    return "\n".join(lines) + "\n"


def format_delta_rows(delta: dict[str, dict[str, int]]) -> list[str]:
    if not delta:
        return ["| none | 0 | 0 | 0 |"]
    return [f"| `{key}` | {value['before']} | {value['after']} | {value['delta']} |" for key, value in delta.items()]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compare two hell-training summary or manifest files.")
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, default=Path("测试数据统计/hell_replay_compare/latest_compare.md"))
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = compare_summaries(args.before, args.after, args.project_root)
    write_compare_report(result, args.output)
    print(f"decision_delta={result['decision_delta']}")
    print(f"marked_delta={result['marked_delta']}")
    print(f"output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
