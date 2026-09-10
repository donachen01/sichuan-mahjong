# 连续学习状态机（低流量恢复）

## 目标

在一次被唤醒的运行中，按本轮选择的模式把一条视频推进到对应终点，再自动领取下一条；不靠高频 heartbeat 推进阶段。状态文件是唯一恢复入口，读取量应保持在几KB级别。

## 状态与动作

`learning-run-state.json` 由 `scripts/learning_state.py` 原子更新。活动视频只能有一条。知识采集模式的概念流程为：

```text
screening -> source_verified -> baseline_indexed -> evidence_review
-> knowledge_note_complete -> 领取下一条
```

其中 `knowledge_note_complete` 只关闭本次知识笔记，不更新为算法 `verified`，也不要求进入校准队列。状态工具必须调用独立的学习笔记检查器后才能进入该终点；不得借用 `complete` 或 `awaiting_calibration` 冒充。

机制与验证模式按以下方向推进：

```text
screening -> acquire_source -> source_verified -> baseline_indexed
-> decision_windows_verified -> semantic_review -> validation -> summary -> complete
```

- `screening`：根据标题、原片与规则范围确定是否相关；不相关必须原子写入`excluded`，记录排除理由并结束该条，不能硬学，也不能计入`verified`或“已完成学习”。
- `acquire_source`：唯一允许浏览器/下载的阶段。先复用同ID且SHA-256核验过的本地原片；没有才取媒体。
- `source_verified`：ID、标题、时长、原片哈希一致。
- `baseline_indexed`：从00:00到结束的1 FPS基线、OCR和联系表完整。
- `decision_windows_verified`：所有关键决策窗口已精确抽帧并可重放。
- `semantic_review`：在机制与验证模式生成公开时间线、知识单元、独立重建、反事实和迁移盲测；知识采集模式不强制这些实验。
- `validation`：运行带帧哈希的验证器并持久化报告；v2必须得到`semantic_mastery=true`。
- `summary`：更新知识卡和库存；库存更新后运行协调器。
- `complete`：本条已关闭，可立即领取下一条。
- `awaiting_calibration`（队列状态，不是完成阶段）：语义理解已严格验证，但单片不能提供数值权重，等待至少两个训练组与两个互斥留出组；允许推进游标继续积累来源，库存不得标记`verified`。
- `excluded`：证据化确认没有可抽象、可反证的决策内容；库存写`screening_status=not_relevant`、`learning_status=excluded`，不计入学习完成，然后领取下一条。

`blocked` 只用于真实人工或外部阻塞，必须含简短、可行动的原因。证据不足不是“完成”，应停在对应阶段或标记`reviewing`。

若证据足够完成语义理解、缺的只是本规程要求的多来源校准，不应把它叫外部阻塞。必须在`summary`阶段运行`defer-for-calibration`，由脚本复核理解阶段报告后原子写入`calibration_queue`与库存`awaiting_calibration`。后续来源达到冻结计划要求并完成机制验证时，以`resume-calibration --video-id ...`恢复；恢复后仍须通过应用级验证器才能`complete`。

Skill 的算法门禁升级后，历史包进入定向复核：事实/语义工件哈希有效时直接复用，但旧 AI 应用状态不继承。应按明确序号逐条运行新版算法审计，不能因原验证报告为绿色而跳过，也不能批量改 schema 字段冒充完成。

## 低流量规则

1. 以`video_id + source_sha256`作为媒体复用键；已有相同原片时，禁止重新访问网页或下载。
2. 1 FPS帧、OCR、接触表都在本地生成和保存；深度视觉复核只读取关键决策窗口或歧义点。
3. 状态文件只记录阶段、下一个动作、人工阻塞与短日志；不要嵌入字幕、帧数据、URL签名或长对话。
4. 每阶段转换前检查目标工件是否已存在且可验证；存在则跳过而非重做。
5. 单次运行受资源或运行时上限打断时写状态；下一次从`next_action`恢复。正常情况下，完成一条后立即领取下一条。

## 确定性本地工作器

媒体下载可能在代理回合结束后才退出。不能把“`source.mp4`已写入”当成状态已推进，也不能等待下一次模型回合才做机械收口。下载成功后运行：

```bash
python3 scripts/advance_local_artifacts.py <bundle> \
  --state research/xiaolaoshi_deep_learning/learning-run-state.json \
  --video-id <id> --expected-title '<title>' \
  --skill-root .codex/skills/sichuan-mahjong-video-deep-learning
```

该工作器只做无需策略判断的本地工件：运行来源核验、从00:00抽取1 FPS、OCR、联系表、采样账本，并以`learning_state.py`原子推进至`baseline_indexed`。任何决策窗口、牌面语义、反事实、盲测迁移或库存`verified`更新均不属于它；工作器结束后由下一次代理回合继续，避免把机械完成误报为“已吃透”。

## 使用

```bash
STATE=research/xiaolaoshi_deep_learning/learning-run-state.json
INVENTORY=research/xiaolaoshi_deep_learning/video-inventory.json
python3 scripts/learning_state.py status --state "$STATE"
python3 scripts/learning_state.py set-mode --state "$STATE" --mode knowledge_acquisition
python3 scripts/learning_state.py claim-next --state "$STATE" --inventory "$INVENTORY" --after-order 50 --mode knowledge_acquisition
python3 scripts/learning_state.py transition --state "$STATE" --stage source_verified --note "ID、标题、时长和SHA-256一致"
python3 scripts/learning_state.py transition --state "$STATE" --stage evidence_review --note "开始证据化撰写逐条学习笔记"
python3 scripts/learning_state.py transition --state "$STATE" --stage knowledge_note_complete \
  --note "知识笔记人工审查完成" --inventory "$INVENTORY" \
  --note-validator scripts/validate_knowledge_note.py
python3 scripts/learning_state.py block --state "$STATE" --reason "需要用户在精确抖音标签页完成登录"
python3 scripts/learning_state.py defer-for-calibration --state "$STATE" --inventory "$INVENTORY" --reason "等待多来源训练/互斥留出组"
python3 scripts/learning_state.py resume-calibration --state "$STATE" --video-id <id>
```

`claim-next`只领取`learning_status=not_started`且筛选状态为`pending`或`relevant`的条目；`needs_review`项不能被自动重试，避免把库存异常或身份不明的视频静默混入队列。它不改变库存中的`learning_status`。只有验证器、持久化报告和库存协调器都通过后，才由学习流程更新库存。

知识采集模式下，`knowledge_note_complete` 会把库存的 `learning_status` 与 `knowledge_status` 写为 `knowledge_note_complete`，保存学习笔记路径和 SHA-256，并显式保留 `algorithm_status=not_started`、`strength_status=not_started`。它不运行正式算法验证器，也不写 `verified`。`validate_knowledge_note.py` 只检查笔记结构、来源身份、证据引用和阶段边界，不证明麻将观点或算法正确。

## 已有证据包的定向复核

当库存诚信审计把已有原片和工件的条目降为`needs_review`时，不应重新下载、丢弃，也不能让它们被普通新视频队列永久跳过。用户明确要求复核时，先用`claim-review --order <序号>`按指定顺序领取；它从`screening`重做来源身份与规则范围核对，再复用本地媒体和工件。只有缺失或哈希不一致时才重新进入`acquire_source`。

如果一个新视频已经在处理中，先运行` suspend-for-review`保存完整活动断点；旧批次完成后运行`resume-suspended`恢复。一次只能有一个活动视频，暂停不等于完成或阻塞，也不会清除已抽帧和已写入的本地证据。

首次接管已有库存时用`--after-order`显式设置断点；其后每条到达`complete`时，状态机会把该序号写为`cursor_order`，下一次只领取更旧的条目，绝不回到队首重复扫描。
