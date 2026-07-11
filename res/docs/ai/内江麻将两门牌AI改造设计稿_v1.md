# 内江麻将两门牌 AI 改造设计稿 v1

## 0. 文档定位

本文档用于指导 `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2` 的下一阶段 AI 重构。

目标不是继续在现有 GDScript 启发式上堆规则，而是在保留当前业务层、规则层、UI 层的前提下，新增一套 **内江麻将两门牌专用 AI Core**，解决以下问题：

- AI 出牌不够老练
- 早听牌能力不足
- 下叫速度慢
- 宽叫、自摸叫判断不强
- 读牌与防守不精准
- 随着牌局深入，场况理解不到位
- AI 计算越来越复杂后，主线程容易卡顿

---

## 1. 结论先行

### 1.1 当前工程现状

当前内江麻将工程已经具备以下基础：

- 规则判定链路完整
- 弃牌建议链路完整
- AI 调参面板已存在
- AI 自动学习与压测统计已存在
- 电脑玩家已经具备基础攻守与反应逻辑

但当前核心 AI 仍以 **GDScript 打分型启发式** 为主，主要依赖：

- `scripts/core/shanten_analyzer.gd`
- `scripts/core/discard_advisor.gd`
- `scripts/core/risk_analyzer.gd`
- `scripts/core/lookahead_evaluator.gd`
- `scripts/core/reaction_advisor.gd`

这条链路已经足够支撑原型与中等强度 AI，但不足以做成真正“老江湖”级别的内江两门牌 AI。

### 1.2 为什么必须按“两门牌专用 AI”重构

内江麻将不是三门麻将的轻微变体，而是 **天然两门牌高密度博弈**。

两门牌的直接后果：

- 成搭速度更快
- 听牌速度更快
- 同类危险牌更集中
- 中后盘公共信息更强
- “先成叫、叫得宽、叫得活” 比单纯追番更关键

因此，AI 的第一目标必须改为：

> **尽快形成高质量听牌（叫），再在不丢速度的前提下保留番型和防守收益。**

### 1.3 改造总方向

建议新增一层高性能 AI Core，具体为：

- **核心算法层**：C#（优先）
- **业务桥接层**：GDScript
- **并发执行层**：WorkerThreadPool
- **调试可视化层**：AIDebugPanel

设计原则：

1. 只为内江麻将两门牌服务
2. 所有重计算移出 GDScript
3. 所有 UI 表现与 AI 决策异步解耦
4. 所有学习能力只作用于参数，不直接在线修改核心逻辑

---

## 2. 改造目标

### 2.1 拟人化老练度目标

AI 应具备以下行为特征：

- 前期尽快成叫
- 同向听时优先宽叫
- 宽叫中优先活张多、自摸率高的叫型
- 高番路线只在“不明显拖慢速度”时追求
- 对报叫、强副露、尾盘风险有明显防守收缩
- 能根据牌局进程切换速度 / 番型 / 防守重心

### 2.2 性能目标

- 单步 AI 决策耗时目标：`<= 500ms`
- 正常大多数决策：`<= 200ms`
- 主线程不阻塞
- UI 动画播放不等待 AI 计算完成
- MCTS 超时熔断：`350~400ms`

### 2.3 模块化目标

逻辑拆成以下独立层：

- 牌编码层
- 向听 / 进张基础层
- 听牌质量评估层
- 贝叶斯读牌层
- 危险度估计层
- 有限前瞻 / MCTS 层
- 最终决策聚合层
- GDScript 调度层
- DebugPanel 可视化层

---

## 3. 现有架构与改造边界

### 3.1 保留模块

这些文件保留为业务层 / 规则层主体：

- `scripts/game/MainSceneV2.gd`
- `scripts/game/GameManager.gd`
- `scripts/core/mahjong_judge.gd`
- `scripts/core/score_resolver.gd`
- `scripts/core/fan_resolver.gd`
- `scripts/core/rule_config.gd`
- `scripts/core/ai_learning_engine.gd`
- `scripts/core/ai_tuning_config.gd`

### 3.2 降级为桥接或兜底的模块

以下模块不再承担主要重计算，只保留为：

- 兼容旧逻辑
- 调试兜底
- 辅助解释生成

包括：

- `scripts/core/shanten_analyzer.gd`
- `scripts/core/discard_advisor.gd`
- `scripts/core/risk_analyzer.gd`
- `scripts/core/lookahead_evaluator.gd`
- `scripts/core/reaction_advisor.gd`

### 3.3 新增 AI Core 层

建议新增目录：

- `dotnet/AI.Core/`
- `scripts/ai/`

建议新增核心类：

- `dotnet/AI.Core/NeijiangTileCodec.cs`
- `dotnet/AI.Core/NeijiangStateCodec.cs`
- `dotnet/AI.Core/NeijiangShantenEngine.cs`
- `dotnet/AI.Core/NeijiangUkeireTable.cs`
- `dotnet/AI.Core/NeijiangCallQualityEvaluator.cs`
- `dotnet/AI.Core/NeijiangBeliefModel.cs`
- `dotnet/AI.Core/NeijiangDangerEstimator.cs`
- `dotnet/AI.Core/NeijiangMctsEvaluator.cs`
- `dotnet/AI.Core/NeijiangDecisionEngine.cs`
- `dotnet/AI.Core/NeijiangStatePool.cs`

以及桥接脚本：

- `scripts/ai/AIManager.gd`
- `scripts/ai/AICoreBridge.gd`
- `scripts/ai/AIDebugPanel.gd`

---

## 4. 两门牌专用数据结构定义

### 4.1 为什么不再使用 27 维牌空间

当前很多分析默认用三门牌 `27` 种牌类型。

但内江麻将天然只有两门牌，继续用 27 维会带来：

- 无效牌型污染查表
- 危险度模型先验失真
- MCTS rollout 产生不存在的动作空间
- 状态哈希空间增大，查表收益下降

因此必须切为 **18 维牌类型空间**。

### 4.2 牌类型编码

运行时只保留两门：

- 主门 A：`0..8`
- 主门 B：`9..17`

示例：

- 若本桌两门为 `条 + 筒`
  - 条 `1..9` -> `0..8`
  - 筒 `1..9` -> `9..17`
- 若本桌两门为 `条 + 万`
  - 条 `1..9` -> `0..8`
  - 万 `1..9` -> `9..17`

因此 AI Core 永远只看到“门 A / 门 B”，不依赖具体中文花色名字。

### 4.3 建议主结构

运行时主结构建议统一为：

- `PackedInt32Array hand_types`
- `PackedInt32Array discard_types`
- `PackedInt32Array meld_types`
- `PackedInt32Array visible_types`
- `int[18] counts18`
- `int[18] remaining18`

其中：

- GDScript 层传输使用 `PackedInt32Array`
- C# 内部计算使用 `int[18]`

### 4.4 状态哈希建议

每种牌最多 4 张，共 18 种。

- 单牌种张数范围：`0..4`
- 可使用 `base-5` 编码
- 也可使用 `3bit x 18 = 54bit` 压缩到一个 `ulong`

推荐结构：

```csharp
public readonly struct NeijiangHandKey
{
    public readonly ulong Key;
    public NeijiangHandKey(ulong key)
    {
        Key = key;
    }
}
```

这会让查表、缓存、对象池都更简单。

---

## 5. 核心决策链设计

### 5.1 决策总链路

AI 单步决策统一走：

`候选弃牌生成 -> 向听硬排序 -> 进张 / 宽叫质量排序 -> 自摸率评估 -> 番型期望补偿 -> 危险度校正 -> Top-K MCTS 精修 -> 输出动作`

### 5.2 决策优先级

#### 一级：向听数最小优先

- 当前手里每一张可打牌都要模拟打出
- 对每种打法计算打出后的向听数
- 只保留向听最小的一组候选

#### 二级：宽叫优先

向听相同的候选中，优先：

- 听牌张类型更多
- 双向 / 多向听牌优于窄叫
- 可接受张分布更均匀者优先

#### 三级：活张多、自摸率高优先

宽叫相同的候选中，优先：

- 剩余活张数更多
- 别家更不容易截留
- 未来 2~3 巡自摸概率更高

#### 四级：番型路线只做补偿项

高番路线不再主导前期决策，只在以下条件加分：

- 不显著拖慢听牌速度
- 不把宽叫压成窄叫
- 不把活张压成死叫

#### 五级：危险度兜底

若进入中后盘、对手报叫、强副露或多家高威胁：

- 危险度优先级快速上升
- 若 `点炮风险 > 当前胡牌收益期望`，切换为防守模式

---

## 6. 向听与进张模块设计

### 6.1 两门牌向听设计原则

由于内江麻将只有两门牌，状态空间更小，适合：

- 标准牌型向听：优先查表
- 七对向听：可直接公式
- 副露状态下：使用增量计算

### 6.2 核心输出

`NeijiangShantenEngine` 输出：

- `best_shanten`
- `standard_shanten`
- `qi_dui_shanten`
- `shape_label`
- `candidate_discards`

### 6.3 Ukeire 查表模块

`NeijiangUkeireTable` 输入：

- `counts18`
- `meld_count`
- `allow_qi_dui`

输出：

- 每个候选弃牌的 `ukeire_count`
- 每个候选弃牌的 `ting_tile_types`
- 每个候选弃牌的 `live_tile_count`

### 6.4 听牌质量评价模块

新增 `NeijiangCallQualityEvaluator`：

输出指标：

- `wide_wait_score`
- `live_wait_score`
- `self_draw_score`
- `tight_wait_penalty`
- `dead_wait_penalty`

推荐公式：

`call_quality = W1 * wide_wait + W2 * live_tiles + W3 * self_draw_rate - W4 * dead_wait_penalty`

注意：

- 此模块只在**同向听候选**之间比较
- 不能反过来压倒向听优先级

---

## 7. 读牌与防守引擎设计

### 7.1 两门牌下读牌的核心变化

三门麻将更偏“哪门竞争小”。

两门麻将更偏：

- 对手正在做速度还是做对子
- 对手在保哪类中张
- 对手是不是已经接近听牌
- 对手是否已转守

因此读牌模型重点不再是“花色猜测”，而是：

- `need_prob[18]`
- `pair_prob[18]`
- `ready_prob`
- `speed_profile`
- `defense_profile`

### 7.2 贝叶斯模型建议

新增：`NeijiangBeliefModel`

对每个对手维护：

- `NeedProb[18]`
- `PairProb[18]`
- `ReadyProb`
- `OffenseTendency`
- `DefenseTendency`

### 7.3 更新事件

每次以下事件发生时更新信念：

- 弃牌
- 碰
- 杠
- 报叫
- 补杠
- 长时间不打某类中张
- 尾盘仍打危险生张

### 7.4 危险度估计

新增：`NeijiangDangerEstimator`

输入：

- 当前待打牌
- `BeliefModel`
- 剩余牌统计
- 巡目阶段

输出：

- `deal_in_probability`
- `danger_label`
- `safe_reason`
- `threat_sources`

### 7.5 弃胡模式切换规则

若满足：

- `P(点炮) * 预期失分 > P(成胡) * 预期得分`

则进入：

- `弃胡保命`
- 优先打现物 / 半现物 / 低风险张
- 已成窄叫也不强行顶到底

---

## 8. MCTS 与有限前瞻设计

### 8.1 为什么两门牌更适合做轻量 MCTS

两门牌动作空间更小，且节奏更快，意味着：

- rollout 更容易收敛
- Top-K 候选更清晰
- 模拟价值比三门麻将更高

### 8.2 设计原则

- 不做全动作树搜索
- 只对 Top-K 候选弃牌做 MCTS 精修
- K 建议取 `3~4`
- 展望深度只做 `6~8` 巡

### 8.3 rollout policy

rollout 不是随机出牌，而是用弱策略：

1. 向听最优
2. 宽叫优先
3. 自摸率优先
4. 风险过高则收守

### 8.4 熔断机制

- 总思考预算：`400ms`
- MCTS 预算：`<= 350ms`
- 超时立即停止，回退到静态 EV 结果

### 8.5 MCTS 输出

- `p_ting_in_2turn`
- `p_win_in_6turn`
- `expected_score`
- `p_deal_in`
- `expected_net_value`

---

## 9. 反应决策模块重构

### 9.1 现状问题

当前碰 / 杠 / 过判断仍偏启发式，容易：

- 能碰不碰
- 能提速却错过副露
- 为了短期番数牺牲成叫速度
- 尾盘还做危险杠

### 9.2 新规则

#### 碰牌

只有以下情况才碰：

- 碰后向听下降
- 碰后维持或扩大宽叫
- 碰后 2 巡内成叫概率显著上升
- 碰后防守能力不崩

#### 杠牌

只有以下情况才杠：

- 杠后不破坏最佳叫型
- 杠分收益大于风险成本
- 尾盘未进入高危阶段

#### 报叫 / 报杠

- 报叫前必须先找“最佳报叫型”
- 如果同时可报杠，则计算“报叫 + 报杠”的联合最优方案
- 报叫后只允许符合锁定规则的后续动作

---

## 10. Godot 专项实现方案

### 10.1 语言分层

#### C# 层

承担：

- 向听数
- 进张查表
- 听牌质量
- 贝叶斯读牌
- 危险度
- MCTS
- 状态对象池

#### GDScript 层

承担：

- GameManager / MainSceneV2 调度
- 快照组装
- 结果应用
- 动画触发
- AI 调参面板
- DebugPanel 显示

### 10.2 WorkerThreadPool 调度

新增：`scripts/ai/AIManager.gd`

职责：

- 接收 AI 决策请求
- 将 payload 投递到后台线程
- 通过 Signal 把结果回主线程

建议信号：

- `ai_decision_ready(seat, decision)`
- `ai_debug_ready(seat, debug_info)`

### 10.3 对象池

新增：`NeijiangStatePool.cs`

复用对象：

- `counts18`
- `remaining18`
- `simulation_state`
- `belief_state`

减少：

- GDScript Dictionary 深复制
- 高频 new / delete
- GC 抖动

### 10.4 资源管理

将以下预计算产物存为资源：

- `res://res/docs/ai/tables/neijiang_shanten_table.tres`
- `res://res/docs/ai/tables/neijiang_ukeire_table.tres`
- `res://res/docs/ai/tables/neijiang_wait_quality_table.tres`

启动时一次性加载到 AI Core。

---

## 11. DebugPanel 设计

建议新增：`scripts/ai/AIDebugPanel.gd`

### 必显信息

- 当前座位
- 当前策略状态
- 当前向听数
- Top 5 弃牌候选
- 每张候选的：
  - `Shanten`
  - `Ukeire`
  - `WideWait`
  - `LiveTiles`
  - `SelfDrawProb`
  - `DealInRisk`
  - `ExpectedValue`
- 当前 MCTS rollout 次数
- 熔断原因
- 最终推荐动作

### UI 建议

- 平时默认隐藏
- 调试模式下右上角打开
- 支持锁定当前玩家视角
- 支持回放最近一次 AI 决策过程

---

## 12. 自动学习与参数调优方案

### 12.1 当前原则

自动学习只允许调整参数，不允许在线篡改核心逻辑。

### 12.2 可学习参数

建议允许学习：

- `tempo_weight`
- `wide_wait_weight`
- `live_tile_weight`
- `self_draw_weight`
- `fan_expectation_weight`
- `risk_weight`
- `defense_switch_threshold`
- `mcts_rollout_count`
- `top_k_candidate_count`

### 12.3 学习依据

每 500~1000 局离线压测后统计：

- 平均听牌巡数
- 平均成胡巡数
- 听牌率
- 自摸率
- 点炮率
- 查叫胜率
- 报叫成牌率
- 平均净 EV

### 12.4 学习方法

推荐：

- A/B 对局压测
- 小步长 hill-climbing
- 参数变更必须通过压测胜率 / EV 双确认
- 在线对局只允许小幅修正，不允许大幅漂移

---

## 13. 交付顺序（实施路线）

### Phase A：基础算子迁移

1. 新增两门牌 `18` 维编码
2. 完成 `NeijiangTileCodec.cs`
3. 完成 `NeijiangShantenEngine.cs`
4. 完成 `NeijiangUkeireTable.cs`
5. 在 `mahjong_judge.gd` 中接入桥接层

### Phase B：高质量叫模型

6. 完成 `NeijiangCallQualityEvaluator.cs`
7. 将同向听排序统一改为：宽叫 -> 活张 -> 自摸率 -> 番型
8. 替换现有 `discard_advisor.gd` 主决策出口

### Phase C：读牌与防守

9. 完成 `NeijiangBeliefModel.cs`
10. 完成 `NeijiangDangerEstimator.cs`
11. 替换 `risk_analyzer.gd` 主危险度模型

### Phase D：有限前瞻

12. 完成 `NeijiangMctsEvaluator.cs`
13. 接入 Top-K 候选精修
14. 加入 `350ms` 熔断

### Phase E：Godot 调度与可视化

15. 完成 `AIManager.gd`
16. 接入 `WorkerThreadPool`
17. 完成 `AIDebugPanel.gd`
18. 将调参面板与新 AI Core 参数联通

---

## 14. 第一阶段直接开工清单

### 14.1 目录结构

建议新增：

- `dotnet/AI.Core/`
- `scripts/ai/`
- `res/docs/ai/tables/`

### 14.2 第一批文件

- `dotnet/AI.Core/NeijiangTileCodec.cs`
- `dotnet/AI.Core/NeijiangStateCodec.cs`
- `dotnet/AI.Core/NeijiangShantenEngine.cs`
- `dotnet/AI.Core/NeijiangUkeireTable.cs`
- `scripts/ai/AICoreBridge.gd`
- `scripts/ai/AIManager.gd`

### 14.3 第一阶段替换范围

先不动：

- `score_resolver.gd`
- `fan_resolver.gd`
- `rule_config.gd`
- 结算逻辑
- 动画逻辑

先替换：

- 出牌建议主入口
- 向听计算
- 进张计算
- 同向听排序

---

## 15. 风险与注意事项

### 15.1 不要一次性全量替换

建议分阶段：

- 第一版先让“快听牌、宽叫”明显变强
- 第二版再做读牌
- 第三版再上 MCTS

### 15.2 不要让 AI 学习逻辑本体

学习只调参数，避免：

- 强度忽高忽低
- 某些局部数据把 AI 带偏
- 玩家打几局后 AI 行为漂移过大

### 15.3 不要把 UI 与 AI 耦合回去

AI 一定要通过信号回主线程，不允许：

- 直接在动画流程中同步等待
- 在 GDScript 主线程做长循环
- UI 控件直接触发重计算

---

## 16. 最终目标描述

改造完成后的内江两门牌 AI，应具备以下特征：

- 前期比人类更快成叫
- 中期比人类更会选宽叫和活叫
- 后期比人类更会防炮
- 全局比人类更稳定地权衡 EV
- 性能稳定，不拖帧，不阻塞主线程

用一句话概括：

> **速度像机器，读牌像老手，防守像高手，决策像老江湖。**

