# Neijiang AI Counting Model Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the current regression suite around the stable Neijiang rule set, then upgrade the C# AI so counting/posterior probabilities become the decision engine's probability foundation while Godot remains a presentation and orchestration layer.

**Architecture:** C# owns AI algorithms, probability modeling, hand-shape evaluation, EV scoring, and benchmark interpretation. Godot owns game-state orchestration, rule execution gates, UI, and transport of state/results. Tests are split into focused current suites so rule correctness, C# contract wiring, AI decision quality, UI explanation behavior, and benchmark calibration can be verified independently.

**Tech Stack:** Godot 4.6 .NET, GDScript test runners, C# `dotnet/AI.Core`, native `NeijiangCSharpRuntime`, focused Godot headless runners, optional future C# test project.

---

## Current Progress

| Phase | Status | Goal | Verification |
|---|---|---|---|
| 0. Regression Suite Rebuild | Complete | Replace the old monolithic 70+/80+ regression expectation with focused current suites. | `NeijiangCurrentSmokeRunner` PASS; `NeijiangBaoJiaoBaoGangRunner` PASS; `NeijiangCSharpContractRunner` PASS. |
| 1. Contract Correctness | Complete | Make C# `Action.TileType`, Godot `recommended`, UI hints, and execution use the same decision. | `NeijiangCSharpContractRunner` PASS. |
| 2. Discard Scoring Repair | Complete | Make posterior defense and calibrated danger probabilities truly affect ordinary discard EV. | `AI.Core.Smoke` PASS; `NeijiangCSharpContractRunner` PASS; current smoke PASS. |
| 3. Hand-Efficiency Deepening | Complete | Add C# shape/equivalent-shanten improvement features for old-hand tile efficiency. | `AI.Core.Smoke` PASS; C# candidate details include shape fields and reasons. |
| 4. Evidence Model | Complete | Build structured evidence for visible tiles, no-hu, no-peng, no-gang, exact safety, recent behavior. | `AI.Core.Smoke` PASS; evidence snapshot emits exact-safe, no-hu, and recent trend. |
| 5. Opponent Range and Wait Probability | Complete | Estimate hold/wait/wall posterior from evidence-backed lightweight range scoring. | `AI.Core.Smoke` PASS; no-hu evidence lowers wait probability and wall posterior is populated. |
| 6. EV and Explanation Integration | Complete | Feed counting probabilities into discard EV and expose reasons to Godot. | `NeijiangAiPanelRunner` PASS; helper shows C# net/self-draw/deal-in/defense/shape/reason details. |
| 7. A/B Calibration | Complete | Compare old/new AI by fixed-seed rounds and merge only if metrics improve or remain justified. | Fixed-seed single and A/B benchmark smoke PASS; JSON/CSV reports generated under `测试数据统计/`. |

## Hell Training Progress

This replaces the previous standalone "Phase 12 situation goal" and "Phase 13 data calibration" work. Situation-goal evaluation and calibration now happen inside the hell-mode training loop so weight changes are based on recorded evidence, not blind tuning.

| Phase | Status | Goal | Verification |
|---|---|---|---|
| H0. Difficulty Mode Redefinition | Complete | Keep UI names unchanged: `骨灰` becomes strongest fair AI; `地狱` becomes cheat/oracle training AI. | `NeijiangHellTrainingRunner` verifies hell preset maps to cheating/oracle flags without changing bone-ash fair mode. |
| H1. Hell Mode Configuration | Complete | Add hell flags for AI hand sharing, human-hand visibility, exact-wall visibility, oracle recording, and oracle execution. | Debug snapshot exposes `hell_ai_share_ai_hands`, `hell_ai_can_see_human_hand`, `hell_ai_can_see_wall`, `hell_record_oracle`, and `hell_execute_oracle_action`. |
| H2. Decision Snapshot Logging | Complete | Record every AI decision with visible state, hidden state, fair AI result, oracle result, and actual action. | `NeijiangHellTrainingRunner` writes a decision JSON under `测试数据统计/hell_training/`. |
| H3. Hell Oracle Engine | Complete | Add C# `NeijiangHellOracleEngine` that scores actions using exact hidden information for diagnosis. | `AI.Core.Smoke` verifies oracle rejects a known exact deal-in tile. |
| H4. Fair vs Oracle Difference Classifier | Complete | Classify differences as risk, wall posterior, wait shape, hand efficiency, situation-goal, or missing/same result. | C# oracle emits `risk_underestimated`, `wall_posterior_error`, `wait_shape_error`, `hand_efficiency_error`, and `situation_goal_error` categories. |
| H5. Mark This Hand | Complete | Add an in-game "标记这手" capture path for suspicious user-observed moments. | Floating AI drawer shows `标记` in hell mode; marked cases save JSON under `测试数据统计/hell_marked_cases/`. |
| H6. Training Round Report | Complete | Generate JSON/CSV/Markdown reports after hell training rounds. | Settlement/report writer emits summary JSON, CSV, and Markdown under `测试数据统计/hell_training/`. |
| H7. Situation Goal Diagnostics | Complete | Use logs to diagnose leading/trailing/dealer/wall-depth/check-ready goal mistakes; do not tune blindly. | Oracle classifier can emit `situation_goal_error` and snapshots include scores, dealer, wall count, and visible/hidden state. |
| H8. Calibration Suggestions | Complete | Generate evidence-backed weight-change suggestions from training reports; do not auto-apply them. | Reports include non-mutating calibration suggestions derived from category/severity counts. |
| H9. Regression Replay Loop | Complete | Replay same seed and marked cases after code changes to prove issue counts drop. | Report writer emits a replay manifest under `测试数据统计/hell_replay/` for same-seed/marked-case comparison. |

## Hell Training Operation

Development training should run from the Godot .NET editor/debug play session against this workspace:

```text
/Users/chendong/Documents/内江麻将工程_20260502_103823_v2
```

Training outputs must be written to project-relative `res://测试数据统计/...`, which resolves to:

```text
/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/测试数据统计/
```

Reserved output directories:

```text
测试数据统计/hell_training/          # full decision snapshots and round reports
测试数据统计/hell_marked_cases/      # user-marked suspicious hands
测试数据统计/hell_replay/            # same-seed and marked-case replay reports
```

Do not use `user://` for the first implementation because exported builds and editor runs can resolve it differently. `res://测试数据统计/` keeps logs in the shared workspace so Codex can read them directly.

## Guardrails

- Do not move AI algorithms into Godot.
- Godot may record facts and snapshots, but C# owns oracle scoring, classification, diagnostics, and calibration suggestions.
- Keep current uncommitted rule fixes intact; do not revert unrelated user changes.
- Write or migrate tests before behavior changes wherever practical.
- Prefer focused runners over one giant regression file.
- Any MCTS/search feature must be reproducible, bounded, and benchmarked; otherwise keep it disabled or clearly labeled as limited lookahead.
- Publish/release work only after the current-suite tests and relevant benchmark smoke pass.

---

## Phase 0: Regression Suite Rebuild

**Goal:** Build a current test structure that matches the current Neijiang rule set and AI architecture.

**Files:**
- Create: `docs/testing/neijiang-current-regression-map.md`
- Create: `tests/current/NeijiangCurrentSmokeRunner.gd`
- Create: `tests/current/NeijiangCSharpContractRunner.gd`
- Create: `tests/current/NeijiangBaoJiaoBaoGangRunner.gd`
- Modify or migrate from: `tests/NeijiangRegressionRunner.gd`
- Modify or migrate from: `tests/NeijiangBaoGangRegressionRunner.gd`
- Keep as legacy during migration: `tests/DingQueRegressionRunner.gd`

- [ ] **Step 0.1: Inventory current and legacy tests**

Run:

```bash
rg -n '_run_test\\("' tests
```

Expected: A complete list of existing test names grouped by runner.

- [ ] **Step 0.2: Write regression map**

Create `docs/testing/neijiang-current-regression-map.md` with these sections:

```markdown
# Neijiang Current Regression Map

## Current Suites

| Suite | Purpose | Runner | Required For |
|---|---|---|---|
| Rule Smoke | Current Neijiang rule and round-flow invariants | tests/current/NeijiangCurrentSmokeRunner.gd | Every change |
| C# Contract | C# result mapping into Godot analysis/execution fields | tests/current/NeijiangCSharpContractRunner.gd | Every AI or bridge change |
| BaoJiao/BaoGang | Opening bao jiao/bao gang and whitelist lock behavior | tests/current/NeijiangBaoJiaoBaoGangRunner.gd | Rule and AI self-action changes |
| AI Decision | C# discard/reaction/self-action targeted cases | tests/current/NeijiangAiDecisionRunner.gd | AI algorithm changes |
| AI Panel | UI helper text and C# candidate detail display | tests/current/NeijiangAiPanelRunner.gd | UI/helper changes |
| Benchmark Smoke | Fixed-seed AI round pressure checks | tests/current/NeijiangAiBenchmarkSmokeRunner.gd | Release or major AI changes |

## Legacy Suites

| Legacy Runner | Keep | Migrate | Retire | Notes |
|---|---:|---:|---:|---|
| tests/NeijiangRegressionRunner.gd |  |  |  | Monolithic current/old mixed suite. |
| tests/DingQueRegressionRunner.gd |  |  |  | Sichuan/ding-que expectations; not current Neijiang primary gate. |
| tests/NeijiangUiRegressionRunner.gd |  |  |  | Migrate AI panel and main controls checks. |
```

- [ ] **Step 0.3: Create current smoke runner**

Create `tests/current/NeijiangCurrentSmokeRunner.gd` with focused smoke tests for current Neijiang invariants:

```gdscript
extends SceneTree

const GAME_STATE_SCRIPT := preload("res://autoload/GameState.gd")
const RULE_CONFIG_SCRIPT := preload("res://scripts/core/rule_config.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_run_test("neijiang_uses_two_suits_without_ding_que", _test_neijiang_uses_two_suits_without_ding_que, failures)
	_run_test("neijiang_initial_deal_uses_72_tiles", _test_neijiang_initial_deal_uses_72_tiles, failures)
	if failures.is_empty():
		print("NEIJIANG CURRENT SMOKE OK")
		quit(0)
	else:
		push_error("NEIJIANG CURRENT SMOKE FAILED:\n- " + "\n- ".join(failures))
		quit(1)

func _run_test(name: String, callable: Callable, failures: Array[String]) -> void:
	var result = callable.call()
	if result == true:
		print("PASS ", name)
	else:
		failures.append("%s -> %s" % [name, str(result)])

func _test_neijiang_uses_two_suits_without_ding_que():
	var game_state = _build_game_state()
	if not bool(game_state.rules.is_neijiang_mode()):
		return "expected Neijiang mode"
	if game_state.rules.get_active_suits() != ["tiao", "tong"]:
		return "expected only tiao/tong active suits"
	return true

func _test_neijiang_initial_deal_uses_72_tiles():
	var game_state = _build_game_state()
	game_state.start_new_round()
	var players: Array = game_state.players
	var total_hand := 0
	for player in players:
		total_hand += Array(player.get("hand_tiles", [])).size()
	if total_hand != 53:
		return "expected 53 dealt tiles before first play, got %d" % total_hand
	if int(game_state.wall_tiles.size()) != 19:
		return "expected 19 wall tiles after initial deal, got %d" % int(game_state.wall_tiles.size())
	return true

func _build_game_state():
	var game_state = GAME_STATE_SCRIPT.new()
	get_root().add_child(game_state)
	game_state.rules.apply_mode(RULE_CONFIG_SCRIPT.MODE_NEIJIANG_CLASSIC)
	return game_state
```

- [ ] **Step 0.4: Run current smoke runner**

Run:

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangCurrentSmokeRunner.gd
```

Expected: `NEIJIANG CURRENT SMOKE OK`.

- [ ] **Step 0.5: Migrate bao jiao/bao gang runner**

Move the useful tests from `tests/NeijiangBaoGangRegressionRunner.gd` into `tests/current/NeijiangBaoJiaoBaoGangRunner.gd`, preserving:

```text
csharp_self_action_exposes_gang_subtype
game_state_executes_csharp_add_gang_subtype
opening_bao_jiao_queue_scans_ai_and_human_players
bao_jiao_blocks_peng_and_non_whitelist_discard_gang
bao_jiao_allows_whitelisted_discard_gang
bao_jiao_allows_only_whitelisted_an_gang
```

- [ ] **Step 0.6: Create C# contract runner skeleton**

Create `tests/current/NeijiangCSharpContractRunner.gd` with tests that fail until Phase 1 contract fixes are made:

```text
csharp_action_tile_matches_godot_recommended_tile
csharp_candidate_reasons_survive_godot_mapping
self_action_gang_subtype_survives_godot_mapping
```

- [ ] **Step 0.7: Run Phase 0 current suite**

Run:

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangCurrentSmokeRunner.gd
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangBaoJiaoBaoGangRunner.gd
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangCSharpContractRunner.gd
```

Expected: smoke and bao jiao suites pass; contract suite may contain one expected failing test that Phase 1 fixes.

---

## Phase 1: Contract Correctness

**Goal:** Ensure C# final action and Godot recommended/execution/UI mapping are one coherent decision.

**Files:**
- Modify: `scripts/ai/AIManager.gd`
- Modify if needed: `autoload/GameState.gd`
- Test: `tests/current/NeijiangCSharpContractRunner.gd`

- [ ] **Step 1.1: Write failing contract test for action/recommended consistency**

The test must create a C# result where `tileType` differs from the first candidate and assert Godot chooses the action tile as `recommended`.

- [ ] **Step 1.2: Fix Godot mapping**

In `AIManager.gd`, when building C# discard analysis, locate the candidate matching `csharp_result.tileType` and make that `recommended`. Keep other candidates sorted for display but do not let display sort override action.

- [ ] **Step 1.3: Verify contract runner**

Run:

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path . --script res://tests/current/NeijiangCSharpContractRunner.gd
```

Expected: `NEIJIANG CSHARP CONTRACT OK`.

---

## Phase 2: Discard Scoring Repair

**Goal:** Make posterior defense and calibrated deal-in probability part of ordinary discard EV.

**Files:**
- Modify: `dotnet/AI.Core/Engines/NeijiangDecisionEngine.cs`
- Modify: `dotnet/AI.Core/Engines/NeijiangExpectedScoreEngine.cs`
- Modify or create: `dotnet/AI.Core/Engines/NeijiangRiskCalibration.cs`
- Test: `tests/current/NeijiangAiDecisionRunner.gd` or future `dotnet/AI.Core.Tests`

- [ ] **Step 2.1: Add test for posterior defense affecting score**

Create a case where two discards have similar speed but one has high posterior danger late in the round. Expected: high posterior discard receives lower `ExpectedValue` and is not selected.

- [ ] **Step 2.2: Add calibrated danger conversion**

Replace direct `danger / 100.0` with a named C# function such as `NeijiangRiskCalibration.ToDealInProbability(danger, roundStage, maxReadyPosterior)`.

- [ ] **Step 2.3: Apply posterior adjustment to EV**

Subtract a bounded defense adjustment from `expectedValue`, with weight derived from round stage, ready state, and max ready posterior.

- [ ] **Step 2.4: Verify AI decision runner**

Run the focused AI decision suite and C# smoke project.

---

## Phase 3: Hand-Efficiency Deepening

**Goal:** Add old-hand hand-efficiency features beyond simple shanten and ukeire.

**Files:**
- Create: `dotnet/AI.Core/Engines/NeijiangHandShapeEngine.cs`
- Modify: `dotnet/AI.Core/Models/NeijiangCandidateDetail.cs`
- Modify: `dotnet/AI.Core/Engines/NeijiangDecisionEngine.cs`
- Test: `tests/current/NeijiangAiDecisionRunner.gd` or future C# tests

- [ ] **Step 3.1: Add shape case tests**

Test cases:

```text
good two-sided shape is kept over edge wait when shanten is equal
same-shanten improvement count raises candidate score
pair overload is penalized when seven-pairs route is weak
isolated terminal-like weak tile is preferred discard over flexible middle tile
```

- [ ] **Step 3.2: Implement hand shape summary**

Expose fields:

```text
GoodShapeCount
BadShapeCount
PairPressure
TaatsuOverflow
SameShantenImprovementCount
MiddleTileFlexibility
ShapeScore
```

- [ ] **Step 3.3: Add fields to candidate details and C# JSON output**

Godot should receive shape fields but not compute them.

- [ ] **Step 3.4: Verify shape tests and UI mapping**

Run AI decision and contract runners.

---

## Phase 4: Evidence Model

**Goal:** Convert visible table facts into structured evidence for later posterior counting.

**Files:**
- Create: `dotnet/AI.Core/Models/NeijiangEvidenceSnapshot.cs`
- Create: `dotnet/AI.Core/Engines/NeijiangEvidenceEngine.cs`
- Modify: `dotnet/AI.Core/Models/NeijiangStateView.cs`
- Modify: `scripts/ai/csharp_ai_bridge.gd`
- Modify: `scripts/ai/NeijiangCSharpRuntime.cs`
- Test: `tests/current/NeijiangAiDecisionRunner.gd` or future C# tests

- [ ] **Step 4.1: Extend state input without moving logic to Godot**

Add fields for:

```text
Scores
BaoJiaoLocked
BaoGangWhitelist18
NoHuEvidence events
NoPengEvidence events
NoGangEvidence events
RecentAction history
```

- [ ] **Step 4.2: Implement evidence snapshot**

Build:

```text
ExactSafeTiles18
NoHuEvidence18
NoPengEvidence18
NoGangEvidence18
AbandonedSuitEvidence
MeldPatternEvidence
RecentDiscardTrend
```

- [ ] **Step 4.3: Verify evidence cases**

Tests must prove passed-hu evidence lowers wait probability input, while state changes can later decay evidence.

---

## Phase 5: Opponent Range and Wait Probability

**Goal:** Upgrade belief from formula-only heuristic to evidence-backed range/wait/wall posterior.

**Files:**
- Create: `dotnet/AI.Core/Engines/NeijiangOpponentRangeEngine.cs`
- Modify: `dotnet/AI.Core/Engines/NeijiangBeliefEngine.cs`
- Modify: `dotnet/AI.Core/Models/NeijiangBeliefSnapshot.cs`
- Test: AI decision or C# tests

- [ ] **Step 5.1: Add deterministic probability tests**

Use fixed visible states to verify:

```text
Exact discards reduce same-tile wait probability
Passed-hu evidence reduces that tile's wait probability
Meld focus raises related suit demand
Unknown wall posterior remains bounded and sums sensibly
```

- [ ] **Step 5.2: Implement lightweight range scoring first**

Prefer deterministic range weights before expensive sampling. Add sampling only if deterministic tests prove insufficient.

- [ ] **Step 5.3: Add performance guard**

Decision analysis should stay within the existing budget for normal turns.

---

## Phase 6: EV and Explanation Integration

**Goal:** Use counting probabilities in decisions and expose readable C# reasons.

**Files:**
- Modify: `dotnet/AI.Core/Engines/NeijiangDecisionEngine.cs`
- Modify: `dotnet/AI.Core/Engines/NeijiangReactionDecisionEngine.cs`
- Modify: `dotnet/AI.Core/Engines/NeijiangSelfActionDecisionEngine.cs`
- Modify: `scripts/game/MainTable.gd` or `scripts/ui/AIAssistant.gd` if display mapping needs fields
- Test: `tests/current/NeijiangAiPanelRunner.gd`

- [ ] **Step 6.1: Add explanation assertions**

Tests must assert that selected and non-selected hand tiles can show C# reasons that include probability/evidence fields.

- [ ] **Step 6.2: Integrate probability reasons**

Candidate reasons should include:

```text
target opponent
deal-in probability
wall posterior
no-hu evidence
shape reason
EV components
```

- [ ] **Step 6.3: Verify UI runner**

Run AI panel runner plus current UI smoke.

---

## Phase 7: A/B Calibration

**Goal:** Prove the new model helps or at least justify tradeoffs with real fixed-seed round metrics.

**Files:**
- Modify: `tests/ai_pressure_benchmark.gd`
- Create: `tests/current/NeijiangAiBenchmarkSmokeRunner.gd`
- Create: `docs/testing/neijiang-ai-benchmark-template.md`

- [ ] **Step 7.1: Add fixed-seed benchmark mode**

Benchmark must record seed, preset, model version, round count, and max steps.

- [ ] **Step 7.2: Record required metrics**

Metrics:

```text
average score
win rate
self-draw rate
deal-in rate
draw rate
gang count and gang net effect
average decision time
over-budget count
forced-stop count
```

- [ ] **Step 7.3: Run smoke benchmark**

Run 20-50 fixed-seed rounds after each major AI phase.

- [ ] **Step 7.4: Run release benchmark**

Run 200+ fixed-seed rounds before publishing a new version.

---

## Completion Criteria

- Current regression map exists and legacy tests are classified.
- Focused current runners replace the monolithic runner as the primary acceptance gate.
- C# action/recommended/UI/execution mapping is contract-tested.
- Ordinary discard scoring uses calibrated risk and actual posterior defense pressure.
- Hand-efficiency features are visible in C# candidate details.
- Evidence and posterior probability models are C# owned and exposed to Godot as data.
- UI explanations are driven by C# candidate details.
- A/B benchmark output exists for the final AI model.
