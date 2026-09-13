"""Focused state-machine tests for multi-source calibration accumulation."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parent / "learning_state.py"


class CalibrationQueueTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="learning-calibration-queue-")
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "project"
        self.research = self.project / "research" / "xiaolaoshi_deep_learning"
        self.research.mkdir(parents=True)
        self.state = self.research / "learning-run-state.json"
        self.inventory = self.research / "video-inventory.json"
        self.bundle = self.research / "video75"
        self.bundle.mkdir()
        self.write_json(self.bundle / "validation-report.json", {
            "ok": True,
            "checks": {
                "semantic_mastery": True,
                "learning_stage": "technique_understood",
                "required_stage": "understanding",
                "ai_application_gate": False,
            },
        })
        self.write_json(self.inventory, {"items": [
            {"order": 75, "video_id": "video75", "title": "semantic source", "screening_status": "pending", "learning_status": "not_started"},
            {"order": 76, "video_id": "video76", "title": "next source", "screening_status": "pending", "learning_status": "not_started"},
        ]})
        self.write_json(self.state, {
            "schema_version": 1,
            "cursor_order": 74,
            "run_status": "active",
            "events": [],
            "active": {
                "video_id": "video75",
                "order": 75,
                "title": "semantic source",
                "stage": "summary",
                "bundle_path": "research/xiaolaoshi_deep_learning/video75",
                "network_permitted": False,
            },
        })

    @staticmethod
    def write_json(path: Path, value: dict) -> None:
        path.write_text(json.dumps(value), encoding="utf-8")

    def invoke(self, *args: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True)
        if ok and result.returncode != 0:
            self.fail(result.stdout + result.stderr)
        return result

    def test_deferred_lesson_is_not_verified_and_next_source_can_be_claimed(self) -> None:
        self.invoke(
            "defer-for-calibration", "--state", str(self.state),
            "--inventory", str(self.inventory), "--reason", "need disjoint source groups",
        )
        state = json.loads(self.state.read_text())
        item = json.loads(self.inventory.read_text())["items"][0]
        self.assertIsNone(state["active"])
        self.assertEqual(state["cursor_order"], 75)
        self.assertEqual(state["calibration_queue"][0]["stage"], "summary")
        self.assertEqual(item["learning_status"], "awaiting_calibration")
        self.assertNotEqual(item["learning_status"], "verified")

        self.invoke("claim-next", "--state", str(self.state), "--inventory", str(self.inventory))
        state = json.loads(self.state.read_text())
        self.assertEqual(state["active"]["video_id"], "video76")

    def test_deferral_rejects_non_green_understanding_report(self) -> None:
        report = json.loads((self.bundle / "validation-report.json").read_text())
        report["ok"] = False
        self.write_json(self.bundle / "validation-report.json", report)
        result = self.invoke(
            "defer-for-calibration", "--state", str(self.state),
            "--inventory", str(self.inventory), "--reason", "invalid", ok=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("strict-green understanding-stage report", result.stderr)

    def test_resume_restores_exact_summary_stage(self) -> None:
        self.invoke(
            "defer-for-calibration", "--state", str(self.state),
            "--inventory", str(self.inventory), "--reason", "need disjoint source groups",
        )
        self.invoke("resume-calibration", "--state", str(self.state), "--video-id", "video75")
        state = json.loads(self.state.read_text())
        self.assertEqual(state["active"]["video_id"], "video75")
        self.assertEqual(state["active"]["stage"], "summary")
        self.assertEqual(state["calibration_queue"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
