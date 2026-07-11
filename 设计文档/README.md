# Neijiang Mahjong Prototype

Godot 4 内江麻将项目（独立内江麻将工程）。

当前工程已不是“首阶段脚手架”，而是持续迭代中的**可玩原型**，已包含：

- 内江麻将两门牌血战式主流程
- 摸打、碰、杠、胡、抢杠胡、报叫/报杠骨架
- 查叫、退税、退杠、呼叫转移等规则（内江版逐步替换）
- 结算页与主桌面 UI
- 3 家电脑 AI + 本家 AI 出牌辅助
- AI 调参面板、自动学习与压测统计输出

## Current milestone

- 主桌面与结算界面可持续对战
- 规则基线已落地到核心判定链
- 内江专用回归入口 `tests/NeijiangRegressionRunner.tscn` 当前 `27/27` 通过
- AI 已升级为分阶段、分局势、分对手画像的动态策略
- 新增“两门牌 AI Core”主链路：最小向听、活进张、宽叫、自摸率、读牌风险联合决策
- C# 路线规划已补强清一色潜力、归 / 四张同牌保护，以及“给碰但不点炮、不拖慢自己下叫”的互动口径
- 报杠选择 UI 已改为单面板横排大牌选择，报杠牌会在本家与 AI 手牌中单独框出
- 测试与压测结果会输出到项目目录 `测试数据统计`

## 实战复盘测试硬性规定

针对用户实战反馈的 AI、规则、流程 bug，回归测试必须同时满足以下要求：

1. 必须以用户当时真实牌桌数据作为第一条测试用例：使用原始 `ai_analysis/.../events.jsonl`、诊断导出的完整状态，或同等粒度的真实事件记录，覆盖当时的手牌、副露、弃牌、剩余牌/牌墙、座位、分数、报叫/报杠、当前阶段、last_draw/current_discard、候选动作和 C# 诊断字段。不得只用简化或手造 fixture 代替真实用例。
2. 必须再补一条同类型扩展数据测试：同类牌理或同类流程风险，但牌面、座位或局势不同，用来防止只修单一事件号。
3. 两条测试都通过，才算该 bug 修复通过；任一条失败都不能宣布通过。
4. 如果真实日志缺关键字段，先补导出/记录能力，或在证据中明确缺口；不得用假数据冒充真实复盘。
5. 测试证据必须入包：原始事件/状态、测试输入、执行命令、测试输出、修复前后关键评分或状态变化，统一放入 `测试数据统计/...` 下的审阅文件夹。
6. 最终反馈必须明确列出真实事件来源（session id、round/event index 或诊断文件）、同类型扩展用例位置、执行命令和结果日志。

## 文档入口

建议优先看以下文档：

- 规则基线：`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/内江麻将正式规则_v1.md`
- AI 规则：`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/res/docs/ai/内江麻将AI规则_v1.md`
- AI 升级设计：`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/骨灰级AI升级设计方案_v1.md`
- 规则与测试对照：`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/规则文档_判定器_测试对照清单_v1.md`

## 文档状态说明

以下文档仍保留，但已不再是当前主入口：

- `麻将游戏开发规格书_v1.md`
  - 早期通用麻将规格草案，包含 136 张牌等旧设定，现已过时
- `规则层重构计划_v1.md`
  - 仍可用于理解当时的拆分思路，但其中“未实现”列表已有不少已完成

## Next implementation targets

1. 继续基于实战复盘调优 C# 牌型路线规划权重，重点观察清一色、归、快速下叫和给碰互动的平衡
2. 细化查叫 / 退税 / 退杠的全链路回归
3. 再做一轮桌面 UI 与交互清理


## AI Core（C# 原型）

当前工程已新增 C# 两门牌 AI 核心库：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/AI.Core.csproj`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core.Smoke/AI.Core.Smoke.csproj`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/tools/build_ai_core.sh`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core.Cli/AI.Core.Cli.csproj`

本机构建命令：

- `zsh /Users/chendong/Documents/内江麻将工程_20260502_103823_v2/tools/build_ai_core.sh`

说明：当前 AI 决策主链已转向 C#。Godot 前端负责状态机、合法候选、动画和执行；C# 负责电脑弃牌、碰、杠、胡、报叫、报杠、自摸/暗杠/补杠，以及地狱挑战透视与三家协作压制。若 C# 决策不合理，应修 C# 引擎或输入参数，不在前端覆盖。

当前桥接支持：

- Godot 内嵌 C# runtime
- TCP host 模式
- CLI JSON 回退模式

补充：C# 输出会带回 `shanten / ukeire / liveUkeire / danger / waitCount / expectedNetScore / winProbability / dealInProbability / routePlan / routePlanPrimary / routePlanScore / reasons` 等诊断字段，便于复盘和调参。
