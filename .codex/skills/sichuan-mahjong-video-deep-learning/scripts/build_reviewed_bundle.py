#!/usr/bin/env python3
"""Publish explicit reviewed documents without manufacturing passing verdicts.

Legacy auto-certifying specs fail before writes. Publication is NOT validation.
The publisher preserves replaced artifacts and never advances queue state.
"""
from __future__ import annotations

import argparse
import json
import os
import tempfile
from pathlib import Path
from learning_quality import REVISION, sha256

DOCUMENTS = {"evidence-index.json", "public-timeline.json", "knowledge-units.json",
             "semantic-review.json", "analysis-plan.json", "subtitle-evidence.json",
             "ai-application-report.json", "knowledge-card.md", "learning-quality.json"}


def prepare(root: Path, spec_path: Path) -> dict[str, bytes]:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    if spec.get("revision") != REVISION or not isinstance(spec.get("reviewed_documents"), dict):
        raise ValueError("Legacy auto-certifying spec rejected; supply explicit expert_learning_v2 reviewed_documents. No files changed.")
    metadata = json.loads((root / "metadata.json").read_text(encoding="utf-8"))
    source_hash = sha256(root / "source.mp4")
    if str(spec.get("video_id")) != root.name or str(metadata.get("aweme_id")) != root.name or metadata.get("sha256") != source_hash:
        raise ValueError("source identity mismatch")
    documents = spec["reviewed_documents"]
    if set(documents) != DOCUMENTS:
        raise ValueError("reviewed_documents must name the complete document set")
    prepared = {}
    for name, ref in documents.items():
        path = (spec_path.parent / ref["path"]).resolve()
        if not path.is_relative_to(spec_path.parent.resolve()) or sha256(path) != ref.get("sha256"):
            raise ValueError(f"reviewed document hash/path mismatch: {name}")
        data = path.read_bytes()
        if name.endswith(".json"):
            obj = json.loads(data)
            if not isinstance(obj, dict):
                raise ValueError(f"expected object: {name}")
            if name == "learning-quality.json" and (obj.get("revision") != REVISION or obj.get("source_sha256") != source_hash):
                raise ValueError("learning-quality identity mismatch")
        prepared[name] = data
    return prepared


def publish(root: Path, documents: dict[str, bytes]) -> None:
    # Preflight precedes all writes; preserve every replaced file. Publication
    # interrupted between files must be recovered from this snapshot and checked.
    backup = Path(tempfile.mkdtemp(prefix="pre-review-", dir=root))
    for name in documents:
        target = root / name
        if target.exists():
            (backup / name).write_bytes(target.read_bytes())
    for name, data in documents.items():
        fd, temp = tempfile.mkstemp(prefix=".review-", dir=root)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temp, root / name)
        finally:
            Path(temp).unlink(missing_ok=True)
    print(json.dumps({"published": True, "validated": False, "backup": str(backup)}, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--spec", type=Path, required=True)
    args = parser.parse_args()
    try:
        root = args.bundle.resolve()
        publish(root, prepare(root, args.spec.resolve()))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, f"{exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
