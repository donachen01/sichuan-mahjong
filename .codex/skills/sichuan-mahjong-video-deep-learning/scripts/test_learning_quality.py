"""Focused tests for the v2 changes. Fixtures are synthetic validator tests only."""
import copy
import json
import tempfile
import unittest
from pathlib import Path

from build_reviewed_bundle import prepare
from evaluate_paired_strength import evaluate, plan_hash
from learning_quality import assertions, artifact, runtime_case, sha256, validate, validate_transfer, suit_transform


class QualityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def save(self, name, value):
        path = self.root / name
        path.write_text(json.dumps(value), encoding="utf-8")
        return {"path": name, "sha256": sha256(path)}

    def runtime(self):
        check = {"id": "action", "kind": "final_action", "operator": "equals", "expected": "Peng"}
        case = {"id": "case1", "decision_node_id": "D1", "visibility": "public_only", "grounding": "synthetic_transfer", "unknowns": [], "rule_variant": "project_default", "assertions": [check]}
        inp = self.save("input.json", {"decision_cases": [case]})
        version = {k: "a" * 64 for k in ("source_tree_sha256", "assembly_sha256", "rules_sha256", "runner_sha256")}
        version.update(build_verified=True, build_command=["dotnet", "build"])
        for field, key in (("assembly_artifact", "assembly_sha256"), ("runner_artifact", "runner_sha256")):
            path = self.root / (field + ".bin")
            path.write_bytes(b"synthetic runtime artifact, not executable")
            version[key] = sha256(path)
            version[field] = {"path": path.name, "sha256": version[key]}
        version_ref = self.save("version.json", version)
        result = {"id": "case1", "decision_node_id": "D1", "passed": True, "state_legality_passed": True, "selected": "Peng", "candidate_scores": {"peng": 2}, "assertions": [{**check, "observed": "Peng", "passed": True}]}
        report = {**version, "ok": True, "runner_kind": "formal_csharp_entry", "version_manifest": version_ref, "input_sha256": inp["sha256"], "results": [result]}
        return {"report": self.save("report.json", report), "fixture": inp, "case_id": "case1", "decision_node_id": "D1"}, report

    def test_real_binding_contract_accepts_consistent_fixture(self):
        binding, _ = self.runtime()
        self.assertEqual(runtime_case(self.root, binding)[0]["selected"], "Peng")

    def test_missing_test_id_rejected(self):
        binding, _ = self.runtime()
        binding["case_id"] = "old-unrelated-test"
        with self.assertRaisesRegex(ValueError, "test ID absent"):
            runtime_case(self.root, binding)

    def test_false_pass_boolean_rejected(self):
        binding, report = self.runtime()
        report["results"][0]["assertions"][0]["observed"] = "Gang"
        binding["report"] = self.save("report.json", report)
        with self.assertRaisesRegex(ValueError, "truth differs"):
            runtime_case(self.root, binding)

    def test_modified_expectation_rejected(self):
        binding, report = self.runtime()
        report["results"][0]["assertions"][0].update(expected="Gang", observed="Gang")
        report["results"][0]["selected"] = "Gang"
        binding["report"] = self.save("report.json", report)
        with self.assertRaisesRegex(ValueError, "expectation|expected assertion changed"):
            runtime_case(self.root, binding)

    def test_wrong_node_rejected(self):
        binding, report = self.runtime()
        report["results"][0]["decision_node_id"] = "D9"
        binding["report"] = self.save("report.json", report)
        with self.assertRaisesRegex(ValueError, "another node"):
            runtime_case(self.root, binding)

    def test_version_mismatch_rejected(self):
        binding, report = self.runtime()
        report["assembly_sha256"] = "b" * 64
        binding["report"] = self.save("report.json", report)
        with self.assertRaisesRegex(ValueError, "provenance mismatch"):
            runtime_case(self.root, binding)

    def test_tamper_rejected(self):
        binding, _ = self.runtime()
        (self.root / "input.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            runtime_case(self.root, binding)

    def test_no_action_assertion_rejected(self):
        with self.assertRaises(ValueError):
            assertions({"passed": True, "assertions": []})

    def test_duplicate_results_rejected(self):
        binding, report = self.runtime()
        report["results"].append(copy.deepcopy(report["results"][0]))
        binding["report"] = self.save("report.json", report)
        with self.assertRaisesRegex(ValueError, "duplicate"):
            runtime_case(self.root, binding)

    def test_legacy_builder_has_no_side_effects(self):
        spec = self.root / "spec.json"
        spec.write_text('{"video_id": "old"}')
        before = set(self.root.iterdir())
        with self.assertRaisesRegex(ValueError, "Legacy"):
            prepare(self.root, spec)
        self.assertEqual(before, set(self.root.iterdir()))

    def test_missing_contract_fails_closed(self):
        self.assertFalse(validate(self.root)["ok"])

    def test_incomplete_suit_transform_rejected(self):
        state = {"hand": "123s", "meld": "777m", "visible": "9p", "dingque": [0, 1, 2, 0]}
        base = {"fixture_state": state, "selected": "Discard:1s"}
        trial = {"fixture_state": suit_transform(state, [1, 2, 0]), "selected": "Discard:1p"}
        cfg = {"suit_permutation": [1, 2, 0], "expected_relation": "equivalent_action"}
        validate_transfer("whole_state_suit_permutation", base, trial, cfg)
        trial["fixture_state"]["dingque"] = state["dingque"]
        with self.assertRaisesRegex(ValueError, "whole-state"):
            validate_transfer("whole_state_suit_permutation", base, trial, cfg)

    def test_claimed_reversal_must_really_reverse(self):
        base = {"fixture_state": {"wall": 40}, "selected": "Peng", "candidate_scores": {"peng": 2}}
        trial = {"fixture_state": {"wall": 4}, "selected": "Peng", "candidate_scores": {"peng": 3}}
        with self.assertRaisesRegex(ValueError, "reversal"):
            validate_transfer("premise_break", base, trial, {"expected_relation": "action_changes", "changed_fields": ["wall"]})


class StrengthTests(unittest.TestCase):
    def fixture(self):
        plan = {"primary_metric": "net_score", "baseline_version": "old", "candidate_version": "new", "rules_sha256": "rules", "opponent_version": "opponent", "min_deals": 2, "alpha": .05, "min_mean_gain": 1, "max_deal_in_increase": .02, "max_p95_latency_ms": 500, "seats": [0, 1, 2, 3], "training_groups": ["train"], "heldout_groups": ["game1", "game2"]}
        plan["frozen_at"] = "2026-09-05T08:00:00Z"
        rows = []
        for group in plan["heldout_groups"]:
            for seat in plan["seats"]:
                for arm in ("baseline", "candidate"):
                    rows.append({"group_id": group, "seed": 7, "seat": seat, "arm": arm, "version": plan[arm + "_version"], "rules_sha256": "rules", "opponent_version": "opponent", "game_origin": "natural_full_round", "completed": True, "uses_hidden_information": False, "initial_wall_sha256": group, "replay_sha256": "synthetic-unit-test-only", "net_score": 2 if arm == "candidate" else 0, "deal_in_rate": .1, "latency_p95_ms": 20})
        return plan, {"measurement_kind": "full_game_settlement", "plan_sha256": plan_hash(plan), "started_at": "2026-09-05T09:00:00Z", "rows": rows}

    def test_paired_math(self):
        plan, runs = self.fixture()
        result = evaluate(plan, runs)
        self.assertEqual(result["mean_net_score_gain"], 2)
        self.assertEqual(result["independent_groups"], 2)
        self.assertTrue(result["promotable"])

    def test_bad_data_rejected(self):
        for fault in ("missing", "duplicate", "different_wall", "proxy", "leak", "version", "nonfinite", "hidden"):
            with self.subTest(fault=fault):
                plan, runs = self.fixture()
                if fault == "missing": runs["rows"].pop()
                if fault == "duplicate": runs["rows"].append(runs["rows"][0])
                if fault == "different_wall": runs["rows"][0]["initial_wall_sha256"] = "different"
                if fault == "proxy": runs["measurement_kind"] = "oracle_regret"
                if fault == "leak":
                    plan["training_groups"].append("game1")
                    runs["plan_sha256"] = plan_hash(plan)
                if fault == "version": runs["rows"][0]["version"] = "changed"
                if fault == "nonfinite": runs["rows"][0]["net_score"] = float("nan")
                if fault == "hidden": runs["rows"][0]["uses_hidden_information"] = True
                with self.assertRaises(ValueError): evaluate(plan, runs)

    def test_loss_cannot_promote(self):
        plan, runs = self.fixture()
        for row in runs["rows"]:
            if row["arm"] == "candidate": row["net_score"] = -2
        self.assertFalse(evaluate(plan, runs)["promotable"])

    def test_reposted_same_deal_cannot_multiply_strength_samples(self):
        plan, runs = self.fixture()
        for row in runs["rows"]:
            row["initial_wall_sha256"] = "same-deal"
        with self.assertRaisesRegex(ValueError, "independent groups"):
            evaluate(plan, runs)

    def test_posthoc_strength_plan_rejected(self):
        plan, runs = self.fixture()
        plan["frozen_at"] = "2026-09-05T10:00:00Z"
        runs["plan_sha256"] = plan_hash(plan)
        with self.assertRaisesRegex(ValueError, "before measurement"):
            evaluate(plan, runs)


class PublicReplayTransferTests(unittest.TestCase):
    def test_entire_replay_is_transformed_without_mutating_source(self):
        from learning_quality import suit_transform
        state = {"hand": "12s", "meld": "333m", "visible": "4p", "dingque": [0,1,2,0],
                 "public_replay": {"history_scope": "checkpoint_window", "initial": {
                     "hand": "12s", "discards": [["4p"],[],[],[]],
                     "melds": [[{"type": "Peng", "tile": "3m", "source_seat": 1}],[],[],[]]},
                     "events": [{"type": "Draw", "tile": None}, {"type": "Discard", "tile": "9s"}]}}
        transformed = suit_transform(state, [1,2,0])
        self.assertEqual(transformed["public_replay"]["initial"]["hand"], "12p")
        self.assertEqual(transformed["public_replay"]["initial"]["discards"][0], ["4m"])
        self.assertEqual(transformed["public_replay"]["initial"]["melds"][0][0]["tile"], "3s")
        self.assertEqual(transformed["public_replay"]["events"], [{"type":"Draw","tile":None},{"type":"Discard","tile":"9p"}])
        self.assertEqual(state["public_replay"]["initial"]["hand"], "12s")

    def test_retained_gang_tile_and_different_last_draw_transform_separately(self):
        state = {"hand":"567s78889m", "meld":"2222s777m", "tile":"7m", "last_draw":"8m", "dingque":[1,1,1,1]}
        transformed = suit_transform(state, [1,2,0])
        self.assertEqual(transformed["tile"], "7s")
        self.assertEqual(transformed["last_draw"], "8s")
        self.assertEqual(state["last_draw"], "8m")


if __name__ == "__main__":
    unittest.main(verbosity=2)
