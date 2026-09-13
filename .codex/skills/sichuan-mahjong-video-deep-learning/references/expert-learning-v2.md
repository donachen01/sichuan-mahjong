# 专家技巧到 AI 能力：v2 修复合同

本合同优先于旧参考文档中“自动生成已吃透”“必须在一个模型回合内完成”“验证未通过不得修改任何 AI”等规定。它不创建日后默认执行的固定回归清单；每轮仅按实际改动和风险选实验。

## 目标与阶段

目标是增强游戏决策能力，不是增加视频完成数。每条视频允许推进到以下阶段，必须报告停在哪层：

| 阶段 | 可声称什么 | 不可声称什么 |
| --- | --- | --- |
| knowledge_note_complete | 已证据化读懂本条，记录核心观点、候选取舍、改意条件、未知与能力关系 | 技巧已经独立验证、算法已覆盖或 AI 已变强 |
| evidence_verified | 原片与分层事实可复核 | 已理解或已改 AI |
| technique_understood | 能解释候选、条件、反例，完成冻结预测后的迁移复核 | 算法已覆盖 |
| validated_existing_algorithm | 正式入口已覆盖该技巧，无新增改造 | 本次使 AI 变强 |
| candidate_implemented | 候选算法已实现，节点与因果实验可重放 | 可晋级、棋力已提高 |
| strength_improvement_verified | 预先定义的留出对局与风险门槛通过 | 已达到老师全部水平 |

当用户选择先完成全库知识采集时，`knowledge_note_complete` 是本阶段合法终点，不得强迫继续算法验证。候选实现可以在用户进入机制与验证阶段、且证据可靠后开始；缺少验证时不得升级正式策略或写“棋力提升”。不确定视频可保存阶段和缺口后恢复，不得用生成文字填成通过。用户的逐条学习顺序不变，不能借修流程跳过未完成视频。

## 八项硬约束

1. **独立复核，不自动自证。** 生成器只发布显式撰写、哈希绑定的文件，不生成语义判断、盲测答案、字幕原文或 passed=true。盲测先冻结新局面、预测与理由，再揭示参考答案，记录两份不可覆盖文件及关联哈希。已经看过的答案只能叫回放，不能叫盲测。时间戳和哈希只检查记录一致性，无法证明代理没有偷看；如需更强保证，应由用户或隔离的出题进程保管答案。
2. **每节点绑定真实测试。** 引用必须绑定输入哈希、测试 ID、决策节点、正式 C# 入口、期望与观察值、最终动作断言、实际执行程序集和源代码版本。旧测试可补充机制证据，不能替代新节点覆盖。有限分数、文件存在、总通过数都不足以证明学会。基线不符合老师时保留失败，不更改老师标签迎合 AI。
3. **四层证据分开。** 每条 claim 只能是 observed_fact、teacher_statement、analyst_inference、algorithm_hypothesis 之一。混合句拆开；推断链接前提；引用是准确字幕/口播而非总结。重放局面校验手牌数、每牌最多四张、碰杠前后、副露、定缺、座位、合法动作。未知墙长/公开事件不填成实战事实：标 unknowns 并用明确合成情境做敏感性分析。
4. **先基线，再改造。** 冻结当前代码、规则、程序集与局面，先跑 AI。差异分类为 already_supported、source_error、rules、features、belief、search、teacher_uncertain。根据差异决定是否改代码；不得每条视频强行加规则。baseline/candidate 目录不得复用覆盖。
5. **证明机制实际起作用。** 记录候选分数、最终动作、特征/机制解释；选择与本改动有关的消融或敏感性对照，保持无关因素一致。分数变化不一定导致动作翻转，二者分别报告。启发式分数必须叫 heuristic_score；没有独立校准，禁止称为净收益期望或真实概率。因果对照若同时改了多个因素，不可归因于一个机制。
6. **跨视频能力档案。** 以 capability_id 归并技巧，记录统一机制、适用边界、支持来源、相反来源、失败牌例、代码组件和 next_gap。同源重复视频不增加独立证据数。冲突先检查规则/局面/巡数/对手差异，不能最后一条视频覆盖前面结论。每轮只维护本轮涉及能力，不能扩张成默认全量测试清单。
7. **策略晋级单独评估。** 按原始牌局/视频组切分训练与留出，不能按帧。冻结基线、候选、规则、对手、种子、四座轮换、最低独立样本、净得分指标和风险/延迟阈值，再运行完整结算对局。现有内部 oracle/regret league 只能叫代理决策指标，不能代替实战。评估器重新计算差值与按原始牌局聚类的置信区间，拒绝缺配对、重复、泄漏、换版本或未完成数据。未达门槛的候选保留实验结果，不晋级。
8. **正确的泛化与校准。** 花色置换要同时变换手牌、定缺、公开牌、事件及动作；任意点数置换不是对称（边张/中张不同），只能作为结构变体并重算答案。对每次改动选前提破坏、结果隔离或结构对照。未来摸牌/对手暗手绝不进入状态。参数只能用多来源训练集估计并在留出集校准，记录样本、单位、误差、区间和来源；单视频不得提供固定概率/权重。

## 学的是专家如何决定，不是再多填一份表

对每个技巧，先把老师的核心问题用一句话讲清，再回答：他关注了什么、忽略了什么、舍弃哪个候选、依据是确定规则还是不确定判断、什么变化会让他改主意。没有回答这些问题，即使取证工件齐全，也没有完成技巧理解。

依次区分三种可迁移内容，避免“一条视频一个 if”：

- **规则计算**：合法动作、向听、听口、公开副本、计分。可确定计算的部分交给正式引擎，不能由老师口述常数替代。
- **局面判断**：对手需求、竞争、危险、进攻/防守阈值。形成有置信范围的候选解释，禁止把“可能有”写成“确定有”。需要更多证据时记录缺口。
- **决策组织**：先检查哪些条件、枚举哪些后继、何时放弃大牌、何时用确定收益换速度。优先完善共享特征、后继搜索和收益比较，不复制最后一张弃牌。

每次转化应交付一个最小可解释差异：“此前 AI 因缺少 X 在局面 Y 错选 A；加入通用机制 X 后选 B；在反例 Z 中不会机械选 B”。如果现有 AI 已会，明确说“补强证据/补充边界”，不制造新改动。对老师没有解释的动作，可提出待验证假设，但不能署名为老师观点。

采用**失败驱动的课程**：同类误判反复出现时回看相关视频并合并能力，而不是靠视频数量衡量进步。可以维护轻量能力档案，但不为每一帧建卡，不把执行精力全部耗在格式和盖章上。新机制与旧机制冲突时，先检查双方前提再试验，不用最新结论覆盖旧结论。

## 文件与工具

`learning-quality.json` 使用 revision=expert_learning_v2，source_sha256、stage、claims、nodes。claims 的 id/text 必须对应 evidence-index 的 id/claim；每条有 layer、unknowns；原始事实有 evidence（path/sha256/timestamp），推理有 depends_on。

每个 node 有 id；理解阶段要求 review、blind_prediction、blind_reveal 三个哈希引用（统一格式 `{ "path": "bundle-relative.json", "sha256": "..." }）。review 包含 decision_node_id、reconstruction、alternatives、counterexample、reversal_condition、teacher_limitations、unresolved_critical_ambiguities。预测含 decision_node_id、prediction、answer_exposed=false、frozen_at；揭示含 prediction_sha256、revealed_at、assessment、comparison。时间统一 ISO UTC，不能追填“先前已经盲测”。

应用阶段 node 增加 capability_id、discrepancy_class/reason、baseline、candidate、mechanism、transfers。runtime 绑定为 report/fixture 两个哈希引用及 case_id。fixture.decision_cases 中每例有 decision_node_id、visibility=public_only、grounding、unknowns、rule_variant、assertions；grounding 为 verified_reconstruction 或 synthetic_transfer。不完整公开状态一律 synthetic_transfer。断言带 id、kind、operator、expected，执行报告增加 observed/passed。只支持 runner 明确实现的动作和规则，不通过填布尔值扩展支持范围。

理解阶段 core_thesis 含 teacher_teaches、why_not_alternatives、algorithmic_problem、uncertainty_and_limits。应用阶段每节点还需 algorithm 对象：public_inputs、derived_state、candidate_actions、objective_terms、components 为非空列表，update_rule、reversal_condition、visibility_review、no_video_special_case_review 为实际推理与审查文字。components 必须存在于候选执行时 source_files 快照，不能只写当前代码路径。**失败基线允许入档**：保留真实 observed/passed，候选复用同一局面和同一期望断言；基线失败不是 skill 失败，错误地篡改基线或验收目标才是。只有 validated_existing_algorithm 要求基线已通过。

能力档案 schema_version=1，capabilities 每项包含 id、mechanism、boundaries、code_components、evidence、contradictions、failure_cases、next_gap。evidence 项含 source_group_id、video_id、node_id、basis。contradictions/failure_cases 项含 id、description、evidence_ref；冲突还含 status=unresolved/resolved，解决后有 resolution。没有冲突可写空列表，但机制、支持来源、边界和代码不许空。合并工具只输出待审 JSON，不直接覆盖正式档案。

mechanism 文件包含 decision_node_id、kind=ablation/sensitivity、scale、interpretation、control/treatment 运行绑定。sensitivity 显式列 changed_fields；ablation 保持输入相同并说明 disabled_mechanism。校准后期望值还需 calibration 引用。transfers 每条包含 kind、expected_relation 与运行绑定；花色置换提供 suit_permutation（spm 索引），关系为 equivalent_action；前提/结构试验列 changed_fields，关系为 action_changes、scores_change 或 same_action_rescored；结果隔离关系为 identical_policy。验证器检查实际输入差异与输出关系，不能只填写一行测试名称。注册表通过 capability_registry 哈希引用固定本次能力版本，不随全局后续变化重写历史证据。

当前 runner 已接入严格的公开检查点窗口重放，但仍没有完整视频重建或所有动作适配。格式与真实游戏输入隔离要求见 [真实执行闭环](executable-loop.md)。出现它不支持的状态，必须保留缺口或实现对应适配，不得删除关键公开条件把真实局面伪装成已重放。任何升级应继续用聚焦合法性/输入隔离测试验证。

- `run_bound_decisions.py PROJECT BUNDLE FIXTURE --run-id NAME`：编译正式 C# 依赖，在独占新目录保存输入、源树/规则/程序集哈希、构建日志、可重放的 runtime 二进制快照和运行结果；源码或二进制执行中变动即拒绝。断言失败仍保存真实报告并返回非零，可作为失败基线。当前局面 runner 仅支持弃牌及非胡牌碰/杠/过，其他动作必须另做真实入口适配，不能伪造支持。
- `learning_quality.py BUNDLE`：检查阶段、分层、节点绑定、断言实际真假与来源哈希；不替代人工语义判断。
- `build_reviewed_bundle.py`：仅发布完整 reviewed_documents 哈希清单，旧自动自证 spec 被拒绝。每个替换文件保存在 pre-review-* 快照，发布后仍必须验证。
- `validate_learning_bundle.py`：原有取证检查加 v2 门禁。缺新证据的旧包需复审，历史报告不得被解释为当前通过。
- `capability_registry.py REGISTRY [--merge INCOMING]`：显式合并本轮涉及能力，冲突不能静默消失；同一原始牌局多个视频只算一个独立来源。
- `evaluate_calibration.py PLAN SAMPLES`：PLAN 含 target=probability/net_score、model_version、training_groups、heldout_groups、min_heldout_groups、max_error、frozen_at；SAMPLES 含 plan_sha256、started_at、rows，行含 id/group_id/model_version/prediction/observed。按独立组计算 Brier 或 MAE，错误、单来源或泄漏数据不能晋级。calibrated_expected_score 的 calibration 引用须含 plan/samples 两个哈希引用，且版本属于本候选；单纯填写“已校准”无效。
- `evaluate_paired_strength.py PLAN RUNS`：仅计算提供的真实完整对局结果，不会替你生成对局。plan_hash 用脚本函数按排序紧凑 JSON 计算。PLAN 必须在实验前冻结；RUNS 必须有同哈希并提供每个 group/seed/seat 的两臂完整结算、版本、墙哈希、回放哈希、净分、点炮率、延迟、completed 和 uses_hidden_information。正式晋级还需人工确认回放来源确为真实引擎，字段校验不是真实性证明。

PLAN 还含 frozen_at，RUNS 含 started_at；先冻结再测量，候选/基线的版本必须与节点绑定的程序集一致。相同墙序不得改 group_id 冒充独立样本。最小样本量和阈值按实际实验目标预先决定，脚本结构下限不是推荐的棋力评估规模；两局通过数学检查也不能称达到高手水平。

## 后续学习的优先级建议

在继续增加视频数前，优先闭环一个能力：真实节点 → 基线错误 → 原因 → 共享机制改造 → 有效反例 → 留出测量。用失败案例驱动回看相关视频；对重复观点归并补证，对未知的公开信息建立显式置信区间。参数训练、对手模型、搜索深度、端侧延迟分开实验，不能把多个改造揉成一个提升结论。
