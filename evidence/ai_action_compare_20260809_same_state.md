# 同状态 AI 对照记录（2026-08-09）

本记录使用同一手牌、同一公开牌墙、同一牌局阶段，分别调用当前 C# 决策入口。它是行为对照，不是新增固定回归清单。

## 状态

- 场景：`flush_pressure`
- 手牌编码：`0,1,2,2,3,4,5,6,6,7,8,8,1,4`
- 牌墙：24
- 活跃玩家：4
- 信息模式：公开（`bone_ash`）或 oracle（`hell`）

## 结果

| 路径 | preset | informationMode | mobileSpeedMode | forceLightweight | 动作 | 分数 | 备注 |
|---|---|---|---:|---:|---|---:|---|
| 桌面 bone_ash | bone_ash | public | false | false | 弃 `4` | 4125 | 完整老手核心，完整候选返回 |
| iOS bone_ash | bone_ash | public | false | false | 弃 `4` | 4125 | 仅 `compactResult=true`，动作与价值完全一致 |
| 诊断轻量路径 | bone_ash | public | false | true | 弃 `4` | 4075 | 仅显式诊断，非默认手机路径 |
| hell challenge | hell | oracle | false | false | 弃 `4` | 10120 | 透视围剿；精确剩余牌计数参与，不能作为老手基线 |

### bone_ash 前三候选价值分解

| 候选 | 总分 | 向听 | 活张 | 净收益 | 预计番 | 点炮概率 | 危险 | 路线 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 弃 `4` | 4125 | 0 | 5 | 10.5808 | 1.6533 | 0.0554 | 37 | 清一色 |
| 弃 `1` | 4109 | 0 | 5 | 10.6070 | 1.6533 | 0.0499 | 35 | 清一色 |
| 弃 `6` | 3953 | 0 | 4 | 9.6166 | 1.6533 | 0.0554 | 37 | 清一色 |

hell 同状态前三候选为：弃 `4`（10120，A_READY，精确活口 4）、弃 `1`（9839，A_READY，精确活口 4）、弃 `8`（9836，A_READY，精确活口 6）。高分差来自 oracle 牌墙与围剿目标，不是移动端加速。

## 同一碰杠状态

- reaction tile：`1`
- 完整 bone_ash：`Gang 454`，短搜索 72 次
- 轻量诊断：`Gang 379`，不搜索
- 动作一致，但价值分解不同；这是后续性能校准的重点。

## 解释

桌面和 iOS 的公共 bone_ash 路径现在共享 `mobileSpeedMode=false` 与同一 C# ActionValue；iOS 只保留 `compactResult` 的传输压缩。hell 的高分来自精确剩余牌、四家手牌和人类压力目标，属于挑战模式结果。`public_same_state.json` 与 `hell_same_state.json` 保存了本轮可复现输入；CLI 诊断入口会真实传递 `mobileSpeedMode/forceLightweight`，不再出现工具读取参数却未应用的假对照。

本记录中的 Brier/ECE 口径使用工程 Smoke 已有校准：`model_brier=0.1810`、`uniform_brier=0.2373`、`model_ece=0.1496`、`uniform_ece=0.1018`。后续报告应继续同时记录逐动作后悔值，不能只报弃牌 Top-1。
