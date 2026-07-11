# 内江麻将两门牌 AI 实施拆解 v1

## 0. 文档定位

本文档是 `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/res/docs/ai/内江麻将两门牌AI改造设计稿_v1.md` 的实施版补充。

目标不是继续停留在概念层，而是把“两门牌 AI Core”拆成：

- 可创建的目录结构
- 可分工的模块边界
- 可对接当前工程的桥接接口
- 可分阶段上线的迁移路径

这份文档默认以 **Godot 4.x + C# AI Core + GDScript 业务调度** 为落地方案。

### 当前实施状态（2026-05-03）

- C# 已落地常驻化基础：
  - `NeijiangStateFingerprint.cs`
  - `NeijiangDecisionCache.cs`
  - `NeijiangAiFacade.cs`
  - `AI.Core.Cli` 的 `host-tcp`
- Godot 运行链已具备：
  - `hybrid_csharp` 候选融合
  - 后台线程分析
  - 1 秒超时熔断
  - host 优先、CLI 兜底
- C# 概率读牌已开始承担真实风险判断：
  - 结合 `discards18 / melds18 / IsCalled / IsReady`
  - 能给出“现物偏安全 / 该门已弃多张 / 已报叫”等风险证据
- C# 后验读牌矩阵已接通：
  - `SeatReadyPosterior`
  - `SeatTileHoldProbability`
  - `TileWallPosterior`
  - 后验结果已参与危险度和 EV
- C# 限时搜索已接通首版骨架：
  - `NeijiangMctsEngine.cs`
  - 仅在 top 候选非常接近时触发
  - 在超时预算内做轻量 rollout，并把 `search_bonus` 回填候选 EV
- C# 自进化调参已接通首版闭环：
  - `learning-record` CLI 命令
  - 局后由 C# 学习器写回 `ai学习数据.json / ai参数学习历史.json`
  - Godot 继续复用现有调参面板与参数应用逻辑
- AI 调参面板学习回显已增强：
  - 直接显示 `学习后端 / 累计学习 / 当前偏置 / 当前参数 / 核心指标 / 最近一轮 / 学习依据`
  - 方便在真机对战后快速确认“学到了什么、为什么这样调”
- AI 调参面板已接入实时读牌摘要：
  - 显示最近一次电脑决策的 `座位 / 后端 / 耗时 / 当前策略 / 阶段 / 桌面威胁`
  - 显示 `头号威胁对手 / 疑似主攻花色 / 清一色像度 / 对对像度 / 威胁分`
  - 显示推荐出牌对应的 `听牌率 / 自摸率 / 胡牌率 / 点炮率`
  - 显示最近危险张与首条危险依据，便于核查“为什么它觉得这张危险”
- AI 调参面板已接入三类后验摘要：
  - `听牌后验`：按座位显示谁最像已经成叫 / 听牌
  - `持张后验`：围绕本次推荐打出的那张牌，显示谁最像正捏着它
  - `牌墙后验`：围绕当前推荐的进张集合，显示哪些牌最像还留在牌墙里
- 后验已正式参与决策，而不只是展示：
  - `尾盘弃牌阈值`：当 `wall_count <= 20` 且 `听牌后验 / 点炮率 / 墙里后验` 同时偏危险时，C# 出牌 EV 会自动额外收缩
  - `碰牌决策`：若尾盘有人高概率已听、且当前这张牌持张后验偏高，则非“直接成叫 / 明显提速”的碰牌会被压制
  - `明杠/补杠/暗杠决策`：若后验显示有人高概率已听，或当前杠牌相关花色被明显需求，则杠分收益会让位给防守
  - 设计目标是：`前中盘能抢速度，后巡不赌危险张；能成叫才攻，不能成叫就明显收缩`
- 候选牌级后验解释已接通：
  - 每张候选牌都会附带 `posterior_adjustment / posterior_reasons`
  - 可直接看到某张牌为何被后验压分，例如：`尾盘已到`、`听牌后验高`、`点炮率偏高`、`牌墙后验低`
  - AI 调参面板会展示前 3 名候选牌的后验压分摘要，便于快速核查排序是否合理
- 最新回归状态：
  - `NEIJIANG REGRESSION OK: 48/48`

---

## 1. 总体落地策略

### 1.1 本次改造的核心原则

1. **规则层不推倒重来**
   - `mahjong_judge.gd`
   - `fan_resolver.gd`
   - `score_resolver.gd`
   - `rule_config.gd`
   继续作为“真值裁判层”。

2. **AI 决策层独立重建**
   - 旧的 `discard_advisor.gd`、`risk_analyzer.gd`、`lookahead_evaluator.gd` 不再承担主决策职责。
   - 它们降级为：解释文案、兼容兜底、回归对照。

3. **两门牌单独建模**
   - 整套 AI 只认 `18` 个牌类型。
   - 不再以“三门牌 + 特判”的方式扩展。

4. **异步计算**
   - UI、动画、音效与 AI 决策彻底解耦。
   - AI 计算放后台线程，主线程只收结果。

5. **先做可用，再做极强**
   - Phase 1：先把“稳定、早听、不卡顿”做出来。
   - Phase 2：再叠加读牌、防守、有限模拟。

---

## 2. 目录结构设计

建议在新版本工程内新增如下结构：

```text
/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/
├─ dotnet/
│  └─ AI.Core/
│     ├─ AI.Core.csproj
│     ├─ Models/
│     │  ├─ NeijiangTile.cs
│     │  ├─ NeijiangAction.cs
│     │  ├─ NeijiangDecisionResult.cs
│     │  ├─ NeijiangBeliefSnapshot.cs
│     │  └─ NeijiangDebugSnapshot.cs
│     ├─ Codec/
│     │  ├─ NeijiangTileCodec.cs
│     │  └─ NeijiangStateCodec.cs
│     ├─ Tables/
│     │  ├─ NeijiangShantenTable.cs
│     │  └─ NeijiangUkeireTable.cs
│     ├─ Engines/
│     │  ├─ NeijiangShantenEngine.cs
│     │  ├─ NeijiangUkeireEngine.cs
│     │  ├─ NeijiangCallQualityEngine.cs
│     │  ├─ NeijiangDangerEngine.cs
│     │  ├─ NeijiangBeliefEngine.cs
│     │  ├─ NeijiangMctsEngine.cs
│     │  └─ NeijiangDecisionEngine.cs
│     ├─ Pool/
│     │  └─ NeijiangStatePool.cs
│     └─ Entry/
│        └─ NeijiangAiFacade.cs
├─ scripts/
│  ├─ ai/
│  │  ├─ AIManager.gd
│  │  ├─ AICoreBridge.gd
│  │  ├─ AIDebugPanel.gd
│  │  └─ ai_payload_builder.gd
│  └─ core/
│     ├─ discard_advisor.gd
│     ├─ risk_analyzer.gd
│     └─ reaction_advisor.gd
├─ res/
│  └─ docs/
│     └─ ai/
│        ├─ 内江麻将AI规则_v1.md
│        ├─ 内江麻将两门牌AI改造设计稿_v1.md
│        └─ 内江麻将两门牌AI实施拆解_v1.md
└─ tests/
   ├─ ai/
   │  ├─ test_neijiang_shanten.gd
   │  ├─ test_neijiang_discard_choice.gd
   │  ├─ test_neijiang_danger_profile.gd
   │  └─ test_neijiang_async_flow.gd
   └─ benchmark/
      └─ benchmark_neijiang_ai.gd
```

---

## 3. 两门牌数据模型

## 3.1 牌编码规则

内江麻将 AI 运行态只保留两门牌。

### 统一编码

- 门 A：`0..8`
- 门 B：`9..17`

例如：

- 条 `1..9` -> `0..8`
- 筒 `1..9` -> `9..17`

如果该桌实际是“条 + 万”，则：

- 条 `1..9` -> `0..8`
- 万 `1..9` -> `9..17`

AI Core 不关心中文牌名，只关心“第一门 / 第二门”。

### 运行时主结构

```csharp
public sealed class NeijiangStateView
{
    public int SeatIndex;
    public int DealerSeat;
    public int CurrentSeat;
    public int WallCount;
    public int TurnIndex;
    public int Phase;

    public int[] Hand18 = new int[18];
    public int[] Visible18 = new int[18];
    public int[] Remaining18 = new int[18];

    public int[][] Discards18 = new int[4][];
    public int[][] Melds18 = new int[4][];

    public bool[] IsCalled = new bool[4];
    public bool[] IsReady = new bool[4];
    public bool[] HasHu = new bool[4];
}
```

### GDScript 侧传输建议

统一传：

- `PackedInt32Array hand_types`
- `PackedInt32Array visible_types`
- `PackedInt32Array remaining_types`
- `Array[PackedInt32Array] discards_by_seat`
- `Array[PackedInt32Array] melds_by_seat`
- `Dictionary flags`

原因：

- Godot 序列化成本低
- 与 WorkerThreadPool 数据传输兼容
- 后面接 C# 也比较顺

---

## 4. 模块职责拆解

## 4.1 `NeijiangTileCodec.cs`

职责：

- 将现有项目中的牌对象 / 牌 ID / 花色值，映射为 AI Core 的 `18` 维编码
- 提供双向转换
- 屏蔽 UI 层牌表示差异

关键接口：

```csharp
public static int EncodeTileType(int suit, int rank, int suitA, int suitB);
public static (int suit, int rank) DecodeTileType(int tileType, int suitA, int suitB);
public static int[] BuildCount18(int[] tileTypes);
```

要求：

- 纯函数
- 无状态
- 可单测

---

## 4.2 `NeijiangStateCodec.cs`

职责：

- 把 Godot 传入的 `Dictionary` / `Array` / `PackedInt32Array`，装配成 `NeijiangStateView`
- 补齐缺省字段
- 快速生成 `Remaining18`

关键接口：

```csharp
public NeijiangStateView DecodeFromGodotVariant(Godot.Collections.Dictionary payload);
```

要求：

- 只做状态装配，不做策略判断
- 所有长度不合法的数组要自动兜底

---

## 4.3 `NeijiangShantenEngine.cs`

职责：

- 计算标准胡的向听数
- 计算七对向听数
- 给出“最小向听”
- 给出每张打出后的向听变化

关键接口：

```csharp
public int CalcStandardShanten(int[] hand18);
public int CalcSevenPairsShanten(int[] hand18);
public int CalcBestShanten(int[] hand18);
public int CalcShantenAfterDiscard(int[] hand18, int tileType);
```

实现原则：

- 两门牌状态空间更小，可做更积极缓存
- 先实现稳定版 DFS / DP
- 后续再用查表替换热点路径

产出字段：

- `base_shanten`
- `discard_to_shanten`
- `best_shanten_discards`

---

## 4.4 `NeijiangUkeireEngine.cs`

职责：

- 对每个候选弃牌，统计打出后可改善向听的有效进张
- 输出 `ukeire_count`
- 输出 `live_ukeire_count`

关键接口：

```csharp
public int CalcUkeireCount(int[] hand18, int[] remaining18, int discardType);
public PackedInt32Array CalcImprovingTiles(int[] hand18, int[] remaining18, int discardType);
```

注意：

- 这里的“进张”必须使用当前桌面 `remaining18` 过滤，不是理想牌山
- 两门牌下，宽叫价值要高于三门麻将，应在后续决策中提高权重

---

## 4.5 `NeijiangCallQualityEngine.cs`

职责：

- 评估听牌质量
- 用于解决“同向听为什么选这张打”的问题

核心维度：

1. `ready_speed_score`：是否直接到 0 向听
2. `ukeire_width_score`：进张宽度
3. `live_tile_score`：活张剩余量
4. `self_draw_score`：自摸潜力
5. `must_show_score`：必现张强度
6. `high_fan_delay_penalty`：高番拖速惩罚

关键接口：

```csharp
public CallQualityResult Evaluate(int[] hand18, int[] remaining18, int discardType, NeijiangBeliefSnapshot belief);
```

排序原则：

- 先比向听
- 再比是否成叫
- 再比宽叫
- 再比活张
- 再比自摸率
- 最后才看番型收益

---

## 4.6 `NeijiangBeliefEngine.cs`

职责：

- 维护对手持牌概率分布
- 给危险度与未来模拟提供先验

两门牌模型比三门更紧凑，建议不直接做 `136 x 4` 明细矩阵，而做：

- `18 x 4` 类型级概率矩阵
- 必要时再细化到实例牌层

核心输入：

- 对手弃牌序列
- 对手副露结构
- 报叫 / 报杠状态
- 是否持续不碰不杠
- 当前巡目

核心输出：

```csharp
public sealed class NeijiangBeliefSnapshot
{
    public float[,] TileTypeSeatProb = new float[18, 4];
    public float[] FlushBias = new float[4];
    public float[] ReadyProb = new float[4];
    public float[] AggroProb = new float[4];
}
```

解释：

- `TileTypeSeatProb[t, s]`：牌型 `t` 在座位 `s` 手牌中的相对概率
- `ReadyProb[s]`：该家已成叫 / 接近成叫概率

---

## 4.7 `NeijiangDangerEngine.cs`

职责：

- 评估每张牌的放炮风险
- 作为尾盘或强压局的防守切换依据

风险来源：

1. 现物安全
2. 同巡安全
3. 已断结构安全
4. 筋牌 / 邻近危险
5. 对手副露后的门清偏移
6. 报叫玩家的高压风险

关键接口：

```csharp
public float EvaluateDiscardDanger(int tileType, int seatIndex, NeijiangStateView state, NeijiangBeliefSnapshot belief);
```

输出要求：

- 返回 `0.0 ~ 1.0` 标准化风险值
- 支持同时输出分项解释，供 DebugPanel 和 AI 提示使用

---

## 4.8 `NeijiangMctsEngine.cs`

职责：

- 只在候选牌非常接近时做短前瞻
- 不替代基础牌效，而是精修边缘决策

适用场景：

- 同向听、同进张、同活张，差异很小
- 中后盘需要平衡“继续进攻”还是“明显收守”
- 是否碰 / 杠 / 报杠收益不清晰

规则：

- 仅 rollout `6~8` 巡
- 仅对 top-k 候选动作做模拟
- 超过 `350~400ms` 立即熔断
- 熔断后回退到 `DecisionEngine` 的静态排序结果

关键接口：

```csharp
public MctsDecisionResult EvaluateTopCandidates(NeijiangStateView state, CandidateAction[] candidates, int timeoutMs);
```

---

## 4.9 `NeijiangDecisionEngine.cs`

职责：

- 聚合所有子模块，输出最终动作

决策顺序建议：

1. 枚举所有可打牌
2. 计算打后向听
3. 保留最小向听候选集
4. 比较进张 / 成叫 / 宽叫 / 活张
5. 加入风险折损
6. 必要时调用 MCTS 精排
7. 返回最终动作 + 原因摘要

关键接口：

```csharp
public NeijiangDecisionResult DecideDiscard(NeijiangStateView state, NeijiangAiConfig config);
public NeijiangDecisionResult DecideReaction(NeijiangStateView state, ReactionContext reaction, NeijiangAiConfig config);
```

---

## 4.10 `NeijiangStatePool.cs`

职责：

- 复用中间状态对象
- 降低 GC 压力
- 为高频 rollout 提供对象池

要求：

- 预分配固定数量对象
- 支持 reset 而非 new
- 只服务 AI Core，不暴露给 UI

---

## 4.11 `NeijiangAiFacade.cs`

职责：

- C# 对 Godot 暴露的唯一入口
- GDScript 不直接碰内部子模块

建议接口：

```csharp
public partial class NeijiangAiFacade : Node
{
    public Godot.Collections.Dictionary DecideDiscard(Godot.Collections.Dictionary payload);
    public Godot.Collections.Dictionary DecideReaction(Godot.Collections.Dictionary payload);
    public Godot.Collections.Dictionary BuildDebugSnapshot(Godot.Collections.Dictionary payload);
}
```

这样做的好处：

- 后续 AI Core 内部重构，不影响 GDScript 调用方
- Godot 侧集成成本低

---

## 5. GDScript 集成方案

## 5.1 `scripts/ai/AICoreBridge.gd`

职责：

- 封装 Godot <-> C# 数据交互
- 隔离 Variant 数据组织细节

建议接口：

```gdscript
class_name AICoreBridge
extends RefCounted

func build_discard_payload(game_manager, seat_index: int) -> Dictionary:
    pass

func request_discard(payload: Dictionary) -> Dictionary:
    pass

func request_reaction(payload: Dictionary) -> Dictionary:
    pass
```

输出统一字段建议：

```gdscript
{
    "action": "discard",
    "tile_type": 12,
    "tile_id": 87,
    "shanten": 0,
    "ukeire": 9,
    "danger": 0.16,
    "score": 0.83,
    "reasons": ["最小向听", "宽叫领先", "活张更多"],
    "debug": {...}
}
```

---

## 5.2 `scripts/ai/AIManager.gd`

职责：

- 负责异步调度 AI
- 与 `GameManager.gd` 解耦
- 统一管理电脑玩家出牌 / 反应 / 调试快照请求

建议信号：

```gdscript
signal ai_decision_ready(seat_index: int, result: Dictionary)
signal ai_debug_snapshot_ready(seat_index: int, snapshot: Dictionary)
```

建议职责边界：

- `GameManager.gd` 只负责：
  - 当前轮到谁
  - 当前允许哪些动作
  - 收到决策后执行动画与规则流程
- `AIManager.gd` 只负责：
  - 发起后台 AI 请求
  - 缓存结果
  - 把结果通过信号回传

异步流程：

1. `GameManager` 通知 `AIManager`：某家可出牌
2. `AIManager` 立刻构造 payload
3. 交给线程池或 C# 线程任务
4. 返回后 emit `ai_decision_ready`
5. `GameManager` 再落地出牌动画与状态推进

---

## 5.3 `scripts/ai/AIDebugPanel.gd`

职责：

- 显示 AI 内心戏
- 只在开发 / 调参面板开启时工作
- 不影响正式运行性能

建议显示内容：

- 当前向听
- 候选弃牌前五名
- 每张候选的：
  - 打后向听
  - 进张数
  - 活张数
  - 危险度
  - 最终综合分
- 当前攻守模式：
  - 抢速度
  - 保宽叫
  - 收守
  - 报叫锁定

---

## 6. 与现有模块的迁移关系

## 6.1 `shanten_analyzer.gd`

迁移方式：

- Phase 1 保留
- 作为 C# 结果的交叉校验器
- 稳定后降级为测试对照用

## 6.2 `discard_advisor.gd`

迁移方式：

- 保留解释文本生成、玩家辅助说明
- 主排序逻辑迁移到 `NeijiangDecisionEngine.cs`

## 6.3 `risk_analyzer.gd`

迁移方式：

- 保留简版危险度解释
- 主风险评分迁移到 `NeijiangDangerEngine.cs`

## 6.4 `reaction_advisor.gd`

迁移方式：

- 保留碰 / 杠 / 胡动作入口
- 碰与杠的“值不值得做”评估迁移到 `DecideReaction`

## 6.5 `lookahead_evaluator.gd`

迁移方式：

- Phase 1 先停用核心排序职责
- 若历史文案还有价值，则只保留解释层

---

## 7. 决策链设计

## 7.1 出牌决策链

每次电脑出牌统一走下面链路：

1. 生成当前可打牌集合
2. 对每张候选牌模拟“打出后手牌”
3. 计算：
   - 最小向听
   - 有效进张
   - 活张
   - 成叫质量
   - 自摸潜力
   - 点炮风险
4. 取“最小向听集合”
5. 在集合内按综合分排序
6. 若前两名差值小于阈值，调用 MCTS 精排
7. 返回第 1 名

### 统一综合分建议

```text
total_score =
    speed_score * W_SPEED
  + ukeire_score * W_UKEIRE
  + live_score * W_LIVE
  + self_draw_score * W_SELF_DRAW
  + call_quality_score * W_CALL_QUALITY
  + fan_potential_score * W_FAN
  - danger_score * W_DANGER
  - delay_penalty * W_DELAY
```

但注意：

- **速度是硬门槛，不是普通加分项**
- 即：先筛最小向听，再谈总分

---

## 7.2 反应决策链（碰 / 杠 / 过）

碰 / 杠判断不能只看当前收益，必须看：

- 是否直接降向听
- 是否直接成叫
- 是否显著提升叫型质量
- 是否破坏宽叫
- 是否暴露牌型后导致风险上升
- 是否受报叫锁定约束

建议决策顺序：

1. `胡` 永远最高优先
2. `报杠` 在规则允许且不破坏已报叫锁定时优先评估
3. `碰` 若可直接成叫或显著提速，则可做
4. `明杠` 仅在收益明显高于风险时做
5. 其余 `过`

---

## 8. 性能方案

## 8.1 先做哪些计算前置缓存

建议预计算并缓存：

- 两门牌基础面子拆解表
- 局部手型标准化 key
- 向听子状态缓存
- 进张改善缓存

缓存 key 建议：

- `18` 维计数压缩为字符串 key 或 `ulong` key
- 后续再根据热点决定是否做更激进位压缩

## 8.2 线程模型

建议：

- 电脑 AI 决策：后台线程
- 玩家辅助提示：也走后台线程，但优先级低
- 音效播放期间可并行思考
- 动画阶段只等待结果，不阻塞渲染

## 8.3 熔断策略

每次决策分 3 层：

1. 基础牌效：必须完成
2. 危险度融合：必须完成
3. MCTS：超时即可砍掉

因此哪怕高负载，也至少能给出：

- 稳定
- 不错
- 较快

的决策，不会卡主线程。

---

## 9. 调参与学习系统如何接入

## 9.1 哪些参数继续保留给调参面板

建议保留为可调权重：

- `W_UKEIRE`
- `W_LIVE`
- `W_SELF_DRAW`
- `W_CALL_QUALITY`
- `W_FAN`
- `W_DANGER`
- `W_DELAY`
- `MCTS_ENABLE`
- `ABSOLUTE_DEFENSE_LATE`
- `CALL_LOCK_STRICT`

## 9.2 哪些内容不要交给自动学习修改

自动学习**不要**碰：

- 向听算法
- 牌编码规则
- 基础规则判定
- 报叫锁定规则
- 胡牌真值判定

自动学习只允许改：

- 各权重上下浮动
- 风险阈值
- 尾盘收守阈值
- MCTS 触发阈值

原因：

- 这些属于策略参数
- 不会破坏规则正确性
- 更适合结合对局统计做微调

---

## 10. 分阶段实施计划

## Phase 1：打基础（先稳）

目标：

- 替换旧出牌主链路
- 明显提升早听牌能力
- 不增加卡顿

任务：

1. 建 `dotnet/AI.Core/` 骨架
2. 实现 `TileCodec / StateCodec`
3. 实现 `ShantenEngine`
4. 实现 `UkeireEngine`
5. 实现 `DecisionEngine` 第一版
6. 接 `AIManager.gd + AICoreBridge.gd`
7. 跑基础回归与性能测试

验收标准：

- 电脑玩家不再明显乱打
- 早听牌率明显提高
- 单步决策稳定在目标耗时内

## Phase 2：读牌与防守（变老练）

任务：

1. 实现 `BeliefEngine`
2. 实现 `DangerEngine`
3. 融合报叫 / 副露 / 尾盘风险
4. 改造 `DecideReaction`
5. 增加 DebugPanel

验收标准：

- AI 尾盘点炮率下降
- 对强势玩家有明显收守
- 反应动作更稳，不乱碰乱杠

## Phase 3：有限模拟（拉上限）

任务：

1. 实现 `MctsEngine`
2. 只对 top-k 候选做 rollout
3. 接入熔断
4. 做压测调优

验收标准：

- 接近牌效候选时，出牌更细腻
- 复杂局面更像老玩家
- 帧率和操作流畅度不受明显影响

## Phase 4：学习闭环（可持续变强）

任务：

1. 把统计文件与新权重体系对接
2. 为权重学习设置边界
3. 输出版本化调参快照
4. 生成阶段性 benchmark 报告

验收标准：

- 参数可随着长期对局小幅优化
- 不会越学越偏
- 可回滚、可对比

---

## 11. 第一批建议直接开工的文件

如果下一步开始真正编码，建议按这个顺序落文件：

1. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AICoreBridge.gd`
2. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIManager.gd`
3. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Entry/NeijiangAiFacade.cs`
4. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Codec/NeijiangTileCodec.cs`
5. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Codec/NeijiangStateCodec.cs`
6. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Engines/NeijiangShantenEngine.cs`
7. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Engines/NeijiangUkeireEngine.cs`
8. `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Engines/NeijiangDecisionEngine.cs`

原因：

- 这批文件能最快打通“可异步请求 -> 得到更聪明弃牌”的最短链路
- 等这条链路跑通，再叠危险度和 MCTS，风险最低

---

## 12.1 已落地状态（2026-05-02）

当前版本已经完成第一阶段真实落地，且已接入现有内江麻将主流程：

- `autoload/GameState.gd`
  - AI 回合决策已接入 `AIManager.gd`
  - AI 反应决策已接入 `AIManager.gd`
  - 调试快照已暴露 `ai_core_debug`
- `scripts/core/discard_advisor.gd`
  - 内江模式下主弃牌决策已切到 `scripts/ai/neijiang_decision_engine.gd`
- `scripts/core/reaction_advisor.gd`
  - 内江模式下碰 / 杠 / 过主决策已切到 `scripts/ai/neijiang_decision_engine.gd`
- `scripts/ai/`
  - 已新增两门牌 AI Core 的 GDScript 版骨架与主实现

当前已落地文件：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/neijiang_tile_codec.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/neijiang_shanten_engine.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/neijiang_belief_engine.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/neijiang_danger_engine.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/neijiang_call_quality_engine.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/neijiang_decision_engine.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AICoreBridge.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIManager.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIDebugPanel.gd`

### 当前实现说明

本轮优先保证“真实接入、能跑、回归通过”，因此核心算法层先以 **GDScript 版 AI Core** 落地，暂未切到 C#。

这样做的原因是：

- 可以最短路径替换当前主决策链
- 可以直接复用现有规则层与回归体系
- 可以先确认两门牌策略本身正确，再继续向 C# 下沉

### 下一阶段建议

当这一版策略稳定后，再把以下热点模块下沉到 C#：

- `neijiang_shanten_engine.gd`
- `neijiang_danger_engine.gd`
- `neijiang_decision_engine.gd` 中的候选遍历与概率计算

这样可以在保持当前行为一致的前提下，把性能再向上推一档。

## 12. 当前版本结论

当前新版本已经具备进入实施阶段的文档条件：

- 有总设计稿
- 有本实施拆解稿
- 有既有 AI 规则文档
- 有当前工程代码可以接桥

建议从这一版开始，正式把“内江麻将两门牌 AI”从旧启发式链路迁移为：

> **两门牌状态建模 + 向听/进张硬约束 + 听牌质量评估 + 读牌防守 + 限时模拟**

这条路线是当前工程里，最稳、最强、也最适合持续演进的一条。


## 13. C# 原型当前接入状态

当前版本已经补齐本机 .NET 8 SDK，并完成 C# 原型库与 smoke 工程：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/AI.Core.csproj`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core.Smoke/AI.Core.Smoke.csproj`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/tools/build_ai_core.sh`

当前策略是：

- 游戏运行态：继续走 GDScript AI Core，保证稳定
- 性能下沉态：C# AI.Core 已可独立编译、运行 smoke
- 下一步：把 `NeijiangDecisionEngine` 与 `NeijiangShantenEngine` 逐步迁入 Godot .NET 调用链


## 14. CLI 桥接现状

为了在不切换 Godot .NET 编辑器的前提下继续推进第二阶段，当前已新增一层 **CLI 桥接**：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core.Cli/AI.Core.Cli.csproj`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/csharp_ai_bridge.gd`

当前策略：

- 默认后端：`gdscript`
- 可选后端：`hybrid_csharp`
- `hybrid_csharp` 的做法不是整局都改成外部进程控制，而是：
  1. 先由 GDScript 主链路生成完整候选
  2. 再由 C# CLI 给出两门牌核心弃牌分析
  3. 最后在 `AIManager.gd` 中把 C# 候选结果逐张回填到现有候选集合

这样既不会破坏现有 UI/解释/风险字段，也能开始用真实 C# 算法参与运行期决策。


补充：当前 `hybrid_csharp` 已从“只重排推荐牌”升级为“候选级融合”，会把 C# 输出的 `shanten / ukeire / liveUkeire / danger / waitCount / waitQualityScore / riskLabel / strategyTag / strategyMode / tenpaiProbability / selfDrawProbability / winProbability / dealInProbability / expectedValue` 回填到候选分析中。现在 C# 读牌层也已接入每家的真实弃牌 `discards18` 与副露 `melds18`，危险度不再只依赖可见总数，而会结合桌面行为参与判断。调试面板也会同步显示当前后端、策略标签与风险标签，方便继续往纯 C# 主链过渡。 本轮继续下沉后，`hybrid_csharp` 已改为由 C# 结果直接生成主 `options` 顺序与核心字段，GDScript 主要负责补牌对象、番型路线和桌面解释字段，进一步接近纯 C# 主决策链。

进一步补充：当前混合模式下，`AIManager.gd` 已不再先跑完整的 GDScript 两门牌评分链，而是改为调用轻量 `support context`，仅补齐 `routes_after / route_loss / risk_reasons / strategy_profile / tile` 等桌面语义字段；候选主排序、概率与核心评分则完全以 C# 输出为准。

再补充本轮下沉结果：

- `NeijiangBeliefSnapshot.cs` 已扩展：
  - `SeatSuitDemand`
  - `SeatExactSafeTiles`
  - `SeatAbandonedSuits`
  - `SeatThreatScore`
- `NeijiangDangerEngine.cs` 已从“只返回危险分”升级为“危险评估对象”：
  - `Risk`
  - `RiskLabel`
  - `TopThreatSeat`
  - `Reasons`
- `MahjongState.build_player_state()` 已补回 `bao_jiao`，确保 Godot -> C# payload 的 `IsCalled / IsReady` 不再丢失
- `AILearningEngine.gd` 已改为“优先调用 C# 学习器，失败再回退 GDScript”
- `AI.Core.Cli` 已新增 `learning-record`，用于局后落盘学习结果
- `NeijiangDecisionEngine.cs` 当前已不再只做静态打分：
  - 先按概率加权 EV 计算候选值
  - 再调用 `NeijiangMctsEngine.cs` 对接近候选做限时前瞻修正
  - 将 `search_bonus / search_used / search_simulations` 回填到候选结果
- 当前 `risk_reasons` 可以直接透传 C# 识别到的桌面证据，便于后续继续把“概率读牌 → 限时搜索 → 自进化调参”都收口到 C# 主链。

本轮继续下沉后，C# 候选结果已新增 `explanationHint` 与 `riskReasons`，主界面出牌辅助文案会优先使用 C# 直接给出的短解释，进一步减少对 GDScript 本地解释分支的依赖。

继续补充：当前 `strategy_profile` 也开始优先使用 C# 输出的摘要字段，包括 `mode_label / round_stage / threat_level / opponent_state.top_threat_profile` 等；GDScript 仅保留兼容合并与极少量桌面语义兜底。

本轮继续补充后，`current_routes / routes_after / route_loss` 也已开始由 C# 主链直接产出，混合模式下前端优先读取 C# 的路线估算，GDScript 只保留兼容回退。


## 15. 性能采样与调试面板现状

为了让“两门牌 AI 更强”与“运行时不卡顿”可以同时量化追踪，当前版本已经把 AI 决策耗时采样接入到运行链路中：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIManager.gd`
  - 每次 `analyze_turn()` 会记录本次出牌决策耗时
  - 每次 `analyze_reaction()` 会记录本次碰 / 杠 / 过反应耗时
  - 已维护滚动统计字段：
    - `turn_count / turn_total_ms / turn_avg_ms / turn_max_ms`
    - `reaction_count / reaction_total_ms / reaction_avg_ms / reaction_max_ms`
  - 对出牌主链还额外分后端记录：
    - `backend_turns.gdscript`
    - `backend_turns.hybrid_csharp`

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIDebugPanel.gd`
  - 已显示当前后端
  - 已显示最近一次出牌/反应耗时
  - 已显示平均耗时
  - 已显示 `hybrid_csharp` 的调用次数、均值与峰值

这样做的意义是：

- 后面把 `shanten / ukeire / belief / danger / mcts` 继续下沉到 C# 时，可以直接对比“体感变强”与“耗时是否上升”
- 可以快速定位卡顿到底发生在：
  - GDScript 主链
  - C# CLI 桥接
  - 反应判断链
- 后续若要接 `WorkerThreadPool` 或 Godot .NET 直连，也能直接复用这一组采样指标做回归对照

### 当前回归覆盖

本轮已新增回归测试：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/tests/NeijiangRegressionRunner.gd`
  - `neijiang_ai_manager_records_performance_metrics`

该测试会校验：

- AI 出牌分析后，`performance_metrics.turn_count` 正常累加
- AI 反应分析后，`performance_metrics.reaction_count` 正常累加
- 平均耗时 / 峰值耗时字段存在且为非负数
- `backend_turns.hybrid_csharp` 在混合后端下会记录调用次数

当前整套内江麻将回归已提升为：

- `NEIJIANG REGRESSION OK: 41/41`


## 16. 异步就绪接口与预算熔断骨架

虽然当前游戏主流程仍以同步取结果为主，但为了后续无缝切到 `WorkerThreadPool` / Godot .NET 直连，本轮已经先把 **“异步就绪接口”** 和 **“时间预算状态”** 落进运行层。

### 16.1 `AIManager.gd` 当前新增能力

- 已新增信号：
  - `ai_turn_analysis_ready(request_id, seat_index, analysis)`
  - `ai_reaction_analysis_ready(request_id, seat_index, analysis)`
- 已新增请求式接口：
  - `request_turn_analysis_async(...)`
  - `request_reaction_analysis_async(...)`
- 当前这两个接口仍是 **同步执行 + 信号回传结果** 的过渡形态
  - 好处是：不改现有牌局流程，也能先把调用协议稳定下来
  - 后续接真线程池时，只需要替换内部执行器，不需要重写上层调度协议

### 16.2 请求状态跟踪

`AIManager.gd` 当前还会维护：

- `request_state.next_request_id`
- `request_state.inflight_count`
- `request_state.last_turn_request_id`
- `request_state.last_reaction_request_id`
- `request_state.last_completed_kind`
- `request_state.last_completed_request`

作用是：

- 给未来线程池版本提供最小闭环的请求生命周期管理
- 方便在调试面板直接看到“现在是否还有 AI 请求未完成”
- 后续若出现“AI 回包晚到、状态过期、旧请求覆盖新请求”的问题，可以直接扩展这一层做防抖和过期判定

### 16.3 时间预算与熔断观测

当前版本先把 **预算观测** 做起来：

- 出牌预算：
  - `hybrid_csharp` 目标预算 `400ms`
  - `gdscript` 观测预算按 `300ms` 记录
- 反应预算：
  - `180ms`

当前已经记录：

- `turn_budget_ms / reaction_budget_ms`
- `turn_over_budget_count / reaction_over_budget_count`
- `backend_turns.<backend>.over_budget_count`

说明：

- 这一版还是“观测型熔断”，即：
  - 会统计是否超预算
  - 会暴露给调试面板
  - 但不会粗暴中断当前同步计算
- 这样做是为了先把现网行为保持稳定，再在下一步把“真超时回退”接进 C# CLI 或线程任务执行器

### 16.4 调试面板新增可见项

`AIDebugPanel.gd` 当前已能看到：

- 最近一次出牌耗时 / 出牌预算 / 出牌均值
- 最近一次反应耗时 / 反应预算 / 反应均值
- 出牌超预算次数 / 反应超预算次数
- `hybrid_csharp` 的次数 / 均值 / 峰值 / 超预算次数
- 当前请求状态（进行中数量、最近完成请求）

这样做的价值是：

- 后面切真异步后，可以第一时间看出：
  - 是算法太慢
  - 是 CLI 启动成本太高
  - 还是请求排队出了问题

### 16.5 本轮回归补充

本轮新增回归：

- `neijiang_ai_manager_request_api_updates_state_and_emits`

当前整套内江麻将回归已提升为：

- `NEIJIANG REGRESSION OK: 41/41`


## 17. 真后台请求骨架（已落地）

在上一轮“同步执行 + 信号回传”的过渡层之上，当前版本已经进一步落地了 **真后台线程请求骨架**，但仍然保持对现有牌局流程零破坏。

### 17.1 当前新增后台接口

`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIManager.gd`

已新增：

- `start_turn_analysis_background(...)`
- `start_reaction_analysis_background(...)`
- `pump_async_requests()`
- `has_pending_async_requests()`

当前执行模型：

1. 主线程发起后台请求
2. `AIManager` 为请求分配 `request_id`
3. 内部启动 `Thread`
4. 后台线程执行：
   - 两门牌出牌分析 / 反应分析
   - hybrid C# 候选融合
5. 主线程通过 `pump_async_requests()` 回收已完成线程
6. 回收时统一：
   - 更新性能统计
   - 更新最近快照
   - 更新请求状态
   - 发出 `ai_turn_analysis_ready` / `ai_reaction_analysis_ready`

这样做的好处是：

- 真正把重计算从主线程剥离了一步
- 保持了结果派发仍在主线程完成，避免 UI/状态层直接吃后台线程回调
- 后面切 `WorkerThreadPool` 时，外部协议基本不用再动

### 17.2 为什么还保留同步接口

当前仍然保留：

- `analyze_turn(...)`
- `analyze_reaction(...)`
- `request_turn_analysis_async(...)`
- `request_reaction_analysis_async(...)`

原因很简单：

- 现有 `GameState.gd` 牌局流程仍以同步拿结果为主
- 先把后台骨架落稳，再把主流程逐步切到“先起后台请求，再在合适时机 pump 回收”
- 这样风险最低，不会把当前可玩的内江麻将牌局一次性推翻

### 17.3 C# CLI 并发隔离

`/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/csharp_ai_bridge.gd`

本轮还顺手修掉了一个后续真并发一定会踩的点：

- C# CLI 临时输入文件不再固定写同一个 `discard_payload.json`
- 当前改为按请求 tag 写入独立文件：
  - `discard_payload_<request_tag>.json`

这一步很关键，因为只要未来允许两个 AI 请求并行，固定文件名就一定会互相覆盖。

### 17.4 当前主线程回收策略

目前 `AIManager.get_debug_snapshot()` 会先自动执行一次 `pump_async_requests()`。

作用：

- 调试面板刷新时，能顺手回收已经完成的后台请求
- 即使暂时还没有把整个 `GameState` 主流程改成全异步，也可以先让开发期面板和测试链路吃到真实后台结果

后续若把主牌局调度正式切到异步模式，则建议：

- 在 `GameState` 的 AI 调度点显式调用 `pump_async_requests()`
- 或在统一主循环 / 定时器中集中 pump

### 17.5 本轮回归补充

新增回归：

- `neijiang_ai_manager_background_request_pumps_and_emits`

该测试已验证：

- 后台请求可成功启动
- 主线程可通过 `pump_async_requests()` 收到完成结果
- `ai_turn_analysis_ready` 信号可正常发出
- `request_state.last_background_request_id` 会被正确更新
- `inflight_count` 能正确归零

当前整套内江麻将回归已提升为：

- `NEIJIANG REGRESSION OK: 41/41`


## 18. `GameState` 预思考接入（已落地）

上一轮只是把后台线程请求骨架搭好；这一轮已经把它真正接入了牌局调度层：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/autoload/GameState.gd`

### 18.1 当前接入方式

#### AI 出牌预思考

在 `_begin_turn()` 中：

- 当某家 AI 摸牌结束、进入 `DISCARD` 阶段后
- 会立刻调用后台分析启动接口
- 这样等待摸牌表现、音效、桌面刷新期间，AI 已经开始思考

#### AI 响应预思考

在 `_prepare_reaction_context()` 中：

- 当出现碰 / 杠 / 胡 / 过的可响应牌时
- 若存在 AI 响应方
- 会立刻启动后台响应分析

也就是说，现在已经不再是“等计时器到了才开始思考”，而是：

- **进入可出牌 / 可响应状态时就提前思考**

这一步对“体感流畅度”很关键。

### 18.2 当前执行链

现在 `run_ai_turn()` / `run_ai_reaction()` 的职责已经变成：

1. 先 `pump` 回收后台结果
2. 若结果已落地，直接执行
3. 若后台还没完成，暂时返回等待
4. 若后台线程已经结束，但结果未成功挂到 `GameState`，则同步兜底计算一次，避免 AI 卡死

这意味着当前版本已经具备：

- **理想路径**：后台预思考 → 主线程执行
- **保底路径**：后台异常落空 → 同步兜底执行

对实战来说，这比“全量强依赖后台结果”更稳。

### 18.3 当前请求绑定方式

`GameState.gd` 已新增：

- `pending_ai_turn_request_id`
- `pending_ai_reaction_request_id`
- `pending_ai_turn_request_meta`
- `pending_ai_reaction_request_meta`

并通过 `AIManager` 信号：

- `ai_turn_analysis_ready`
- `ai_reaction_analysis_ready`

把后台结果重新挂回：

- `pending_ai_turn_decision`
- `pending_ai_reaction_decision`

其中还做了两层兜底：

1. **上下文有效性校验**
   - 回合号
   - 座位
   - 阶段
   - 牌墙数 / 手牌数 / 当前响应牌
2. **推荐牌重新映射**
   - 若后台回来的推荐牌没有稳定 `id`
   - 会按 `花色 + 点数` 重新映射到当前手牌中的真实 tile

这一步是为了避免“后台算法给了正确牌型，但无法精确打出当前手里那张牌”的问题。

### 18.4 当前调度兼容性

`MainTable.gd` 这一层目前**无需改 UI 计时器模型**：

- 仍然由原有计时器驱动 `run_ai_turn()` / `run_ai_reaction()`
- 只是现在这两个入口不再“到点才开始思考”
- 而是“到点时优先取已经思考好的结果”

这意味着本轮收益主要来自：

- 不破坏当前桌面流程
- AI 体感更快
- 为下一步彻底切异步执行打好基座

### 18.5 本轮回归补充

新增两条调度级回归：

- `neijiang_prepare_ai_turn_starts_background_request`
- `neijiang_run_ai_turn_executes_after_background_analysis`

它们已经覆盖：

- 准备阶段是否会启动后台思考
- 运行阶段是否能回收后台结果并真正完成 AI 出牌

当前整套内江麻将回归已提升为：

- `NEIJIANG REGRESSION OK: 41/41`


## 19. 前端计时器与后台完成联动

在 `GameState` 已经支持“预思考 + 主线程回收执行”之后，当前桌面层也已经补上最后一层节奏联动：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/game/MainTable.gd`

### 19.1 当前计时器策略

原先逻辑是：

- AI 出牌计时器固定等 `0.8s`
- AI 响应计时器固定等 `0.7s`
- 到点后才尝试开始真正执行

这样会有两个问题：

1. 后台早就算完了，也还要傻等整段固定时间
2. 如果到点时后台还没算完，就只能再等下一轮调度

当前版本已改为“两段式”：

- **第一段：最短展示时长**
  - 出牌至少展示 `0.8s`
  - 响应至少展示 `0.7s`
- **第二段：短轮询等结果**
  - 一旦达到最短展示时长，就改为约 `60ms` 的短轮询
  - 后台结果一旦可执行，就立即落地

也就是说，现在的行为更像：

- **不抢拍**
- **不呆等**
- **算好就走**

### 19.2 当前桌面层具体行为

`_schedule_ai_turn_if_needed()` / `_schedule_ai_reaction_if_needed()` 当前会：

1. 先调用 `prepare_ai_turn_decision()` / `prepare_ai_reaction_decision()`
2. 这一步会触发后台预思考，或确认已有结果
3. 然后计时器按“最短展示时长剩余时间”启动

`_on_ai_turn_timer_timeout()` / `_on_ai_reaction_timer_timeout()` 当前会：

1. 若最短展示时长还没到
   - 按剩余时间再次启动计时器
2. 若最短展示时长已到
   - 先尝试执行 `run_ai_turn()` / `run_ai_reaction()`
3. 若后台结果还没完全可执行
   - 使用 `60ms` 短轮询继续等待
4. 一旦后台结果已可执行
   - 立即完成出牌 / 响应

### 19.3 当前收益

这一层接完之后，整条链已经形成闭环：

- 摸牌 / 出现可响应牌 → `GameState` 立刻后台预思考
- 前端计时器负责最短展示时长
- 一过最短展示时长 → 只要后台结果已好，就立即执行
- 若后台稍慢 → 短轮询补齐，不会重新傻等整段大延时

对体感来说，效果会更像真人老玩家：

- 有一点反应时间
- 但不会机械卡顿
- 也不会突然特别慢

### 19.4 当前仍保留的稳态兜底

即使在这一版里，仍然保留三层兜底：

1. `GameState` 后台预思考
2. 主线程 `pump` 回收结果
3. 若后台线程结束但结果未成功绑定，则同步兜底计算一次

所以即使后台链偶发不稳定，也不会把牌局卡死。


## 20. 真超时熔断（1 秒回退）

按当前新要求，后台 AI 请求不再是“无限等到结果出来”为止，而是已经接入 **真超时熔断**：

- 超时阈值：`1000ms`
- 作用范围：
  - AI 出牌后台请求
  - AI 响应后台请求

核心实现位置：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/autoload/GameState.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIManager.gd`

### 20.1 当前熔断行为

当 `GameState` 检测到：

- 当前后台请求仍然挂起
- 且从请求启动开始已经超过 `1000ms`

则会立刻：

1. 放弃等待该后台请求
2. 清空挂起的请求 id / meta
3. 直接切到 **同步轻量后备链**
4. 生成可执行的出牌 / 响应决策

这意味着现在的运行优先级是：

- **先后台算**
- **超过 1 秒就别等**
- **立刻回退，保证牌局继续**

### 20.2 轻量后备链是什么

这次没有让超时后再去走一遍完整 `hybrid_csharp`，因为那样没有意义，可能继续卡。

当前回退策略是：

- **出牌回退**：强制走 `AIManager.analyze_turn_lightweight(...)`
  - 禁用 `hybrid_csharp`
  - 直接使用 GDScript 两门牌主分析链
- **响应回退**：走 `AIManager.analyze_reaction_lightweight(...)`
  - 直接同步拿响应建议

这样做的目标很明确：

- 超时后的任务，不追求最强
- 只追求 **尽快、稳定、能继续打**

### 20.3 当前可见性

一旦发生超时熔断，`GameState.debug_last_message` 会记录：

- “AI 后台出牌分析超时（>1000ms），已切回轻量后备链”
- 或
- “AI 后台响应分析超时（>1000ms），已切回轻量后备链”

这样后续你做压测或我们看桌面调试信息时，能明确知道：

- 到底是后台正常返回
- 还是已经触发过超时回退

### 20.4 本轮回归补充

新增两条回归：

- `neijiang_turn_background_timeout_falls_back_after_1s`
- `neijiang_reaction_background_timeout_falls_back_after_1s`

它们已经验证：

- 超过 `1s` 的挂起请求会被识别为超时
- 超时后会自动切到轻量后备链
- 挂起请求 id 会被清空
- 调试文案会留下“超时”提示

当前整套内江麻将回归已提升为：

- `NEIJIANG REGRESSION OK: 41/41`


## 21. 出牌分析缓存（已落地）

为了进一步降低重复计算、减少超时触发率，当前版本已经先落地了 **AI 出牌分析缓存**：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIManager.gd`

### 21.1 当前缓存范围

本轮先只缓存：

- **turn / 出牌分析结果**

暂时不缓存 reaction，原因是：

- 出牌分析是当前最重、也最容易在同一局面下被重复请求的部分
- reaction 链相对更短，先把高收益部分做稳最划算

### 21.2 当前缓存键

缓存键不是简单用 request id，而是基于局面状态构建，主要包含：

- 当前 seat
- 当前 turn / dealer / wall count
- 是否作弊分析
- 是否强制走轻量后备链
- 当前手牌计数
- 四家弃牌序列
- 四家副露序列
- 是否报叫 / 是否已胡

也就是说，只有在“同一局面”再次分析时，才会命中缓存。

### 21.3 当前缓存行为

当 `AIManager` 做 turn 分析时：

1. 先生成缓存 key
2. 若命中缓存：
   - 直接返回缓存结果
   - 记一次 `turn_cache_hits`
3. 若未命中：
   - 正常跑分析
   - 把结果写入缓存
   - 记一次 `turn_cache_misses`

当前缓存为：

- **有限大小缓存**
- 上限：`128` 条
- 超过后按访问顺序淘汰最旧项

### 21.4 当前可观测性

`AIManager.get_debug_snapshot()` 当前已额外暴露：

- `turn_cache_size`
- `turn_cache_limit`
- `turn_cache_hits`
- `turn_cache_misses`

这意味着后续做压测时，我们已经可以直接看：

- 缓存是否真的在命中
- 命中率是否足够高
- 是否值得继续扩展到 reaction 或更细粒度候选缓存

### 21.5 本轮回归补充

新增回归：

- `neijiang_turn_analysis_cache_hits_on_same_state`

它已经验证：

- 同一局面连续分析两次
- 第二次能够命中缓存
- 缓存统计会正确增加

当前整套内江麻将回归已提升为：

- `NEIJIANG REGRESSION OK: 41/41`


## 22. C# 常驻 Host 骨架（已起步）

按当前新的总体要求：

- 先做：评测体系 + 缓存
- 再做：概率读牌
- 然后做：限时搜索
- 最后做：自进化调参闭环

并且这几条要求尽量使用 **高效语言（C#）** 落地。

基于这个目标，当前版本已经开始把关键基础设施从“Godot 调单次 CLI”推进到 **C# 常驻 Host 架构**。

### 22.1 当前已落地的 C# 基础设施

#### 状态指纹

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Analysis/NeijiangStateFingerprint.cs`

作用：

- 为缓存统一构建局面 key
- 为后续评测、搜索、学习模块提供一致的状态签名

#### C# LRU 决策缓存

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Cache/NeijiangDecisionCache.cs`

作用：

- 在 C# 运行时内保留 turn 决策缓存
- 为后续常驻进程提供真正可持续复用的缓存层

#### C# 评测统计模型

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Benchmark/NeijiangBenchmarkStats.cs`

作用：

- 记录决策次数
- 记录缓存命中 / 未命中
- 记录平均 turn 耗时 / 峰值耗时
- 记录超时回退次数

这一步是为“真正的数据化评测体系”提前铺底。

### 22.2 当前 `Facade` 和 CLI 的状态

#### `Facade`

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core/Entry/NeijiangAiFacade.cs`

已新增：

- `DecideDiscardCached(...)`
- `GetTurnCacheSnapshot()`

#### CLI

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/dotnet/AI.Core.Cli/Program.cs`

当前已支持两种模式：

- `discard-json`
  - 兼容现有一次性调用链
- `host-tcp`
  - 作为常驻 C# Host 骨架
  - 监听本地 `127.0.0.1`
  - 按请求行协议处理 `discard` 请求
  - 若端口已被现有 host 占用，则输出 `AI host already listening...` 并优雅退出，不再抛异常噪音

### 22.3 为什么这一步很关键

如果继续停留在“Godot 每次分析都起一个 CLI 子进程”的模式下：

- C# 内存缓存无法真正持续复用
- 搜索树无法保留
- 学习态无法在进程内沉淀

所以这次虽然还没有把运行链默认切到 Host，但已经把最关键的分水岭搭起来了：

- **兼容当前单次 CLI**
- **为常驻 C# Host 准备协议和基础设施**

### 22.4 当前 Godot 侧桥接状态

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/csharp_ai_bridge.gd`

当前已预留：

- Host mode 开关
- 本地 TCP 连接能力
- Host 请求 / 响应读写逻辑

但目前默认仍保持关闭，原因是：

- 先保证现有可玩的稳定链不被破坏
- 在 Host 模式切为默认前，先把协议和构建链跑稳

### 22.5 当前判断

到这一步为止，我们已经不是“只是在 GDScript 上不断补规则”，而是在真正把未来四个阶段的核心能力，往 **C# 主导架构** 上搬。

### 22.6 可选启用链路（已接通）

当前版本还额外补齐了“**可选启用常驻 Host**”的运行接缝：

- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/csharp_ai_bridge.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/scripts/ai/AIManager.gd`
- `/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/autoload/GameState.gd`

当前已经支持：

- 在桥接层配置：
  - Host mode 开关
  - Host port
- 在 `AIManager` 状态快照中看到：
  - `csharp_host_mode_enabled`
  - `csharp_host_port`
  - `csharp_host_connected`
- 在 `GameState` 层通过统一入口切换：
  - `set_ai_csharp_host_mode_enabled(enabled, port)`

这意味着：

- 现在还没有默认切到常驻 Host
- 但**运行链的接缝已经打通**
- 后面如果要把 C# Host 升级成默认运行方式，不需要再改一轮整体接口

本轮新增回归：

- `neijiang_csharp_host_mode_toggle_updates_backend_status`

当前整套内江麻将回归已提升为：

- `NEIJIANG REGRESSION OK: 41/41`
