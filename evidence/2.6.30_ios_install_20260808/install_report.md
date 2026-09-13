# 四川麻将 2.6.30 iOS 打包与安装报告

日期：2026-08-08

源码提交：`7b20f09f27f2fede875c33724a0942012a829b45`

核心 2.6.30 桌布源码/导入提交：`407f0e298589f656c37b1562c689465bdc7fb5f6`

Bundle ID：`com.chendong.sichuanmahjong.iosdev`

## 结论

- 已从当前 2.6.30 源码全新执行 C# Release、Godot iOS/NativeAOT 导出、Xcode 26.6 Release 真机签名构建和 IPA 归档，没有复用 2.6.29 App。
- 已通过局域网覆盖安装到 `dona‘s iPhone`（iPhone 15）。设备端读回“四川麻将新版”版本 `2.6.30 / 2.6.30`。
- 远程前台启动成功。启动约 3 分钟后，设备进程仍在运行，PID `3480`。
- 最终 App 的 PCK 已直接加载校验，包内版本为 2.6.30，并包含本轮桌布 GLB、底色、法线和 ORM 纹理；包内文件 SHA-256 与当前源码逐项一致。

## 源码与回归

- 固定发布清单：`27 / 27 PASS`。
- 覆盖规则、计分、C# AI 合同、定缺、反应动作、3D 桌面、材质、灯光、相机、牌面、HUD、动效、触控和四档空间布局。
- 四档空间布局：`1365x768`、`2048x1152`、`2400x1080`、`2556x1179` 全部通过。
- C# Release：`0 warning / 0 error`。
- 桌布 Metal 参考复验：中位 `RGB(53, 131, 64)`，R/G `0.40458`、B/G `0.48855`、明度 `0.42972`，通过。

## 导出与 NativeAOT

- Godot：`4.6.2.stable.mono.official.71f334935`。
- iOS 模板 SHA-256：`aecc5d9a668cb0f862c3c741405ff03f8e29f12bc3dd6e0b8955cc3b9d2e96fb`，ZIP 完整性通过。
- Godot iOS Project Files Only 导出结果：`ios_export_result=0`。
- 新生成的 iOS NativeAOT framework：arm64 Mach-O。
- AOT SHA-256：`229d2293f709f8116d3243ea3dd05e0dca9b0ee4eccba6f0ad90aed8a08f863b`。
- AOT 关键符号检查包含 `SichuanAiFacade`、`SichuanDingQueDecisionEngine`、`SichuanReactionDecisionEngine` 和 `SichuanUnifiedDecisionEngine`。

## Xcode 与签名

- Xcode：`26.6 (17F113)`。
- Release / iphoneos / iPhone 15：`BUILD SUCCEEDED`。
- App 主程序和 AOT framework 均为 arm64。
- App 版本：`CFBundleShortVersionString=2.6.30`，`CFBundleVersion=2.6.30`。
- 签名身份：`Apple Development: donachen2027@outlook.com (MN54CC5STV)`。
- Team ID：`FCB4ZVWWD8`。
- 描述文件 UUID：`db1baa0e-3dbc-4c83-9049-a7c3d944a9ed`。
- 描述文件到期时间：`2026-08-14 20:36:34 CST`。
- 描述文件包含目标设备 UDID：`00008120-000915803A90A01E`。
- `codesign --verify --deep --strict`：通过。
- 描述文件开发证书 SHA-1 与签名证书一致：`3D:AD:65:E5:96:3A:B5:00:15:B1:BF:11:3B:44:B1:07:0E:EB:ED:23`。
- App 与描述文件的 application identifier、Team ID 和 `get-task-allow=true` entitlements 一致。

## 最终包内容

- 导出 PCK 与签名 App 内 PCK SHA-256 均为 `2a5bd72d68fab8f64afaf685240accc7942b0998a4b773f730489fe5e3642aaa`。
- 桌布 GLB：`1c9629ce925437b0f46696696776a111792fc0ea4a050a7acb6b270ff1e4babd`。
- 桌布 3D 底色：`7854438dea5997d64ba391f7420bfc0bc70e0a670b4606663dfa1275dbb179a5`。
- 材质 BaseColor：`5206ec120531d2e4d3bb05bcc590e8845c66d615ba8b30f846fffebe9a90b0f8`。
- 材质 Normal：`34ba96033230cf094efe718035e19c72b260fbeaeaa03509986a1a023daa1848`。
- 材质 ORM：`d8685cb6dde53f6a3889b7289dabf8e2d25fb17c05b663044deb418d63f4bdf9`。

## 产物

- App：`build/ios/DerivedData-2.6.30-20260808/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`。
- IPA：`build/ios/SichuanMahjong-2.6.30-development-20260808.ipa`。
- IPA 大小：`96,600,726` bytes。
- IPA SHA-256：`627bb28ad2f3e96124c3c20dd3582790eeae8a30216e779e6fa042b301c9c1b5`。
- IPA ZIP 完整性：通过；归档内没有 `__MACOSX` 元数据目录。

## 设备结果

- 设备：`dona‘s iPhone`，iPhone 15（iPhone15,4）。
- CoreDevice ID：`516E99D2-18B6-5DD8-94E1-6993510A036D`。
- 局域网覆盖安装：成功。
- 新安装位置：`/private/var/containers/Bundle/Application/EA658B39-0340-4960-BE33-BCC94C54D952/SichuanMahjongIOS.app`。
- 设备端读回：名称“四川麻将新版”，Version `2.6.30`，Bundle Version `2.6.30`。
- 远程前台启动：成功。
- 延时驻留：启动约 3 分钟后 PID 仍为 `3480`。

## 已知诊断与验证边界

- Xcode 有三个既有空权限说明警告（相机、麦克风、照片）和一条无 AppIntents 依赖的元数据跳过警告；构建成功，当前游戏流程未使用这些权限。
- Godot 无界面导出在成功完成后报告既有退出期 RID/ObjectDB 清理诊断；导出返回码和 `ios_export_result` 均为 0，Xcode 后续构建与签名验证均通过。
- 当前最强证据到：完整源码回归、全新 NativeAOT、Xcode 真机签名构建、最终包内容与桌布同源校验、局域网安装、设备端版本读回、远程前台启动和约 3 分钟进程驻留。
- 尚未由自动化证明手机屏幕上的最终桌布视觉、真实触控、完整一局、长时帧率、发热和功耗；这些需要用户在手机上现场体验确认。
