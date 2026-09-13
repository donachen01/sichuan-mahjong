# 四川麻将 2.6.36 iOS 发布报告

日期：2026-08-10

## 版本与产物

- 应用版本：`2.6.36`
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`
- App：`build/ios/DerivedData-2.6.36/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`
- IPA：`build/ios/SichuanMahjong-2.6.36.ipa`
- IPA SHA-256：`bcf3d03039f49590105be0b8df4d6e114a6d649475b97fb35207f23ff74ebac6`
- 主程序 SHA-256：`25aeaa1974a2e277f1b97f632764b5604784343c0c60515b247844589015fecc`
- PCK SHA-256：`9b66d40a7de6ffd6e935e936db0bed260b1ce1608cfe70b7c5ef775fd78e2e0f`
- NativeAOT framework SHA-256：`8b00fb96f9790a95243f466ba50e168cf34ee3402cf94b710adec75866515a4b`

## 构建核验

- Godot 4.6.2 .NET 导出 Xcode 工程成功，导出消息计数为 0。
- Xcode Release 构建成功；`CFBundleShortVersionString=2.6.36`，`CFBundleVersion=2.6.36`。
- 主程序为 `Mach-O arm64`；嵌入的 `SichuanMahjong.Godot.framework` 为 `Mach-O arm64`，确认包含本轮 C# NativeAOT 代码。
- IPA 压缩数据完整性检查通过。
- Apple Development 描述文件有效期至 `2026-08-14 20:36:34 CST`。
- Xcode 保留 3 项既有权限说明为空警告（相机、麦克风、相册）；当前游戏不请求这些权限，不影响本次安装和启动。
- 本机 `codesign --verify --deep --strict` 返回 `CSSMERR_TP_NOT_TRUSTED`，但 Xcode 签名构建成功、描述文件 CMS 校验成功，且设备实际安装与启动成功；因此按真实设备结果记录，不把本机证书链提示写成签名完全无警告。

## 真机交付

- 目标设备：已配对的 iPhone 15，局域网状态 `available (paired)`。
- 覆盖安装后设备应用数据库回读：名称“**四川麻将新版**”，版本 `2.6.36`，Bundle Version `2.6.36`。
- `devicectl device process launch --terminate-existing` 成功拉起 `com.chendong.sichuanmahjong.iosdev`。

## 验证层级

- 已完成：产物生成、Release 构建、版本/架构/AOT 核验、IPA 完整性、真机安装、真机启动。
- 未声称：自动化完成真机上的整局触控实战。算法牌局验证见同目录 `ai_verification_report.md`。
