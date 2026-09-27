# 当前 Handoff - 内江麻将工程

更新时间：2026-05-22  
工作目录：`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2`  
当前分支：`codex/matte-2p5d-tile-redesign`  
当前 HEAD：`ed2b6bd Fix backend reported bao gang decisions`  
当前项目版本：`project.godot` 为 `1.0.49`

## 一句话状态

工程当前重点是继续做 AI 地狱训练模式：用真实牌桌数据复盘 AI 的每一次后台决策，优化 C# AI 算法，Godot 只负责状态机、合法动作闸门、UI 和执行，不允许前端代替后台做牌理决策。

## 项目背景

这是 Godot 4.6 .NET 内江麻将工程，已进入可玩原型和实战调优阶段。主规则和 AI 架构见：

- `设计文档/README.md`
- `docs/superpowers/plans/2026-05-14-neijiang-ai-counting-model-roadmap.md`
- `内江麻将正式规则_v1.md`
- `res/docs/ai/内江麻将AI规则_v1.md`

当前架构边界：

- C# owns：电脑弃牌、碰、杠、胡、报叫、报杠、自摸/暗杠/补杠、地狱挑战透视、三家协作压制、候选牌评分、原因解释。
- Godot owns：牌局状态、规则执行闸门、合法候选、动画/UI、安卓打包、训练日志落盘。
- 实战 bug 修复必须以事实数据为准，不能只看截图猜测。

## 当前最重要的用户约束

1. 修 AI 或规则 bug 时，第一条测试必须使用用户当时真实牌桌数据。
2. 还必须补一条同类型扩展测试。
3. 两条都通过才算修复通过。
4. 如果拿不到真实数据，必须明确说明缺失，不能用手造数据冒充真实复盘。
5. 证据必须落到 `测试数据统计/...` 下可审阅目录，包含原始数据、测试输入、执行命令、输出结果、关键评分或状态变化。
6. 前端不参与 AI 牌理决策计算，后台 C# 输出才是决策来源；前端只做合法性和执行保护。
7. 不允许超时后自动替 AI 出牌，必须等待后台计算返回，若超时要查后台为什么超时。

这些规则也写在 `设计文档/README.md` 的“实战复盘测试硬性规定”。

## 最近完成的关键工作

### 1. 地狱训练记录链路恢复

恢复了 Godot.NET 桌面 debug 下的地狱训练记录：

- `测试数据统计/hell_training/`
- `测试数据统计/hell_marked_cases/`
- `测试数据统计/hell_replay/`

关键代码位置：

- `autoload/GameState.gd`
  - `HELL_TRAINING_DIR := "res://测试数据统计/hell_training"`
  - `HELL_MARKED_CASE_DIR := "res://测试数据统计/hell_marked_cases"`
  - `HELL_REPLAY_DIR := "res://测试数据统计/hell_replay"`
  - `DEBUG_TRAINING_RECORDING_ENABLED := true`
  - `_is_debug_training_recording_enabled()` 排除 `android / ios / web`

当前意图：

- Godot.NET 编辑器/桌面 debug：开启训练记录，方便实战复盘。
- 安卓/实用包：不靠该 debug 训练开关写 `res://` 训练样本。

### 2. 训练样本补充候选评分事实

训练 JSON 中 discard 决策会补充 `turn_diagnostic`，并保存关键候选字段：

- `keeps_ready`
- `exact_deal_in`
- `feeds_human_hu`
- `feeds_human_peng`
- `feeds_human_gang`
- `human_peng_threat`
- `human_peng_penalty`
- `tempo_peng_allowance_bonus`
- `peng_only_interaction_bonus`
- `exact_wall_remaining`
- `deal_in_target_seats`

这用于复盘用户反馈的同类问题：AI 自己能下叫，打出的牌本家只能碰不能胡，应允许打；不能为了避免普通碰而放弃自身下叫。

### 3. C# 地狱挑战和给碰互动修正

近期 C# smoke 输出过关键证据：

```text
hell_challenge_ready_human_peng_only_tile=16 score=2558 ready=True feeds_hu=False feeds_peng=True
```

含义：候选牌 16，即 8 筒，自己保持下叫，给本家碰但不点炮，应该可以作为合理选择。

### 4. UI 和布局相关未完成改动

工作树里已有与以下问题相关的改动，用户已在 2026-05-22 确认第 4、5 条验证通过：

- 对家顶部手牌和碰杠超过 3 组时动态排布，目标是一排最多 18 张，向左利用空间。
- 左侧菜单“明牌”按钮打开。
- debug 决策 trace 增强。

具体 dirty files 见下方“当前未提交状态”。

### 5. 版本号和训练工具整理

2026-05-22 已处理 backlog 第 6-10 条：

- `export_presets.cfg` 已统一到 `1.0.49 / version code 49`。
- dirty worktree 已按主题整理到 `docs/handoff/dirty-worktree-groups-20260522.md`，尚未提交。
- 新增地狱训练索引工具 `tools/hell_training_index.py`。
- 新增 replay/summary 对比工具 `tools/hell_replay_compare.py`。
- 新增标准证据包工具 `tools/create_regression_evidence_package.py`。
- 新增工具测试 `tests/tools/test_training_tools.py`。

真实产物：

```text
测试数据统计/hell_training_index/20260522_index.csv
测试数据统计/hell_training_index/20260522_summary.md
测试数据统计/hell_replay_compare/20260522_compare.md
测试数据统计/hell_replay_compare/20260522_manifest_compare.md
测试数据统计/回归证据_20260522_工具初始化/
```

## 最近验证记录

最近一次明确通过的验证命令记录如下：

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangHellTrainingRunner.gd
```

结果：`NEIJIANG HELL TRAINING OK`

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangCurrentSmokeRunner.gd
```

结果：`NEIJIANG CURRENT SMOKE OK`

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangCSharpContractRunner.gd
```

结果：`NEIJIANG CSHARP CONTRACT OK`

```bash
dotnet run --project dotnet/AI.Core.Smoke/AI.Core.Smoke.csproj
```

结果：退出码 `0`

```bash
python3 -m unittest tests.tools.test_training_tools
```

结果：`Ran 4 tests ... OK`

注意：以上是最近一次功能验证记录。若继续修改代码，必须重新运行相关命令。

## 当前训练证据锚点

最新可见地狱训练汇总：

- `测试数据统计/hell_training/20260521_182034_seedlive_summary.json`
- `decision_count = 372`
- `marked_count = 0`
- `round_index = 17`
- `category_counts = {"hell_challenge_direct": 290, "not_evaluated": 82}`
- `severity_counts = {"none": 372}`

这说明恢复训练记录后，工程目录内已经继续生成实战训练样本。

另一个小型专项样本：

- `测试数据统计/hell_training/20260521_174225_seedlive_decision_000001.json`
- `测试数据统计/hell_marked_cases/20260521_174225_seedlive_mark_0001.json`
- `测试数据统计/hell_replay/20260521_174225_seedlive_replay_manifest.json`

该样本确认过字段：

```text
tile_label = 8筒
score = 2558
shanten = 0
keeps_ready = true
feeds_human_hu = false
feeds_human_peng = true
feeds_human_gang = false
peng_only_interaction_bonus = 420
```

## 当前未提交状态

当前工作树不是干净状态。不要随便 reset 或 checkout。

已修改文件：

```text
autoload/GameState.gd
dotnet/AI.Core.Cli/Program.cs
dotnet/AI.Core.Smoke/Program.cs
dotnet/AI.Core/Engines/NeijiangBaoJiaoActionEngine.cs
dotnet/AI.Core/Engines/NeijiangHellChallengeEngine.cs
dotnet/AI.Core/Models/NeijiangDecisionResult.cs
dotnet/AI.Core/Models/NeijiangHellOracleResult.cs
scripts/ai/AIManager.gd
scripts/ai/NeijiangCSharpRuntime.cs
scripts/game/MainSceneV2.gd
scripts/ui/PlayerUI.gd
tests/NeijiangUiRegressionRunner.gd
tests/V17LayoutContract.gd
tests/current/NeijiangCSharpContractRunner.gd
tests/current/NeijiangCurrentSmokeRunner.gd
tests/current/NeijiangHellTrainingRunner.gd
tools/export_android_debug.sh
```

未跟踪文件：

```text
tests/TopOpponentMeldLayoutRegressionRunner.gd
tests/TopOpponentMeldLayoutRegressionRunner.gd.uid
docs/handoff/current-handoff.md
docs/backlog/current-backlog.md
docs/handoff/dirty-worktree-groups-20260522.md
tools/__init__.py
tools/hell_training_index.py
tools/hell_replay_compare.py
tools/create_regression_evidence_package.py
tests/tools/test_training_tools.py
```

## 当前安装包状态

本地已有包：

```text
build/android/NeijiangMahjong-1.0.49-release.apk
build/android/NeijiangMahjong-1.0.49-release-aligned.apk
build/android/NeijiangMahjong-1.0.49-direct-debug.apk
```

注意：

- `project.godot` 是 `1.0.49`
- `export_presets.cfg` 已统一到 `1.0.49 / version code 49`
- 当前 handoff 初始化未重新打包，也未推送 GitHub

## 下一位接手者建议

1. 先不要改算法，先确认用户是否已经用 Godot.NET 打出新的实战样本。
2. 若用户反馈 AI 打错牌，先到 `测试数据统计/hell_training` 找对应时间段和 seat 的 decision JSON。
3. 提取真实 `visible_state / hidden_state / fair_ai / turn_diagnostic / actual_action`。
4. 用真实样本写第一条回归，再构造同类型扩展样本写第二条回归。
5. 修 C# AI 权重或规则，不在 Godot 前端覆盖出牌决策。
6. 跑 `AI.Core.Smoke`、`NeijiangCSharpContractRunner`、`NeijiangCurrentSmokeRunner` 和相关专项 runner。
7. 证据写入 `测试数据统计/回归证据_YYYYMMDD_<问题名>/`。
