# 当前 Backlog - 内江麻将工程

更新时间：2026-05-22  
工作目录：`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2`  
主目标：把 AI 地狱训练模式用起来，基于真实牌桌数据持续优化 C# AI。

## Backlog 使用规则

每个实战 bug 必须满足：

1. 第一条测试使用用户当时真实牌桌数据。
2. 第二条测试使用同类型扩展数据。
3. 两条测试都通过才算通过。
4. 所有证据放进 `测试数据统计/回归证据_YYYYMMDD_<问题名>/`。
5. 如果拿不到真实数据，先补日志能力或明确说明缺口。

## P0 - 当前最高优先级

### P0-1. 用最新地狱训练样本复盘用户继续打出的 AI 错牌

状态：待执行  
原因：用户现在要继续做 AI 地狱训练模式，算法优化必须从真实样本开始。

输入来源：

```text
测试数据统计/hell_training/
测试数据统计/hell_marked_cases/
测试数据统计/hell_replay/
```

执行步骤：

1. 按用户反馈时间找到对应 `*_decision_*.json`。
2. 确认 `seat`、`decision_type`、`actual_action`、`visible_state.players`、`hidden_state.all_hands18`。
3. 读取 `fair_ai.turn_diagnostic.selected` 和 `top_score_candidates`。
4. 对比候选牌的：
   - `keeps_ready`
   - `feeds_human_hu`
   - `feeds_human_peng`
   - `feeds_human_gang`
   - `exact_deal_in`
   - `human_peng_penalty`
   - `peng_only_interaction_bonus`
5. 写真实复盘测试。
6. 写同类型扩展测试。
7. 修 C# AI。
8. 输出证据目录。

验收：

- 能指出真实 session id 和 decision index。
- 能列出当时所有候选牌分值。
- 能解释 AI 为什么选了那张牌。
- 能证明修复后真实样本和扩展样本都通过。

### P0-2. 对“自己能下叫，只给本家碰不点炮，可以打”的口径继续校准

状态：部分完成，继续观察  
相关文件：

```text
dotnet/AI.Core/Engines/NeijiangHellChallengeEngine.cs
dotnet/AI.Core.Smoke/Program.cs
dotnet/AI.Core/Models/NeijiangHellOracleResult.cs
scripts/ai/AIManager.gd
scripts/ai/NeijiangCSharpRuntime.cs
tests/current/NeijiangCSharpContractRunner.gd
```

已知已验证口径：

```text
hell_challenge_ready_human_peng_only_tile=16 score=2558 ready=True feeds_hu=False feeds_peng=True
```

继续观察：

- AI 是否仍因“本家可碰”过度避让，导致自己不下叫。
- AI 是否误把“可碰”当成“可胡”。
- AI 是否在中后期该保听时过度防守。

验收：

- 真实样本中该类候选能正确高分。
- C# smoke 和 Godot 合同测试保留该场景。
- 训练 JSON 能看到完整评分字段。

### P0-3. 报叫/报杠后卡住或打出杠牌的真实样本复查

状态：继续观察  
背景：之前已多次修复“报叫后报杠、暗杠、摸进已报杠牌、不该打出杠牌”的问题，但用户反馈过多次复发。

重点检查：

- 报叫玩家已报杠，摸进对应第四张，应该杠，不该打出。
- 报叫玩家未报某张杠，摸进第四张，必须摸什么打什么。
- 报叫玩家不能碰牌改形。
- 前端不得替换 C# 后台返回的报叫/报杠决策。

相关测试：

```text
tests/current/NeijiangBaoJiaoBaoGangRunner.gd
tests/current/NeijiangBaoJiaoFourthTileEvidenceRunner.gd
tests/current/NeijiangCurrentSmokeRunner.gd
tests/current/NeijiangCSharpContractRunner.gd
dotnet/AI.Core.Smoke/Program.cs
```

验收：

- 真实日志样本一条。
- 同类型扩展样本一条。
- C# 和 Godot 执行链一致。
- 证据目录包含原始日志、测试输出、关键代码片段。

## P1 - 近期工程整理

### P1-1. 完成顶部对家手牌和碰杠动态排布

状态：用户已验证通过（2026-05-22）  
相关文件：

```text
scripts/ui/PlayerUI.gd
tests/V17LayoutContract.gd
tests/TopOpponentMeldLayoutRegressionRunner.gd
```

目标：

- 对家顶部手牌加碰杠最多一排 18 张。
- 多组碰杠时向左利用空白空间。
- 不遮挡玩家名称和分数。
- 手机宽屏和桌面窗口都能显示完整。

验收：

- 用户已确认第 4 条通过。
- 后续提交前仍建议跑布局 regression。

### P1-2. 左侧菜单明牌按钮打开后的交互确认

状态：用户已验证通过（2026-05-22）  
相关文件：

```text
scripts/game/MainSceneV2.gd
tests/NeijiangUiRegressionRunner.gd
```

验收：

- 用户已确认第 5 条通过。
- 后续提交前仍建议跑 UI regression。

### P1-3. 整理版本号和导出 preset

状态：已处理（2026-05-22）  
当前事实：

```text
project.godot: application/config/version = 1.0.49
export_presets.cfg: application/short_version = 1.0.49
export_presets.cfg: application/version = 1.0.49
export_presets.cfg: version/code = 49
export_presets.cfg: version/name = 1.0.49
```

风险：

- 启动页版本号来自 `project.godot`。
- 安卓安装包版本可能来自 export preset。
- 两者不一致容易造成用户看到的版本、安装包名、安卓系统版本不一致。

验收：

- 已统一 export preset 到 1.0.49 / code 49。
- 打包前仍需确认启动页版本号可见。
- 打包后仍需确认 APK 文件名和 Android 系统版本一致。

### P1-4. 当前 dirty worktree 分批提交或整理

状态：已整理分组，未提交（2026-05-22）  
当前改动跨多个主题：

- C# AI 给碰互动和报叫报杠。
- Godot 训练日志和 debug trace。
- UI 布局和菜单。
- Android 导出脚本。
- 测试 runner。

建议拆分：

1. AI 决策和 C# 合同修复。
2. 地狱训练记录恢复。
3. UI 布局和明牌按钮。
4. Android 导出脚本和版本整理。
5. 训练工具和 handoff/backlog 文档。

整理文件：

```text
docs/handoff/dirty-worktree-groups-20260522.md
```

验收：

- 每个提交有对应测试输出。
- 不把不同主题混进同一个提交。

### P1-5. 1.0.57 当前 dirty worktree 建立检查点并分批归档

状态：待处理（2026-06-30）

背景：当前工作区包含多批未提交改动，主要覆盖报叫/报杠卡死修复、AI 老手策略、AIContextCache、逐局压测/复盘报告、版本号与变更记录。用户已确认先把 dirty worktree 问题作为待处理问题，不在本轮 AI 出牌审计中清理。

建议拆分：

1. 报叫/报杠与 stale AI turn 恢复修复。
2. 老手 AI 上下文缓存、策略模式、候选排序和 C# 合同字段。
3. AI 逐张出牌审计、压测报告和训练索引工具。
4. 版本号、CHANGELOG、Android 打包元数据。
5. 临时生成数据和 replay result 单独确认是否进入版本库。

验收：

- 先建立当前状态检查点，避免后续调 AI 时覆盖已验证修复。
- 每组提交对应清晰验证命令和输出摘要。
- 临时测试输出、生成 JSON、真实 fixture 分开处理。
- 不把本轮出牌审计新增改动和旧修复混成不可拆的大提交。

## P2 - 后续质量提升

### P2-1. 建立训练样本索引工具

状态：已实现基础版（2026-05-22）  
目标：快速从 `hell_training` 中按时间、seat、tile、action、feeds_human_peng、exact_deal_in 等字段搜索样本。

工具：

```text
tools/hell_training_index.py
tests/tools/test_training_tools.py
```

验收：

- `python3 -m unittest tests.tools.test_training_tools` 已通过。
- 已对真实目录生成：
  - `测试数据统计/hell_training_index/20260522_index.csv`
  - `测试数据统计/hell_training_index/20260522_summary.md`
- 本次索引统计：1429 条 decision、17 个 session、5 条 `feeds_human_peng` 候选。

### P2-2. 回放 manifest 真正驱动自动 replay

状态：已实现 summary/manifest 对比基础版（2026-05-22）  
现状：`hell_replay` 已有 manifest；当前工具先支持读取 summary 或可解析到 summary 的 manifest，输出修复前后 category/severity/count 差异。

工具：

```text
tools/hell_replay_compare.py
tests/tools/test_training_tools.py
```

验收：

- `python3 -m unittest tests.tools.test_training_tools` 已通过。
- 已生成真实对比报告：
  - `测试数据统计/hell_replay_compare/20260522_compare.md`
- 已验证可直接读取真实 replay manifest，并生成：
  - `测试数据统计/hell_replay_compare/20260522_manifest_compare.md`
- 注意：当前是对比基础版，不是完整自动复放引擎；完整 replay 仍可后续增强。

### P2-3. 训练报告按用户可审阅格式增强

状态：已实现基础版（2026-05-22）  
目标：每次实战反馈后自动生成审阅包：

```text
测试数据统计/回归证据_YYYYMMDD_<问题名>/
  README.md
  original_events.jsonl
  real_case_input.json
  similar_case_input.json
  before_after_scores.json
  test_output.log
  changed_files.md
  SHA256SUMS.txt
```

验收：

- 工具已实现：
  - `tools/create_regression_evidence_package.py`
  - `tests/tools/test_training_tools.py`
- `python3 -m unittest tests.tools.test_training_tools` 已通过。
- 已生成示例证据包：
  - `测试数据统计/回归证据_20260522_工具初始化/`
- 包内包含 `README.md`、`changed_files.md`、`SHA256SUMS.txt` 和 `source/`。

## 常用验证命令

Godot 当前 smoke：

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangCurrentSmokeRunner.gd
```

C# 合同：

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangCSharpContractRunner.gd
```

地狱训练：

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangHellTrainingRunner.gd
```

AI Core smoke：

```bash
dotnet run --project /Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core.Smoke/AI.Core.Smoke.csproj
```

BaoJiao/BaoGang：

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/current/NeijiangBaoJiaoBaoGangRunner.gd
```

UI/layout：

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/NeijiangUiRegressionRunner.gd
```

```bash
/Applications/Godot.NET.app/Contents/MacOS/Godot --headless --path /Users/chendong/Documents/内江麻将工程_20260502_103823_v2 --script res://tests/TopOpponentMeldLayoutRegressionRunner.gd
```

## 不要做的事

- 不要只根据截图推断 AI 分值。
- 不要用简化 fixture 冒充真实复盘数据。
- 不要把 AI 决策逻辑塞回 Godot 前端。
- 不要在后台未返回时让前端超时自动出牌。
- 不要清理或移动 `测试数据统计` 下的证据目录，除非用户明确要求。
- 不要 reset 当前工作树。
