"""Calibration evaluator arithmetic and isolation tests; not real training data."""
import unittest
from evaluate_calibration import evaluate
from evaluate_paired_strength import plan_hash


class CalibrationTests(unittest.TestCase):
    def fixture(self):
        plan = {"target": "probability", "model_version": "candidate", "training_groups": ["t1", "t2"], "heldout_groups": ["h1", "h2"], "min_heldout_groups": 2, "max_error": .1, "frozen_at": "2026-09-05T08:00:00Z"}
        samples = {"plan_sha256": plan_hash(plan), "started_at": "2026-09-05T09:00:00Z", "rows": [{"id": group, "group_id": group, "model_version": "candidate", "prediction": .8, "observed": 1} for group in ["h1", "h2"]]}
        return plan, samples

    def test_recomputes_error(self):
        plan, samples = self.fixture()
        report = evaluate(plan, samples)
        self.assertAlmostEqual(report["error"], .04)
        self.assertTrue(report["accepted"])

    def test_probability_error_fails_threshold(self):
        plan, samples = self.fixture()
        samples["rows"][0]["prediction"] = 0
        self.assertFalse(evaluate(plan, samples)["accepted"])

    def test_invalid_calibration_provenance(self):
        for fault in ("overlap", "one_source", "version", "late_plan", "duplicate", "probability_out_of_range"):
            with self.subTest(fault=fault):
                plan, samples = self.fixture()
                if fault == "overlap": plan["training_groups"].append("h1")
                if fault == "one_source": plan["training_groups"] = ["t1"]
                if fault == "version": samples["rows"][0]["model_version"] = "other"
                if fault == "late_plan": plan["frozen_at"] = "2026-09-05T10:00:00Z"
                if fault == "duplicate": samples["rows"].append(samples["rows"][0])
                if fault == "probability_out_of_range": samples["rows"][0]["prediction"] = 2
                samples["plan_sha256"] = plan_hash(plan)
                with self.assertRaises(ValueError): evaluate(plan, samples)


if __name__ == "__main__":
    unittest.main(verbosity=2)
