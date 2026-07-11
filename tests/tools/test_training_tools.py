import csv
import json
import tempfile
import unittest
from pathlib import Path

from tools.create_regression_evidence_package import create_evidence_package
from tools.discard_audit import build_audit_events, build_audit_events_from_trace, write_audit
from tools.hell_replay_compare import compare_summaries, resolve_summary_path, write_compare_report
from tools.hell_training_index import build_index_rows, write_index


class HellTrainingToolTests(unittest.TestCase):
    def test_hell_training_index_extracts_decision_fields(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            training_dir = root / "hell_training"
            training_dir.mkdir()
            decision_path = training_dir / "session_decision_000001.json"
            decision_path.write_text(
                json.dumps(
                    {
                        "session_id": "session",
                        "decision_index": 1,
                        "created_at": "2026-05-22T08:00:00",
                        "round_index": 3,
                        "phase": 5,
                        "decision_type": "discard",
                        "seat": 2,
                        "difference": {"category": "not_evaluated", "severity": "none"},
                        "actual_action": {"action": "discard", "tile_type": 16},
                        "extra": {
                            "decision": {
                                "analysis": {
                                    "turn_diagnostic": {
                                        "quality_metrics": {
                                            "quality_score": 72,
                                            "opportunity_loss_score": 28,
                                            "mode_consistency_score": 80,
                                            "expected_net_gap_to_best": 1.75,
                                            "score_gap_to_best": 420,
                                            "risk_gap_to_best_safe": 26,
                                            "quality_flags": ["defense_mode_ignored_safe_alternative"],
                                        },
                                        "selected": {
                                            "tile_type": 16,
                                            "tile_label": "8筒",
                                            "score": 2558,
                                            "shanten": 0,
                                            "live_ukeire": 2,
                                            "danger": 62,
                                            "strategy_mode": "defense",
                                            "keeps_ready": True,
                                            "feeds_human_hu": False,
                                            "feeds_human_peng": True,
                                            "exact_deal_in": False,
                                            "human_peng_penalty": -180,
                                            "peng_only_interaction_bonus": 420,
                                            "score_components": {
                                                "expected_net_score": 2.5,
                                            },
                                        }
                                    }
                                }
                            }
                        },
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

            rows = build_index_rows(training_dir)
            self.assertEqual(1, len(rows))
            self.assertEqual("8筒", rows[0]["selected_tile_label"])
            self.assertEqual(True, rows[0]["feeds_human_peng"])
            self.assertEqual(420, rows[0]["peng_only_interaction_bonus"])
            self.assertEqual(72, rows[0]["quality_score"])
            self.assertEqual("defense", rows[0]["selected_strategy_mode"])
            self.assertEqual("defense_mode_ignored_safe_alternative", rows[0]["quality_flags"])

            paths = write_index(rows, root / "index", "fixed")
            self.assertTrue(paths.csv_path.exists())
            self.assertTrue(paths.summary_path.exists())
            with paths.csv_path.open("r", encoding="utf-8", newline="") as file:
                csv_rows = list(csv.DictReader(file))
            self.assertEqual("8筒", csv_rows[0]["selected_tile_label"])
            self.assertEqual("72", csv_rows[0]["quality_score"])
            self.assertIn("feeds_human_peng candidates: 1", paths.summary_path.read_text(encoding="utf-8"))
            self.assertIn("avg_quality_score: 72.00", paths.summary_path.read_text(encoding="utf-8"))
            self.assertIn("`defense_mode_ignored_safe_alternative`: 1", paths.summary_path.read_text(encoding="utf-8"))

    def test_hell_training_index_extracts_hell_challenge_candidates(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            training_dir = root / "hell_training"
            training_dir.mkdir()
            decision_path = training_dir / "session_decision_000002.json"
            decision_path.write_text(
                json.dumps(
                    {
                        "session_id": "session",
                        "decision_index": 2,
                        "decision_type": "discard",
                        "seat": 1,
                        "difference": {"category": "hell_challenge_direct", "severity": "none"},
                        "actual_action": {"action": "discard", "tile_type": 7},
                        "extra": {
                            "decision": {
                                "analysis": {
                                    "csharp_result": {
                                        "tileType": 7,
                                        "score": 900,
                                        "selectedTier": "C_WIDE_TWO_AWAY",
                                        "candidates": [
                                            {
                                                "tileType": 7,
                                                "score": 900,
                                                "shanten": 2,
                                                "liveUkeire": 4,
                                                "danger": 35,
                                                "feedsHumanPeng": True,
                                                "humanPengThreat": 4,
                                                "tier": "C_WIDE_TWO_AWAY",
                                                "tierRank": 28,
                                                "tierAdjustment": 350,
                                                "strategyMode": "地狱挑战",
                                            },
                                            {
                                                "tileType": 3,
                                                "score": 640,
                                                "shanten": 1,
                                                "liveUkeire": 7,
                                                "danger": 0,
                                                "tier": "B_ONE_AWAY_LIVE",
                                                "tierRank": 10,
                                                "tierAdjustment": 1900,
                                                "strategyMode": "地狱挑战",
                                            },
                                        ],
                                    }
                                }
                            }
                        },
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

            rows = build_index_rows(training_dir)
            self.assertEqual(1, len(rows))
            self.assertEqual(7, rows[0]["selected_tile_type"])
            self.assertEqual("C_WIDE_TWO_AWAY", rows[0]["selected_tier"])
            self.assertEqual(4, rows[0]["human_peng_threat"])
            self.assertIn("hell_selected_feeds_strong_peng", rows[0]["quality_flags"])
            self.assertIn("selected_narrow_live_ukeire", rows[0]["quality_flags"])
            self.assertEqual(3, rows[0]["best_speed_tile_type"])
            self.assertEqual("B_ONE_AWAY_LIVE", rows[0]["best_big_route_tier"])

    def test_discard_audit_grades_and_classifies_bad_discards(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            training_dir = root / "hell_training"
            training_dir.mkdir()
            decision_path = training_dir / "session_decision_000003.json"
            decision_path.write_text(
                json.dumps(
                    {
                        "session_id": "session",
                        "decision_index": 3,
                        "created_at": "2026-06-30T08:00:00",
                        "round_index": 1,
                        "phase": 5,
                        "decision_type": "discard",
                        "seat": 2,
                        "actual_action": {"action": "discard", "tile_type": 16},
                        "visible_state": {
                            "wall_count": 4,
                            "discard_pile": [{"tile_type": 1}],
                            "players": [
                                {"seat": 2, "nickname": "AI-2", "score": 0, "bao_jiao": True},
                            ],
                        },
                        "fair_ai": {
                            "turn_diagnostic": {
                                "selected_rank_by_score": 3,
                                "candidate_count": 4,
                                "quality_metrics": {
                                    "quality_score": 58,
                                    "opportunity_loss_score": 42,
                                    "score_gap_to_best": 780,
                                    "risk_gap_to_best_safe": 44,
                                    "quality_flags": ["defense_mode_ignored_safe_alternative"],
                                },
                                "diagnostic_flags": ["high_table_threat"],
                                "selected": {
                                    "tile_type": 16,
                                    "tile_label": "8筒",
                                    "score": 1200,
                                    "shanten": 0,
                                    "live_ukeire": 1,
                                    "danger": 82,
                                    "strategy_mode": "defense",
                                    "keeps_ready": False,
                                    "feeds_human_hu": True,
                                    "exact_deal_in": True,
                                    "reasons": ["后期仍选择高危牌"],
                                },
                                "top_score_candidates": [
                                    {
                                        "tile_type": 3,
                                        "tile_label": "3条",
                                        "score": 1980,
                                        "shanten": 0,
                                        "live_ukeire": 3,
                                        "danger": 12,
                                    },
                                    {
                                        "tile_type": 16,
                                        "tile_label": "8筒",
                                        "score": 1200,
                                        "shanten": 0,
                                        "live_ukeire": 1,
                                        "danger": 82,
                                    },
                                ],
                                "best_safe_alternative": {
                                    "tile_type": 3,
                                    "tile_label": "3条",
                                    "score": 1980,
                                    "shanten": 0,
                                    "live_ukeire": 3,
                                    "danger": 12,
                                },
                                "best_speed_alternative": {
                                    "tile_type": 3,
                                    "tile_label": "3条",
                                    "score": 1980,
                                    "shanten": 0,
                                    "live_ukeire": 3,
                                    "danger": 12,
                                },
                            }
                        },
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

            events = build_audit_events(training_dir)
            self.assertEqual(1, len(events))
            event = events[0]
            self.assertEqual("E_BLUNDER", event["quality_grade"])
            self.assertIn("BAO_JIAO_ERROR", event["categories"])
            self.assertIn("RISK_ERROR", event["categories"])
            self.assertIn("WEIGHT_ERROR", event["categories"])
            self.assertEqual("late", event["stage"])

            paths = write_audit(events, root / "audit", "fixed")
            self.assertTrue(paths.jsonl_path.exists())
            self.assertTrue(paths.report_path.exists())
            report_text = paths.report_path.read_text(encoding="utf-8")
            self.assertIn("E 级严重错牌：1", report_text)
            self.assertIn("BAO_JIAO_ERROR", report_text)
            self.assertIn("最需要复盘的错牌 Top 20", report_text)

    def test_discard_audit_accepts_late_fold_safe_discard(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            training_dir = root / "hell_training"
            training_dir.mkdir()
            decision_path = training_dir / "session_decision_000004.json"
            decision_path.write_text(
                json.dumps(
                    {
                        "session_id": "session",
                        "decision_index": 4,
                        "created_at": "2026-06-30T08:10:00",
                        "round_index": 1,
                        "phase": 5,
                        "decision_type": "discard",
                        "seat": 1,
                        "actual_action": {"action": "discard", "tile_type": 5},
                        "visible_state": {
                            "wall_count": 4,
                            "discard_pile": [{"tile_type": 1}],
                            "players": [
                                {"seat": 1, "nickname": "AI-1", "score": 8, "bao_jiao": False},
                            ],
                        },
                        "fair_ai": {
                            "turn_diagnostic": {
                                "selected_rank_by_score": 3,
                                "candidate_count": 3,
                                "quality_metrics": {
                                    "quality_score": 12,
                                    "opportunity_loss_score": 88,
                                    "score_gap_to_best": 1800,
                                    "expected_net_gap_to_best": 2.6,
                                    "quality_flags": ["faster_alternative_exists"],
                                },
                                "diagnostic_flags": ["high_table_threat"],
                                "selected": {
                                    "tile_type": 5,
                                    "tile_label": "6条",
                                    "score": 300,
                                    "shanten": 1,
                                    "live_ukeire": 12,
                                    "danger": 10,
                                    "strategy_mode": "fold",
                                    "keeps_ready": False,
                                    "feeds_human_hu": False,
                                    "exact_deal_in": False,
                                },
                                "top_score_candidates": [
                                    {
                                        "tile_type": 4,
                                        "tile_label": "5条",
                                        "score": 2100,
                                        "shanten": 0,
                                        "live_ukeire": 2,
                                        "danger": 60,
                                    },
                                    {
                                        "tile_type": 5,
                                        "tile_label": "6条",
                                        "score": 300,
                                        "shanten": 1,
                                        "live_ukeire": 12,
                                        "danger": 10,
                                    },
                                ],
                                "best_speed_alternative": {
                                    "tile_type": 4,
                                    "tile_label": "5条",
                                    "score": 2100,
                                    "shanten": 0,
                                    "live_ukeire": 2,
                                    "danger": 60,
                                },
                            }
                        },
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

            events = build_audit_events(training_dir)
            self.assertEqual(1, len(events))
            event = events[0]
            self.assertEqual("B_ACCEPTABLE", event["quality_grade"])
            self.assertNotIn("WEIGHT_ERROR", event["categories"])
            self.assertNotIn("EV_ERROR", event["categories"])
            self.assertEqual("fold", event["strategy_mode"])
            self.assertEqual("late", event["stage"])

    def test_discard_audit_reads_debug_trace_events(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            trace_path = root / "events.jsonl"
            trace_path.write_text(
                json.dumps(
                    {
                        "session_id": "trace-session",
                        "event_index": 9,
                        "event_type": "turn_decision_built",
                        "created_at": "2026-06-30T09:00:00",
                        "round_index": 2,
                        "phase": 5,
                        "current_turn_seat": 1,
                        "wall_count": 10,
                        "visible_state": {
                            "wall_count": 10,
                            "discard_pile": [],
                            "players": [{"seat": 1, "nickname": "AI-1", "score": 3, "bao_jiao": False}],
                        },
                        "payload": {
                            "seat": 1,
                            "decision_path": "discard",
                            "decision": {"action": "discard", "actual_action": {"action": "discard", "tile_type": 4}},
                            "turn_diagnostic": {
                                "selected_rank_by_score": 1,
                                "candidate_count": 2,
                                "quality_metrics": {"quality_score": 96, "score_gap_to_best": 0, "quality_flags": []},
                                "selected": {
                                    "tile_type": 4,
                                    "tile_label": "5条",
                                    "score": 1800,
                                    "shanten": 1,
                                    "live_ukeire": 8,
                                    "danger": 18,
                                    "strategy_mode": "balanced",
                                },
                                "top_score_candidates": [
                                    {"tile_type": 4, "tile_label": "5条", "score": 1800, "shanten": 1, "live_ukeire": 8, "danger": 18}
                                ],
                            },
                        },
                    },
                    ensure_ascii=False,
                )
                + "\n",
                encoding="utf-8",
            )

            events = build_audit_events_from_trace(trace_path)
            self.assertEqual(1, len(events))
            self.assertEqual("trace-session#9", events[0]["event_id"])
            self.assertEqual("A_OPTIMAL", events[0]["quality_grade"])
            self.assertEqual("5条", events[0]["selected_tile_label"])

    def test_hell_replay_compare_reports_deltas(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            before_path = root / "before_summary.json"
            after_path = root / "after_summary.json"
            before_path.write_text(
                json.dumps(
                    {
                        "session_id": "before",
                        "decision_count": 10,
                        "marked_count": 1,
                        "round_index": 2,
                        "category_counts": {"risk_underestimated": 3},
                        "severity_counts": {"high": 2},
                    }
                ),
                encoding="utf-8",
            )
            after_path.write_text(
                json.dumps(
                    {
                        "session_id": "after",
                        "decision_count": 12,
                        "marked_count": 1,
                        "round_index": 2,
                        "category_counts": {"risk_underestimated": 1, "not_evaluated": 4},
                        "severity_counts": {"high": 0, "none": 4},
                    }
                ),
                encoding="utf-8",
            )

            result = compare_summaries(before_path, after_path)
            self.assertEqual(2, result["decision_delta"])
            self.assertEqual(-2, result["category_delta"]["risk_underestimated"]["delta"])
            output_path = root / "compare.md"
            write_compare_report(result, output_path)
            text = output_path.read_text(encoding="utf-8")
            self.assertIn("| `risk_underestimated` | 3 | 1 | -2 |", text)

    def test_hell_replay_compare_resolves_res_manifest_summary(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            training_dir = root / "测试数据统计" / "hell_training"
            replay_dir = root / "测试数据统计" / "hell_replay"
            training_dir.mkdir(parents=True)
            replay_dir.mkdir(parents=True)
            summary_path = training_dir / "session_summary.json"
            manifest_path = replay_dir / "session_replay_manifest.json"
            summary_path.write_text(
                json.dumps({"session_id": "session", "decision_count": 4, "category_counts": {}, "severity_counts": {}}),
                encoding="utf-8",
            )
            manifest_path.write_text(
                json.dumps({"summary_path": "res://测试数据统计/hell_training/session_summary.json"}),
                encoding="utf-8",
            )

            self.assertEqual(summary_path, resolve_summary_path(manifest_path, root))

    def test_evidence_package_copies_sources_and_writes_checksums(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "real_case.json"
            source.write_text('{"ok": true}', encoding="utf-8")

            package_dir = create_evidence_package("AI错牌复盘", [source], root / "evidence", "20260522")

            self.assertTrue((package_dir / "README.md").exists())
            self.assertTrue((package_dir / "changed_files.md").exists())
            self.assertTrue((package_dir / "SHA256SUMS.txt").exists())
            self.assertTrue((package_dir / "source" / "real_case.json").exists())
            self.assertIn("Real table source data", (package_dir / "README.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
