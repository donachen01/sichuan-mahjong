#!/usr/bin/env python3
"""Validate the four-state by four-resolution HUD evidence matrix."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from check_ui_capture import inspect_capture


EXPECTED_RESOLUTIONS = {
    "1365x768": (1365, 768),
    "2048x1152": (2048, 1152),
    "2400x1080": (2400, 1080),
    "2556x1179": (2556, 1179),
}
REQUIRED_STATES = ("ding-que", "response-hu", "won", "ai-expanded")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_state_ui_capture.py <matrix-directory>", file=sys.stderr)
        return 2

    matrix_dir = Path(sys.argv[1]).expanduser().resolve()
    reports: list[dict] = []
    failures: list[str] = []
    for resolution, expected_size in EXPECTED_RESOLUTIONS.items():
        for state in REQUIRED_STATES:
            relative = Path(resolution) / f"{state}.png"
            path = matrix_dir / relative
            if not path.is_file():
                failures.append(f"缺少截图: {relative}")
                continue
            report, capture_failures = inspect_capture(path, expected_size)
            report["state"] = state
            report["resolution"] = resolution
            report["relative_path"] = str(relative)
            reports.append(report)
            failures.extend(f"{relative}: {failure}" for failure in capture_failures)

    output = {
        "expected_count": len(EXPECTED_RESOLUTIONS) * len(REQUIRED_STATES),
        "actual_count": len(reports),
        "captures": reports,
        "failures": failures,
    }
    report_path = matrix_dir / "state_capture_check_report.json"
    report_path.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for report in reports:
        print(
            f"{report['relative_path']}: black={report['black_ratio']:.4%}, "
            f"transparent={report['transparent_ratio']:.4%}, "
            f"bbox={report['content_bbox']}"
        )
    if failures:
        for failure in failures:
            print(f"FAILED: {failure}", file=sys.stderr)
        return 1
    print(f"SICHUAN STATE UI CAPTURE CHECK OK: {len(reports)}/{output['expected_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
