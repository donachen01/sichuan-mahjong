# 单视频证据包结构

每条视频以抖音`modal_id`或视频ID作为目录名：

```text
<video-id>/
├── source.mp4
├── metadata.json
├── knowledge-card.md
├── evidence-index.json
├── validation-report.json
├── ai-application-report.json      # AI应用时：schema v2算法抽象与反过拟合门禁
├── source-verification.json         # schema v3：本地媒体可复用证明
├── analysis-plan.json              # schema v3：基线与有理由的补采样
├── subtitle-evidence.json          # schema v3：字幕/画面交叉证据
├── evidence-context.json           # schema v3：小型引用包，不含媒体
└── artifacts/
    ├── baseline_1fps/
    │   ├── frames.json
    │   ├── ocr.json
    │   └── frame_*.jpg
    ├── keyframe_verification/
    │   ├── frames.json
    │   ├── ocr.json
    │   └── frame_*.jpg
    └── contact_sheets/
        └── sheet_*.jpg
```

## metadata.json

至少保存：`aweme_id`、原始URL、规范URL、标题、作者、页面发布标签、原片文件名、字节数、SHA-256、时长、视频尺寸/编码和音频编码。不要保存Cookie、登录Token、临时媒体URL或浏览器资料。

页面发布标签、视频画面叠加日期和下载日期是不同字段；它们冲突时保留各自来源。

## evidence-index.json

顶层字段：

- `schema_version`：当前低流量严格流程为`3`；旧版`1/2`仅保留兼容。
- `video_id`、`source_sha256`、`status`。
- `claims`：核心结论。每项包含唯一`id`、`start_seconds`、`end_seconds`、`grade`、`claim`、`evidence`和`reasoning_role`。
- `decision_nodes`：关键张或动作选择。每项包含问题、候选、选择、结果、推理链和关联结论ID。
- `counterfactuals`：至少覆盖出牌顺序、可见张/剩余张、我方收益或局势三类变化。
- `transfer_tests`：至少一个相似迁移牌例和一个破坏前提牌例。

`evidence[].file`必须是证据包内相对路径，`timestamp`必须落在原片范围内，并与相应`frames.json`记录一致。证据等级只能使用A/B/C/D；组合证据写成`A+B`。状态为`verified`时，不允许D级结论进入`ai_mapping_claims`。

## schema v3 低流量工件

- `analysis-plan.json`：必须确认完整1 FPS基线；每项高密度/精确补采样绑定决策节点、基线不足原因、范围、证据和解决结果。
- `source-verification.json`：由`resolve_or_verify_source.py`产生，必须证明当前原片的ID、时长、SHA-256可复用；没有该证明不允许把已有文件直接当成可信原片。
- `subtitle-evidence.json`：每个A级结论必须绑定经人工复核的OCR文字帧和视觉帧，状态为`cross_verified`。
- `evidence-context.json`：仅保存结构化引用，必须小于64KiB；不得包含媒体内容、临时URL或认证数据。

## 完成判定

`validation-report.json`必须由当前版本验证器使用`--verify-frame-hashes --report`生成并持久化；其中`ok=true`只代表机械完整性。库存中的`verified`还必须通过`reconcile_video_inventory.py`复核，不能手工改状态绕过。最终“已吃透”仍必须由学习者完成人工语义自检：牌面正确、动作顺序正确、候选结构充分、原话与重构分离、概率边界正确、反事实和迁移成立。若用于正式 AI，`ai-application-report.json`必须为 schema v2，并额外通过算法抽象、反过拟合、四类泛化与真实 C# runtime 门禁；旧 schema v1 只能作为历史记录，不能维持 AI 应用完成状态。
