"""Complete contract-path tests. ALL semantic/runtime data here are synthetic.

These tests validate the skill's evidence-handling behavior, not Mahjong mastery
or improved playing strength. No video bundle or queue is touched.
"""
import copy
import json
import tempfile
import unittest
import io
import contextlib
from pathlib import Path
from unittest.mock import patch

from learning_quality import REVISION, validate, sha256
from capability_registry import merge, validate_registry
from build_reviewed_bundle import DOCUMENTS, prepare, publish
from rebuild_existing_algorithm_bundle import rebuild
from upgrade_historical_algorithm_contracts import upgrade_bundle


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="skill-contract-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # Not an MP4; deliberately never passed to the media validator.
        (self.root / "source.mp4").write_bytes(b"synthetic contract test, not source video")
        self.source_hash = sha256(self.root / "source.mp4")
        self.save("metadata.json", {"aweme_id": self.root.name, "sha256": self.source_hash})
        self.save("evidence-index.json", {"claims": [{"id": "C1", "claim": "Synthetic reviewed observation"}], "decision_nodes": [{"id": "D1"}]})
        self.state = {"kind": "reaction", "hand": "25677789s99m", "meld": "222m", "visible": "7s", "tile": "7s", "dingque": [1, 2, 0, 1], "wall": 40}

    def save(self, name, obj):
        path = self.root / name
        path.write_text(json.dumps(obj), encoding="utf-8")
        return {"path": name, "sha256": sha256(path)}

    def run_binding(self, name, state=None, selected="Peng", expected="Peng", value=10, version="a"):
        state = copy.deepcopy(state or self.state)
        check = {"id": "action", "kind": "final_action", "operator": "equals", "expected": expected}
        case = {**state, "id": "case", "decision_node_id": "D1", "visibility": "public_only", "grounding": "synthetic_transfer", "unknowns": ["unit test only"], "rule_variant": "project_default", "assertions": [check]}
        inp = self.save(name + "-input.json", {"decision_cases": [case]})
        ver = {k: version * 64 for k in ("source_tree_sha256", "assembly_sha256", "rules_sha256", "runner_sha256")}
        ver.update(build_verified=True, build_command=["dotnet", "build"])
        ver["rules_sha256"] = "c" * 64
        ver["source_files"] = {"FormalEntry": "a" * 64}
        for field, key in (("assembly_artifact", "assembly_sha256"), ("runner_artifact", "runner_sha256")):
            path = self.root / (name + field + ".bin")
            path.write_bytes((version + " synthetic test artifact, not executable").encode())
            ver[key] = sha256(path)
            ver[field] = {"path": path.name, "sha256": ver[key]}
        version_ref = self.save(name + "-version.json", ver)
        passed = selected == expected
        result = {"id": "case", "decision_node_id": "D1", "passed": passed, "state_legality_passed": True, "selected": selected, "candidate_scores": {"peng": value, "gang": 1}, "assertions": [{**check, "observed": selected, "passed": passed}]}
        report = {**ver, "ok": passed, "runner_kind": "formal_csharp_entry", "version_manifest": version_ref, "input_sha256": inp["sha256"], "results": [result], "recorded_at": "2026-09-05T10:00:00+00:00"}
        return {"report": self.save(name + "-report.json", report), "fixture": inp, "case_id": "case"}

    def contract(self, changed=False):
        q = {"revision": REVISION, "source_sha256": self.source_hash, "stage": "candidate_implemented" if changed else "validated_existing_algorithm", "claims": [{"id": "C1", "text": "Synthetic reviewed observation", "layer": "observed_fact", "unknowns": [], "evidence": [{"path": "source.mp4", "sha256": self.source_hash, "timestamp": 0}]}],
             "core_thesis": {"teacher_teaches": "Compare action successors", "why_not_alternatives": "Immediate income may lose tempo", "algorithmic_problem": "Compare legal action successors", "uncertainty_and_limits": "Not fixed tile instructions"}}
        node = {"id": "D1", "capability_id": "meld-tempo", "discrepancy_class": "features" if changed else "already_supported", "discrepancy_reason": "Missing successor cost" if changed else "Existing evaluator covers the case"}
        q["nodes"] = [node]
        node["algorithm"] = {"public_inputs": ["own hand", "public counts", "wall"], "derived_state": ["successor hand readiness"], "candidate_actions": ["Peng", "Gang", "Pass"], "objective_terms": ["immediate income", "tempo"], "components": ["FormalEntry"], "update_rule": "Evaluate all successors under the same public information", "reversal_condition": "Gang preserves tempo", "visibility_review": "No concealed opponent hand is provided", "no_video_special_case_review": "No video ID or tile sequence in policy"}
        node["review"] = self.save("review.json", {"decision_node_id": "D1", "reconstruction": "Explicit known-state reconstruction", "alternatives": "Compare Peng/Gang/Pass", "counterexample": "Gang keeps ready hand", "reversal_condition": "Successor gains outweigh lost tempo", "teacher_limitations": "Hidden draws unknown", "unresolved_critical_ambiguities": []})
        node["blind_prediction"] = self.save("prediction.json", {"decision_node_id": "D1", "prediction": "Peng under declared premises", "answer_exposed": False, "frozen_at": "2026-09-05T08:00:00+00:00"})
        node["blind_reveal"] = self.save("reveal.json", {"prediction_sha256": node["blind_prediction"]["sha256"], "revealed_at": "2026-09-05T09:00:00+00:00", "assessment": "pass", "comparison": "Prediction and declared reference agree"})
        node["baseline"] = self.run_binding("base", selected="Gang" if changed else "Peng", version="b" if changed else "a")
        node["candidate"] = self.run_binding("new")
        altered = {**self.state, "wall": 4}
        treatment = self.run_binding("sensitivity", state=altered, value=3)
        node["mechanism"] = self.save("mechanism.json", {"decision_node_id": "D1", "kind": "sensitivity", "scale": "heuristic_score", "interpretation": "Wall horizon changes action evaluation; this synthetic trace tests the contract only", "changed_fields": ["wall"], "control": node["candidate"], "treatment": treatment})
        from learning_quality import suit_transform
        suit = self.run_binding("suit", state=suit_transform(self.state, [1, 2, 0]))
        node["transfers"] = [{**suit, "kind": "whole_state_suit_permutation", "expected_relation": "equivalent_action", "suit_permutation": [1, 2, 0]}, {**treatment, "kind": "premise_break", "expected_relation": "same_action_rescored", "changed_fields": ["wall"]}]
        registry = {"schema_version": 1, "capabilities": [{"id": "meld-tempo", "mechanism": "Compare successor tempo", "boundaries": ["Public states only"], "code_components": ["FormalEntry"], "evidence": [{"source_group_id": "game1", "video_id": "video1", "node_id": "D1", "basis": "Synthetic test binding"}], "contradictions": [], "failure_cases": [], "next_gap": "Test broader wall horizons"}]}
        q["capability_registry"] = self.save("registry.json", registry)
        return q

    def test_existing_capability_end_to_end(self):
        report = validate(self.root, self.contract())
        self.assertTrue(report["ok"], report)
        self.assertTrue(report["algorithm_evidence_verified"])
        self.assertFalse(report["strength_improvement_verified"])

    def test_failed_old_ai_and_passed_candidate_is_valid_learning(self):
        report = validate(self.root, self.contract(changed=True))
        self.assertTrue(report["ok"], report)
        self.assertEqual(report["stage"], "candidate_implemented")
        self.assertFalse(report["strength_improvement_verified"])

    def test_failed_old_ai_cannot_claim_existing_capability(self):
        q = self.contract(changed=True)
        q["stage"] = "validated_existing_algorithm"
        report = validate(self.root, q)
        self.assertFalse(report["ok"])
        self.assertIn("failed baseline", report["errors"][0])

    def test_candidate_cannot_rewrite_expected_answer(self):
        q = self.contract(changed=True)
        q["nodes"][0]["candidate"] = self.run_binding("cheat", selected="Gang", expected="Gang")
        self.assertIn("acceptance targets", validate(self.root, q)["errors"][0])

    def test_failed_blind_transfer_is_not_understanding(self):
        q = self.contract()
        reveal = json.loads((self.root / "reveal.json").read_text())
        reveal["assessment"] = "fail"
        q["nodes"][0]["blind_reveal"] = self.save("reveal.json", reveal)
        self.assertIn("blind transfer", validate(self.root, q)["errors"][0])

    def test_answer_seen_before_prediction_rejected(self):
        q = self.contract()
        reveal = json.loads((self.root / "reveal.json").read_text())
        reveal["revealed_at"] = "2026-09-05T07:00:00+00:00"
        q["nodes"][0]["blind_reveal"] = self.save("reveal.json", reveal)
        self.assertIn("before reveal", validate(self.root, q)["errors"][0])

    def test_circular_reasoning_rejected(self):
        q = self.contract()
        q["claims"][0].update(layer="analyst_inference", depends_on=["C1"])
        self.assertIn("circular", validate(self.root, q)["errors"][0])

    def test_empty_capability_fields_rejected(self):
        q = self.contract()
        registry = json.loads((self.root / "registry.json").read_text())
        registry["capabilities"][0]["mechanism"] = ""
        q["capability_registry"] = self.save("registry.json", registry)
        self.assertIn("mechanism", validate(self.root, q)["errors"][0])

    def test_unresolved_conflict_blocks_application(self):
        q = self.contract()
        registry = json.loads((self.root / "registry.json").read_text())
        registry["capabilities"][0]["contradictions"] = [{"id": "conflict1", "status": "unresolved", "description": "Opposite recommendation under seemingly same assumptions", "evidence_ref": "other-source"}]
        q["capability_registry"] = self.save("registry.json", registry)
        self.assertIn("unresolved", validate(self.root, q)["errors"][0])

    def test_registry_deduplicates_original_game(self):
        self.contract()
        registry = json.loads((self.root / "registry.json").read_text())
        other = copy.deepcopy(registry)
        other["capabilities"][0]["evidence"][0]["video_id"] = "reposted-video"
        combined = merge(registry, other)
        self.assertEqual(len(combined["capabilities"][0]["evidence"]), 2)
        self.assertEqual(validate_registry(combined)["meld-tempo"], 1)

    def test_registry_cannot_silently_replace_mechanism(self):
        self.contract()
        registry = json.loads((self.root / "registry.json").read_text())
        other = copy.deepcopy(registry)
        other["capabilities"][0]["mechanism"] = "Always Peng"
        with self.assertRaisesRegex(ValueError, "overwrite"):
            merge(registry, other)

    def test_sensitivity_cannot_change_policy_and_state_together(self):
        q = self.contract()
        mechanism = json.loads((self.root / "mechanism.json").read_text())
        mechanism["treatment"] = self.run_binding("other-policy", state={**self.state, "wall": 4}, value=3, version="b")
        q["nodes"][0]["mechanism"] = self.save("mechanism.json", mechanism)
        self.assertIn("changed policy", validate(self.root, q)["errors"][0])

    def test_strength_claim_without_full_game_evidence_rejected(self):
        q = self.contract(changed=True)
        q["stage"] = "strength_improvement_verified"
        self.assertFalse(validate(self.root, q)["ok"])

    def test_publisher_preserves_explicit_failed_review(self):
        q = self.contract()
        sources = self.root / "authored"
        sources.mkdir()
        refs = {}
        for name in DOCUMENTS:
            content = q if name == "learning-quality.json" else {"passed": False, "unresolved": ["not reviewed"]}
            path = sources / name
            path.write_text("状态：回看中" if name.endswith(".md") else json.dumps(content))
            refs[name] = {"path": "authored/" + name, "sha256": sha256(path)}
        spec = self.root / "spec.json"
        spec.write_text(json.dumps({"revision": REVISION, "video_id": self.root.name, "reviewed_documents": refs}))
        documents = prepare(self.root, spec)
        with patch("builtins.print"):
            publish(self.root, documents)
        self.assertFalse(json.loads((self.root / "semantic-review.json").read_text())["passed"])
        self.assertTrue(list(self.root.glob("pre-review-*")))

    def test_retired_auto_certifiers_cannot_write(self):
        before = set(self.root.iterdir())
        with self.assertRaisesRegex(RuntimeError, "retired"):
            rebuild(self.root)
        with self.assertRaisesRegex(RuntimeError, "retired"):
            upgrade_bundle(self.root, self.root)
        self.assertEqual(before, set(self.root.iterdir()))

    def test_stage_selection_does_not_demand_old_completion_marker(self):
        from validate_learning_bundle import stage_satisfies
        q = self.contract(changed=True)
        report = validate(self.root, q)
        self.assertTrue(stage_satisfies(report, "application"))
        self.assertFalse(stage_satisfies(report, "strength"))
        q["stage"] = "technique_understood"
        report = validate(self.root, q)
        self.assertTrue(stage_satisfies(report, "understanding"))
        self.assertFalse(stage_satisfies(report, "application"))

    def test_preserved_binary_tamper_rejected(self):
        q = self.contract()
        (self.root / "newassembly_artifact.bin").write_bytes(b"tampered")
        self.assertIn("runtime hash", validate(self.root, q)["errors"][0])

    def test_heuristic_cannot_be_renamed_calibrated_score(self):
        q = self.contract()
        mechanism = json.loads((self.root / "mechanism.json").read_text())
        mechanism["scale"] = "calibrated_expected_score"
        q["nodes"][0]["mechanism"] = self.save("mechanism.json", mechanism)
        self.assertFalse(validate(self.root, q)["ok"])

    def test_main_validator_routes_v2_without_legacy_self_certification(self):
        # This test mocks MEDIA checks only. Real local-media negative checking
        # is separate; do not report this synthetic file as a valid video.
        import validate_learning_bundle as entry
        q = self.contract(changed=True)
        self.save("learning-quality.json", q)
        metadata = {"aweme_id": self.root.name, "sha256": self.source_hash, "canonical_url": "https://example.invalid/" + self.root.name, "file_size": (self.root / "source.mp4").stat().st_size}
        self.save("metadata.json", metadata)
        (self.root / "knowledge-card.md").write_text("\n".join(entry.REQUIRED_CARD_SECTIONS) + "\n学习阶段：candidate_implemented\nevidence-index.json\n")
        with patch.object(entry, "probe_duration", return_value=1), patch.object(entry, "metadata_duration", return_value=1), patch.object(entry, "validate_manifests", return_value={}), patch.object(entry, "validate_index"), patch.object(entry, "validate_low_traffic_v3", return_value=True), patch.object(entry, "validate_semantic_mastery", side_effect=AssertionError("legacy semantic gate called")), patch.object(entry, "validate_ai_application", side_effect=AssertionError("legacy AI gate called")), patch("sys.argv", ["validate", str(self.root), "--required-stage", "application"]), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(entry.main(), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
