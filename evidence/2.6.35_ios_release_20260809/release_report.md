# 四川麻将 2.6.35 发布报告

## 交付内容

- `bone_ash` 保持为公平公开信息下的老手基线，`hell` 保持为显式透视围剿挑战。
- 修正反应动作后继时序：过牌等待摸牌，碰后弃牌，直杠/暗杠/补杠先处理抢杠、杠分与补张，再判断杠上花或弃牌。
- 弃牌、碰、杠、过改用同尺度 ActionValue 和确定性公共样本；手牌结构改为互斥动态规划分解，强化对子、刻子、复合搭和五对以上七对路线保护。
- 新增独立离线反事实裁判、冻结基线配对擂台和受限影子日志；正式包不启用线上自动调权。
- 版本升级为 `2.6.35`，Android `versionCode=295`。本轮只发布 iOS 包，不生成 Android 产物。

## 算法与运行验证

- C# Release：0 warning，0 error。
- C# Smoke：通过；动作转移张数为 `pass=13`、`peng=11`、`gang=10`、`replacement=11`。
- 19 组 PDF 黄金听口通过；131,841 个单门精确牌形穷举无失败。
- 两组各 500 个状态的配对擂台均通过晋级门槛。盲测种子 `20260810` 的弃牌后悔值从基线 `0.199027` 降至 `0.170147`，碰/过/杠后悔值从 `1.587463` 降至 `0.196338`，同状态一致率 `100%`。
- Godot 真实 C# runtime 压力运行 5 局全部自然结束，强制终止 0、反应阻塞 0；共记录 47 次碰/过/杠/胡机会。
- 影子日志一局 94 个事件、268KB，隐藏状态非空事件 0；每会话限制 1600 事件、最多保留 4 个会话。首次发现的约 1.7GB 递归临时日志已删除。
- 版本一致性 Runner 通过；Godot 4.6.2 .NET 工程解析通过。导出退出时仍有既有 RID/ObjectDB 清理诊断，不影响导出退出码和产物。

详细 AI 数据见 `ai_verification_report.md`。

## iOS 产物

- Godot 4.6.2 .NET iOS/NativeAOT 导出：成功。
- Xcode 26.6 Release 真机目标构建：`BUILD SUCCEEDED`。
- App：`build/ios/DerivedData-2.6.35/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`。
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`。
- 版本/构建号：`2.6.35 / 2.6.35`。
- 主程序与 `SichuanMahjong.Godot.framework`：arm64。
- 主程序 SHA-256：`179b7a34e20a826e65b3409aef820a3f0414a757604bf3acffc2af6b7fe66fbb`。
- PCK SHA-256：`c351eeeb525d4cd607e61afb057aa467d56c008d5e32fe540baaa00cf266a70d`。
- AOT framework SHA-256：`473cf5a212cc80b9b0ec34cfdc58455186eb23d50ec002d2f7c2c39fec77f819`。
- IPA：`build/ios/SichuanMahjong-2.6.35-development-20260809.ipa`，`98,772,170` bytes。
- IPA SHA-256：`abeb4f2e077b57498e6def3847c9b3a504aa42163cd384bb62acfc844d328a7c`；ZIP 完整性通过。
- Apple Development 身份在钥匙串中有效，证书有效至 `2027-07-01`。App 内描述文件包含目标设备，有效至 `2026-08-14 20:36:34 CST`。
- 本机 `codesign --verify --deep --strict` 对证书链返回 `CSSMERR_TP_NOT_TRUSTED`；Xcode 签名构建成功，且目标 iPhone 实际接受安装并成功启动，因此本轮没有把本机信任诊断误报为设备可安装性证据。

## 真机安装

- 设备：已配对的 iPhone 15，局域网状态 `available (paired)`。
- 2.6.35 覆盖安装成功；设备应用数据库读回版本/构建号 `2.6.35 / 2.6.35`。
- 远程前台启动成功；延时进程检查确认应用仍在运行，执行路径与本次新安装一致。
- 原始设备安装、应用数据库、启动和进程 JSON 只保留在本机发布目录，不提交到 GitHub。

## 证据边界

本轮最强证据达到源码与精确算法验证、Godot 实际 C# runtime 压力运行、iOS NativeAOT/Xcode 签名构建、设备安装、版本读回、前台启动和延时进程存活。用户在真机上连续完成多局后的长期平均净分、主观老手感和发热/耗电仍需后续真实影子样本衡量。本报告不建立新的固定回归清单。
