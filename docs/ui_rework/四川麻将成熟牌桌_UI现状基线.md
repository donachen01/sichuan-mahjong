# 四川麻将成熟牌桌 UI 现状基线

## 基线时间

- 日期：2026-07-14
- 唯一可写工程：`/Volumes/AI/Codex/四川麻将工程_20260701_v2`
- 改造前备份：`/Volumes/AI/Codex/备份/四川麻将工程_20260701_v2_UI改造前_20260714`

## 事实来源

当前源码、场景、测试和打包脚本是实施事实来源。`docs/ui_baseline/` 下仍含内江麻将名称、旧版本号和“完成度 100%”结论，只能作为历史视觉参考，不能作为四川麻将新版当前验收结论。

## 当前结构

- `scenes/table/MainSceneV2.tscn`：主牌桌节点树。
- `scripts/game/MainSceneV2.gd`：同时承担状态分发、安全区、四家布局、弃牌层、动作栏、结算层、AI 抽屉和样式，职责过载。
- `scripts/ui/PlayerUI.gd`：承担牌墙、副露、弃牌、身份牌、庄家和定缺样式，与主场景存在重复表现职责。
- `scripts/ui/HandCanvas2D.gd`：自家大牌和点击区域。
- `scripts/ui/TableMaterialOverlay.gd`：连续桌布绘制。
- `scripts/ui/WallCountDisc.gd`：中心余牌圆盘。

## 用户截图问题

1. iPhone 超宽横屏存在左右黑边，右上控件靠近裁切区域。
2. 四家身份 HUD 位置、尺寸和信息层级不统一。
3. 其他家定缺徽章与本家不统一，移动端可读性不足。
4. 对局中“下一局”仍占位，AI、退出等工具控件风格割裂。
5. 左右和顶部牌墙与桌布明度接近，像透明细条，缺少实体感。
6. 中心圆盘只有数字和方位，缺少“余牌”和当前行动语义。
7. 本家 HUD、定缺徽章、手牌和动作栏没有形成稳定的一体布局。
8. 定缺、AI 辅助和结算浮层仍带明显工具面板感。

## 改造前测试证据

- `SichuanUiSixIssuesRunner.gd`：`VERIFY SIX ISSUES OK: 7/7`
- `SichuanIosFontRegressionRunner.gd`：`SICHUAN IOS FONT REGRESSION OK`
- `SichuanTileAssetRegressionRunner.gd`：`SICHUAN TILE ASSET REGRESSION OK`

日志目录：`evidence/ui_rework_20260714/baseline/`

## 已知基线告警

- `SichuanUiSixIssuesRunner.gd` 退出时有 CanvasItem、ObjectDB 和 Resource 泄漏告警。
- `SichuanIosFontRegressionRunner.gd` 退出时有 CanvasItem、字体 RID、ObjectDB 和 Resource 泄漏告警。
- 这些告警不影响三项功能断言的基线结论，但最终验收前应通过显式释放场景和等待 frame 清理。

## 结论边界

当前证据证明桌面 headless 下的定缺、庄家出牌、AI 跟牌、中文字体和万字牌资源合同通过。它不证明 iPhone 超宽屏无黑边，不证明真机所有触控流程，也不证明当前 UI 已达到成熟 App 视觉标准。
