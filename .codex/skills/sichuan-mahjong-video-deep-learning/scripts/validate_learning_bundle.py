#!/usr/bin/env python3
"""Validate the mechanical integrity of one Mahjong video learning bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

from learning_quality import REVISION, validate as validate_quality


def stage_satisfies(quality: dict, required: str) -> bool:
    if not quality.get("ok"):
        return False
    if required == "evidence":
        return True
    if required == "understanding":
        return quality.get("stage") != "evidence_verified"
    if required == "application":
        return quality.get("algorithm_evidence_verified") is True
    if required == "strength":
        return quality.get("strength_improvement_verified") is True
    raise ValueError("unknown required stage")


REQUIRED_CARD_SECTIONS = (
    "## 视频证据",
    "## 核心知识点",
    "## 公开信息时间线",
    "## 决策节点",
    "## 反事实",
    "## 迁移",
    "## 概率",
    "## AI 映射",
)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def read_json(path: Path, errors: list[str]) -> object | None:
    if not path.is_file():
        errors.append(f"missing file: {path.name}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"invalid JSON {path.name}: {exc}")
        return None


def probe_duration(source: Path, errors: list[str]) -> float:
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        errors.append("ffprobe is required")
        return 0.0
    completed = subprocess.run(
        [ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "json", str(source)],
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        errors.append(f"ffprobe failed: {completed.stderr.strip()}")
        return 0.0
    try:
        return float(json.loads(completed.stdout)["format"]["duration"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        errors.append("ffprobe returned no usable duration")
        return 0.0


def metadata_duration(metadata: dict) -> float:
    if "duration_seconds" in metadata:
        return float(metadata.get("duration_seconds") or 0)
    return float(metadata.get("probe", {}).get("format", {}).get("duration", 0) or 0)


def validate_manifests(
    root: Path,
    source_sha: str,
    duration: float,
    verify_hashes: bool,
    errors: list[str],
    warnings: list[str],
) -> dict[str, dict]:
    frame_records: dict[str, dict] = {}
    manifests = sorted((root / "artifacts").glob("*/frames.json"))
    if not manifests:
        errors.append("no frame manifests found under artifacts")
        return frame_records
    baseline_found = False
    keyframe_found = False
    for manifest_path in manifests:
        data = read_json(manifest_path, errors)
        if not isinstance(data, dict):
            continue
        if data.get("video_sha256") != source_sha:
            errors.append(f"source hash mismatch in {manifest_path.relative_to(root)}")
        records = data.get("frames")
        if not isinstance(records, list) or data.get("frame_count") != len(records):
            errors.append(f"frame count mismatch in {manifest_path.relative_to(root)}")
            continue
        if data.get("mode") == "baseline":
            baseline_found = True
            fps = float(data.get("fps") or 0)
            if fps >= 0.9 and len(records) + 2 < duration:
                errors.append("baseline frame coverage does not reach the video ending")
        if manifest_path.parent.name == "keyframe_verification" and data.get("mode") == "exact":
            keyframe_found = True
        for record in records:
            file_name = record.get("file", "")
            frame_path = manifest_path.parent / file_name
            relative = frame_path.relative_to(root).as_posix()
            if not frame_path.is_file():
                errors.append(f"missing frame: {relative}")
                continue
            timestamp = float(record.get("timestamp", -1))
            if timestamp < 0 or timestamp > duration + 0.25:
                errors.append(f"frame timestamp outside video: {relative} @ {timestamp}")
            if relative in frame_records:
                errors.append(f"duplicate frame path in manifests: {relative}")
            frame_records[relative] = record
            if verify_hashes and record.get("sha256") != digest(frame_path):
                errors.append(f"frame hash mismatch: {relative}")
        ocr_path = manifest_path.parent / "ocr.json"
        if ocr_path.is_file():
            ocr = read_json(ocr_path, errors)
            if isinstance(ocr, list):
                if len(ocr) != len(records):
                    errors.append(f"OCR/frame count mismatch in {ocr_path.relative_to(root)}")
                ocr_files = {str(item.get("file", "")) for item in ocr if isinstance(item, dict)}
                frame_files = {str(item.get("file", "")) for item in records if isinstance(item, dict)}
                if ocr_files != frame_files:
                    errors.append(f"OCR/frame file mismatch in {ocr_path.relative_to(root)}")
        else:
            errors.append(f"OCR missing for {manifest_path.parent.relative_to(root)}")
    if not baseline_found:
        errors.append("no baseline frame manifest")
    if not keyframe_found:
        errors.append("no exact keyframe verification manifest")
    contact_sheets = list((root / "artifacts" / "contact_sheets").glob("sheet_*.jpg"))
    if not contact_sheets:
        errors.append("no timestamped contact sheets")
    return frame_records


def validate_index(
    root: Path,
    index: dict,
    video_id: str,
    source_sha: str,
    duration: float,
    frame_records: dict[str, dict],
    errors: list[str],
) -> None:
    if index.get("schema_version") not in {1, 2, 3}:
        errors.append("evidence-index schema_version must be 1, 2, or 3")
    if str(index.get("video_id", "")) != video_id:
        errors.append("evidence-index video_id mismatch")
    if index.get("source_sha256") != source_sha:
        errors.append("evidence-index source_sha256 mismatch")
    if index.get("status") != "verified":
        errors.append("evidence-index status must be verified")
    claims = index.get("claims")
    if not isinstance(claims, list) or not claims:
        errors.append("evidence-index must contain claims")
        claims = []
    claim_ids: set[str] = set()
    for claim in claims:
        claim_id = str(claim.get("id", ""))
        if not claim_id or claim_id in claim_ids:
            errors.append(f"missing or duplicate claim id: {claim_id}")
        claim_ids.add(claim_id)
        grades = set(str(claim.get("grade", "")).split("+"))
        if not grades or not grades.issubset({"A", "B", "C", "D"}):
            errors.append(f"invalid evidence grade for {claim_id}")
        if not str(claim.get("claim", "")).strip() or not str(claim.get("reasoning_role", "")).strip():
            errors.append(f"claim text or reasoning_role missing: {claim_id}")
        start = float(claim.get("start_seconds", -1))
        end = float(claim.get("end_seconds", -1))
        if start < 0 or end < start or end > duration + 0.25:
            errors.append(f"invalid time range for {claim_id}")
        evidence = claim.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            errors.append(f"claim has no evidence: {claim_id}")
            continue
        for locator in evidence:
            relative = str(locator.get("file", ""))
            timestamp = float(locator.get("timestamp", -1))
            if relative not in frame_records:
                errors.append(f"unindexed evidence frame for {claim_id}: {relative}")
                continue
            manifest_timestamp = float(frame_records[relative].get("timestamp", -2))
            if abs(timestamp - manifest_timestamp) > 0.02:
                errors.append(f"evidence timestamp mismatch for {claim_id}: {relative}")
            if not (start - 1.1 <= timestamp <= end + 1.1):
                errors.append(f"evidence outside claim range for {claim_id}: {relative}")

    nodes = index.get("decision_nodes")
    if not isinstance(nodes, list) or not nodes:
        errors.append("evidence-index must contain decision_nodes")
        nodes = []
    required_chain = {"observations", "hypotheses", "constraints", "tradeoff", "choice"}
    for node in nodes:
        node_id = str(node.get("id", "unknown"))
        candidates = node.get("candidates")
        if not isinstance(candidates, list) or len(candidates) < 2:
            errors.append(f"decision node needs at least two candidates: {node_id}")
        if not str(node.get("selected", "")).strip() or not str(node.get("result", "")).strip():
            errors.append(f"decision node selection or result missing: {node_id}")
        chain = node.get("reasoning_chain")
        if not isinstance(chain, dict) or not required_chain.issubset(chain):
            errors.append(f"incomplete reasoning chain: {node_id}")
        linked = set(node.get("claim_ids", []))
        if not linked or not linked.issubset(claim_ids):
            errors.append(f"invalid claim links: {node_id}")

    counterfactuals = index.get("counterfactuals")
    required_counterfactuals = {"discard_order", "visible_tiles", "own_value_or_stage"}
    found_types = {item.get("type") for item in counterfactuals} if isinstance(counterfactuals, list) else set()
    if not required_counterfactuals.issubset(found_types):
        errors.append("counterfactuals must cover discard_order, visible_tiles, own_value_or_stage")
    transfers = index.get("transfer_tests")
    transfer_types = {item.get("type") for item in transfers} if isinstance(transfers, list) else set()
    if not {"similar", "broken_assumption"}.issubset(transfer_types):
        errors.append("transfer_tests need similar and broken_assumption cases")
    if index.get("status") == "verified":
        ai_claims = set(index.get("ai_mapping_claims", []))
        d_claims = {claim.get("id") for claim in claims if "D" in str(claim.get("grade", "")).split("+")}
        if ai_claims & d_claims:
            errors.append("D-grade claims cannot enter ai_mapping_claims")


def validate_semantic_mastery(root: Path, index: dict, duration: float, errors: list[str]) -> bool:
    """Validate the v2 semantic gate without weakening v1 evidence compatibility."""
    if index.get("schema_version") not in {2, 3}:
        return False
    timeline = read_json(root / "public-timeline.json", errors)
    units = read_json(root / "knowledge-units.json", errors)
    review = read_json(root / "semantic-review.json", errors)
    node_ids = {str(node.get("id", "")) for node in index.get("decision_nodes", []) if isinstance(node, dict)}
    claim_ids = {str(claim.get("id", "")) for claim in index.get("claims", []) if isinstance(claim, dict)}
    frame_records: dict[str, dict] = {}
    for manifest_path in (root / "artifacts").glob("*/frames.json"):
        manifest_errors: list[str] = []
        manifest = read_json(manifest_path, manifest_errors)
        if isinstance(manifest, dict):
            for record in manifest.get("frames", []):
                if isinstance(record, dict):
                    frame_records[(manifest_path.parent / str(record.get("file", ""))).relative_to(root).as_posix()] = record

    if not isinstance(timeline, dict) or not isinstance(timeline.get("events"), list) or not timeline["events"]:
        errors.append("semantic v2 requires non-empty public-timeline events")
    else:
        for event in timeline["events"]:
            required = {"id", "start_seconds", "end_seconds", "actor_seat", "event_type", "public_facts", "unknowns", "evidence"}
            if not isinstance(event, dict) or not required.issubset(event):
                errors.append("public timeline event is incomplete")
                continue
            start, end = float(event["start_seconds"]), float(event["end_seconds"])
            if start < 0 or end < start or end > duration + 0.25:
                errors.append(f"public timeline event outside video: {event.get('id', '?')}")
            if not isinstance(event["public_facts"], list) or not isinstance(event["unknowns"], list) or not isinstance(event["evidence"], list):
                errors.append(f"public timeline event has invalid collections: {event.get('id', '?')}")
                continue
            if not event["public_facts"] or not event["unknowns"] or not event["evidence"]:
                errors.append(f"public timeline event lacks facts, unknowns, or evidence: {event.get('id', '?')}")
            for locator in event["evidence"]:
                if not isinstance(locator, dict) or str(locator.get("claim_id", "")) not in claim_ids:
                    errors.append(f"public timeline event has invalid claim evidence: {event.get('id', '?')}")
                    continue
                relative = str(locator.get("file", ""))
                if relative not in frame_records:
                    errors.append(f"public timeline event has unindexed frame: {event.get('id', '?')}")
                    continue
                if abs(float(locator.get("timestamp", -1)) - float(frame_records[relative].get("timestamp", -2))) > 0.02:
                    errors.append(f"public timeline event frame timestamp mismatch: {event.get('id', '?')}")

    if not isinstance(units, dict) or not isinstance(units.get("knowledge_units"), list) or not units["knowledge_units"]:
        errors.append("semantic v2 requires non-empty knowledge units")
    else:
        required = {"id", "decision_node_ids", "trigger_conditions", "candidate_actions", "decision_principle", "daily_play_rule", "exclusions", "reversal_conditions", "probability_semantics", "evidence_grades"}
        covered_nodes: set[str] = set()
        required_text = {"decision_principle", "daily_play_rule", "probability_semantics"}
        required_lists = {"trigger_conditions", "candidate_actions", "exclusions", "reversal_conditions", "evidence_grades"}
        for unit in units["knowledge_units"]:
            if not isinstance(unit, dict) or not required.issubset(unit):
                errors.append("knowledge unit is incomplete")
                continue
            linked = set(unit["decision_node_ids"])
            if not linked or not linked.issubset(node_ids):
                errors.append(f"knowledge unit has invalid decision links: {unit.get('id', '?')}")
            covered_nodes.update(linked)
            if not isinstance(unit["candidate_actions"], list) or len(unit["candidate_actions"]) < 2:
                errors.append(f"knowledge unit needs two candidate actions: {unit.get('id', '?')}")
            for field in required_text:
                if not str(unit[field]).strip():
                    errors.append(f"knowledge unit lacks text: {unit.get('id', '?')} {field}")
            for field in required_lists:
                if not isinstance(unit[field], list) or not unit[field]:
                    errors.append(f"knowledge unit lacks list: {unit.get('id', '?')} {field}")
            abstraction = unit.get("algorithm_abstraction")
            abstraction_text = {"algorithmic_question"}
            abstraction_lists = {
                "state_variables",
                "action_space",
                "objective_terms",
                "invariants",
                "reversal_conditions",
            }
            if not isinstance(abstraction, dict):
                errors.append(f"knowledge unit lacks algorithm abstraction: {unit.get('id', '?')}")
            else:
                for field in abstraction_text:
                    if not str(abstraction.get(field, "")).strip():
                        errors.append(
                            f"knowledge unit algorithm abstraction lacks {field}: {unit.get('id', '?')}"
                        )
                for field in abstraction_lists:
                    if not isinstance(abstraction.get(field), list) or not abstraction[field]:
                        errors.append(
                            f"knowledge unit algorithm abstraction lacks {field}: {unit.get('id', '?')}"
                        )
        if not node_ids.issubset(covered_nodes):
            errors.append("knowledge units do not cover every decision node")

    if not isinstance(review, dict) or review.get("overall_status") != "semantically_mastered":
        errors.append("semantic review is not semantically_mastered")
        return False
    decisions = review.get("decision_reviews")
    if not isinstance(decisions, list) or not decisions:
        errors.append("semantic review needs decision reviews")
        return False
    reviewed = set()
    required_checks = {"reconstruction_passed", "candidate_comparison_passed", "counterfactual_passed", "transfer_blind_test_passed"}
    for decision in decisions:
        if not isinstance(decision, dict) or "decision_node_id" not in decision:
            errors.append("semantic decision review is incomplete")
            continue
        reviewed.add(str(decision["decision_node_id"]))
        if not required_checks.issubset(decision) or not all(bool(decision[key]) for key in required_checks):
            errors.append(f"semantic decision review failed: {decision.get('decision_node_id', '?')}")
        if decision.get("unresolved_critical_ambiguities"):
            errors.append(f"semantic decision retains critical ambiguity: {decision.get('decision_node_id', '?')}")
        for field in ("independent_reconstruction", "candidate_comparison", "counterfactual_prompt", "counterfactual_answer", "transfer_blind_prompt", "transfer_blind_answer"):
            if not str(decision.get(field, "")).strip():
                errors.append(f"semantic decision review lacks {field}: {decision.get('decision_node_id', '?')}")
    if not node_ids.issubset(reviewed):
        errors.append("semantic review does not cover every decision node")
    return not errors


def validate_low_traffic_v3(root: Path, index: dict, frame_records: dict[str, dict], errors: list[str]) -> bool:
    """Require reusable media, evidence references, and justified escalation for v3."""
    if index.get("schema_version") != 3:
        return False
    plan = read_json(root / "analysis-plan.json", errors)
    subtitles = read_json(root / "subtitle-evidence.json", errors)
    source_verification = read_json(root / "source-verification.json", errors)
    context_path = root / "evidence-context.json"
    context = read_json(context_path, errors)
    claim_ids = {str(claim.get("id", "")) for claim in index.get("claims", []) if isinstance(claim, dict)}
    decision_ids = {str(node.get("id", "")) for node in index.get("decision_nodes", []) if isinstance(node, dict)}

    if not isinstance(source_verification, dict) or source_verification.get("action") != "reuse_local_source":
        errors.append("low-traffic v3 requires a reusable local source verification")
    elif source_verification.get("source_sha256") != index.get("source_sha256") or str(source_verification.get("video_id", "")) != root.name:
        errors.append("source verification identity mismatch")

    if not isinstance(plan, dict) or plan.get("schema_version") != 3:
        errors.append("low-traffic v3 requires analysis-plan.json schema_version=3")
    else:
        baseline = plan.get("baseline")
        if not isinstance(baseline, dict) or baseline.get("fps") != 1 or not baseline.get("complete") or int(baseline.get("frame_count", 0)) <= 0:
            errors.append("analysis plan lacks complete 1 FPS baseline")
        if plan.get("source_sha256") != index.get("source_sha256") or str(plan.get("video_id", "")) != root.name:
            errors.append("analysis plan source identity mismatch")
        if plan.get("unresolved_ambiguities"):
            errors.append("analysis plan retains unresolved ambiguity")
        escalations = plan.get("sampling_escalations")
        if not isinstance(escalations, list) or not escalations:
            errors.append("analysis plan needs justified sampling escalations")
        else:
            covered: set[str] = set()
            required = {"id", "decision_node_ids", "trigger", "baseline_insufficiency", "sampling", "resolution", "evidence"}
            for item in escalations:
                if not isinstance(item, dict) or not required.issubset(item):
                    errors.append("sampling escalation is incomplete")
                    continue
                linked = set(item["decision_node_ids"])
                covered.update(linked)
                if not linked or not linked.issubset(decision_ids):
                    errors.append(f"sampling escalation has invalid decision link: {item.get('id', '?')}")
                if not all(str(item[field]).strip() for field in ("trigger", "baseline_insufficiency", "resolution")):
                    errors.append(f"sampling escalation lacks rationale: {item.get('id', '?')}")
                sampling = item["sampling"]
                is_high_fps = isinstance(sampling, dict) and float(sampling.get("fps", 0)) > 1
                is_exact = isinstance(sampling, dict) and sampling.get("mode") == "exact_timestamps" and isinstance(sampling.get("timestamps"), list) and sampling["timestamps"]
                if not isinstance(sampling, dict) or not (is_high_fps or is_exact) or sampling.get("start_seconds") is None or sampling.get("end_seconds") is None:
                    errors.append(f"sampling escalation lacks bounded high-detail window: {item.get('id', '?')}")
                if not isinstance(item["evidence"], list) or not item["evidence"]:
                    errors.append(f"sampling escalation lacks evidence: {item.get('id', '?')}")
            if not decision_ids.issubset(covered):
                errors.append("sampling escalations do not cover every decision node")

    if not isinstance(subtitles, dict) or subtitles.get("schema_version") != 3:
        errors.append("low-traffic v3 requires subtitle-evidence.json schema_version=3")
    else:
        links = subtitles.get("claim_links")
        if not isinstance(links, list):
            errors.append("subtitle evidence claim_links missing")
        else:
            linked = {str(item.get("claim_id", "")) for item in links if isinstance(item, dict) and item.get("status") == "cross_verified"}
            required_claims = {str(claim.get("id")) for claim in index.get("claims", []) if "A" in str(claim.get("grade", "")).split("+")}
            if not required_claims.issubset(linked):
                errors.append("A-grade claims lack subtitle/visual cross-verification")
            for item in links:
                if not isinstance(item, dict) or str(item.get("claim_id", "")) not in claim_ids:
                    errors.append("subtitle evidence has invalid claim link")
                    continue
                if item.get("status") != "cross_verified" or not str(item.get("verified_text", "")).strip():
                    errors.append(f"subtitle evidence is not cross-verified: {item.get('claim_id', '?')}")
                for field in ("text_evidence", "visual_evidence"):
                    evidence = item.get(field)
                    if not isinstance(evidence, list) or not evidence:
                        errors.append(f"subtitle evidence lacks {field}: {item.get('claim_id', '?')}")
                        continue
                    for locator in evidence:
                        relative = str(locator.get("file", "")) if isinstance(locator, dict) else ""
                        if relative not in frame_records:
                            errors.append(f"subtitle evidence has unindexed frame: {item.get('claim_id', '?')}")

    if not isinstance(context, dict) or context.get("schema_version") != 3:
        errors.append("low-traffic v3 requires evidence-context.json schema_version=3")
    else:
        if context_path.stat().st_size > 64 * 1024:
            errors.append("evidence context exceeds 64KiB")
        video = context.get("video")
        if not isinstance(video, dict) or video.get("id") != root.name or video.get("sha256") != index.get("source_sha256"):
            errors.append("evidence context video identity mismatch")
        references = context.get("claims")
        if not isinstance(references, list) or {str(item.get("id", "")) for item in references if isinstance(item, dict)} != claim_ids:
            errors.append("evidence context does not cover exactly the claims")
        forbidden = set(context.get("forbidden_payloads", []))
        if not {"source.mp4", "image_bytes", "audio_bytes", "temporary_media_url", "cookies"}.issubset(forbidden):
            errors.append("evidence context does not declare media/privacy exclusions")
    return not errors


def validate_ai_application(root: Path, index: dict, errors: list[str]) -> tuple[bool, bool]:
    """Require a no-peek implementation and a separately visible abstraction gate."""
    report = read_json(root / "ai-application-report.json", errors)
    if not isinstance(report, dict):
        errors.append("AI application report is missing or invalid")
        return False, False
    node_ids = {str(node.get("id", "")) for node in index.get("decision_nodes", []) if isinstance(node, dict)}
    project_root = root.parents[2]
    if report.get("schema_version") != 2:
        errors.append("AI application report schema_version must be 2")
    if str(report.get("video_id", "")) != root.name or report.get("source_sha256") != index.get("source_sha256"):
        errors.append("AI application report source identity mismatch")
    if set(map(str, report.get("decision_node_ids", []))) != node_ids:
        errors.append("AI application report must cover exactly every decision node")
    if report.get("learning_standard_revision") == "core_thesis_ai_v1":
        thesis = report.get("core_thesis")
        if not isinstance(thesis, dict):
            errors.append("core-thesis learning standard requires core_thesis")
        else:
            for field in ("statement", "algorithmic_problem", "objective", "mode_switch_rule"):
                if not str(thesis.get(field, "")).strip():
                    errors.append(f"core_thesis lacks {field}")
            for field in ("public_triggers", "reversal_conditions", "prohibited_learning"):
                if not isinstance(thesis.get(field), list) or not thesis[field]:
                    errors.append(f"core_thesis lacks {field}")
        trace = report.get("thesis_to_algorithm_trace")
        traced_ids: list[str] = []
        if not isinstance(trace, list) or not trace:
            errors.append("core-thesis learning standard requires thesis_to_algorithm_trace")
        else:
            for item in trace:
                if not isinstance(item, dict):
                    errors.append("thesis-to-algorithm trace item is invalid")
                    continue
                traced_ids.append(str(item.get("decision_node_id", "")))
                for field in ("evidence_windows", "public_inputs", "derived_state", "candidate_actions", "objective_terms", "components"):
                    if not isinstance(item.get(field), list) or not item[field]:
                        errors.append(f"thesis-to-algorithm trace lacks {field}: {item.get('decision_node_id', '?')}")
                if not str(item.get("mode_switch_or_reversal", "")).strip() or not str(item.get("implementation_status", "")).strip() or not str(item.get("runtime_artifact", "")).strip():
                    errors.append(f"thesis-to-algorithm trace is incomplete: {item.get('decision_node_id', '?')}")
            if len(traced_ids) != len(set(traced_ids)) or set(traced_ids) != node_ids:
                errors.append("thesis_to_algorithm_trace must cover every decision node exactly once")
    visibility = report.get("visibility_contract")
    if not isinstance(visibility, dict) or visibility.get("uses_hidden_information") is not False or not isinstance(visibility.get("public_inputs"), list) or not visibility["public_inputs"]:
        errors.append("AI application report lacks a no-peek public-input contract")
    abstraction_errors: list[str] = []
    abstraction = report.get("abstraction_contract")
    if not isinstance(abstraction, dict):
        abstraction_errors.append("AI application report lacks abstraction_contract")
    else:
        if not str(abstraction.get("algorithmic_question", "")).strip():
            abstraction_errors.append("abstraction_contract lacks algorithmic_question")
        for field in ("state_variables", "action_space", "objective_terms", "invariants"):
            if not isinstance(abstraction.get(field), list) or not abstraction[field]:
                abstraction_errors.append(f"abstraction_contract lacks {field}")
        if abstraction.get("runtime_video_specific_literals") is not False:
            abstraction_errors.append("runtime_video_specific_literals must be false")

    mappings = report.get("node_mappings")
    mapped_ids: list[str] = []
    if not isinstance(mappings, list) or not mappings:
        abstraction_errors.append("AI application report lacks node_mappings")
    else:
        for mapping in mappings:
            if not isinstance(mapping, dict):
                abstraction_errors.append("AI node mapping is invalid")
                continue
            node_id = str(mapping.get("decision_node_id", ""))
            mapped_ids.append(node_id)
            if not str(mapping.get("principle", "")).strip():
                abstraction_errors.append(f"AI node mapping lacks principle: {node_id or '?'}")
            if not isinstance(mapping.get("algorithm_inputs"), list) or not mapping["algorithm_inputs"]:
                abstraction_errors.append(f"AI node mapping lacks algorithm_inputs: {node_id or '?'}")
            if not str(mapping.get("algorithm_output", "")).strip():
                abstraction_errors.append(f"AI node mapping lacks algorithm_output: {node_id or '?'}")
            components = mapping.get("components")
            if not isinstance(components, list) or not components:
                abstraction_errors.append(f"AI node mapping lacks components: {node_id or '?'}")
            else:
                for relative in components:
                    if not isinstance(relative, str) or not (project_root / relative).is_file():
                        abstraction_errors.append(f"AI node mapping component missing: {relative}")
        if len(mapped_ids) != len(set(mapped_ids)) or set(mapped_ids) != node_ids:
            abstraction_errors.append("AI node_mappings must cover every decision node exactly once")

    implementation = report.get("implementation")
    implementation_statuses = {
        "implemented_new_algorithm",
        "extended_shared_algorithm",
        "validated_existing_algorithm",
    }
    if not isinstance(implementation, dict) or implementation.get("status") not in implementation_statuses or not str(implementation.get("behavior", "")).strip() or not isinstance(implementation.get("component_paths"), list) or not implementation["component_paths"]:
        errors.append("AI application report lacks implementation evidence")
    else:
        for relative in implementation["component_paths"]:
            if not isinstance(relative, str) or not (project_root / relative).is_file():
                errors.append(f"AI implementation path missing: {relative}")

    anti_overfit = report.get("anti_overfit_review")
    forbidden_flags = (
        "hard_coded_video_id",
        "fixed_tile_sequence_trigger",
        "tile_name_specific_multiplier",
        "outcome_leakage",
        "single_video_numeric_weight",
    )
    if not isinstance(anti_overfit, dict):
        abstraction_errors.append("AI application report lacks anti_overfit_review")
    else:
        for field in forbidden_flags:
            if anti_overfit.get(field) is not False:
                abstraction_errors.append(f"anti_overfit_review {field} must be false")
        audited_paths = anti_overfit.get("audited_component_paths")
        if not isinstance(audited_paths, list) or not audited_paths:
            abstraction_errors.append("anti_overfit_review lacks audited_component_paths")
        else:
            for relative in audited_paths:
                if not isinstance(relative, str) or not (project_root / relative).is_file():
                    abstraction_errors.append(f"anti-overfit audited path missing: {relative}")

    generalization = report.get("generalization_evidence")
    required_generalization = {
        "suit_rotation",
        "structural_variant",
        "broken_assumption",
        "outcome_invariance",
    }
    passed_generalization: set[str] = set()
    if not isinstance(generalization, list):
        abstraction_errors.append("AI application report lacks generalization_evidence")
    else:
        for item in generalization:
            if not isinstance(item, dict):
                abstraction_errors.append("AI generalization evidence is invalid")
                continue
            kind = str(item.get("kind", ""))
            if item.get("passed") is True:
                passed_generalization.add(kind)
            if not str(item.get("test_case_id", "")).strip() or not str(item.get("command", "")).strip() or not str(item.get("artifact", "")).strip():
                abstraction_errors.append(f"AI generalization evidence is incomplete: {kind or '?'}")
                continue
            if not (project_root / str(item["artifact"])).is_file():
                abstraction_errors.append(f"AI generalization artifact missing: {item['artifact']}")
        if not required_generalization.issubset(passed_generalization):
            abstraction_errors.append("AI generalization needs suit_rotation, structural_variant, broken_assumption, and outcome_invariance")

    calibration = report.get("calibration")
    if not isinstance(calibration, dict):
        abstraction_errors.append("AI application report lacks calibration")
    else:
        if calibration.get("video_derived_numeric_weights") is not False:
            abstraction_errors.append("video_derived_numeric_weights must be false")
        mode = calibration.get("mode")
        if mode not in {"qualitative_or_existing_calibration", "multi_source_calibrated"}:
            abstraction_errors.append("AI calibration mode is invalid")
        if mode == "multi_source_calibrated":
            if not isinstance(calibration.get("sources"), list) or len(calibration["sources"]) < 2:
                abstraction_errors.append("multi-source calibration needs at least two sources")
            if calibration.get("train_holdout_separated") is not True:
                abstraction_errors.append("multi-source calibration needs train/holdout separation")
    conflict = report.get("conflict_review")
    if not isinstance(conflict, dict) or conflict.get("status") != "resolved" or not isinstance(conflict.get("known_boundaries"), list) or not conflict["known_boundaries"]:
        errors.append("AI application conflict review is unresolved or incomplete")
    tests = report.get("test_evidence")
    if not isinstance(tests, list):
        errors.append("AI application report lacks test evidence")
    else:
        kinds = {str(item.get("kind", "")) for item in tests if isinstance(item, dict) and item.get("passed") is True}
        if not {"focused", "csharp_runtime"}.issubset(kinds):
            errors.append("AI application needs passing focused and csharp_runtime evidence")
        project_root = root.parents[2]
        for item in tests:
            if not isinstance(item, dict) or not str(item.get("command", "")).strip() or not str(item.get("artifact", "")).strip() or item.get("passed") is not True:
                errors.append("AI application test evidence is incomplete")
                continue
            if not (project_root / str(item["artifact"])).is_file():
                errors.append(f"AI application test artifact missing: {item['artifact']}")
    if report.get("completion_status") != "algorithmically_implemented_and_verified":
        errors.append("AI application completion_status must be algorithmically_implemented_and_verified")
    errors.extend(abstraction_errors)
    algorithm_abstraction_gate = not abstraction_errors
    return not errors, algorithm_abstraction_gate


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--verify-frame-hashes", action="store_true")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--required-stage", choices=("evidence", "understanding", "application", "strength"), default="application")
    cfg = parser.parse_args()
    root = cfg.bundle.resolve()
    errors: list[str] = []
    warnings: list[str] = []
    checks: dict[str, object] = {}
    retracted = (root / "evidence-retraction.json").is_file()
    if retracted and cfg.required_stage != "evidence":
        errors.append("evidence_retracted: independent re-review required; historical green report is not authoritative")
    quality = validate_quality(root)
    quality_contract = None
    if (root / "learning-quality.json").is_file():
        quality_contract = read_json(root / "learning-quality.json", errors)
    uses_v2 = isinstance(quality_contract, dict) and quality_contract.get("revision") == REVISION

    source = root / "source.mp4"
    if not source.is_file():
        errors.append("missing file: source.mp4")
        source_sha = ""
        duration = 0.0
    else:
        source_sha = digest(source)
        duration = probe_duration(source, errors)
    metadata = read_json(root / "metadata.json", errors)
    index = read_json(root / "evidence-index.json", errors)
    card_path = root / "knowledge-card.md"
    card = card_path.read_text(encoding="utf-8") if card_path.is_file() else ""
    if not card:
        errors.append("missing file: knowledge-card.md")

    video_id = root.name
    if isinstance(metadata, dict):
        metadata_id = str(metadata.get("aweme_id", ""))
        if metadata_id != video_id:
            errors.append("metadata aweme_id does not match bundle directory")
        if metadata.get("sha256") != source_sha:
            errors.append("metadata source hash mismatch")
        if video_id not in str(metadata.get("canonical_url", "")):
            errors.append("metadata canonical_url does not identify the target video")
        if int(metadata.get("file_size", -1)) != (source.stat().st_size if source.is_file() else -2):
            errors.append("metadata source size mismatch")
        declared_duration = metadata_duration(metadata)
        if abs(declared_duration - duration) > 0.05:
            errors.append("metadata duration mismatch")

    frame_records = validate_manifests(
        root, source_sha, duration, cfg.verify_frame_hashes, errors, warnings
    )
    semantic_mastery = False
    low_traffic_gate = False
    ai_application_gate = False
    algorithm_abstraction_gate = False
    if isinstance(index, dict):
        validate_index(root, index, video_id, source_sha, duration, frame_records, errors)
        # Each gate must retain its own result.  Reporting a later AI-application
        # failure must not retroactively label independently valid semantic or
        # low-traffic evidence as failed.
        if uses_v2:
            # V2 owns semantic truth records and per-node tests. Do not require
            # the legacy auto-filled booleans or "already completed" marker.
            semantic_mastery = quality["ok"] and quality["stage"] != "evidence_verified"
        else:
            semantic_errors: list[str] = []
            semantic_mastery = validate_semantic_mastery(root, index, duration, semantic_errors)
            errors.extend(semantic_errors)
        low_traffic_errors: list[str] = []
        low_traffic_gate = validate_low_traffic_v3(root, index, frame_records, low_traffic_errors)
        errors.extend(low_traffic_errors)
        if index.get("schema_version") == 3:
            semantic_mastery = semantic_mastery and low_traffic_gate
        if uses_v2:
            ai_application_gate = algorithm_abstraction_gate = quality["algorithm_evidence_verified"]
        else:
            ai_errors: list[str] = []
            ai_application_gate, algorithm_abstraction_gate = validate_ai_application(root, index, ai_errors)
            errors.extend(ai_errors)

    for section in REQUIRED_CARD_SECTIONS:
        if section not in card:
            errors.append(f"knowledge card missing section prefix: {section}")
    if uses_v2:
        if f"学习阶段：{quality['stage']}" not in card:
            errors.append("knowledge card learning stage differs from v2 contract")
    else:
        if "状态：已吃透" not in card:
            errors.append("knowledge card is not marked 已吃透")
        if "状态：回看中" in card:
            errors.append("knowledge card still contains 回看中 status")
    if "evidence-index.json" not in card:
        errors.append("knowledge card does not link evidence-index.json")

    checks.update({
        "video_id": video_id,
        "source_sha256": source_sha,
        "duration_seconds": round(duration, 6),
        "frame_records": len(frame_records),
        "contact_sheets": len(list((root / "artifacts" / "contact_sheets").glob("sheet_*.jpg"))),
        "claims": len(index.get("claims", [])) if isinstance(index, dict) else 0,
        "decision_nodes": len(index.get("decision_nodes", [])) if isinstance(index, dict) else 0,
        "counterfactuals": len(index.get("counterfactuals", [])) if isinstance(index, dict) else 0,
        "transfer_tests": len(index.get("transfer_tests", [])) if isinstance(index, dict) else 0,
        "frame_hashes_verified": cfg.verify_frame_hashes,
        "semantic_mastery": semantic_mastery,
        "low_traffic_gate": low_traffic_gate,
        "ai_application_gate": ai_application_gate,
        "algorithm_abstraction_gate": algorithm_abstraction_gate,
    })
    checks["expert_learning_gate"] = quality["ok"]
    checks["learning_stage"] = quality["stage"]
    checks["strength_improvement_verified"] = quality["strength_improvement_verified"]
    if not quality["algorithm_evidence_verified"]:
        checks["ai_application_gate"] = False
        checks["algorithm_abstraction_gate"] = False
    errors.extend(f"expert_learning_v2: {error}" for error in quality["errors"])
    checks["required_stage"] = cfg.required_stage
    if retracted:
        checks["semantic_mastery"] = False
        checks["expert_learning_gate"] = False
        checks["ai_application_gate"] = False
        checks["algorithm_abstraction_gate"] = False
        checks["strength_improvement_verified"] = False
        checks["learning_stage"] = "needs_independent_review"
    if not stage_satisfies(quality, cfg.required_stage):
        errors.append(f"expert_learning_v2: {cfg.required_stage} stage not met")
    report = {"ok": not errors, "checks": checks, "warnings": warnings, "errors": errors}
    if cfg.report:
        cfg.report.parent.mkdir(parents=True, exist_ok=True)
        cfg.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
