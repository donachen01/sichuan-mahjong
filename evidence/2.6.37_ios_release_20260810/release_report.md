# 四川麻将 2.6.37 iOS 发布报告

日期：2026-08-10

## 版本与产物

- 应用版本/构建号：`2.6.37 / 2.6.37`
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`
- App：`build/ios/DerivedData-2.6.37/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`
- IPA：`build/ios/SichuanMahjong-2.6.37.ipa`
- IPA SHA-256：`6f13b12742fc122e3fddf0cfa7b71e83dbc67ba9c201cd3b3ab0300dd9df0222`
- 主程序 SHA-256：`9d9057281c93aa5d8ca8ba08adf45e9ab63d3269ad6ecfb1a9a2520007f4a7c9`
- PCK SHA-256：`c40a91cc6188ce8cc6309c7bc962645294677d1c6b9f49abfb82b57fa03fdbc1`
- NativeAOT SHA-256：`dde4392010f1d8893655f2eecb54d8ab5d52346573a4e4bf493cda436bc9544d`

## 构建核验

- Godot 4.6.2 .NET 导出 Xcode/NativeAOT 工程成功，`message_count=0`。
- Xcode Release `BUILD SUCCEEDED`，使用 Apple Development `MN54CC5STV` 和描述文件 `db1baa0e-3dbc-4c83-9049-a7c3d944a9ed`。
- 主程序为 Mach-O arm64；嵌入 `SichuanMahjong.Godot.framework` 为 Mach-O arm64，包含本轮 C# NativeAOT。
- IPA 压缩完整性通过；描述文件 CMS 校验通过，有效期至 `2026-08-14 20:36:34 CST`。
- Xcode 保留 3 项既有权限说明为空警告（相机、麦克风、相册）；当前游戏不请求这些权限。
- 本机 `codesign --verify --deep --strict` 返回 `CSSMERR_TP_NOT_TRUSTED`；Xcode 签名构建和 CMS 校验均成功，以真机安装结果作为更强证据，不将本机证书链提示误写为完全无警告。

## 真机交付

- 目标设备：`dona‘s iPhone`，iPhone 15，CoreDevice ID `516E99D2-18B6-5DD8-94E1-6993510A036D`。
- 局域网覆盖安装成功；设备应用数据库回读名称“**四川麻将新版**”，版本/构建号 `2.6.37 / 2.6.37`。
- 首次启动被 iOS 拒绝，设备返回 `Locked`；随后一次重试遇到局域网设备瞬时断开。安装不受影响，最终启动结果待设备解锁并重新在线后补记。

## 验证层级

- 已完成：源码/算法回归、产物生成、Release 构建、版本/架构/AOT/IPA/描述文件核验、真机安装、真机版本回读。
- 待完成：真机自动启动和进程存活回读。
- 未声称：自动化完成真机上的整局触控实战；算法牌局证据见 `evidence/2.6.37_ai_evolution_20260810/ai_verification_report.md`。
