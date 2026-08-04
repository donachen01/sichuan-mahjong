# 四川麻将 2.6.29 iOS 发布验证报告

日期：2026-08-04

分支：`codex/tile-model-consistency-2.6.14`

Bundle ID：`com.chendong.sichuanmahjong.iosdev`

## 发布内容

- 中心东、西激活红区改为与真实分隔线一致的 `124.48292°` 扇区，完整覆盖各自区域；北、南保持 `55.51708°`。
- 四个激活区继续使用精确显示色 `#A13D2D`，中央余牌计数器切口和无黄色外缘合同保持不变。
- 结算页改为单层深翡翠主壳，减少框线、放大文字并按可用高度展开玩家与明细区域；展示内容、麻将牌、玩家切换和按钮行为保持不变。
- 版本统一升级到 `2.6.29`；Android `versionCode` 同步为 `289`，但本报告只交付 iOS 产物。

## 源码与渲染回归

- 固定发布清单：`27/27 PASS`。
- C# Release：`0 warning / 0 error`。
- Apple M1 Pro / Metal 4.0 / Forward+：四方向中心和四档结算页均有真实渲染截图。
- 四方向激活红色：精确 `RGB(161, 61, 45)` / `#A13D2D`。
- 中央余牌圆圈红色侵入像素：四方向均为 `0`。
- 中心外缘黄色像素：四方向均为 `0`。
- 中心 GLB：`9` 对象、`1,044` 三角面、`4` 个激活扇区。
- 中心 GLB SHA-256：`ab4bb4f0ec1f5f4d5544a486b36c7eea7267cc5841c8b8dd68152a6fb38e8e44`。
- 视觉报告与 8 张成品图：`evidence/ui_center_settlement_redesign_20260804/verification_report.md`。

## iOS 构建与最终包核验

- Godot 4.6.2 Mono iOS 导出成功，NativeAOT 已嵌入。
- Xcode 26.6，Release / iphoneos / arm64：`BUILD SUCCEEDED`。
- Apple Development 签名与深度 `codesign --verify --deep --strict`：通过。
- 描述文件：`iOS Team Provisioning Profile: com.chendong.sichuanmahjong.iosdev`。
- Team ID：`FCB4ZVWWD8`。
- 描述文件 UUID：`e9230a76-d6b5-4ce3-b9fe-12a68d75d71f`。
- 描述文件到期：`2026-08-06 20:25:19 CST`；到期后需重新签名安装。
- App 读回版本：`2.6.29 / 2.6.29`。
- IPA：`build/ios/SichuanMahjong-2.6.29-development.ipa`。
- IPA 大小：`97,363,720` bytes。
- IPA SHA-256：`4573f52ad379e70f5b3af644f9d58242de9d678a0da08b62cad36cede6c8586d`。
- IPA ZIP 完整性：通过。
- Godot 导出 PCK 与签名 App 内 PCK SHA-256 均为 `cc9deaa883163fd7dc39cda4b828bd10d5c7868c0acedd02af130d356ae4d7a7`，同源匹配。
- 直接挂载签名 App 内最终 PCK 的专项检查：`PACKAGED_IOS_2_6_29_PASS CENTER + SETTLEMENT`。这证明安装包包含本轮中心几何与结算页修改，而不只是源码目录已修改。

构建阶段仍有三个非阻塞警告：相机、麦克风、照片用途说明为空。当前应用不请求这些权限，不影响本次签名、安装或已有游戏流程；如未来加入对应功能，应先补真实用途说明。

## iPhone 安装结果

- 设备：`dona‘s iPhone`，iPhone 15，CoreDevice ID `516E99D2-18B6-5DD8-94E1-6993510A036D`。
- 覆盖安装：成功。
- 设备端读回：应用名“`四川麻将新版`”，Bundle ID `com.chendong.sichuanmahjong.iosdev`，Version `2.6.29`，Bundle Version `2.6.29`。
- 安装位置：`/private/var/containers/Bundle/Application/846ADFC9-F2DD-4B9A-9E32-7414DACA9B51/SichuanMahjongIOS.app`。
- 自动前台启动：未完成。CoreDevice 最终返回 `Locked`，明确说明设备未解锁，SpringBoard 拒绝启动请求；这不是应用崩溃或签名失败。

## 验证边界

本轮最强证据到：源码与渲染回归、Godot 导出、NativeAOT、Xcode Release 签名构建、最终 PCK 内容核验、IPA 完整性、真机覆盖安装和设备端版本读回。由于 iPhone 锁屏，自动启动与延时 PID 未取得；用户解锁后可直接点击设备上的“`四川麻将新版`”进行最终视觉和真实手指牌局验收。完整一局、连续触控和长时性能不由本次自动化结果替代。
