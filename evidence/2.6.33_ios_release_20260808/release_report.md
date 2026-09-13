# 2.6.33 iOS 发布证据

- 全新 Godot 4.6.2 Mono / NativeAOT 导出：成功。
- Xcode Release arm64 构建：`** BUILD SUCCEEDED **`。
- App：`build/ios/DerivedData-2.6.33-20260808/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`。
- IPA：`build/ios/SichuanMahjong-2.6.33-development-20260808.ipa`，97 MB。
- IPA SHA-256：`8b97bdbc00ef37b4aea7f70232dc09b4da46529a0071d1f63a32e7eb1eecfe6b`。
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`。
- App 版本：`CFBundleShortVersionString=2.6.33`，`CFBundleVersion=2.6.33`。
- 签名：Apple Development，Team `FCB4ZVWWD8`；`codesign --verify --deep --strict` 通过。
- Provisioning profile：`iOS Team Provisioning Profile: com.chendong.sichuanmahjong.iosdev`，到期时间 `2026-08-14 20:36:34 CST`。
- 目标设备：`dona‘s iPhone`，iPhone 15，局域网 paired/available。
- 安装：成功，设备侧应用列表显示 `2.6.33 / 2.6.33`。
- 启动：成功；后续进程查询仍见 `SichuanMahjongIOS` PID 5104。
- 视觉边界：已在 macOS Metal 完成三档截图与指标验证；设备安装/启动不等于 iPhone 内部牌局画面的肉眼验收，需用户在手机上确认。
