#!/usr/bin/env python3
"""Audit and transactionally reconcile the Xiaolaoshi video inventory.

The inventory is an index, not an authority.  A ``verified`` entry is valid only
when its bundle exists, has a successful persisted validation report with every
strict learning gate true, and the bundle validator succeeds with frame-hash
verification in the current run.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import shutil
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


REQUIRED_BUNDLE_FILES = (
    "source.mp4",
    "metadata.json",
    "knowledge-card.md",
    "evidence-index.json",
    "validation-report.json",
)


def read_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json_atomic(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def bundle_precheck(bundle: Path) -> list[str]:
    errors = [name for name in REQUIRED_BUNDLE_FILES if not (bundle / name).is_file()]
    report_path = bundle / "validation-report.json"
    if report_path.is_file():
        try:
            report = read_json(report_path)
            checks = report.get("checks", {}) if isinstance(report, dict) else {}
            required = (
                "frame_hashes_verified",
                "semantic_mastery",
                "low_traffic_gate",
                "ai_application_gate",
                "algorithm_abstraction_gate",
                "expert_learning_gate",
            )
            missing = [name for name in required if checks.get(name) is not True]
            if not isinstance(report, dict) or report.get("ok") is not True or missing:
                errors.append(
                    "validation-report.json is not strict-green "
                    "(requires ok=true plus frame_hashes_verified, semantic_mastery, low_traffic_gate, "
                    "ai_application_gate and algorithm_abstraction_gate=true)"
                )
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"invalid validation-report.json: {exc}")
    return errors


def validate_bundle(validator: Path, bundle: Path, persist_report: bool) -> tuple[bool, str]:
    command = [sys.executable, str(validator), str(bundle), "--verify-frame-hashes"]
    if persist_report:
        report = bundle / "validation-report.json"
        if report.is_file():
            backup = Path(tempfile.mkdtemp(prefix="pre-validation-", dir=bundle))
            shutil.copy2(report, backup / report.name)
        command.extend(["--report", str(bundle / "validation-report.json")])
    completed = subprocess.run(command, capture_output=True, text=True)
    detail = completed.stderr.strip() or completed.stdout.strip()
    return completed.returncode == 0, detail


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("inventory", type=Path)
    parser.add_argument("--validator", required=True, type=Path)
    parser.add_argument("--order", type=int, action="append", help="audit only these explicit orders; no default new checklist")
    parser.add_argument(
        "--repair",
        action="store_true",
        help="persist fresh reports and demote invalid verified entries atomically",
    )
    cfg = parser.parse_args()

    inventory_path = cfg.inventory.resolve()
    project_root = inventory_path.parents[2]
    validator = cfg.validator.resolve()
    inventory = read_json(inventory_path)
    if not isinstance(inventory, dict) or not isinstance(inventory.get("items"), list):
        raise SystemExit("inventory must be an object containing an items array")

    items = inventory["items"]
    video_ids = [str(item.get("video_id", "")) for item in items]
    orders = [item.get("order") for item in items]
    duplicate_ids = sorted(value for value, count in Counter(video_ids).items() if value and count > 1)
    duplicate_orders = sorted(value for value, count in Counter(orders).items() if value is not None and count > 1)
    global_errors: list[str] = []
    if any(not value for value in video_ids):
        global_errors.append("one or more items have an empty video_id")
    if duplicate_ids:
        global_errors.append(f"duplicate video_id values: {duplicate_ids}")
    if duplicate_orders:
        global_errors.append(f"duplicate order values: {duplicate_orders}")

    checked = 0
    valid = 0
    invalid: list[dict[str, object]] = []
    changed = False
    for item in items:
        if cfg.order and item.get("order") not in cfg.order:
            continue
        if item.get("learning_status") != "verified":
            continue
        checked += 1
        video_id = str(item.get("video_id", ""))
        configured_path = item.get("bundle_path")
        reasons: list[str] = []
        bundle: Path | None = None
        if not configured_path:
            reasons.append("verified entry has no bundle_path")
        else:
            bundle = (project_root / str(configured_path)).resolve()
            try:
                bundle.relative_to(project_root)
            except ValueError:
                reasons.append("bundle_path escapes project root")
            if bundle.name != video_id:
                reasons.append("bundle directory name does not match video_id")
            if not bundle.is_dir():
                reasons.append("bundle directory does not exist")

        if bundle and bundle.is_dir():
            if cfg.repair:
                ok, detail = validate_bundle(validator, bundle, persist_report=True)
                if not ok:
                    reasons.append(f"bundle validator failed: {detail[-1200:]}")
            reasons.extend(bundle_precheck(bundle))
            if not cfg.repair and not reasons:
                ok, detail = validate_bundle(validator, bundle, persist_report=False)
                if not ok:
                    reasons.append(f"bundle validator failed: {detail[-1200:]}")

        if reasons:
            invalid.append({"video_id": video_id, "order": item.get("order"), "reasons": reasons})
            if cfg.repair:
                item["learning_status"] = "needs_review"
                item["inventory_issue"] = {
                    "detected_at": datetime.now(timezone.utc).isoformat(),
                    "reasons": reasons,
                }
                changed = True
        else:
            valid += 1
            if cfg.repair and "inventory_issue" in item:
                del item["inventory_issue"]
                changed = True

    audit = {
        "ok": not global_errors and not invalid,
        "inventory": str(inventory_path),
        "total_items": len(items),
        "verified_checked": checked,
        "verified_valid": valid,
        "verified_invalid": len(invalid),
        "global_errors": global_errors,
        "invalid_entries": invalid,
        "repair_requested": cfg.repair,
        "inventory_changed": changed,
    }

    if cfg.repair:
        inventory["integrity"] = {
            "last_reconciled_at": datetime.now(timezone.utc).isoformat(),
            "verified_rule": "bundle + persisted strict-green report + fresh frame-hash validation",
            "verified_checked": checked,
            "verified_valid": valid,
            "verified_demoted": len(invalid),
        }
        write_json_atomic(inventory_path, inventory)

    print(json.dumps(audit, ensure_ascii=False, indent=2))
    return 0 if audit["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
