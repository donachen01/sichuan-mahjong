# 低流量强制门禁（schema v3）

这不是降低取证标准，而是限制只有信息增益的媒体读取与上下文传递。

## 1. 先复用，后获取

每次进入`acquire_source`前运行：

```bash
python3 scripts/resolve_or_verify_source.py <bundle> --video-id <id> --expected-title <title>
```

返回`reuse_local_source`时，原片、元数据、SHA-256和时长已闭环；禁止下载。返回`acquire_source`时才可访问网页，并且下载后必须重新运行该命令通过。

## 2. 采样升级必须可解释

先生成完整1 FPS基线、OCR和联系表，再创建`analysis-plan.json`：

```bash
python3 scripts/build_low_traffic_artifacts.py init-plan <bundle>
```

每一次高FPS或精确时间戳补采样都要绑定决策节点，并记录：基线具体缺什么、为什么影响候选动作、补采样的时间范围/FPS、引用帧和补采样后解决了什么。没有该记录不得生成高密度帧。

每条`sampling_escalations`记录必须含`id`、`decision_node_ids`、`trigger`、`baseline_insufficiency`、`sampling`、`resolution`和`evidence`。精确抽帧使用`mode: exact_timestamps`，并同时写`timestamps`、`start_seconds`和`end_seconds`。`resolution`必须说明已消除什么歧义，不能写`pending`。

## 3. 字幕结论必须回到画面

```bash
python3 scripts/build_low_traffic_artifacts.py subtitle-skeleton <bundle>
```

在`subtitle-evidence.json`中把每个A级结论链接到至少一个经人工复核的OCR字幕帧和一个牌面/动作帧。OCR只是候选文字；它与画面冲突或不清楚时，结论降级或回到补采样，不能由字幕单独成立。

## 4. 恢复上下文只含引用

```bash
python3 scripts/build_low_traffic_artifacts.py export-context <bundle>
```

`evidence-context.json`仅含ID、哈希、时间范围、结论、证据相对路径和时间戳，大小不得超过64KiB。禁止嵌入图像、音频、原片、联系表、Cookie和临时CDN URL。

## 5. 验证

`schema_version: 3`包必须同时通过：原片/帧哈希、语义门禁和`low_traffic_gate=true`。任何未解决歧义、未说明的高密度采样、缺少字幕—画面交叉验证或超大的上下文包，均不可标记`semantic_mastery=true`。
