# 四川麻将 AI · 算法全景图解

**代码版本：2.6.82 · abf8c6e · 核对日期：2026-09-28**

> 这是 2.6.82 发布代码的历史图解。后续算法修复及其验证见[2026-09-28 算法修复记录](../algorithm-repair-20260928.md)。本文保留原版本行为与源码证据，供前后对照。

这份图解以当前实际调用的代码为准，覆盖从发牌定缺、每次摸打与碰杠胡，到血战继续、记牌推理、阶段变化、单行道与地狱模式。它描述实现现状，不把类名、日志用语或设计文档直接当成已经实现的能力。

**先回答最关键的问题：普通模式是每家以自己的视角独立决策，但会评估整桌公开局势；地狱模式另加全信息与三家协同。计算服务共用，普通模式的暗牌输入不互通。**

阅读顺序：先看 01–03 建立全貌，再看 04–09 理解怎么打，最后看 10–15 理解特殊模式、运行边界与源码依据。

图中实线表示当前调用或数据流；虚线表示条件分支、诊断能力或有条件的影响。文中的“概率”“净值”除明确说明外均是当前算法的模型估计，不是经过实战校准的真实胜率或保证收益。

## 01 · 谁在计算：独立视角、共享引擎、整桌观察

```mermaid
flowchart TB
  G["真实牌局状态<br/>规则引擎持有全部手牌与牌墙"] --> F["普通模式信息过滤<br/>按本次行动座位生成输入"]
  F --> A["电脑一视角<br/>自己的手牌＋整桌公开信息"]
  F --> B["电脑二视角<br/>自己的手牌＋整桌公开信息"]
  F --> C["电脑三视角<br/>自己的手牌＋整桌公开信息"]
  A --> E["共用本机 C# 算法服务<br/>一次请求处理一个座位的动作"]
  B --> E
  C --> E
  E --> M["按局号＋座位保存战略记忆<br/>主路线／备用路线／承诺度／历史"]
  M --> D["返回当前座位的一个动作<br/>及候选评分、推理依据"]
  D --> V["牌局核对状态与合法性<br/>执行动作，产生新公开事件"]
  V --> F
```

“独立”指的是**输入视角、行动目标和按座位保存的战略记忆**。并不是电脑一、二、三各装了一个不同模型，也不是一定同时开三个线程计算。`SichuanCSharpRuntime` 持有一个 `SichuanAiFacade`，各座位依次或通过后台请求使用同一套引擎。

普通 AI 会分别判断其他三家的威胁、定缺、花色需求和可能听口，考虑还有几家付款、谁已经胡牌退出，因此有整桌局势意识；但它没有把三家普通 AI 的得分合并成团队目标，也没有逐层求解四家所有未来打法。

主战略记忆以 `(round, seat)` 分开存放。底层还有共享的推理缓存、一次决策缓存和“上一份上下文”缓存；不能把实现描述成四套完全隔离的运行实例。缓存本身也不等于允许读取别家的暗牌。

单机在本设备计算；联机由房主侧的权威牌局推进，客户端提交动作并接收投影后的状态。iPhone、iPad 的正常模式调用同一 C# 核心，移动端压缩返回内容，不默认降低策略。没有在线大模型调用参与实时选牌。[S01][S02][S03][S04]

## 02 · AI 能看见什么，不能看见什么

```mermaid
flowchart LR
  subgraph allowed["普通模式输入"]
    H["本家暗手与本次摸牌"]
    P["四家弃牌／副露／定缺<br/>积分／剩余手牌张数／已胡状态"]
    W["牌墙剩余总张数<br/>当前座位与局号"]
    T["按顺序的公开事件<br/>摸牌发生、舍牌、碰杠胡"]
    O["自己的过胡锁与过牌记录"]
  end
  H --> S["当前行动座位的状态视图"]
  P --> S
  W --> S
  T --> S
  O --> S
  subgraph blocked["普通模式过滤掉"]
    X["其他家的真实暗手"]
    Y["牌墙具体牌种与顺序"]
    Z["其他家真实听牌标志<br/>可胡可碰但选择过的私有资格"]
  end
  S --> E["只能据公开行为推测未知部分"]
```

| 信息 | 当前普通输入的处理 |
|---|---|
| 自己的暗手 | 精确 27 种牌计数；变量名 `Hand18` 是历史命名，实际长度 27 |
| 其他人的暗手 | 不传具体牌；传剩余张数 |
| 他家摸牌 | 保留“他摸过牌”这个事件，牌种改为 `-1` |
| 他家听牌 | 不把游戏内部 `is_ting` 当公开事实传入 |
| 碰杠 | 传副露牌种和类型；`IsCalled` 在当前桥接中表示“已有副露”，不是报听 |
| 他家过胡／过碰／过杠 | 私有资格产生的 pass 事件整体过滤，矩阵只保留本家行 |
| 自己过胡后的限制 | 保留自己的锁番、锁定时点与摸牌解锁标志 |
| 牌墙 | 普通模式只传总量，不传真实构成和顺序 |
| 手切／摸切 | 事件存在且来源已记录时可用于推理；未知来源不能当成手切 |

因此，虽然推理库有“某人能碰却没碰”的计算接口，**当前实战桥接没有把其他人的私有可碰资格送给普通 AI**，不能在图里宣称它平时知道谁故意不碰。[S03][S05]

## 03 · 整局动作循环：先合法，再选择，再执行

```mermaid
flowchart TB
  START["发牌"] --> Q["定缺<br/>各花色计数，选最少的一门"]
  Q --> DRAW["轮到未胡玩家摸牌"]
  DRAW --> SELF{"自己有自摸胡或杠选项？"}
  SELF -->|有| SA["自家动作比较<br/>自摸胡／暗杠／补杠／继续"]
  SELF -->|无| DISC["逐种合法弃牌评分"]
  SA -->|继续| DISC
  SA -->|杠| REPLACE["规则执行杠与补牌"]
  REPLACE --> SELF
  SA -->|胡| EXIT["结算本次胡牌<br/>该玩家退出本局摸打"]
  DISC --> PLAY["状态签名与合法性核对后出牌"]
  PLAY --> REACT["规则生成他家合法反应<br/>各反应座位独立算胡／碰／杠／过"]
  REACT -->|胡或一炮多响| EXIT
  REACT -->|碰| DISC
  REACT -->|杠| REPLACE
  REACT -->|都过| END{"牌局是否结束？"}
  EXIT --> END
  END -->|尚有牌且继续血战| DRAW
  END -->|牌墙耗尽或达到结束条件| SET["规则引擎最终结算<br/>查叫、花猪、杠分及适用转移"]
```

本图的“逐种”指同一种牌只评价一次，不必给四张相同牌重复算四次。最终再映射成手里具体那张牌的 ID。

定缺是当前最简单的一层：只比较三门张数，平手按花色输入顺序选。默认条、筒、万；**没有比较拆搭损失、清一色潜力或定缺后的整手收益**。

有缺门牌时必须先打缺门，合法性优先于任何做大策略。胡、碰、杠资格由规则层产生；AI 只从这些动作中选择。执行时重新核对局号、座位、阶段、牌墙、手牌及公开状态签名，旧状态上的结果不能直接落地。C# 未返回有效结果时会保留错误状态，不用前端简化打牌冒充成功。[S06][S07]

## 04 · 记牌与推理：从确定数量到不确定分布

```mermaid
flowchart TB
  A["每种牌原有 4 张"] --> B["减去本家手牌与已知公开牌"]
  B --> C["27 种未见牌数量<br/>包含他家暗手和牌墙"]
  E["按座位记录舍牌顺序、花色、邻张<br/>副露、定缺、手切／摸切与事件新旧"] --> R["经验范围模型<br/>花色需求／持张权重／听口权重／听牌程度"]
  C --> P["构造可能的暗手与剩余牌池<br/>通常 32 个假设，牌墙≤12 时 48 个"]
  E --> P
  P --> PP["对假设验向听、听口与牌型<br/>按行为相容程度加权"]
  R --> MIX["经验估计与抽样结果混合<br/>主要采用 85%／15%"]
  PP --> MIX
  MIX --> N["按每种牌分配座位和牌墙权重<br/>归一化，避免数量溢出"]
  N --> WC["牌墙总量约束<br/>期望张数合计等于实际剩余总张数"]
  WC --> USE["输出墙内有效进张估计<br/>＋各家危险度与听口估计"]
```

记牌分成三层：

1. **数量账**：自己的每种牌、牌河、副露、已公开的胡牌张、未见张数、牌墙总量。
2. **时序账**：谁先切什么、最近切什么、手切还是摸切、碰杠改变了哪些公开结构、是否已经退出。
3. **推理账**：未知牌可能分布在哪家或牌墙，各家可能需要哪门、是否接近听牌、哪些牌更危险。

桥接中 `Visible18` 实际已包含本家手牌；`Remaining18 = max(0, 4 − Visible18)`。所以这里的“可见”应理解为**对本 AI 已知**，不能不加区别地再减一次本家手牌。

举例：自己有 1 张五筒，外面已见 2 张，则未见最多 1 张。但它可能在其他人的暗手里；AI 还要估计其中有多少属于牌墙。墙内期望可以是 0.35 张，这表示不确定分配的平均数。供部分整数算法使用时，会再转换为总量一致的代表性整数牌墙。

推理细节：

- 经验模型考虑中张联络性、邻张可见量、同门舍牌数、副露集中度、舍牌进度与牌墙压力。
- 抽样从未见牌池分配假设暗手；不是读取真实暗手。每种牌抽到后从池中减掉，避免同一张牌同时分给两家。
- 普通当前分支使用 `BehaviorWeightedLegacy` 提案：行为倾向同时影响抽牌权重和假设权重；新“公开先验＋一次似然”提案主要用于诊断分支。两者不能混称为同一套严格贝叶斯后验。
- 持张、听口、听牌程度先按 85% 经验＋15% 抽样混合；持张项随后还会经过归一化覆盖。牌墙份额也混合归一化份额与抽样份额。
- 普通粒子默认不完整纳入已退出玩家的暗手；后续牌墙总量层能约束总数，但不能因此宣称所有隐藏分配都精确。长程诊断另有包含退出玩家的守恒投影。
- `hold probability` 经归一化后还承担“该牌分配给某座位的份额”含义，并不处处等价于“至少持有一张的真实概率”。[S08][S09][S10][S11]

## 05 · 如何推断危险：硬规则、软证据、临时安全

```mermaid
flowchart TB
  T["考虑打出某张牌"] --> L{"对这个对手：<br/>已胡退出／非活动座位／缺此门？"}
  L -->|是| ZERO["该对手不能胡这张<br/>主危险引擎跳过"]
  L -->|否| R["听牌程度＋持张与听口估计<br/>花色需求＋副露压力＋大牌威胁"]
  R --> S["用同张、邻张、近期舍牌等软证据修正"]
  S --> E["尾盘弱化旧安全证据<br/>必要时抬高风险下限"]
  E --> M["逐家比较<br/>主危险值取最强威胁，压到 0–100"]
  M --> P["按阶段映射为估计点炮概率<br/>用于收益和防守计算"]
  S --> TIME["另算出牌时机<br/>现在先打，还是留作后手安全牌？"]
  TIME --> SCORE["进入弃牌修正与最终防守闸门"]
  P --> SCORE
```

| 证据 | 当前实现怎样解释 | 不能推成什么 |
|---|---|---|
| 对手定缺某门 | 不能胡该门；但未清完缺时仍可能持有 | 不能说开局手里就没有该门 |
| 对手打过同张 | 降低“还需要这张”的估计；越近权重通常越大 | 四川没有永久自弃振听，不能认定永远安全 |
| 近邻牌舍出多 | 作为局部搭子需求减弱的软证据 | 不能直接复原整副暗手 |
| 同门连切多 | 降低该门需求，形成弃门倾向 | 除明确的定缺合法性外，不是零概率 |
| 副露集中一门 | 提高该门需求与清色／大牌威胁 | 一次碰牌不等于已经听牌 |
| 最近同张通过 | 有限时间的安全储备，随事件距离衰减 | 不是永久安全证书 |
| 补杠风险 | 用公开听口／听牌估计 | 不读取“真实有几家能抢杠” |

当前主危险分级为：低危 `<34`、中危 `34–55`、高危 `56–77`、极危险 `≥78`。危险值主要取各家风险的最大值，不是把三家点炮概率严格相加；上下文中另有分级阈值，不能把不同模块的数字直接混用。

一个值得知道的实现偏向：范围模型只要看到 `IsCalled=true`，就先给出 `0.86` 的听牌程度经验值，再与粒子混合；而桥接的 `IsCalled` 只是“已有副露”。因此当前 AI 可能较早把副露玩家视为强威胁。这里是启发式赋值，不是“听牌概率已被测得为 86%”。

时机模型会同时考虑：危险牌以后是否更难打出去、清色威胁拿到它的收益、近期安全牌是否值得保留。它对最终分数的贡献被限制在小范围内。`SeatExactSafeTiles` 字段虽保留，但当前证据构造器没有把“自己打过的牌”灌成永久安全集合。[S12][S13][S14]

## 06 · 每张弃牌到底怎么算

```mermaid
flowchart TB
  IN["最新座位视图＋本局战略记忆"] --> LEGAL["列出手中不同牌种<br/>有缺门时只列缺门牌"]
  LEGAL --> REMOVE["假设打出候选牌，剩余手牌重算"]
  REMOVE --> HAND["向听／真实听口／进张种数<br/>墙内期望活张／结构损失"]
  REMOVE --> ROUTE["平胡、对子、七对、清色路线<br/>主路线连续性与普通胡退路"]
  REMOVE --> RISK["逐家危险与牌桌压力<br/>现在打和以后打的差别"]
  HAND --> EV["统一动作价值<br/>机会抽样＋收益成本＋路线价值"]
  ROUTE --> EV
  RISK --> AUX["第二套收益估计与防守修正"]
  EV --> SUM["共同价值为主<br/>加入有界牌形、路线与短前瞻修正"]
  AUX --> SUM
  SUM --> SORT["按进攻／平衡／追分／防守／弃和排序"]
  SORT --> SEARCH["满足尾盘近分条件时<br/>少量候选短程抽样重排"]
  SEARCH --> GATE["同速避险、尾盘安全速度<br/>近分结构裁决、最后保叫"]
  GATE --> OUT["推荐一张牌＋候选明细＋理由"]
```

**手牌结构层。** 普通向听递归枚举刻子、顺子、对子与搭子的互斥分解；门清时再比较七对向听，四张同牌可按两对计算。向听 `−1` 表示已成胡形，`0` 表示听牌，`1` 表示一向听。每次假设弃牌后，枚举可能进张，检查是否降低向听；听牌则逐种补牌并验证真实胡牌分解。

**质量层。** 比较两面、嵌张、边张、单钓、双碰；评估中张联络、对子压力、搭子过剩、同向听改良、拆对拆刻、连续顺形、孤立幺九。它不只是数“进张种类”，还比较未见量和墙内估计。经典牌形分数 `ClassicPatternScore` 目前写入候选诊断，并未直接加到这条主评分公式中。

**统一价值层。** 普通主路径对每个候选调用机会节点抽样，当前传入 512 次。它用活张总量、牌墙总数、活动人数、简化赢分和对手赢牌参数模拟机会；没有在每次抽样里完整重建四家打牌策略。尤其非听牌时，改良张被作为推进／成功代理量使用，不能把输出直接当真实胡牌概率。

它合并自己收益、杠收益、查叫价值、路线／退出价值，减去点炮、对手后续收益、结构损失及不确定性成本。多人效用是当前行动者的视角；普通 AI 不因此变成共同围攻玩家的团队。

**实际组合公式。** 代码当前先算：

```text
V = U + 0.06 × L + 0.05 × R + 0.20 × M − 0.35 × D
Score = round(100 × V)

U：统一动作价值
L：有限前瞻分，限制在 −18 至 24
R：分别限幅后合计的牌形、路线连续性和出牌时机证据
M：第二套预计净值与 U 的差，限制在 −2 至 2
D：后验防守成本，限制在 0 至 2
```

`R` 中普通牌形最多 ±0.75，保对保刻 ±2.50，连顺与听牌中张各 ±1.25，尾盘对子听口 ±1.50，路线连续性 ±2.00，出牌时机 ±0.85；孤立幺九的限幅随阶段变化。它们合计后再乘 0.05。这样可限制旧经验分压过共同价值。

但**最终动作并不总是 Score 最大者**：防守／弃和模式先分安全层级，后面还有显式闸门能换掉首选。阅读候选表时必须连同“实际推荐”及覆盖理由一起看。[S15][S16][S17][S18]

## 07 · 大牌路线如何保持，又何时放弃

```mermaid
flowchart TB
  H["当前手牌：向听、对子、刻子<br/>同门数量、异门成本、公开竞争"] --> RAW["给各路线打经验权重"]
  RAW --> R["平胡／大对子／清一色／清对<br/>暗七对／龙七对／清七对／青龙七对"]
  R --> B["读取本座位已有主路线<br/>备用路线、目标门、承诺度"]
  B --> SW{"新路线优势足够大<br/>或旧路线失效？"}
  SW -->|否| KEEP["保持路线，调整承诺度"]
  SW -->|是| CHANGE["切换主路线，保留可行退路"]
  KEEP --> ACTION["影响打牌、碰杠取舍<br/>作为有限修正及部分动作闸门"]
  CHANGE --> ACTION
  ACTION --> RECORD["记录本次选择<br/>特别记录主动拆刻等结构承诺"]
  RECORD --> B
```

路线不是每摸一张就从头忘记重选。持续大脑记住主／备用路线、目标花色、承诺度和近期动作。切换基准优势门槛是 `8 + 承诺度/5 + 阶段×3`；很早期的前两次观察、已较成形的清色路线还会提高切换门槛。

七对系列要求门清；五对以上显著提高承诺，碰杠会损失门清与四张当两对的结构，因此反应层设有较重保护。主动拆刻会留下记录，防止下一步轻易把刚拆掉的刻子又碰回来。

清一色还会调用专项规划：假设当前弃牌，再枚举摸牌与随后弃牌，比较成叫、听口、目标门竞争、根杠潜力、危险与普通胡退路。当前这个较老的专项仍以 `Remaining18` 未见牌量做部分估计，**并非所有子模块都已经统一到墙内期望口径**；所以它只作为有界路线证据，不能把显示的完成率当实战标定概率。

番型识别与路线规划也不同：评分投影能识别金钩钓、将对、十八罗汉等，不意味着持续大脑为每一种番型都有一套独立长程规划器。预测基础规则使用冻结快照：27 种牌、每种 4 张、无吃、血战、一炮多响、四番封顶、自摸加底；最终是否合法与如何结算仍由实际游戏规则执行。[S19][S20][S21]

## 08 · 前、中、后期：实际阈值与策略模式

```mermaid
flowchart TB
  STATE["当前公开进度"] --> L{"墙≤6？<br/>或有高听牌压力且墙≤8？"}
  L -->|是| LATE["主出牌阶段：后期"]
  L -->|否| M{"任一家弃牌≥10？<br/>或墙≤13？或总副露组≥5？"}
  M -->|是| MID["主出牌阶段：中期"]
  M -->|否| EARLY["主出牌阶段：前期"]
  LATE --> COMB["结合手牌质量、威胁与总积分"]
  MID --> COMB
  EARLY --> COMB
  COMB --> MODE["进攻／平衡／追分／防守／弃和"]
  MODE --> RESULT["决定风险容忍、候选排序<br/>以及部分尾盘覆盖规则"]
```

这里“高听牌压力”在主出牌阶段器中包括：他家已有副露、真实输入允许的听牌标志，或推理听牌程度 `≥0.55`。普通桥接不会提供他家真实听牌标志。代码还有“有压力且墙≤10 划中期”分支，但已被墙≤13 的判断覆盖。

| 层次 | 前期 | 中期 | 后期 |
|---|---|---|---|
| 主出牌阶段器 | 不满足后两列时 | 最大弃牌数≥10，或墙≤13，或总副露≥5 | 墙≤6；或有上述压力且墙≤8 |
| 持续战略记忆 | 不满足后两列时 | 最大弃牌数≥9，或墙≤13，或总副露≥5 | 墙≤6，或最大弃牌数≥15 |
| 碰杠／自家动作阶段器 | 不满足后两列时 | 最大弃牌数≥10，或墙≤13，或总副露≥5 | 墙≤6；或存在副露／听牌标志且墙≤8 |
| 路线粗价值模块 | 墙>16 | 8<墙≤16 | 墙≤8 |

**没有统一的“第几巡以后全部切换”开关。** 同一局面可能被主出牌视作中期、持续记忆视作后期，这是当前多模块实现的实际状态。

前期主要保留可扩展结构、建立主路线、清理缺门与低价值孤张；中期在成叫速度、墙内活张、大牌机会和他家压力之间取舍；后期增加点炮风险、查叫与保叫权重，重评旧安全证据，不轻易用死叫换掉有改良的手牌。这些是组合效果，不是三套完全分离的算法。

阶段之外还有总积分：领先且临近结束倾向保护领先；落后至少 12 分被识别为落后，最后两局或落后至少 24 分进一步触发追分倾向。威胁极高时仍可进入防守或弃和，并非落后就无条件冲。

最后几张的闸门尤其具体：墙≤5 时可启用硬防守与最终保叫；墙在 1–8 且存在相近风险的更快路线时可改选；最终保叫会找危险<70 的听牌候选。闸门按代码顺序依次执行，后面的判断可能覆盖前面的选择。[S22][S23][S24]

## 09 · 碰、杠、胡、过：比较的是动作之后的局面

```mermaid
flowchart TB
  R["他家出牌，规则给出合法动作"] --> H{"可以胡？"}
  H -->|是| HC["比较立即胡／过胡<br/>同时可碰时比较碰后保叫"]
  HC --> HG["过胡门槛：墙≥6、代表活张≥2<br/>置信度≥0.82、后续净值超过收益溢价"]
  HG --> CH["从允许的候选中选动作"]
  H -->|否| BR["建立三个反事实分支"]
  BR --> PASS["过：保留当前暗手<br/>等待真正轮到自己的摸牌"]
  BR --> PENG["碰：移出两张形成副露<br/>立即枚举必须打出的那张"]
  BR --> GANG["杠：移出三张形成明杠<br/>先枚举补牌，再看胡或弃牌"]
  PASS --> EV["同一尺度比较速度、活张、番分<br/>杠分、查叫、路线损失与风险"]
  PENG --> EV
  GANG --> EV
  EV --> SR["必要时用相同抽样牌墙<br/>比较 24 轮、最多两次本家摸牌"]
  SR --> GUARD["避免碰成死叫、破坏宽进张<br/>保护七对和已作出的结构选择"]
  GUARD --> RULE["若规则强制杠，则服从规则"]
  RULE --> CH
```

这层真正重要的是**时序不同**：过不会凭空先打一张；碰后要马上打牌，可能被迫打危险张；杠后先补牌，可能直接胡，也可能补完还要冒险打牌。每条分支都有不同的下一次本家摸牌位置。

普通碰杠评分会先生成旧经验诊断，再由统一反事实值重排；在这一反应主路径里，旧经验分明确只留作诊断，不直接参与最后统一分。七对路线损失、主动拆刻后的回碰损失及反应闸门仍能影响选择。

胡牌并非一个无条件按钮：

- **自摸可胡：当前直接胡。** 代码会计算确认信息，但最终返回胡。
- **普通接炮可胡：可以比较过胡。** 未来收益扣除顺胡锁成本、风险和不确定性后，需要至少高于即时收益 `max(0.25, 即时收益×25%)`，还要满足活张、牌墙和置信度门槛。
- **同时能碰能胡：** 可以评估碰后仍听的分支；用实际出牌引擎预测碰后的首打，只为这条真正可能执行的后续路线估值，再扣强制首打风险。不随便假定碰后会打出理想牌。
- **自家暗杠／补杠：** 与继续出牌比较，计算补牌、杠收益、七对损失及补杠被抢风险。实际可抢杠人数不进入公平判断。
- **地狱模式接炮可胡：直接胡**，与普通过胡路径不同。[S25][S26][S27]

## 10 · 前瞻有几层，各算多远

```mermaid
flowchart LR
  C["当前候选动作"] --> A["结构枚举<br/>弃牌后枚举一种进张，重算向听与听口"]
  C --> B["清色专项<br/>当前弃牌 → 摸一张 → 再弃一张"]
  C --> L["有限前瞻<br/>尾盘选 4 或 6 种进张，找最好后续弃牌"]
  C --> MC["近分弃牌抽样<br/>前 3–4 个候选，共用抽样牌墙<br/>看 1–2 次本家摸牌"]
  C --> R["碰杠反应抽样<br/>24 轮共用牌墙，考虑动作摸牌偏移"]
  C -.-> E["极尾盘整桌模拟器<br/>设计范围墙≤4、32 个暗手假设"]
  E -.-> BLOCK["当前游戏可见牌口径不一致<br/>入口守恒检查会拒绝"]
  C -.-> DIAG["长程血战／联合路线诊断<br/>不改当前正式选择"]
```

| 层 | 实际范围 | 对动作的影响 |
|---|---|---|
| 向听／听口枚举 | 遍历合法弃牌与可能进张 | 核心输入 |
| 统一机会抽样 | 弃牌 512 次；副露反事实 256 次；抽象成功／失败事件 | 统一价值主项；不是四家完整对弈 |
| 清色专项 | 满足路线或粗完成估计条件时，枚举下一摸与再弃牌 | 有界路线修正 |
| 有限前瞻 | 墙≤6 取 6 种；墙≤12 且向听≤1 取 4 种；其余不启用这一层 | 加权后限幅 |
| 名为 MCTS 的弃牌搜索 | 墙 1–12；前两候选统一价值差≤0.70 或总估值差≤0.55，再经过内部条件 | 45ms；墙≤8 为65ms。前3，墙≤8前4；墙≤10看2摸，否则1摸 |
| 碰杠短搜索 | 多个候选接近，或较早期碰杠领先等条件 | 24 轮、每条路线最多2次本家摸牌 |
| 极尾盘整桌模拟 | 模块设计为墙≤4、保听候选、32粒子、同组牌墙比较 | **当前实战桥接口径下被阻断** |
| 更长血战／公开联合路线 | 显式诊断接口，或测试策略开关 | 当前 `current` 策略不采用 |

弃牌抽样没有树节点 UCT 选择、完整四人动作扩展或对手最优策略求解；它在同一抽样墙上比较少数候选的本家短程推进。搜索修正限制在 ±0.75 后加回，因此不能等同于“全局最优证明”。不同设备在限时内完成的样本数量可能不同，同一策略并不保证所有近分局面在每台设备上逐位一致。

**入口问题的验证。** 小型验证调用当前编译核心的 `TryPrepare`：同一合法手牌与未见牌池，用不含本家手牌的公开可见数组时通过并得到 1 个候选；用当前游戏桥接的“可见已含本家手牌”数组时拒绝，5 种持有牌违反它要求的 `Hand + Visible + Remaining = 4`。该游戏桥接满足的是 `Visible + Remaining = 4`。因此不能把这个整桌尾盘模拟器标成当前游戏已经有效发挥作用。已退出玩家未纳入分配、过胡锁等情况还会另触发它的拒绝条件。

本次只是记录和验证这一现状，没有修改算法。[S28][S29][S30]

## 11 · 单行道：怎样保留这一门，又怎样留出退路

```mermaid
flowchart TB
  A{"其他三家原始定缺相同<br/>且这一门不是本家定缺？"} -->|否| NORMAL["普通候选价值"]
  A -->|是| LEGAL{"本家已清缺，副露仍能清色<br/>且还有有效摸牌预算？"}
  LEGAL -->|否| NORMAL
  LEGAL -->|是| PUBLIC["逐家查最近摸／打事件<br/>打出非缺门可证明当时已清缺<br/>随后摸牌会使该证明失效"]
  PUBLIC --> SUPPLY["估计墙内目标牌<br/>尚未清缺者可能排出的牌<br/>以及后续摸入后被迫排出的牌"]
  SUPPLY --> EACH["对每种弃牌分别试算"]
  EACH --> ROUTE["目标门向听与普通向听<br/>异门清理成本、可碰／可胡供张"]
  EACH --> EXIT["再摸目标门后，枚举下次弃牌<br/>能否保持路线且安全打得出去"]
  ROUTE --> P["有限摸牌预算下<br/>估计路线完成机会"]
  EXIT --> P
  P --> VALUE["完成机会 × 清色增益 × 付款人数<br/>减去失败和延迟成本"]
  VALUE --> NORMAL
  NORMAL --> FINAL["与其他弃牌一起比较<br/>仍服从危险控制和最终闸门"]
```

它不是简单的“这门一律不打”。新模块逐候选比较保留目标门与打出目标门的代价，并将分值加入统一动作价值。

关键实现：

- 激活依据是**其他三个座位的定缺都相同**，不是只看当前剩下的一两个对手碰巧同缺；计算付款人数和供张时再只看仍在场玩家。
- 本家缺门未清、已经有异门副露导致清一色不可能、没有剩余摸牌预算时，专项不加值。
- 本家摸牌预算为 `min(18, floor(牌墙数/活动人数))`，是简化预算，不逐一模拟所有将来的抢碰、杠和退出。
- 供张只有已有对子／刻子能碰杠，或可直接胡时才计入有效完成帮助；没有吃牌。
- 针对目标门的下一次进张，再逐种试弃：墙>24 时可容忍普通路线暂时多一向听；墙≤24 时不允许这一额外退步。
- 后续可弃牌数量会按当前危险度折减，保留多条可走出口比只剩一张危险牌可打更有利。
- 完成机会由固定推进率的二项尾概率近似，再乘未来弃牌空间系数；清色基础 2 番，根与封顶限制后估算增益，扣除做大失败／拖慢成本。

这些是有边界的近似。未来出牌风险用当前公开估计，不能预知那时对手的新听口；供张按手牌数量与预算分配，也不是逐张精确反推。全部活动对手都显示已清缺时，模块会把该门未见牌视作在墙内，这还依赖未见池没有夹带退出玩家暗手的前提；当前实现未在此处做完整退出暗手分离。图中所以使用“估计收益”，不写“已经实现全局收益最大化”。[S31]

## 12 · 地狱模式：共享暗牌与协同到底到了哪一步

```mermaid
flowchart TB
  MODE["选择地狱预设"] --> FLAGS["打开 AI 暗手共享<br/>读取玩家暗手、读取真实牌墙数量<br/>执行全信息动作"]
  FLAGS --> IN["当前行动家普通候选<br/>＋四家真实暗手计数<br/>＋每种牌真实剩余数量＋积分"]
  IN --> TEAM["团队计划：目标座位固定为 0<br/>按积分分配主压制／截断／追赶角色"]
  IN --> EXACT["逐候选检查实际点炮对象<br/>玩家能否碰杠、真实进张与听口"]
  TEAM --> SCORE["在普通牌理基础上重评分<br/>重点避免喂玩家胡和高威胁杠碰"]
  EXACT --> SCORE
  SCORE --> ACTION["仍然只返回当前行动家的动作"]
  ACTION --> NEXT["牌局更新后，下一行动家重新算"]
```

地狱预设默认会打开三项信息权限：AI 暗手共享、看玩家暗手、看牌墙。实际挑战入口还要求预设为 `hell`、执行全信息动作开关和看墙开关成立。

它传的是**牌墙每种牌的剩余张数，不是牌墙顺序**。因此能够知道还有几张某牌，却没有从这个输入直接知道“下一张必定摸到什么”。

出牌先获得普通骨灰引擎的合法候选与牌理，再利用真实手牌检查具体点炮风险、是否让玩家碰／杠、真实活张等。角色按积分选择主压制者，对当前行动者和落后 AI 设置截断／追赶倾向。各家仍逐次出动作，并没有联合枚举三家完整策略或优化全部后续团队总分。

这也不是“永不放任何碰”：代码保留普通碰的互动空间，自己能保持速度、对方碰后威胁不高时可以放行。能胡时则直接锁定收益。自摸、暗杠／补杠的前置动作仍走共用自家动作入口，不能把所有环节一概说成全透视专用求解器。

因此回答“是不是全盘计算”必须分三种意思：

| 问题 | 普通模式 | 地狱挑战 |
|---|---|---|
| 是否看整桌公开局势？ | 是 | 是 |
| 是否拿到其他家真实暗手与墙内数量？ | 否 | 开关打开时是，地狱预设默认打开 |
| 是否三家使用协同压制目标？ | 没有这层团队计划 | 有，固定针对座位0 |
| 是否精确知道牌墙下一张？ | 否 | 此输入也没有牌墙顺序 |
| 是否求解四家全部未来最优打法？ | 否 | 否 |

联机或非默认座位布局下，固定目标0也不自动等于“所有真人”；这是当前团队规划器的假设。[S32][S33][S34]

## 13 · 已胡退出、流局收益与实际规则的边界

```mermaid
flowchart TB
  H["有人胡牌"] --> A["更新活动座位与人数"]
  A --> D["重新估计轮到自己摸牌的频率"]
  A --> P["自摸付款人数减少"]
  A --> R["退出者不再作为点炮威胁"]
  D --> V["本家未来动作价值重算"]
  P --> V
  R --> V
  W["牌墙接近耗尽"] --> CJ["增加成叫／查叫价值<br/>减少拖延做大的时间预算"]
  CJ --> V
  V --> ACT["AI 提交动作"]
  ACT --> RULE["实际规则引擎执行与记分"]
```

AI 的收益估计考虑点炮单家付款、自摸多家付款、番型与根、杠分、血战人数变化、查叫风险。规则投影支持杠后、抢杠、呼叫转移等计算；冻结预测快照的退杠开关当前为 `false`，因此不能因代码里存在退杠相关类就写成“所有决策都启用退杠”。

不同估值层精度不同：完整手形的番型投影可以按分解算分；普通弃牌机会模型仍使用一些固定赢分／对手损失系数；第二套期望分又用估计番型、胡牌份额和查叫压力。**“统一动作净值”是一种比较尺度，不能理解成所有候选都经过同一套完整规则对弈算出的精确现金期望。**

AI 不决定庄家规则。实际牌局在下一局按第一批胡牌事件确定：首个单独胡牌者坐庄；首次就是同一张牌的一炮多响则放炮者坐庄，后续多响不覆盖先胡者。[S18][S21][S35]

## 14 · 缓存、运行与学习：哪些在持续，哪些没有启用

```mermaid
flowchart TB
  NEW["新状态请求"] --> KEY["当前视角状态指纹<br/>手牌、公开事件、规则状态、策略记忆版本"]
  KEY --> HIT{"缓存有相同请求？"}
  HIT -->|是| REUSE["复用本状态已有结果"]
  HIT -->|否| CALC["重算脏模块与候选"]
  CALC --> SAVE["保存推理／决策缓存<br/>更新本座位局内战略记忆"]
  REUSE --> CHECK["执行前再次核对当前状态"]
  SAVE --> CHECK
  CHECK --> ACT["执行动作"]
  ACT --> LOG["可记录影子事件与诊断"]
  LOG -.-> OFF["离线复盘、独立评判、策略候选实验"]
  OFF -.-> PROMOTE["经独立验证后另行修改正式策略"]
```

| 类型 | 当前状态 |
|---|---|
| 局内连续记忆 | 启用，保存路线承诺、近期选择和拆刻记录 |
| 推理与决策缓存 | 启用，节省相同状态重复计算；推理缓存上限256份 |
| 后台计算 | 提供原生后台请求、轮询和同步入口；后台并不意味着脱离最新状态自主打牌 |
| iOS NativeAOT | 使用同一 C# 核心的编译产物和紧凑传输入口 |
| 移动轻量模式 | 需要显式标志；正常桥接 `mobileSpeedMode=false` |
| 自动学习持久化 | `AI_LEARNING_RECORDING_ENABLED=false`，新局也据此关闭自动学习 |
| 影子记录 | `AI_SHADOW_RECORDING_ENABLED=true`；记录不等于自动改策略 |
| 视频知识／离线训练／联赛评测类 | 有工具与代码，不能据此宣称在手机上边打边训练 |
| 测试策略变体 | 需指定 `policyVariant`；正常为 `current`，联合路线 shadow 与 v1/v3–v7 不默认生效 |
| 筋线断张／孤张活性等汇总指标 | `PublicReadFeatures` 中会生成；当前核心未发现读取这些汇总键来改变候选的调用。底层舍牌、邻张、手切证据仍有其他实际消费路径 |
| 主动战略性点小炮接口 | `CanStrategicallyDealIn` 存在，但当前未发现正式调用；不能说普通 AI 已启用“故意喂小胡压大胡”的完整策略 |
| 中级与骨灰预设 | 配置参数不同，但当前这条 C# 桥接没有把多数旧倾向参数传给核心，实际又直接执行推荐牌；不能仅凭预设参数表宣称它们使用两套已验证的不同强度策略 |

“越打越记得本局路线”与“跨局自动训练越来越强”是两回事。当前明确生效的是前者。中级／骨灰分流效果、共享上下文缓存键的隔离程度需要专门行为验证，本文不把未做的验证写成结论。[S01][S04][S07][S36][S37]

## 15 · 完整模块地图、现状与证据

```mermaid
flowchart LR
  UI["牌局与界面"] --> BR["Godot 视角过滤与动作合同"]
  BR --> RT["原生 C# Runtime / Facade"]
  RT --> DQ["定缺"]
  RT --> DS["弃牌"]
  RT --> RE["他家出牌反应"]
  RT --> SA["自摸与自家杠"]
  DS --> COMMON["共用基础：牌编码、向听、胡形分解<br/>番型与结算投影、合法动作、摸牌顺序"]
  RE --> COMMON
  SA --> COMMON
  DS --> INFER["证据 → 对手范围 → 假设暗手<br/>归一化 → 墙内张数 → 危险"]
  DS --> PLAN["阶段与积分目标 → 攻防模式<br/>持续路线 → 清色／单行道"]
  DS --> EV["统一候选价值 → 有界修正<br/>短程搜索 → 最终闸门"]
  RE --> CF["过／碰／杠／胡的后续局面比较"]
  SA --> CF
  RT -.-> HELL["地狱专用：全信息候选修正<br/>＋三家团队目标"]
  RT -.-> LAB["诊断／候选实验／离线评测学习"]
```

**当前能力应这样概括：** 规则与精确牌形计算为基础，公开行为推理与少量隐藏牌假设提供不确定信息，路线记忆保持连续性，候选动作通过近似收益、防守约束和有限前瞻选出；地狱模式再叠加真实隐藏信息与团队压力。

当前正式入口并不是神经网络或大语言模型下棋：主要组成是程序规则、人工设计的启发式、递归枚举和随机抽样估值。

**需要保留的现实边界：** 普通推理不是精确读心；分值与概率没有统一完成实战校准；前中后期阈值不统一；部分清色与上下文模块仍使用未见牌代理；极尾盘模拟受可见牌口径阻断；长程联合搜索和自动学习不能列为默认能力。这里未改动任何游戏算法，也未运行与说明任务无关的固定回归。

### 术语速查

| 术语 | 在本图解里的意思 |
|---|---|
| 向听 | 到听牌还差多少步的结构指标；0为听牌，−1为成胡形 |
| 进张／有效牌 | 摸入后改善当前向听或听口的牌 |
| 未见张 | 本视角尚未知道位置的牌，可能在对手手里，也可能在墙里 |
| 墙内期望活张 | 估计有效牌中有多少张实际属于牌墙，可为小数 |
| 后验 | 结合已观察行为后更新的估计；当前多处是经验混合估计 |
| 粒子 | 一份可能的暗手与剩余牌池假设，不是真实暗手 |
| 反事实 | 假设现在碰／杠／过／打某张，再比较后续会变成什么局面 |
| EV／净值 | 预测收益减成本的比较分；精度取决于所用子模型 |
| 路线 | 当前倾向完成的牌型方向，如平胡、七对、清一色 |
| 承诺度 | 保持已选路线的惯性；较高时不为很小的短期优势改方向 |
| 退出空间 | 后续还能安全打哪些牌、能否保留普通听胡退路 |
| 闸门／覆盖规则 | 在候选算分后，按明确条件否决或替换原推荐 |
| 影子计算 | 算出来用于观察比较，但不让结果控制正式动作 |

### 源码索引

链接固定到本次核对提交，避免后续改动使说明与代码错位。行号定位入口，阅读时可向后展开对应函数。

| 编号 | 核对位置 | 支撑内容 |
|---|---|---|
| S01 | [Runtime](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/ai/SichuanCSharpRuntime.cs#L16)、[Facade](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Entry/SichuanAiFacade.cs#L8) | 共享服务、正式与诊断入口 |
| S02 | [RoundBrain](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanRoundBrainEngine.cs#L6) | 按局与座位保存记忆 |
| S03 | [普通输入桥接](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/ai/csharp_ai_bridge.gd#L207) | 输入视角、移动端策略一致 |
| S04 | [联机权威状态](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/network/lan_room_session.gd#L111)、[上下文缓存](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Cache/SichuanAiContextCache.cs#L8) | 房主处理与共享缓存 |
| S05 | [事件过滤](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/ai/csharp_ai_bridge.gd#L359) | 他家摸牌、私有pass过滤 |
| S06 | [定缺](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanDingQueDecisionEngine.cs#L5) | 最少张数规则 |
| S07 | [实际行动链](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/autoload/GameState.gd#L1104)、[AI管理器](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/ai/AIManager.gd#L1542) | 自家动作优先、执行推荐、失败行为 |
| S08 | [牌计数](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/ai/sichuan_tile_codec.gd#L62) | 可见与未见牌口径 |
| S09 | [推理合成](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanBeliefEngine.cs#L90) | 32/48粒子、混合、归一化 |
| S10 | [暗手假设](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Inference/SichuanHiddenHandInferenceEngine.cs#L8) | 默认与新提案区别 |
| S11 | [墙内分配](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanWallAvailabilityEngine.cs#L21)、[归一化](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanPosteriorNormalizer.cs#L5) | 数量约束与份额含义 |
| S12 | [证据构造](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanEvidenceEngine.cs#L5)、[对手范围](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanOpponentRangeEngine.cs#L5) | 舍牌软证据与副露压力 |
| S13 | [危险引擎](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanDangerEngine.cs#L5)、[风险映射](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanRiskCalibration.cs#L3) | 硬排除、风险分级和点炮代理 |
| S14 | [出牌时机](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Strategy/SichuanDefenseTempoEvaluator.cs#L19) | 临时安全储备与未来危险 |
| S15 | [出牌主入口](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanDecisionEngine.cs#L54) | 特征、合分与覆盖顺序 |
| S16 | [向听](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanShantenEngine.cs#L3)、[精确分解](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Rules/SichuanExactHandAnalyzer.cs#L6) | 普通／七对／听口 |
| S17 | [统一动作价值](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Decision/SichuanUnifiedDecisionEngine.cs#L22)、[多人效用](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Search/SichuanMultiPlayerUtilityEngine.cs#L24) | 共同评分尺度、过胡门槛 |
| S18 | [机会抽样](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Search/SichuanActionTreeEvaluator.cs#L18)、[第二收益估计](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanExpectedScoreEngine.cs#L6) | 抽象EV与启发式参数 |
| S19 | [路线规划](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanRoutePlanEngine.cs#L5) | 路线权重与门清约束 |
| S20 | [清色专项](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Strategy/SichuanQingYiSePlanner.cs#L24)、[路线粗价值](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Strategy/SichuanRouteValueEvaluator.cs#L13) | 清色前瞻、未见量口径 |
| S21 | [番型投影](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Rules/SichuanFanProjectionEngine.cs#L23)、[冻结规则](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Domain/SichuanRuleSnapshot.cs#L3) | 番、根、封顶、规则开关 |
| S22 | [阶段与攻防](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanContextEvaluators.cs#L6) | 主阶段、积分、模式 |
| S23 | [持续大脑阶段](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanRoundBrainEngine.cs#L58) | 另一套阶段阈值 |
| S24 | [最终闸门](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanDecisionEngine.cs#L1778) | 同速避险、尾盘保叫等 |
| S25 | [反应入口](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanReactionDecisionEngine.cs#L20) | 碰杠过胡、统一评分与闸门 |
| S26 | [自家动作](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanSelfActionDecisionEngine.cs#L16) | 自摸、暗杠、补杠 |
| S27 | [副露反事实](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Decision/SichuanMeldCounterfactualEvaluator.cs#L24)、[能胡时的碰与过](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Decision/SichuanUnifiedDecisionEngine.cs#L174) | 动作真实时序 |
| S28 | [短程搜索](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanMctsEngine.cs#L6)、[有限前瞻](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanLimitedLookaheadEngine.cs#L5) | 搜索真实深度 |
| S29 | [极尾盘入口](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Decision/SichuanPublicEndgameEvaluator.cs#L376)、[Runtime不改可见数组](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/ai/SichuanCSharpRuntime.cs#L1211) | 口径冲突与拒绝条件 |
| S30 | [诊断接口](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Entry/SichuanAiFacade.cs#L10) | 长程能力未进入正式策略 |
| S31 | [单行道](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Strategy/SichuanSingleLaneEvaluator.cs#L15) | 供张、空间、完成与延迟模型 |
| S32 | [预设开关](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/core/ai_tuning_config.gd#L34)、[地狱启用条件](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/autoload/GameState.gd#L5298)、[全信息输入](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/autoload/GameState.gd#L5892) | 模式、暗手与墙内数量 |
| S33 | [地狱弃牌](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanHellChallengeEngine.cs#L24)、[团队角色](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanHellChallengeTeamPlanner.cs#L5) | 全信息重评分、固定目标0 |
| S34 | [地狱反应](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanHellChallengeReactionEngine.cs#L25) | 可胡直接胡、碰杠修正 |
| S35 | [轮庄](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/core/dealer_rotation.gd#L1) | 下一局庄家不属AI策略 |
| S36 | [学习开关](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/autoload/GameState.gd#L57)、[新局处理](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/autoload/GameState.gd#L405)、[学习持久化](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/scripts/core/ai_learning_engine.gd#L48) | 自动学习关闭、影子记录开启 |
| S37 | [策略变体与影子路径](https://github.com/donachen01/sichuan-mahjong/blob/abf8c6ea1712c7ce08712ef8780b0c91a612d2d0/dotnet/AI.Core/Engines/SichuanDecisionEngine.cs#L381) | 候选研究不等于上线 |

### 本次验证记录

- 阅读并跟踪实际入口、桥接、正式分支、主要评分和搜索模块；按源码确认启用条件。
- 用当前 Release 核心做同局面双口径入口验证，结果保存在本目录 `audit-probe.txt`；这是入口验证，不是整局棋力评测。
- 图解中的公式和参数对应此提交；“估计”“代理”“未校准”“条件启用”和“被阻断”保留原有能力边界。
- HTML 图文版将各图预渲染为矢量图，可离线阅读；本 Markdown 保留可编辑的 Mermaid 图源。
