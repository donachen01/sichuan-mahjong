# 四川麻将 AI Core

本目录是四川麻将新版的主 AI 决策核心，不是原型或备用实现。Godot 通过 `scripts/ai/SichuanCSharpRuntime.cs` 和 `scripts/ai/csharp_ai_bridge.gd` 同步传递 27 类牌、四家定缺、公开牌、精确牌墙和骨灰透视状态。

## 决策边界

- 默认对局使用 `bone_ash` 公平老手预设，只使用公开信息；`hell` 仅在用户显式选择挑战模式时读取四家手牌与牌墙并执行透视决策。
- 缺门未清时，C# 候选集只允许当前玩家的缺门牌。
- 四川三门牌统一编码为条 `0..8`、筒 `9..17`、万 `18..26`。
- 四川番数统一按当前规则 4 番封顶估值；主决策与结算投影共享 `1/2/4/8/16`（`2^番`）分档，3 番与 4 番不再压平。
- 出牌、响应和自摸/杠决策以 C# 为唯一线上来源；Godot 不再用本地首张牌逻辑替代失败决策。

## 主要模块

- `Codec/`：27 类牌和桌面状态契约。
- `Engines/SichuanDecisionEngine.cs`：公平信息出牌候选与综合决策。
- `Engines/SichuanHellChallengeEngine.cs`：显式“透视围剿挑战”出牌决策，不作为老手基线。
- `Engines/SichuanReactionDecisionEngine.cs`：碰、杠、胡、过响应。
- `Engines/SichuanRoutePlanEngine.cs`：平胡、对子胡、清一色、七对等四川路线规划。
- `Engines/SichuanExpectedScoreEngine.cs`：4 番封顶的净分期望，与结算投影共用 `SichuanRuleSnapshot.Frozen`。
- `Models/SichuanStateView.cs`：手牌、定缺、分数、公开信息和透视输入。

## 评估原则

线上候选总分不能给自己判卷。`scripts/ai/sichuan_old_hand_discard_scorer.gd` 作为独立规则裁判，只根据向听、活张、听口、风险、精确点炮、喂碰杠和牌型破坏评分，不读取在线 AI 的 `score` 排序。30 局逐张审计和固定种子 A/B 均由 `tests/current/sichuan_ai_pressure_benchmark.gd` 生成。
