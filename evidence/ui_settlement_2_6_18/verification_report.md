# 2.6.18 定缺、实体牌与结算页修复验证

日期：2026-08-01
工程：`/Volumes/AI/Codex/四川麻将工程_20260701_v2`
分支：`codex/tile-model-consistency-2.6.14`

## 2.6.22 三家平扣白绿覆盖修复（2026-08-02）

- 针对最新截图中其余三家胡牌、碰杠平扣牌“白色牌身大、绿色背层小，白绿像分离层”的问题，定位为共享 `MahjongTileBack` 总内缩 `0.018` 与平扣覆盖层同尺寸造成的约 9mm 白边。
- `tools/3d/generate_mahjong_assets.py` 与当前 `res/art/3d/mahjong_tile_body.glb` 已统一到 `MahjongTileBack=0.414×0.074×0.574`，运行时 `SichuanTile3D.CONCEALED_BACK_SIZE=0.414×0.574`、圆角 `0.022`；保留 3mm 象牙唇边与真实绿背厚度，未改唯一牌体总尺寸 `0.42×0.24×0.58`、相机、规则、AI、布局或触控。
- 证据：`SichuanTileVisualQualityRunner`、`Sichuan3DTableStageRunner` PASS；Apple M1 Pro / Metal Forward+ 实拍 `followup_20260802_v3/ai-self-draw-1/2/3_2556x1179.png`、`ai-discard-win-1/2/3_2556x1179.png`、`max-meld_2556x1179.png`。实拍中白绿边界已收紧为连续牌体，仍保留实体边缘和接触阴影。
- 当前本轮仍需完成全量固定清单与 2.6.22 双端重新构建；手机设备安装/完整牌局仍按平台证据分层，不以源码或导出成功替代。

## 2.6.21 三家胡牌与本家副露视觉大小二次校准（2026-08-02）

- 按真实透视投影量测，三家 AI 胡牌平扣不再直接复用站立牌倍率：上家/下家使用 `1.34`，对家使用 `1.56`，使平扣单牌投影面积回到接近同座位立牌。
- 本家碰、杠改用本家手牌倍率的 `0.84×`（正常本家 `1.6296`），仍复用同一个 `mahjong_tile_body.glb`、三轴统一缩放和本家底部轨道。
- 牌距按实际平扣倍率同比同步；实体牌身/背层世界空间底边和厚度门禁继续生效。Metal 实拍：`followup_20260802_v2/ai-self-draw-1/2/3_2556x1179.png`、`ai-discard-win-1/2/3_2556x1179.png`、`max-meld_2556x1179.png`。

## 2.6.20 牌体大小与翻扣落桌校正（2026-08-02）

- 三家 AI 胡牌平扣牌列恢复原有座位倍率：上家/下家 `1.44`、对家 `1.28`；不再沿用本家胡牌倍率，也不再额外乘 `1.20`。
- 翻扣抬高量改为 `0.24 × 当前实际等比倍率`，保证同一 `0.42×0.24×0.58` GLB 的牌身与翡翠背层在世界空间完整落桌；暗杠中间两张按副露倍率同步处理。
- `Sichuan3DTableStageRunner` 新增世界空间底边/厚度检查，防止平扣牌再次嵌入桌面或退化成薄边。

## 2.6.19 本轮交付验证（2026-08-01）

- Android 正式包：`build/android/SichuanMahjong-2.6.19-release.apk`，150,170,374 bytes，SHA-256 `4f0bc42ded550922212ade58f63071770df6b52a763a93941fcfe7e202932b07`；包名 `com.chendong.sichuanmahjong`，`versionCode=279`、`versionName=2.6.19`，仅 `arm64-v8a`。
- Android APK v2/v3 签名通过，证书 SHA-256 `9ca9ba45de9a950e19f140e2d706d0fe187e90070601d162becf8848b6a75600`；包内包含本轮 `SichuanTile3D.gdc`、`SichuanTableStage3D.gdc` 和 `assets/_cl_` 的 `--rendering-method gl_compatibility`。
- 免费官方 Android 15 ARM64 `Codex_Sichuan_API35` 模拟器覆盖安装成功，设备读回 `2.6.19/279`；显式启动后 PID `1979` 在 5s、20s、40s 检查仍存活，日志确认 `renderer: gl_compatibility (CommandLine)` 和 `[SichuanCSharpRuntime] ready`，无 FATAL、native signal、ANR、`QueuePresentKHR` 或 force quit。完成一次输入事件后 PID 仍为 `1979`。
- iOS Godot/.NET Xcode/NativeAOT 导出和 `Release-iphoneos` 构建均成功；签名 App：`build/ios/DerivedData-2.6.19/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`；Development IPA：`build/ios/SichuanMahjong-2.6.19-development.ipa`，SHA-256 `667cf150d3a53145f44d59cd872e4fed99ae6b40159a050639b2b6bcf420de19`。Bundle ID `com.chendong.sichuanmahjong.iosdev`，版本/构建 `2.6.19/2.6.19`，`codesign --deep --strict` 和 IPA ZIP 完整性通过。
- iPhone 15 CoreDevice `516E99D2-18B6-5DD8-94E1-6993510A036D` 覆盖安装成功，设备数据库读回 `2.6.19/2.6.19`；前台启动成功，PID `95209` 在启动后约 8s 和再过 20s 仍存活。自动化证据已到构建、签名、安装、版本读回、启动和短时稳定进程；完整一局、真实手指触控和长时性能仍需用户人工验收。

## 后续牌体一致性复核（2026-08-01）

- 复查用户截图后确认：三家 AI 胡牌平扣结果和暗杠中间牌朝上受顶灯直射，直接使用立牌源色会在 Metal 画面中偏亮；现改为同一树脂 PBR 参数下的深翡翠源色补偿，禁止无光照平面或二维贴片。下家立牌的深翡翠作为画面目标色。
- 上家、对家、下家三家 AI 的自摸胡与点炮胡都统一使用同一 `mahjong_tile_body.glb`、同一 `0.42×0.24×0.58` 实体厚度和各自原有座位倍率；没有只拉厚 Y 轴，也没有替换 GLB。平扣后的实体背层按当前座位实际倍率同步抬高，避免嵌入桌面。
- 暗杠矩阵新增四个座位（本家、上家、对家、下家）逐组检查：外侧两张正面、中间两张真实实体牌背；两张中间牌均检查同一 GLB、统一三轴比例、物理翻扣高度、翡翠背层材质和倒角，不再只检查对家样例。
- `Sichuan3DTableStageRunner`、`SichuanTileVisualQualityRunner` 和四档 `SichuanSpatialLayoutRunner` 在当前源码上通过；固定清单仍为 `27/27`。
- 新 Metal 4.0 实拍目录：`followup_20260801/` 下的 `ai-self-draw-1/2/3_2048.png` 与 `ai-discard-win-1/2/3_2048.png`，分别覆盖上家、对家、下家两种胡牌来源；逐图复核平扣牌均为深翡翠实体背面且保留牌边、阴影和厚度。

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
