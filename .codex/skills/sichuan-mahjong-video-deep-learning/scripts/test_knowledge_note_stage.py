"""Focused tests for phase-one note validation and inventory/state integration."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parent
VALIDATOR = SCRIPTS / "validate_knowledge_note.py"
STATE_TOOL = SCRIPTS / "learning_state.py"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class KnowledgeNoteStageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="knowledge-note-stage-")
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "project"
        self.research = self.project / "research" / "xiaolaoshi_deep_learning"
        self.bundle = self.research / "video77"
        self.bundle.mkdir(parents=True)
        self.source = self.bundle / "source.mp4"
        self.source.write_bytes(b"synthetic phase-one test; not a real video")
        evidence = self.bundle / "evidence" / "frame_001.jpg"
        evidence.parent.mkdir()
        evidence.write_bytes(b"synthetic evidence")
        self.write_json(self.bundle / "source-verification.json", {
            "video_id": "video77",
            "source_sha256": digest(self.source),
            "duration_seconds": 12.0,
        })
        self.note = {
            "schema_version": 1,
            "status": "knowledge_note_complete",
            "video": {
                "video_id": "video77",
                "title": "Synthetic knowledge-note fixture",
                "source_path": "source.mp4",
                "source_sha256": digest(self.source),
            },
            "full_video_review": {
                "reviewed_from_start": True,
                "reviewed_to_end": True,
                "method": "Synthetic test declares an explicit full review boundary",
            },
            "core_thesis": {
                "teacher_teaches": "Compare route value before committing",
                "decision_problem": "Choose between two publicly legal routes",
                "reasoning": "One route preserves flexibility while the other gains immediate speed",
            },
            "public_observations": [{
                "observation": "A public event changes the route comparison",
                "evidence": [{
                    "path": "evidence/frame_001.jpg",
                    "sha256": digest(evidence),
                    "timestamp_seconds": 5.0,
                }],
            }],
            "candidate_actions": [
                {"action": "route_a", "assessment": "chosen", "reason": "preserves the stated objective"},
                {"action": "route_b", "assessment": "rejected", "reason": "loses flexibility under the public premise"},
            ],
            "reversal_conditions": [
                {"provenance": "teacher_explicit", "condition": "the public threat rises", "effect": "prefer the safer route"},
                {"provenance": "analyst_hypothesis", "condition": "the horizon becomes short", "effect": "speed may dominate"},
            ],
            "unknowns": ["opponent concealed tiles are not visible"],
            "outcome_separation": "Later outcomes are recorded separately and are not treated as decision inputs.",
            "capability_links": [{
                "relation": "new_candidate",
                "capability_id": "route-tradeoff",
                "reason": "The note introduces a reusable public route comparison question",
            }],
        }
        self.write_json(self.bundle / "knowledge-note.json", self.note)
        self.state = self.research / "learning-run-state.json"
        self.inventory = self.research / "video-inventory.json"
        self.write_json(self.inventory, {"schema_version": 1, "items": [
            {"order": 77, "video_id": "video77", "title": "first", "screening_status": "pending", "learning_status": "not_started"},
            {"order": 78, "video_id": "video78", "title": "next", "screening_status": "pending", "learning_status": "not_started"},
        ]})
        self.write_json(self.state, {
            "schema_version": 1,
            "cursor_order": 76,
            "run_status": "active",
            "events": [],
            "active": {
                "video_id": "video77",
                "order": 77,
                "title": "first",
                "stage": "evidence_review",
                "bundle_path": "research/xiaolaoshi_deep_learning/video77",
                "network_permitted": False,
            },
        })

    @staticmethod
    def write_json(path: Path, value: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    def invoke(self, script: Path, *args: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run([sys.executable, str(script), *args], capture_output=True, text=True)
        if ok and result.returncode != 0:
            self.fail(result.stdout + result.stderr)
        return result

    def test_valid_note_passes_without_ai_claims(self) -> None:
        result = self.invoke(VALIDATOR, str(self.bundle))
        report = json.loads(result.stdout)
        self.assertTrue(report["ok"])
        self.assertFalse(report["claims_ai_validated"])
        self.assertFalse(report["claims_strength_improved"])

    def test_note_rejects_missing_candidate_comparison(self) -> None:
        self.note["candidate_actions"] = self.note["candidate_actions"][:1]
        self.write_json(self.bundle / "knowledge-note.json", self.note)
        result = self.invoke(VALIDATOR, str(self.bundle), ok=False)
        self.assertIn("at least two candidate actions", result.stdout)

    def test_completion_updates_inventory_but_never_marks_verified(self) -> None:
        self.invoke(STATE_TOOL, "set-mode", "--state", str(self.state), "--mode", "knowledge_acquisition")
        self.invoke(
            STATE_TOOL,
            "transition", "--state", str(self.state),
            "--stage", "knowledge_note_complete", "--note", "phase-one note reviewed",
            "--inventory", str(self.inventory), "--note-validator", str(VALIDATOR),
        )
        state = json.loads(self.state.read_text())
        item = json.loads(self.inventory.read_text())["items"][0]
        self.assertEqual(state["active"]["stage"], "knowledge_note_complete")
        self.assertEqual(state["cursor_order"], 77)
        self.assertEqual(state["workflow_mode"], "knowledge_acquisition")
        self.assertEqual(item["learning_status"], "knowledge_note_complete")
        self.assertEqual(item["knowledge_status"], "knowledge_note_complete")
        self.assertEqual(item["algorithm_status"], "not_started")
        self.assertEqual(item["strength_status"], "not_started")
        self.assertNotEqual(item["learning_status"], "verified")
        self.assertEqual(item["knowledge_note_sha256"], digest(self.bundle / "knowledge-note.json"))

        self.invoke(STATE_TOOL, "claim-next", "--state", str(self.state), "--inventory", str(self.inventory))
        state = json.loads(self.state.read_text())
        self.assertEqual(state["active"]["video_id"], "video78")

    def test_completion_rejects_note_for_another_video(self) -> None:
        self.note["video"]["video_id"] = "different-video"
        self.write_json(self.bundle / "knowledge-note.json", self.note)
        result = self.invoke(
            STATE_TOOL,
            "transition", "--state", str(self.state),
            "--stage", "knowledge_note_complete", "--note", "invalid identity",
            "--inventory", str(self.inventory), "--note-validator", str(VALIDATOR),
            ok=False,
        )
        self.assertNotEqual(result.returncode, 0)
        item = json.loads(self.inventory.read_text())["items"][0]
        self.assertEqual(item["learning_status"], "not_started")


if __name__ == "__main__":
    unittest.main(verbosity=2)
