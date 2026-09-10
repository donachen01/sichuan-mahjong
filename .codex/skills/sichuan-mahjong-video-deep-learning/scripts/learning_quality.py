#!/usr/bin/env python3
"""Fail-closed learning evidence contracts; passing is NOT proof of playing strength.

All references are bundle-relative, hash-bound files. No assertion or review is
invented here. Historical bundles lacking the contract require re-review.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from datetime import datetime
from pathlib import Path

REVISION = "expert_learning_v2"
STAGES = {"evidence_verified", "technique_understood", "validated_existing_algorithm",
          "candidate_implemented", "strength_improvement_verified"}
APPLIED = {"validated_existing_algorithm", "candidate_implemented", "strength_improvement_verified"}
LAYERS = {"observed_fact", "teacher_statement", "analyst_inference", "algorithm_hypothesis"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def require(condition: object, message: str) -> None:
    if not condition:
        raise ValueError(message)


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def instant(value: str) -> datetime:
    stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(stamp.tzinfo is not None, "timestamp must include timezone")
    return stamp


def unique(items: list, key: str) -> dict:
    require(isinstance(items, list) and items, f"empty {key} collection")
    result = {}
    for item in items:
        require(isinstance(item, dict) and nonempty(item.get(key)), f"missing {key}")
        require(item[key] not in result, f"duplicate {key}: {item[key]}")
        result[item[key]] = item
    return result


def artifact(root: Path, ref: dict) -> dict:
    require(isinstance(ref, dict) and nonempty(ref.get("path")), "missing artifact reference")
    path = (root / ref["path"]).resolve()
    require(path.is_relative_to(root.resolve()), "artifact must remain inside bundle")
    require(path.is_file() and sha256(path) == ref.get("sha256"), f"artifact hash mismatch: {path.name}")
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "artifact must be an object")
    return value


def binary_artifact(root: Path, ref: dict, expected_sha: str) -> None:
    path = (root / ref["path"]).resolve()
    require(path.is_relative_to(root.resolve()) and path.is_file(), "missing preserved runtime artifact")
    require(sha256(path) == ref.get("sha256") == expected_sha, "preserved runtime hash mismatch")


def assertions(result: dict, require_pass: bool = True) -> bool:
    checks = unique(result.get("assertions", []), "id")
    require(any(x.get("kind") == "final_action" for x in checks.values()), "missing final-action assertion")
    for check in checks.values():
        require("expected" in check and "observed" in check, "assertion lacks expected/observed")
        require(check.get("operator") in {"equals", "in", "range"}, "unsupported assertion operator")
        actual, expected = check["observed"], check["expected"]
        if check["operator"] == "equals":
            measured = actual == expected
        elif check["operator"] == "in":
            require(isinstance(expected, list) and expected, "invalid assertion membership")
            measured = actual in expected
        else:
            require(isinstance(expected, list) and len(expected) == 2, "invalid assertion interval")
            require(all(type(v) in (int, float) and math.isfinite(v) for v in [actual, *expected]), "nonfinite assertion")
            measured = expected[0] <= actual <= expected[1]
        require(check.get("passed") is measured, "assertion truth differs from passed flag")
        if check["kind"] == "final_action":
            require(actual == result.get("selected"), "final-action observation differs from actual selection")
        if check["kind"] == "candidate_score":
            require(actual == result.get("candidate_scores", {}).get(check.get("candidate")), "score observation differs from trace")
    passed = all(check["passed"] for check in checks.values())
    require(result.get("passed") is passed, "case truth differs from passed flag")
    if require_pass:
        require(passed, "runtime case did not pass")
    return passed


def runtime_case(root: Path, binding: dict, require_pass: bool = True) -> tuple[dict, dict]:
    report = artifact(root, binding["report"])
    fixture = artifact(root, binding["fixture"])
    require(report.get("input_sha256") == binding["fixture"]["sha256"], "runtime input mismatch")
    require(report.get("runner_kind") == "formal_csharp_entry", "not formal C# runtime")
    version = artifact(root, report["version_manifest"])
    for name in ("source_tree_sha256", "assembly_sha256", "rules_sha256", "runner_sha256"):
        value = version.get(name)
        require(isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value), f"invalid {name}")
        require(report.get(name) == value, f"runtime provenance mismatch: {name}")
    require(version.get("build_verified") is True, "source/assembly build not verified")
    require(isinstance(version.get("build_command"), list) and version["build_command"] and all(nonempty(x) for x in version["build_command"]), "missing build command argv")
    binary_artifact(root, version["assembly_artifact"], version["assembly_sha256"])
    binary_artifact(root, version["runner_artifact"], version["runner_sha256"])
    fixtures = unique(fixture.get("decision_cases", []), "id")
    results = unique(report.get("results", []), "id")
    require(set(fixtures) == set(results), "runtime did not return every fixture exactly once")
    require(report.get("ok") is all(r.get("passed") is True for r in results.values()), "report aggregate truth mismatch")
    case_id = binding.get("case_id")
    require(case_id in fixtures and case_id in results, "bound test ID absent from input or result")
    case, result = fixtures[case_id], results[case_id]
    require(case.get("decision_node_id") == binding.get("decision_node_id"), "fixture belongs to another node")
    require(result.get("decision_node_id") == binding.get("decision_node_id"), "result belongs to another node")
    require(case.get("visibility") == "public_only", "hidden information fixture")
    require(case.get("grounding") in {"verified_reconstruction", "synthetic_transfer"}, "unclassified fixture")
    require(isinstance(case.get("unknowns"), list), "unknown fields must be declared")
    require(nonempty(case.get("rule_variant")), "missing frozen rule variant")
    require(result.get("state_legality_passed") is True, "state legality not checked")
    assertions(result, require_pass=require_pass)
    expected = unique(case.get("assertions", []), "id")
    actual = unique(result["assertions"], "id")
    require(set(expected) == set(actual), "runtime dropped or invented assertions")
    for key in expected:
        for field in ("operator", "expected", "kind", "candidate"):
            require(expected[key].get(field) == actual[key].get(field), "expected assertion changed after execution")
    # Compare the actual public fixture, not node labels or rewritten assertions.
    state = {k: v for k, v in case.items() if k not in {"id", "decision_node_id", "assertions", "grounding", "unknowns"}}
    result = {**result, "fixture_state": state, "frozen_assertions": case["assertions"], "recorded_at": report.get("recorded_at")}
    return result, version


def changed_fields(before: dict, after: dict) -> set:
    return {key for key in set(before) | set(after) if before.get(key) != after.get(key)}


def suit_transform(state: dict, permutation: list) -> dict:
    require(sorted(permutation) == [0, 1, 2], "invalid suit permutation")
    require(permutation != [0, 1, 2], "identity is not a transfer test")
    mapping = str.maketrans({"spm"[i]: "spm"[permutation[i]] for i in range(3)})
    result = dict(state)
    for field in ("hand", "meld", "visible", "tile", "last_draw"):
        if field in result:
            result[field] = result[field].translate(mapping)
    result["dingque"] = [permutation[s] for s in state["dingque"]]
    if "public_replay" in state:
        # Transform tile identities, not enum/field names or evidence prose.
        replay = json.loads(json.dumps(state["public_replay"]))
        initial = replay["initial"]
        initial["hand"] = initial["hand"].translate(mapping)
        initial["discards"] = [[t.translate(mapping) for t in row] for row in initial["discards"]]
        for row in initial["melds"]:
            for meld in row:
                meld["tile"] = meld["tile"].translate(mapping)
        for event in replay["events"]:
            if event["tile"] is not None:
                event["tile"] = event["tile"].translate(mapping)
        result["public_replay"] = replay
    return result


def validate_transfer(kind: str, base: dict, trial: dict, config: dict) -> None:
    relation = config.get("expected_relation")
    if kind == "whole_state_suit_permutation":
        permutation = config["suit_permutation"]
        require(trial["fixture_state"] == suit_transform(base["fixture_state"], permutation), "not a whole-state suit transform")
        expected = base["selected"]
        if expected.startswith("Discard:"):
            expected = expected[:-1] + "spm"[permutation["spm".index(expected[-1])]]
        require(trial["selected"] == expected, "suit-transformed final action is not equivalent")
        require(relation == "equivalent_action", "invalid suit relation")
    elif kind == "outcome_invariance":
        require(trial["fixture_state"] == base["fixture_state"], "future outcomes changed policy inputs")
        require(relation == "identical_policy" and trial["selected"] == base["selected"] and trial["candidate_scores"] == base["candidate_scores"], "outcome affected policy")
    else:
        differences = changed_fields(base["fixture_state"], trial["fixture_state"])
        require(differences and differences == set(config.get("changed_fields", [])), "undeclared or missing changed premises")
        require(relation in {"action_changes", "scores_change", "same_action_rescored"}, "invalid structural relation")
        require(trial.get("candidate_scores") != base.get("candidate_scores"), "premise did not affect evaluation")
        if relation == "action_changes":
            require(trial["selected"] != base["selected"], "claimed reversal did not happen")
        elif relation == "same_action_rescored":
            require(trial["selected"] == base["selected"], "action unexpectedly changed")


def validate(root: Path, contract: dict | None = None) -> dict:
    root = root.resolve()
    errors = []
    stage = None
    try:
        require(not (root / "evidence-retraction.json").exists(),
                "evidence_retracted: independent re-review required")
        q = contract if contract is not None else json.loads((root / "learning-quality.json").read_text(encoding="utf-8"))
        require(q.get("revision") == REVISION, "legacy or missing expert-learning contract")
        stage = q.get("stage")
        require(stage in STAGES, "invalid learning stage")
        require(q.get("source_sha256") == sha256(root / "source.mp4"), "learning source mismatch")
        layers = unique(q.get("claims", []), "id")
        for claim in layers.values():
            require(claim.get("layer") in LAYERS, "claim must use exactly one evidence layer")
            require(nonempty(claim.get("text")), "missing claim text")
            require(isinstance(claim.get("unknowns"), list), "claim unknowns absent")
            if claim["layer"] in {"observed_fact", "teacher_statement"}:
                require(claim.get("evidence"), "source claim lacks evidence")
                for ref in claim["evidence"]:
                    path = (root / ref["path"]).resolve()
                    require(path.is_relative_to(root) and path.is_file() and sha256(path) == ref.get("sha256"), "claim frame hash mismatch")
                    require(type(ref.get("timestamp")) in (int, float) and math.isfinite(ref["timestamp"]) and ref["timestamp"] >= 0, "invalid evidence time")
            else:
                require(claim.get("depends_on") and set(claim["depends_on"]).issubset(layers), "untraced inference")
        def grounded(claim_id: str, visiting: set) -> None:
            require(claim_id not in visiting, "circular evidence justification")
            claim = layers[claim_id]
            if claim["layer"] in {"analyst_inference", "algorithm_hypothesis"}:
                for parent in claim["depends_on"]:
                    grounded(parent, visiting | {claim_id})
        for claim_id in layers:
            grounded(claim_id, set())
        nodes = unique(q.get("nodes", []), "id")
        index = json.loads((root / "evidence-index.json").read_text(encoding="utf-8"))
        require(set(nodes) == set(unique(index["decision_nodes"], "id")), "quality nodes do not cover evidence index")
        require(set(layers) == set(unique(index["claims"], "id")), "quality claims do not cover evidence index")
        for claim_id, claim in layers.items():
            indexed = next(x for x in index["claims"] if x["id"] == claim_id)
            require(indexed.get("claim") == claim["text"], "typed claim and index text diverge")
        if stage != "evidence_verified":
            thesis = q.get("core_thesis", {})
            for field in ("teacher_teaches", "why_not_alternatives", "algorithmic_problem", "uncertainty_and_limits"):
                require(nonempty(thesis.get(field)), f"core thesis missing {field}")
            for node in nodes.values():
                review = artifact(root, node["review"])
                require(review.get("decision_node_id") == node["id"], "review node mismatch")
                require(review.get("unresolved_critical_ambiguities") == [], "unresolved critical ambiguities")
                for field in ("reconstruction", "alternatives", "counterexample", "reversal_condition", "teacher_limitations"):
                    require(nonempty(review.get(field)), f"review missing {field}")
                blind = artifact(root, node["blind_prediction"])
                reveal = artifact(root, node["blind_reveal"])
                require(blind.get("decision_node_id") == node["id"], "blind node mismatch")
                require(reveal.get("prediction_sha256") == node["blind_prediction"]["sha256"], "blind prediction changed")
                require(blind.get("answer_exposed") is False and nonempty(blind.get("prediction")), "not a frozen blind prediction")
                require(instant(blind["frozen_at"]) < instant(reveal["revealed_at"]), "prediction not recorded before reveal")
                require(reveal.get("assessment") == "pass" and nonempty(reveal.get("comparison")), "blind transfer not reviewed")
        if stage in APPLIED:
            for node in nodes.values():
                require(nonempty(node.get("capability_id")), "node lacks capability ID")
                algorithm = node.get("algorithm", {})
                for field in ("public_inputs", "derived_state", "candidate_actions", "objective_terms", "components"):
                    require(isinstance(algorithm.get(field), list) and algorithm[field] and all(nonempty(x) for x in algorithm[field]), f"algorithm trace missing {field}")
                for field in ("update_rule", "reversal_condition", "visibility_review", "no_video_special_case_review"):
                    require(nonempty(algorithm.get(field)), f"algorithm trace missing {field}")
                baseline, baseline_version = runtime_case(root, {**node["baseline"], "decision_node_id": node["id"]}, require_pass=False)
                candidate, candidate_version = runtime_case(root, {**node["candidate"], "decision_node_id": node["id"]})
                require(all(p in candidate_version.get("source_files", {}) for p in algorithm["components"]), "algorithm component not bound to executed source version")
                require(baseline["fixture_state"] == candidate["fixture_state"], "baseline/candidate use different public states")
                require(baseline["frozen_assertions"] == candidate["frozen_assertions"], "candidate changed baseline acceptance targets")
                require(instant(baseline["recorded_at"]) <= instant(candidate["recorded_at"]), "baseline recorded after candidate")
                require(nonempty(node.get("discrepancy_reason")), "baseline discrepancy not diagnosed")
                require(node.get("discrepancy_class") in {"already_supported", "source_error", "rules", "features", "belief", "search", "teacher_uncertain"}, "unclassified discrepancy")
                mechanism = artifact(root, node["mechanism"])
                require(mechanism.get("decision_node_id") == node["id"], "mechanism node mismatch")
                require(mechanism.get("scale") in {"heuristic_score", "calibrated_expected_score"}, "undeclared score units")
                require(nonempty(mechanism.get("interpretation")), "missing causal interpretation")
                require(mechanism.get("kind") in {"ablation", "sensitivity"}, "missing causal experiment")
                control, control_version = runtime_case(root, {**mechanism["control"], "decision_node_id": node["id"]}, require_pass=False)
                treatment, treatment_version = runtime_case(root, {**mechanism["treatment"], "decision_node_id": node["id"]}, require_pass=False)
                if mechanism["kind"] == "sensitivity":
                    require(changed_fields(control["fixture_state"], treatment["fixture_state"]) == set(mechanism.get("changed_fields", [])) and mechanism.get("changed_fields"), "sensitivity changes not isolated")
                    require(control_version["assembly_sha256"] == treatment_version["assembly_sha256"] == candidate_version["assembly_sha256"], "sensitivity changed policy version")
                else:
                    require(control["fixture_state"] == treatment["fixture_state"], "ablation changed input state")
                    require(nonempty(mechanism.get("disabled_mechanism")), "ablation lacks disabled mechanism")
                    require(control_version["assembly_sha256"] != treatment_version["assembly_sha256"], "ablation did not change implementation")
                    require(treatment_version["assembly_sha256"] == candidate_version["assembly_sha256"], "ablation treatment is not candidate")
                require(control.get("candidate_scores") and treatment.get("candidate_scores"), "missing candidate score trace")
                require(control["candidate_scores"] != treatment["candidate_scores"], "no measured mechanism effect")
                if mechanism["scale"] == "calibrated_expected_score":
                    calibration = artifact(root, mechanism["calibration"])
                    from evaluate_calibration import evaluate as evaluate_calibration
                    calibration_plan = artifact(root, calibration["plan"])
                    calibration_samples = artifact(root, calibration["samples"])
                    require(calibration_plan.get("target") == "net_score", "expected score needs score calibration")
                    require(calibration_plan.get("model_version") == candidate_version["assembly_sha256"], "calibration belongs to another model")
                    require(evaluate_calibration(calibration_plan, calibration_samples)["accepted"], "calibration criteria not met")
                transfers = node.get("transfers", [])
                require(transfers, "missing targeted transfer tests")
                kinds = set()
                for transfer in transfers:
                    require(transfer.get("kind") in {"whole_state_suit_permutation", "structural_variant", "premise_break", "outcome_invariance"}, "invalid invariance; rank permutation is not symmetry")
                    require(nonempty(transfer.get("expected_relation")), "missing transfer expectation")
                    trial, trial_version = runtime_case(root, {**transfer, "decision_node_id": node["id"]})
                    require(trial_version["assembly_sha256"] == candidate_version["assembly_sha256"], "transfer used different policy")
                    validate_transfer(transfer["kind"], candidate, trial, transfer)
                    kinds.add(transfer["kind"])
                require({"whole_state_suit_permutation", "premise_break"}.issubset(kinds), "missing suit/premise evidence")
                if stage == "validated_existing_algorithm":
                    require(baseline["passed"], "failed baseline cannot claim existing capability")
                    require(all(baseline_version[k] == candidate_version[k] for k in ("source_tree_sha256", "assembly_sha256", "rules_sha256", "runner_sha256")) and node["discrepancy_class"] == "already_supported", "existing-algorithm claim uses changed implementation")
            registry = artifact(root, q["capability_registry"])
            capabilities = unique(registry.get("capabilities", []), "id")
            from capability_registry import validate_registry
            validate_registry(registry)
            for node in nodes.values():
                require(node["capability_id"] in capabilities, "capability absent from registry snapshot")
                capability = capabilities[node["capability_id"]]
                for field in ("mechanism", "boundaries", "evidence", "contradictions", "failure_cases", "code_components", "next_gap"):
                    require(field in capability, f"capability missing {field}")
                require(not any(c["status"] == "unresolved" for c in capability["contradictions"]), "unresolved capability contradiction")
        if stage == "strength_improvement_verified":
            strength = artifact(root, q["strength_report"])
            from evaluate_paired_strength import evaluate
            plan = artifact(root, strength["plan"])
            runs = artifact(root, strength["runs"])
            for node in nodes.values():
                _, base_version = runtime_case(root, {**node["baseline"], "decision_node_id": node["id"]}, require_pass=False)
                _, new_version = runtime_case(root, {**node["candidate"], "decision_node_id": node["id"]})
                require(plan.get("baseline_version") == base_version["assembly_sha256"] and plan.get("candidate_version") == new_version["assembly_sha256"], "strength experiment belongs to another implementation")
                require(plan.get("rules_sha256") == base_version["rules_sha256"] == new_version["rules_sha256"], "strength experiment changed rules")
            measured = evaluate(plan, runs)
            require(measured["promotable"], "strength promotion criteria not met")
    except (OSError, ValueError, TypeError, KeyError, AttributeError, IndexError) as exc:
        errors.append(str(exc))
    return {"ok": not errors, "revision": REVISION, "stage": stage,
            "algorithm_evidence_verified": not errors and stage in APPLIED,
            "strength_improvement_verified": not errors and stage == "strength_improvement_verified",
            "errors": errors, "scope": "Evidence integrity only; manual semantic truth and genuine blinding cannot be certified by field checks."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    report = validate(args.bundle)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
