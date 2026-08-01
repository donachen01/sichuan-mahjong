# 2.6.17 发布与验证报告

日期：2026-08-01
工程：`/Volumes/AI/Codex/四川麻将工程_20260701_v2`
版本：`2.6.17`；Android versionCode：`277`

## 本轮修复

1. 移动端定向阴影使用 4096 阴影图与中等软阴影过滤，平扣牌阴影边缘不再呈锯齿。
2. 定缺条/筒/万去除装饰点，并按 CJK 字面光学居中；只有当前选择项显示外圈高亮。
3. 查叫结算排除已经胡牌的玩家，避免重复获取查叫分。
4. 结算页玩家行支持触控选择，显示所选玩家手牌与分数来源；已胡玩家不再显示重复查大叫收益。
5. 结算页使用安全区和响应式布局，标题/关闭/下一局控件不越界。

## 源码与回归证据

- 固定清单 `docs/ui_rework/emerald_final_runner_manifest_V1.txt`：`27/27 PASS`。
- 规则回归：`34/34 PASS`。
- 结算触控、4 档分辨率边界、3D 阴影/灯光、牌体与 C# Release 编译均通过。
- Metal 实拍：`metal/ding_que_2048x1152.png`、`metal/settlement_2048x1152.png`、`metal/self_draw_shadow_2048x1152.png`。
- Android 实机画面：`android_2.6.17.png`（官方 Android 15 ARM64 模拟器，2400×1080）。

## Android

- 产物：[SichuanMahjong-2.6.17-release.apk](../../build/android/SichuanMahjong-2.6.17-release.apk)
- 包名：`com.chendong.sichuanmahjong`
- 版本：`2.6.17 (277)`；minSdk `24`；targetSdk `35`；arm64-v8a
- 大小：`150166278` bytes
- SHA-256：`ec0ed19119a3f7685588e27945db6b1476734a0e64fb3a25cd1122c6549bd8a7`
- ZIP、zipalign、APK v2/v3 签名通过；证书 SHA-256：`9ca9ba45de9a950e19f140e2d706d0fe187e90070601d162becf8848b6a75600`
- 免费官方 AVD `Codex_Sichuan_API35`（Android 15 ARM64、gl_compatibility）覆盖安装成功；显式启动后 C# runtime ready，PID `2012` 在约 20 秒检查仍存活；崩溃扫描未发现 FATAL、ANR、SIGSEGV、SIGABRT、QueuePresentKHR 或 Godot force quit。

## iOS

- 签名 App：[SichuanMahjongIOS.app](../../build/ios/DerivedData-2.6.17/Build/Products/Release-iphoneos/SichuanMahjongIOS.app)
- Development IPA：[SichuanMahjong-2.6.17-development.ipa](../../build/ios/SichuanMahjong-2.6.17-development.ipa)
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`
- 版本/构建：`2.6.17/2.6.17`；主程序 arm64；`codesign --verify --deep --strict` 通过
- IPA 大小：`96060537` bytes；SHA-256：`695b720645923e319d90bd572c05adf6d930bb224e6bca2ca9aaf8984168914c`
- iPhone 15 CoreDevice `516E99D2-18B6-5DD8-94E1-6993510A036D`：局域网隧道覆盖安装成功；设备数据库读回 `2.6.17/2.6.17`；前台启动及后续复启命令均成功。
- 当前 Apple 账号无 iOS Distribution 证书和 App Store Connect provider，因此 `xcodebuild -exportArchive` 的商店分发 IPA 不可生成；已交付个人 Apple Development 签名 App/IPA，可在已信任该开发者账号的设备安装。

## 尚未由自动化替代的验收

自动化最强证据到源码回归、Metal/Android 模拟器画面、签名构建、iOS 安装、版本读回和启动。用户仍需在 iPhone 上人工完成一局，确认结算页点选玩家、关闭后进入下一局，以及长时帧率/发热和最终视觉观感。
