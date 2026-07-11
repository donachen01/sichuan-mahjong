# Dirty Worktree Groups - 2026-05-22

This file organizes the current uncommitted work so it can be reviewed or committed in coherent chunks. It is intentionally not a commit record.

## Group 1 - C# AI decision, bao-jiao, and hell challenge scoring

Files:

```text
dotnet/AI.Core.Cli/Program.cs
dotnet/AI.Core.Smoke/Program.cs
dotnet/AI.Core/Engines/NeijiangBaoJiaoActionEngine.cs
dotnet/AI.Core/Engines/NeijiangHellChallengeEngine.cs
dotnet/AI.Core/Models/NeijiangDecisionResult.cs
dotnet/AI.Core/Models/NeijiangHellOracleResult.cs
scripts/ai/AIManager.gd
scripts/ai/NeijiangCSharpRuntime.cs
tests/current/NeijiangCSharpContractRunner.gd
```

Purpose:

- Preserve backend ownership of AI decision scoring.
- Keep bao-jiao/bao-gang decisions in C#.
- Preserve candidate diagnostics such as `feeds_human_peng`, `keeps_ready`, and hell challenge candidate details.

Recommended verification before committing:

```bash
dotnet run --project dotnet/AI.Core.Smoke/AI.Core.Smoke.csproj
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangCSharpContractRunner.gd
```

## Group 2 - Hell training recording and decision trace

Files:

```text
autoload/GameState.gd
tests/current/NeijiangCurrentSmokeRunner.gd
tests/current/NeijiangHellTrainingRunner.gd
```

Purpose:

- Restore desktop Godot.NET debug hell-training recording into `res://测试数据统计/...`.
- Keep mobile/exported runtime from using the desktop debug training switch.
- Persist `turn_diagnostic` and selected-candidate scoring fields in training snapshots.
- Preserve debug decision trace for fact-based replay.

Recommended verification before committing:

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangHellTrainingRunner.gd
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangCurrentSmokeRunner.gd
```

## Group 3 - UI layout and debug controls

Files:

```text
scripts/game/MainSceneV2.gd
scripts/ui/PlayerUI.gd
tests/NeijiangUiRegressionRunner.gd
tests/V17LayoutContract.gd
tests/TopOpponentMeldLayoutRegressionRunner.gd
tests/TopOpponentMeldLayoutRegressionRunner.gd.uid
```

Purpose:

- Top opponent hand and meld layout uses available horizontal space.
- Debug menu includes the revealed-hand control the user verified.
- Layout tests cover the previously clipped top opponent melds.

User verification:

- User reported backlog item 4 passed.
- User reported backlog item 5 passed.

Recommended verification before committing:

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/NeijiangUiRegressionRunner.gd
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/TopOpponentMeldLayoutRegressionRunner.gd
```

## Group 4 - Version/export packaging

Files:

```text
export_presets.cfg
tools/export_android_debug.sh
```

Purpose:

- Align export preset version fields with `project.godot` version `1.0.49`.
- Keep Android package naming/build behavior aligned with the visible startup version.

Recommended verification before committing:

```bash
rg -n 'short_version|application/version|version/code|version/name|config/version' project.godot export_presets.cfg
```

## Group 5 - Training operations tooling and docs

Files:

```text
docs/backlog/current-backlog.md
docs/handoff/current-handoff.md
docs/handoff/dirty-worktree-groups-20260522.md
tools/__init__.py
tools/hell_training_index.py
tools/hell_replay_compare.py
tools/create_regression_evidence_package.py
tests/tools/test_training_tools.py
```

Purpose:

- Maintain current handoff/backlog.
- Provide a searchable hell-training index.
- Provide summary/manifest comparison for replay-style calibration checks.
- Create standardized regression evidence packages.

Recommended verification before committing:

```bash
python3 -m unittest tests.tools.test_training_tools
```

