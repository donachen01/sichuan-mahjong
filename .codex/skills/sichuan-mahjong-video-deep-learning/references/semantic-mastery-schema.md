# 语义吃透协议（schema v2）

本页保留旧证据结构与人工复核方法。新学习使用[专家学习 v2 合同](expert-learning-v2.md)的阶段与显式预测/揭示文件；旧布尔字段不能代替真实复核，也不能被生成器自动填为 true。

## 目标与状态

`evidence_verified` 只表示原片、帧、索引与旧版机械门禁完整。`semantically_mastered` 才表示可以在不读取结论的情况下复原博主当时看到的公开局面、比较候选行牌并将原理迁移到新牌例。证据不足必须保持 `reviewing`，不得由结果、字幕摘录或验证器通过升级。

## 强制产物

### public-timeline.json

每个公开事件必须有 `id`、`start_seconds`、`end_seconds`、`actor_seat`、`event_type`、`public_facts`、`unknowns`、`evidence`。`public_facts` 只能写当时可见的弃牌/副露/定缺/已胡/牌墙/动作；暗手只能放在 `unknowns` 的候选范围中，并写支持与反证。

### knowledge-units.json

每个最小知识单元必须绑定至少一个决策节点，且包含：

- `trigger_conditions`：可观测触发条件；
- `candidate_actions`：至少两项候选；
- `decision_principle`：为什么比较、为什么选择；
- `daily_play_rule`：日常行牌时可执行的条件规则；
- `exclusions` 与 `reversal_conditions`：不适用或应翻转的情形；
- `probability_semantics`：对象、条件、可量化与不可量化部分；
- `algorithm_abstraction`：通用问题、状态变量、动作空间、目标项、不变量和翻转条件；
- `evidence_grades` 与 `decision_node_ids`：来源和可追溯性。

不得把“牌少”“高手这样打”“最终胡了”写成原则，也不得把本局固定摸打顺序写成算法。没有公开牌墙/隐藏状态样本时，只能写相对变化，不得虚构百分比。

### semantic-review.json

未读过答案的新迁移局面先冻结选择和理由，再揭示参考答案并记录比较。已经看过结论的原视频只能叫复核，不能因“把文字隐藏”就改叫盲测。旧记录中的 `reconstruction_passed`、`candidate_comparison_passed`、`counterfactual_passed`、`transfer_blind_test_passed` 仅保留为历史判断，v2 使用哈希绑定的原始重建、预测、揭示和复核记录验收。

迁移盲测至少包含：一个保持原前提的相似牌例，和一个破坏原前提、结论应减弱或翻转的牌例。先写独立选择与理由，再与知识单元对照；不能反向抄结论。

## 语义审查问题

1. 不看结论，是否能从关键帧与公开时间线复原当时已知信息？
2. 是否至少比较两个候选动作，并说明每个被排除动作在何种条件下反而成立？
3. 是否严格分开博主原话、画面事实、规则推导、策略解释与事后结果？
4. 新牌例中的选择是否由触发条件推出，而非复述原视频动作？
5. 所有概率是否说明事件、条件、未知空间与不可校准之处？
6. 完整状态花色置换是否保持同构？改变点数后是否重新检查边张/中张及邻接结构，而非误用“点数任意置换”的不变量？
7. 是否明确哪些视频事实不得成为生产特征或单局权重？

任意问题不能肯定回答，即不可标记 `semantically_mastered`。
