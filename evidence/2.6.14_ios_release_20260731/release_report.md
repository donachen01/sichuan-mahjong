# 四川麻将 2.6.14 iOS Release 与真机安装报告

日期：2026-07-31

## 成品

- App：`build/ios/DerivedData-2.6.14/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`
- IPA：`build/ios/SichuanMahjong-2.6.14-development.ipa`
- IPA 大小：`96,069,590` bytes
- IPA SHA-256：`47ee658e6a5ee8fcb5a98eb9e4030d487b4a917105aea68db496dc44d84c9a25`
- App 主程序 SHA-256：`0091fe0a483c5f00d477333927f518137ad222f96b55b969c10848b701cc6df0`
- App PCK SHA-256：`35089c602c1687550fc169c1fae38a3b423ad7175767982bb7928ac792d1c845`

## 构建、签名与包内模型

- Godot 4.6.2 .NET iOS Xcode/NativeAOT 导出成功，`ios_export_result=0`、`message_count=0`。
- Xcode `Release-iphoneos`：`BUILD SUCCEEDED`。
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`；短版本/构建版本：`2.6.14/2.6.14`。
- App 主程序和 `SichuanMahjong.Godot.framework` 均为 `arm64`；`codesign --verify --deep --strict` 通过。
- Apple Development Team：`FCB4ZVWWD8`；描述文件到期：`2026-08-06 20:25:19 CST`。
- Xcode 工程 PCK 与签名 App 内 PCK SHA-256 完全一致。
- 独立验证脚本挂载签名 App PCK 后加载牌体，实测组合 AABB 为 `(0.42, 0.24, 0.58)`，输出 `PACKAGED_IOS_TILE_MODEL_PASS`。
- Development IPA 使用 Apple `ditto` 生成标准 Payload，ZIP 完整性通过。

## iPhone 局域网安装与启动

- 设备：dona‘s iPhone，iPhone 15 (`iPhone15,4`)，CoreDevice ID `516E99D2-18B6-5DD8-94E1-6993510A036D`，状态 `available (paired)`。
- 通过 CoreDevice 局域网隧道覆盖安装成功；安装数据库读回 `2.6.14/2.6.14`。
- `devicectl device process launch --terminate-existing --activate` 前台启动成功。
- 约 5 秒、50 秒和 95 秒三个进程检查点均为同一 PID `88361`，可执行路径均指向本次新安装的 `A58AC094-FAB9-4CF0-949F-71903A58AABF/SichuanMahjongIOS.app`。

## 验证边界

自动化最强证据到：固定清单 `27/27`、真实 Metal 多种碰杠画面、签名构建、包内统一模型、局域网覆盖安装、设备版本读回、前台启动和约 95 秒稳定 PID。完整一局、真实手指触控、手机屏幕上的最终主观大小/厚度观感、长时帧率与发热仍需用户真机人工验收。
