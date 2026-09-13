#!/usr/bin/env python3
"""Validate a phase-one Xiao teacher knowledge note without claiming AI validation."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


CAPABILITY_RELATIONS = {
    "new_candidate",
    "support",
    "boundary",
    "contradiction",
    "duplicate",
    "no_technique",
}
REVERSAL_PROVENANCE = {"teacher_explicit", "analyst_hypothesis"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def require_text(obj: dict, field: str, errors: list[str]) -> None:
    if not nonempty(obj.get(field)):
        errors.append(f"{field} must be non-empty text")


def validate_evidence_ref(bundle: Path, ref: object, duration: float, label: str, errors: list[str]) -> None:
    if not isinstance(ref, dict):
        errors.append(f"{label} must be an evidence object")
        return
    rel = ref.get("path")
    if not nonempty(rel):
        errors.append(f"{label}.path must be non-empty")
        return
    path = (bundle / rel).resolve()
    try:
        path.relative_to(bundle.resolve())
    except ValueError:
        errors.append(f"{label}.path escapes bundle")
        return
    if not path.is_file():
        errors.append(f"{label}.path does not exist: {rel}")
        return
    expected = ref.get("sha256")
    if not nonempty(expected) or sha256(path) != expected:
        errors.append(f"{label}.sha256 does not match {rel}")
    timestamp = ref.get("timestamp_seconds")
    if not isinstance(timestamp, (int, float)) or isinstance(timestamp, bool):
        errors.append(f"{label}.timestamp_seconds must be numeric")
    elif timestamp < 0 or timestamp > duration + 0.5:
        errors.append(f"{label}.timestamp_seconds is outside video duration")


def validate(bundle: Path) -> dict:
    errors: list[str] = []
    note_path = bundle / "knowledge-note.json"
    source_path = bundle / "source.mp4"
    verification_path = bundle / "source-verification.json"
    if not note_path.is_file():
        return {"ok": False, "stage": "knowledge_note", "errors": ["knowledge-note.json is missing"]}
    try:
        note = read_json(note_path)
        verification = read_json(verification_path)
    except ValueError as exc:
        return {"ok": False, "stage": "knowledge_note", "errors": [str(exc)]}

    if note.get("schema_version") != 1:
        errors.append("schema_version must equal 1")
    if note.get("status") != "knowledge_note_complete":
        errors.append("status must equal knowledge_note_complete")
    if not source_path.is_file():
        errors.append("source.mp4 is missing")

    identity = note.get("video")
    if not isinstance(identity, dict):
        errors.append("video must be an object")
        identity = {}
    for field in ("video_id", "title", "source_path", "source_sha256"):
        require_text(identity, field, errors)
    if identity.get("source_path") != "source.mp4":
        errors.append("video.source_path must equal source.mp4")
    expected_id = str(verification.get("video_id") or verification.get("aweme_id") or "")
    if expected_id and str(identity.get("video_id")) != expected_id:
        errors.append("video.video_id does not match source-verification.json")
    expected_hash = str(verification.get("sha256") or verification.get("source_sha256") or "")
    if source_path.is_file():
        actual_hash = sha256(source_path)
        if identity.get("source_sha256") != actual_hash:
            errors.append("video.source_sha256 does not match source.mp4")
        if expected_hash and expected_hash != actual_hash:
            errors.append("source-verification hash does not match source.mp4")
    duration = verification.get("duration_seconds") or verification.get("duration")
    if not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0:
        errors.append("source-verification duration must be positive")
        duration = 0.0

    review = note.get("full_video_review")
    if not isinstance(review, dict):
        errors.append("full_video_review must be an object")
        review = {}
    if review.get("reviewed_from_start") is not True or review.get("reviewed_to_end") is not True:
        errors.append("full_video_review must confirm start-to-end review")
    require_text(review, "method", errors)

    thesis = note.get("core_thesis")
    if not isinstance(thesis, dict):
        errors.append("core_thesis must be an object")
        thesis = {}
    for field in ("teacher_teaches", "decision_problem", "reasoning"):
        require_text(thesis, field, errors)

    observations = note.get("public_observations")
    if not isinstance(observations, list) or not observations:
        errors.append("public_observations must be a non-empty list")
        observations = []
    for index, observation in enumerate(observations):
        if not isinstance(observation, dict):
            errors.append(f"public_observations[{index}] must be an object")
            continue
        require_text(observation, "observation", errors)
        evidence = observation.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            errors.append(f"public_observations[{index}].evidence must be non-empty")
            continue
        for ref_index, ref in enumerate(evidence):
            validate_evidence_ref(bundle, ref, float(duration), f"public_observations[{index}].evidence[{ref_index}]", errors)

    candidates = note.get("candidate_actions")
    if not isinstance(candidates, list):
        errors.append("candidate_actions must be a list")
        candidates = []
    for index, candidate in enumerate(candidates):
        if not isinstance(candidate, dict):
            errors.append(f"candidate_actions[{index}] must be an object")
            continue
        for field in ("action", "assessment", "reason"):
            require_text(candidate, field, errors)

    reversals = note.get("reversal_conditions")
    if not isinstance(reversals, list):
        errors.append("reversal_conditions must be a list")
        reversals = []
    for index, reversal in enumerate(reversals):
        if not isinstance(reversal, dict):
            errors.append(f"reversal_conditions[{index}] must be an object")
            continue
        if reversal.get("provenance") not in REVERSAL_PROVENANCE:
            errors.append(f"reversal_conditions[{index}].provenance is invalid")
        require_text(reversal, "condition", errors)
        require_text(reversal, "effect", errors)
    if not reversals and not nonempty(note.get("reversal_unknown_reason")):
        errors.append("provide reversal_conditions or a non-empty reversal_unknown_reason")

    unknowns = note.get("unknowns")
    if not isinstance(unknowns, list) or any(not nonempty(item) for item in unknowns):
        errors.append("unknowns must be a list of non-empty strings (an empty list is allowed)")
    require_text(note, "outcome_separation", errors)

    links = note.get("capability_links")
    if not isinstance(links, list) or not links:
        errors.append("capability_links must be a non-empty list")
        links = []
    no_technique = False
    for index, link in enumerate(links):
        if not isinstance(link, dict):
            errors.append(f"capability_links[{index}] must be an object")
            continue
        relation = link.get("relation")
        if relation not in CAPABILITY_RELATIONS:
            errors.append(f"capability_links[{index}].relation is invalid")
        no_technique = no_technique or relation == "no_technique"
        require_text(link, "reason", errors)
        if relation != "no_technique" and not nonempty(link.get("capability_id")):
            errors.append(f"capability_links[{index}].capability_id is required")
    if not no_technique and len(candidates) < 2:
        errors.append("a technique note must compare at least two candidate actions")

    return {
        "ok": not errors,
        "stage": "knowledge_note",
        "knowledge_status": "knowledge_note_complete" if not errors else "reviewing",
        "video_id": identity.get("video_id"),
        "note_sha256": sha256(note_path),
        "errors": errors,
        "claims_ai_validated": False,
        "claims_strength_improved": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = validate(args.bundle.resolve())
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
