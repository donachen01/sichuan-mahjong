# 单视频 AI 应用门禁

新包由[专家学习 v2 合同](expert-learning-v2.md)验收。以下 legacy `ai-application-report.json` 字段用于读历史，不要求新包制造旧 completion_status。新包的核心观点、逐节点算法链、失败基线、候选、机制实验、泛化和能力档案集中在 learning-quality.json；主验证器按 revision 路由，默认要求 application，不要求基线成功或棋力先晋级。

一条视频只有在“证据吃透”“算法抽象”和“正确进入四川麻将 AI”都完成后才能关闭。先读取[决策算法抽象与反过拟合门禁](decision-algorithm-abstraction-gate.md)。应用不是把博主口播或本局动作顺序复制成固定权重，也不是用结果亮牌给 AI 透视。

图像、牌面和字幕识别只是证据阶段。AI 应用的首要验收是：潇老师的核心观点已被转成可计算的公开状态、候选比较和翻转条件，并且真实 C# runtime 证明它实际影响决策。仅有文字摘要、组件路径或原局同动作断言不合格。

## 必需产物：`ai-application-report.json`

报告必须包含：

- `video_id`、`source_sha256`、全部 `decision_node_ids` 与知识单元 ID；
- `core_thesis`：带触发条件、优化目标、模式切换和翻转条件的本片核心观点；
- `thesis_to_algorithm_trace`：逐核心观点绑定证据窗口、公开输入、派生状态、候选动作、目标/约束、切换/翻转条件、正式组件与 runtime 测试；
- `visibility_contract`：明确只能读取的公开状态，并将 `uses_hidden_information` 固定为 `false`；
- `abstraction_contract`：通用算法问题、状态变量、动作空间、目标项、不变量，并确认运行时没有视频特定字面量；
- `node_mappings`：逐节点说明原则如何映射到算法输入、输出与正式组件；
- `implementation`：`implemented_new_algorithm`、`extended_shared_algorithm`或`validated_existing_algorithm`，以及正式组件、可观察行为和边界；
- `anti_overfit_review`：确认没有视频 ID、固定摸打序列、具体牌名乘数、结果泄漏或单视频数值权重；
- `generalization_evidence`：花色置换、结构变体、破坏前提、结果不变性四类测试全部通过；
- `calibration`：单视频数值权重固定为 false；如有参数变更必须给出多来源训练/留出证据；
- `conflict_review`：与四川规则、已验证视频、经验权重的冲突已消解；未消解不得完成；
- `test_evidence`：至少一项聚焦规则/算法测试和一项真实 C# runtime 测试，均须通过并引用本地证据；
- `completion_status: "algorithmically_implemented_and_verified"`。

报告使用`schema_version: 2`。每个决策节点都要有唯一映射；如果某一节点无法在无透视、规则正确、可泛化、可测试的前提下实现，视频保持待复核，而不是用模糊权重、组件路径或注释绕过。

## 应用原则

1. 公开视频只产生可解释的观察特征、候选集合约束或决策比较，不可读取其他玩家暗手、牌墙顺序或结局亮牌。
2. 视频中的定性顺序、条件分支和反转条件可以实现；任何百分比、阈值或收益权重必须来自独立仿真/牌谱校准，不得由单条视频编造。
3. 每次合入前先审计现有未提交 AI 实验改动，保留其基线、来源和测试结论；不可把旧实验误归因于本视频。
4. 一条视频的实现必须有可定位的代码与测试证据。跨视频的冲突矩阵仍是后续综合门禁，不被单视频实现替代。
5. 视频事实可以保留完整有序事件，但生产特征必须是通用状态估计或动作似然，不得识别本局的固定牌序后直接调整具体候选。
6. 已有算法若已正确覆盖节点，应验证并复用；禁止为了让每条视频看起来“有代码改动”而增加规则。
