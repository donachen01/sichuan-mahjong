# 四川麻将 2.6.16 六项修复与双端发布报告

日期：2026-08-01

## 用户问题与结果

1. 投骰动画改为与帧率无关的单调时钟截止：3 秒声音播放结束后约 0.05 秒完成交接，进入定缺后骰子和中央计数都隐藏。
2. 条、筒、万印章重新生成，不再烘焙文字下方装饰点；文字上下内边距一致并在圆内居中。
3. 定缺初始状态释放三个按钮焦点，不再只给“条”显示亮圈；仅在用户明确选择后给被选项聚焦反馈。
4. 本家和牌倒牌继续复用同一个 `0.42×0.24×0.58` 实体模型，仅做三轴一致的视觉补偿，不压薄任何轴。
5. 本家碰、杠和剩余手牌共用一条最多 18 张的连续底部轨道；所有本家副露与手牌共享同一个等比缩放，按实际总张数自动收紧，并保留组间和副露/手牌间的可读缝隙。
6. iOS 结算层增加原生触摸显式路由。关闭积分后自动展开工具栏并露出“下一局”；下一局触摸已由自动测试验证会推进 `round_index` 并进入新一局投骰阶段。

## 自动化与真实 Metal

- 最终固定清单 `docs/ui_rework/emerald_final_runner_manifest_V1.txt` 从头执行：`27/27 PASS`，包含规则、计分、iOS 字体与触控、结算、C#、3D 牌桌、牌体、四档空间布局、相机和灯光。
- 新增低帧率投骰门禁：随机换点回调可以丢帧，但 3.05 秒单调时钟截止不会依赖回调次数。
- 新增 iOS 原生 `InputEventScreenTouch` 结算关闭→工具栏展开→下一局完整回归。
- 新增 4 个杠加 2 张手牌的 18 张压力测试，逐牌验证手牌/副露使用相同三轴缩放、轨道不越界、组间不重叠。
- Apple M1 Pro / Metal 4.0 / Forward+、2048×1152 实拍：`ding-que_2048x1152.png`、`self-draw_2048x1152.png`、`max-meld_18_2048x1152.png`。

## Android 2.6.16

- APK：`build/android/SichuanMahjong-2.6.16-release.apk`
- 版本：`versionName=2.6.16`、`versionCode=276`
- 大小：`150166278` bytes
- SHA-256：`8749f6e913a6988fcb4ac44248a2942b0d025650708226da1d944f5ac89f715c`
- 包名：`com.chendong.sichuanmahjong`；arm64；zipalign、APK v2/v3 签名验证通过；签名证书 SHA-256 为 `9ca9ba45de9a950e19f140e2d706d0fe187e90070601d162becf8848b6a75600`。
- 免费官方 Android Emulator 37.1.11、Android 15 ARM64 AVD `Codex_Sichuan_API35` 覆盖安装成功；设备版本读回正确，应用 PID `2047` 稳定存活。
- 日志明确为 `usesVulkan(): false`、`renderer: gl_compatibility (CommandLine)`，C# runtime ready；进入牌桌并执行手牌触摸后无 FATAL、ANR、native signal、应用进程死亡或 `QueuePresentKHR`。

## iOS 2.6.16

- App：`build/ios/DerivedData-2.6.16/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`
- IPA：`build/ios/SichuanMahjong-2.6.16-development.ipa`
- IPA 大小：`96077791` bytes
- IPA SHA-256：`9e63813fcf9ca33d89cc677ae5c0748ecc4ac084533fef963cc3314ea4ee877d`
- App 主程序 SHA-256：`8961cfed118fd18930b2357c7eadf3c7fa3790bec09e9b76afd6bf35db6b1718`
- App PCK SHA-256：`0c14e7aa6e3eb6d160abd1c534c534fb570226d8a18baeb4b32fe4d122089b3a`
- Xcode `Release-iphoneos`：`BUILD SUCCEEDED`；Bundle ID `com.chendong.sichuanmahjong.iosdev`；短版本/构建版本 `2.6.16/2.6.16`；arm64；`codesign --deep --strict` 通过；IPA ZIP 完整性通过。
- iPhone 15（CoreDevice `516E99D2-18B6-5DD8-94E1-6993510A036D`）通过局域网覆盖安装成功，设备数据库读回 `2.6.16/2.6.16`，前台启动成功；延时复核仍为同一 PID `90894`。

## 验证边界

最强自动化证据到：源码合同、27/27 固定回归、真实 Metal 视觉、Android 正式包签名/安装/启动/触摸/稳定进程、iOS 签名构建/局域网安装/设备版本/前台启动/稳定进程。iPhone 上完整打完一局、真实手指完成结算关闭和下一局、以及长时帧率/发热，仍需用户在手机上人工体验确认。
