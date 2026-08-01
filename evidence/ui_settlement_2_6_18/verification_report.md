# 2.6.18 定缺、实体牌与结算页修复验证

日期：2026-08-01
工程：`/Volumes/AI/Codex/四川麻将工程_20260701_v2`
分支：`codex/tile-model-consistency-2.6.14`

## 本轮修复

- 定缺圆印 `条/筒/万` 使用 `content_margin_top=3`、`content_margin_bottom=17`，按 CJK 字面重心向上补偿 7px；不改变圆印尺寸、选中亮圈或触控合同。
- 立牌与胡牌后倒牌继续复用唯一 `0.42×0.24×0.58` GLB，并将本家平扣视觉倍率从 `0.90` 恢复为 `1.00`；姿态只旋转，不压薄或压缩模型。
- 弃牌河面朝上的实体牌显式显示翡翠底层 `concealed_cap_mesh`，并新增 Stage/视觉 Runner 门禁检查每个弃牌条目的绿色背层声明、可见性和材质。
- 结算页按面板可用高度分配玩家列表、胡牌摘要、手牌和分数明细；明细四列改为比例列宽、最小宽度和垂直填充，长文案裁剪；内容、详情、玩家列表和主面板均限制在安全边界内。

## 源码回归与实拍

- 固定清单 `docs/ui_rework/emerald_final_runner_manifest_V1.txt`：`27/27` 命令退出码为 0，包含 Godot UI/触控/规则/C#/3D/材质/四档空间/相机/灯光及 C# Release 编译。
- 重点 Runner：`SichuanTableTouchTargetRunner`、`SichuanHudStateIntegrityRunner`、`Sichuan3DTableStageRunner`、`SichuanRestoredUiRegressionRunner`、`SichuanTileVisualQualityRunner` 均 PASS。
- Metal 4.0 / Apple M1 Pro 实拍：
  - `ding_2048x1152.png`
  - `discard_2048x1152.png`
  - `self_draw_2048x1152.png`
  - `settlement_2048x1152_c.png`
  - `settlement_1365x768.png`
- 1365×768 和 2048×1152 结算图均显示完整标题、四家列表、手牌、分数明细和“下一局”，未见文字/边框/页脚越界。

## Android 2.6.18

- 成品：`build/android/SichuanMahjong-2.6.18-release.apk`
- `versionName=2.6.18`、`versionCode=278`、仅 arm64-v8a。
- SHA-256：`fe131a437fe04fbd6358f7692530d4e0c1bbbc2697b9d2fef37f4b43adf608f8`
- APK v2/v3 签名验证通过；证书 SHA-256：`9ca9ba45de9a950e19f140e2d706d0fe187e90070601d162becf8848b6a75600`。
- 免费官方 `Codex_Sichuan_API35` ARM64 模拟器 `emulator-5554` 覆盖安装成功；设备读回 `versionCode=278/versionName=2.6.18`。
- 显式 Activity 启动成功，日志确认 `renderer: gl_compatibility (CommandLine)`、C# runtime ready；启动后约 62 秒 PID `2155` 仍存活，未发现 FATAL EXCEPTION、native signal、进程死亡或 ANR。

## iOS 2.6.18

- Xcode/NativeAOT `Release-iphoneos`：`BUILD SUCCEEDED`。
- 签名 App：`build/ios/DerivedData-2.6.18/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`
- Development IPA：`build/ios/SichuanMahjong-2.6.18-development.ipa`
- IPA SHA-256：`c07b7690b0a25e5997d2585cb3f1a8a2d2f466ed0249fba00f6a6261a7c39e79`
- Bundle ID `com.chendong.sichuanmahjong.iosdev`，短版本/构建版本 `2.6.18/2.6.18`，`codesign --deep --strict` 与 IPA ZIP 完整性通过。
- iPhone 15（CoreDevice `516E99D2-18B6-5DD8-94E1-6993510A036D`）覆盖安装成功，设备数据库读回 `2.6.18/2.6.18`。
- 首次启动时设备短暂处于锁定状态，CoreDevice 返回 `FBSOpenApplicationServiceErrorDomain ... Locked`；设备解锁后已用 `--terminate-existing` 重试成功。启动约 20 秒的进程检查仍为 `SichuanMahjongIOS` PID `92768`。因此本轮 iOS 自动化证据已到构建、安装、版本读回、前台启动和短时进程存活；完整一局、真实手指触控与长时性能仍需用户在手机上人工验收。
