# 四川麻将 iOS 2.6.49 发布记录

- 签名 App：`build/ios/DerivedData-2.6.49-device/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`
- Development IPA：`build/ios/SichuanMahjong-2.6.49-development.ipa`
- IPA SHA-256：`d7a9cf21d183a3b4cc430aeb736312a0b179746b625f7bd707df9b7aed8c7ca0`
- 版本/构建：`2.6.49/2.6.49`，Bundle ID `com.chendong.sichuanmahjong.iosdev`。
- 构建：Xcode `BUILD SUCCEEDED`，应用与 .NET NativeAOT framework 均为 arm64，`codesign --deep --strict` 通过。
- 内容：NativeAOT framework 可检出 `SichuanClassicPatternEngine` 特征符号。
- 真机：`dona‘s iPhone` (iPhone 15) 覆盖安装成功，设备应用数据库读回 `2.6.49/2.6.49`，前台启动成功，后续进程 PID `5957` 仍存活。

自动化最强证据到签名构建、安装、版本读回、启动和短时存活；完整一局、真实手指连续操作及长时发热仍需用户真机人工验收。
