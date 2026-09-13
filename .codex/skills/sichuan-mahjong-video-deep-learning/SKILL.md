---
name: sichuan-mahjong-video-deep-learning
description: 分阶段学习四川麻将教学视频：先证据化读懂并归并专家策略，再按能力重建共享算法并独立验证；用于批量视频知识采集、能力整理、历史审计或已授权公平 AI 强化，不用于标题摘要、牌谱动作复刻或单视频调权。
---

# 四川麻将教学视频深学

## 先判定本轮任务，防止跑偏

- **强化/审计 skill**：只修改 skill 和必要配套工具，先用隔离的测试数据检验。用户提到“第 N 条为例”不等于授权改写第 N 条历史记录。完成工具验证后才在独立实验目录试用该视频；不推进学习队列、不改库存、不覆盖知识卡或旧报告。
- **学习/继续学习视频**：按持久化检查点逐条进行，优先复用用户指定的 `/Volumes/other/潇老师麻将视频下载/`；本地有多少学多少，不以 100 条为上限，不重新下载已有原片。
- **批量知识采集与能力归并**：当用户明确要求“先读懂全部视频，之后再谈算法/验证”时，读取[视频知识采集阶段](references/knowledge-acquisition-phase.md)。逐条交付证据化学习笔记并挂接能力草案；本阶段不得强制做 C# 映射、盲测、反例实验或棋力晋级。
- **实施 AI 改造**：先确认属于用户已授权的公平 AI 范围，冻结基线后实现候选；不得借学习任务更改规则、透视挑战模式、界面或发布版本。

本轮目标明确为 skill 完善时，不得把“修正某个历史视频”替代为主线。最终交付分别报告 skill 规则、工具测试和示例试用的结果，不能互相替代。

不要把两种模式混成一条强制流水线。知识采集模式只验收“证据可信、观点读懂、候选与边界记清、未知保留、能力挂接”；机制与验证模式才读取[真实执行闭环](references/executable-loop.md)，按公开输入重放、失败驱动改造、跨视频支持与反例、独立完整结算推进。工具接通、公平性修复、技巧覆盖及棋力增益仍须分别证明。

目标是复现博主在当时可见信息下的思考，并把它提升为对任意等价牌例成立的决策算法。视频中的具体摸打只属于事实证据和测试夹具，不是生产 AI 的规则模板。只有能够重放公开局面、解释候选动作、抽象状态变量与目标、经反事实和跨花色盲测复现，并落成有边界的通用决策方法，才可称为“已吃透并应用”。

## 首要验收标准

视频负责提供专家策略、候选比较与因果假设，不承担全部概率训练数据。合法规则引擎生成的自然牌局可用于概率及续局模型校准，须按原始牌局隔离训练与留出，并冻结规则、对手策略和生成版本；它不等于真人专家标签。人工检查点只用于机制检查。来源组数量是结构下限，不是校准充分性的保证。

发现自证、答案已暴露或实验经过结果驱动修改时，保留原报告，新增 `evidence-retraction.json`，写明撤回的结论与原因；理解及更高阶段必须拒绝该包，直至独立重审并另行发布新证据。已看过结果的不同种子只检查抽样稳定性，不能恢复留出资格。多因素翻转只算边界探查。能力改造主线未闭合时，不以推进更多视频替代解决当前机制问题。

知识采集模式以[视频知识采集阶段](references/knowledge-acquisition-phase.md)为当前验收合同。进入机制与验证模式时，必须再读并执行[专家学习 v2 修复合同](references/expert-learning-v2.md)；它规定八项修复、真实节点重放与候选策略晋级。代码和文档审查不等于棋力提升，任何模式都禁止由脚本自动生成“盲测通过”或把旧测试总数当成新视频覆盖。

视频身份、图像、牌面、动作和字幕识别只是取证手段，不是学习成果。在完整的“机制与验证模式”中，单条或多条来源支持的核心交付是：

1. 准确提炼潇老师这条视频真正在教的核心观点和技巧，不得只复述标题、字幕或出牌结果；
2. 把核心观点改写为可执行的决策机制：公开触发条件、候选动作、状态更新、风险收益比较、攻守切换和翻转条件；
3. 正确映射或实现到四川麻将正式 AI，并用真实 C# runtime 和泛化对照用例证明算法实际参与了候选排序或动作选择。

在“知识采集模式”中只要求第 1 项，并把第 2 项降为能力草案：记录通用问题、公开依据、候选取舍、可能翻转条件和未知，不要求证明机制正确；第 3 项明确后置。完成标记只能是 `knowledge_note_complete`，不能写成已验证、已应用或棋力提升。

仅“看完”、“OCR 完成”、“牌面认清”、“知识包字段齐全”或“机械验证器通过”均不得标记为学会。每条视频都必须通过[核心观点提炼与 AI 转化方法](references/core-thesis-ai-conversion.md)。

## 开始前

先选择模式。知识采集模式读取[视频知识采集阶段](references/knowledge-acquisition-phase.md)、[核心观点提炼与 AI 转化方法](references/core-thesis-ai-conversion.md)的共同取证/提炼部分和[专家推理知识卡](references/knowledge-card-template.md)，不加载或执行 AI 应用门禁。机制与验证模式再读取[单视频证据化深学协议](references/learning-protocol.md)、[语义吃透协议](references/semantic-mastery-schema.md)、[决策算法抽象与反过拟合门禁](references/decision-algorithm-abstraction-gate.md)与[单视频 AI 应用门禁](references/ai-application-gate.md)。

新建或续做证据包时遵守[证据包结构与索引规范](references/evidence-bundle-schema.md)。首次使用本 Skill 或方法发生争议时，读取[首条视频试点复盘](references/pilot-lessons.md)，避免重犯“只记字幕、不还原决策”的错误。

必须永久保存原片并校验视频ID、时长和SHA-256。抖音搜索页的`modal_id`要作为视频主键；浏览器页面可能预加载其他视频，只有播放器时长、标题和视频ID一致时才能下载。禁止把404页或下一条自动播放的视频当成目标。

## 连续低流量调度

读取[连续学习状态机](references/continuous-learning-state-machine.md)。视频深学默认不是“每十分钟检查一次”的轮询任务，而是一次唤醒后的连续批处理。知识采集模式逐条完成到 `knowledge_note_complete` 后立即领取下一条；机制与验证模式才继续算法验证和总结。没有可抽象、可反证决策内容的视频必须记录 `no_technique` 或证据化排除理由，不能写成算法 `verified`。每完成一个阶段立即写入小型本地状态文件；中断后从该阶段恢复，绝不重传已经由SHA-256确认的原片、重抽已经存在的帧、或重新分析已通过的节点。

原片获取这种可能超出一次代理回合的确定性本地作业，必须在下载结束后立即调用`advance_local_artifacts.py`收口：它会核验媒体并生成从00:00开始的1 FPS、OCR、联系表和低流量账本，然后原子推进到`baseline_indexed`并停止。它不得判断关键张、撰写知识结论或跨入语义阶段；这些仍由后续代理回合按证据审查完成。

只有`acquire_source`阶段可访问网页或下载媒体。其余阶段仅使用本地原片、帧、OCR、证据包和状态文件。没有人工阻塞时不得等待下一次定时任务；应继续执行`next_action`。若需要登录/解锁/释放精确标签页、视频身份冲突、关键歧义未消除、资源上限或本地故障，写入`blocked`并停止。恢复自动化只能作为低频保险：先读状态文件，若为空、已完成、已阻塞或已有活动运行则静默退出。

`source_verified`后的机械本地索引应优先交给`prepare_local_index.py`：它会在不联网、不调用模型的情况下完成原片复核、1 FPS基线、OCR、联系表、低流量工件和原子状态推进。它只能把视频推进到`baseline_indexed`，不能替代牌面语义审查、反事实或迁移盲测。

知识采集模式的证据审查与 `knowledge_note_complete` 必须显式提交；协调器绝不能根据文件“存在”自动判断视频已读懂。机制与验证模式的 `semantic_review`、`validation` 与 `summary` 同样必须显式提交。可跨模型回合保存真实阶段和未完成节点后恢复；若关键歧义不能消除，保持 `reviewing`，只有真实人工或外部阻塞才写 `blocked`。不得要求在同一回合硬凑完成，更不能把半成品声称为已应用。

单条视频已经通过理解门禁、但按本规程必须等待多来源训练/留出校准时，使用`defer-for-calibration`进入`awaiting_calibration`队列：它必须绑定严格绿色的理解阶段报告，只推进学习游标，不得写成`verified`或`complete`。积累到足够独立来源后统一校准，再用`resume-calibration`恢复该条并完成算法应用门禁。禁止用`blocked`伪装这种正常研究积累，也禁止让第一条待校准视频永久堵住后续来源。

AI 应用还包含独立的`algorithm_review`语义门禁：先把视频事实改写为通用决策问题，再审查生产代码没有视频专属动作序列或单局权重，并验证与本轮机制有关的完整状态花色迁移和前提变化；结构变体、结果隔离等按本轮风险选取，不以固定测试总数代替真实覆盖。事实/语义证据通过不代表算法门禁通过；旧报告只有组件路径和原局同动作时必须重新审计。

对新的`schema_version: 3`包，读取[低流量强制门禁](references/low-traffic-gates.md)。先运行`resolve_or_verify_source.py`；返回`reuse_local_source`时禁止下载。先生成1 FPS基线与OCR，再记录基线不足的具体歧义，才可补高FPS或精确帧。所有A级口播/字幕结论必须在`subtitle-evidence.json`中有原帧文字与牌面/动作的交叉确认。继续分析或恢复时只传递`evidence-context.json`，不得嵌入原片、图片、音频、联系表或临时媒体URL。

## 取证工具

- `scripts/download_douyin_video.py`：接受分享、`/video/`或搜索`modal_id`地址。公共无登录抓取不稳定时，通过已登录浏览器打开精确卡片、读取目标播放器`currentSrc`到权限为0600的临时文件，再用`--media-url-file`下载；不要导出Cookie。
- `scripts/resolve_or_verify_source.py`：在任何下载前检查本地ID、标题、时长和SHA-256；只有返回`acquire_source`才允许进入获取阶段。
- `scripts/build_low_traffic_artifacts.py`：初始化采样升级账本、生成本地OCR证据骨架、导出小于64KiB的证据引用上下文。
- `scripts/prepare_local_index.py`：无网络的确定性索引工作器；用于消除“下载已完成但模型回合结束，状态未推进”的断点。
- `scripts/extract_frames.py`：先以1 FPS生成全片基线；对关键节点用`--start/--end --fps 2`或`--timestamps`精确回看。
- `scripts/ocr_subtitles.swift`：使用本机Vision识别硬字幕，结果只是候选文本，必须回到原帧核对麻将牌和同音错字。
- `scripts/build_reviewed_bundle.py`：仅发布显式撰写的 reviewed_documents 哈希清单并备份旧文件；拒绝旧自动自证 spec，不合成通过结论、字幕原文或盲测答案，不更新库存。
- `scripts/run_bound_decisions.py`：针对本轮明确选定的局面编译并调用正式 C# 入口，绑定输入、节点、断言、源树和程序集；不生成固定回归清单。
- `scripts/learning_quality.py`：检查 v2 分层证据与逐节点实验绑定；该检查不证明人工理解正确。
- `scripts/validate_knowledge_note.py`：检查第一阶段逐条学习笔记的来源身份、证据引用、核心观点、候选取舍、改意条件、未知和能力挂接；它不证明算法正确或棋力提升。
- `scripts/validate_opportunity_scan.py`：把自然机会侦测逐批绑定到冻结计划，拒绝版本漂移、种子缺失/重复、结果窥视、错误触发范围和选择性漏报。
- `scripts/evaluate_paired_strength.py`：根据预先冻结的方案评估完整对局配对结果；内部启发式分数不可作为实战得分。
- `scripts/capability_registry.py`：校验/合并本轮选定能力档案，同源去重，保留反例与冲突，不静默覆盖机制。
- `scripts/evaluate_calibration.py`：重新计算独立留出数据的概率误差或净分误差，不能把启发式分数换个名字就叫校准收益。
- `scripts/evaluate_public_posterior_calibration.py`：对牌墙后验执行专用留出校准；强制多来源分组、模型/原片/公开输入/事后标签哈希、固定多种子、ESS 与种子波动门槛，并拒绝公开输入中出现暗手、未来摸牌或亮牌字段。
- `scripts/validate_learning_bundle.py`：检查视频ID、原片哈希/时长、帧与OCR清单、证据索引、决策节点、反事实、迁移牌例和知识卡状态。它只验证证据闭环，不替代人工判断牌面与推理是否正确。
- `scripts/reconcile_video_inventory.py`：审计库存中的重复ID/序号和所有`verified`条目；只有证据包存在、持久化报告为`ok=true`，且当前重新进行帧哈希验证成功时才保持`verified`。使用`--repair`时先刷新验证报告，再以临时文件和原子替换方式更新库存；幽灵完成项会降级为`needs_review`并保留原因。

## 学习要求

知识采集模式按视频可见内容记录关键公开事件，不要求在画面未提供足够信息时强行重建完整四家牌谱；核心结论必须绑定原片时间和证据帧。对每个老师实际讨论的关键节点，写出“观察 → 候选 → 取舍理由 → 选择”，并把隐藏手牌、未展示时序和牌墙留在 `unknowns`。机制与验证模式若要用某节点证明算法，才必须重建该节点所需的完整公开输入、合法动作和状态一致性。

知识采集阶段的每个核心结论必须包含：博主观点、为什么、使用了哪些公开信息、舍弃的候选、老师明确的改意条件、分析者待验证假设、适用边界和未知项。反例、新牌例迁移、正式状态变量、动作空间与目标项属于后续机制与验证阶段。关键证据不清楚就回拖重看；不得用标题、单句字幕或语音摘要补造牌面。

禁止把视频内的固定摸打、碰后弃牌、相邻牌顺序或具体牌名做成生产候选乘数、模式触发器或单局数值权重。公开视频顺序可以进入通用的公开事件后验模型，但模型必须对任意牌张和花色使用同一似然机制，并通过跨花色与破坏前提测试。若视频只验证已有通用算法，不要求制造新改动；应记录`validated_existing_algorithm`及真实覆盖证据。

知识采集阶段至少固化逐条学习笔记、证据定位和能力关系；只有实际观察到的信息才进入公开时间线。进入机制与验证阶段、创建或迁移正式证据包时，才按对应 schema 固化 `public-timeline.json`、`knowledge-units.json`、`semantic-review.json`、`analysis-plan.json`、`subtitle-evidence.json` 与 `evidence-context.json` 并执行相应门禁。旧版证据包可保持其历史证据状态，不得仅因旧验证器通过而改称“已吃透”。

一条视频未完成时保留具体阶段和未解决项。知识采集阶段使用 `knowledge_note_complete`，不用旧“已吃透”或 `verified`；语义理解、算法覆盖、棋力晋级是后续不同层次。只有进入机制与验证模式后，才按当前目标运行正式证据包验证：

```bash
python3 scripts/validate_learning_bundle.py /absolute/path/to/video-bundle --verify-frame-hashes --required-stage application
```

验证完成时必须同时使用`--report <bundle>/validation-report.json`持久化报告。对 `schema_version: 2`，验证报告还必须显示 `semantic_mastery=true`；对`schema_version: 3`，还必须显示`low_traffic_gate=true`。任一关键歧义、盲测失败、未交叉验证字幕结论或仅有结果倒推时，语义门禁必须为`false`。更新总库存后必须运行库存协调器；不得只改`learning_status`文字：

```bash
python3 scripts/reconcile_video_inventory.py /absolute/path/to/video-inventory.json \
  --validator /absolute/path/to/scripts/validate_learning_bundle.py
```

机制与验证模式中，验证器通过也不等于观点正确。`--required-stage` 可选 evidence、understanding、application（默认）、strength；应用阶段要求每个节点具备无透视输入、通用算法合同、反例、冲突审查和真实 C# 证据，仅证据或理解阶段的通过不得推进算法完成。v2 核心门禁为 `expert_learning_gate`，机器检查与人工判断同时满足才可作相应层级的结论。知识采集模式不运行该应用门禁。单视频不得产生数值权重；候选过测不等于棋力提升。skill 自身测试使用明确标注的隔离合成数据，不冒充视频学习或真人专家验收。
