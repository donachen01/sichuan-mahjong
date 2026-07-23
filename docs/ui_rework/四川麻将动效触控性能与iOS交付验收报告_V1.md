# 四川麻将动效、触控、性能与 iOS 交付验收报告 V1

## 1. 当前结论

`2.6.1` 的源码、四档真实 Metal 画面、独立设计复评、Godot/C# 回归、桌面 Metal 性能、iOS Release 构建、arm64 架构、开发签名、PCK 一致性与真机覆盖安装已通过。设备安装库已确认 `dona‘s iPhone` 上的版本/构建为 `2.6.1/2.6.1`。

当前设备处于锁屏状态，iOS 以 `FBSOpenApplicationErrorDomain error 7 / Locked` 拒绝自动启动；启动 PID 与 60 秒存活检查必须在手机解锁后复测，未将锁屏拒绝写成启动通过。

## 2. 视觉门禁

- 对手牌姿和 AI 点炮展示报告：`docs/ui_rework/四川麻将对手牌姿与点炮展示验收报告_V1.md`。
- 最终证据：`evidence/ui_opponent_pose_20260718/final_v3/`，四档正常局面 + AI 点炮胡牌共 8 张，结构检查 `8/8`。
- 左右家平均主轴角 `76.033°`，目标图 `73.136°`，差 `2.897°`；左家前景位移 `-2.847%`，右家 `+2.848%`，方向与目标图一致。
- 对家主轴偏离水平线 `0.0031°`。
- AI 点炮胡牌合同：普通暗手 `0` 张、胡牌张 `1` 张、来源标记 `1` 个，20 次正常/点炮状态往返无残留。
- 独立设计首轮 `15/20` 因有向透视轴相反否决；重做后二轮 `18/20`，P0=0、P1=0，结论 PASS。

## 3. 功能与回归

- 非摄像机 `Sichuan*Runner.gd`：`24/24`。
- 摄像机四档合同：`4/4`。
- 点炮单牌、唯一来源、20 次状态切换、牌姿和不可点击状态：通过。
- 左上工具栏 iOS touch + 模拟 mouse 双事件去重合同、连续真实触摸合同：通过。
- C# `AI.Core` Release：`0 warning / 0 error`。
- Python 分析器编译、结果结构和 `git diff --check`：通过。

## 4. 性能证据

原始数据：`evidence/ui_delivery_20260718/performance/metal_2556x1179_final_2.6.1.json`。

| 指标 | 结果 | 门槛 | 判定 |
|---|---:|---:|---|
| 帧数 | 600 | ≥600 | 通过 |
| 平均 FPS | 119.999 | ≥55 | 通过 |
| 1% Low | 87.001 FPS | ≥45 FPS | 通过 |
| P99 帧时 | 11.2 ms | 记录 | 通过 |
| 最大帧时 | 11.906 ms | 记录 | 通过 |
| 峰值静态内存 | 267.264 MB | ≤1.2 GB | 通过 |

该数据来自 macOS 真实 `Metal 4.0 - Forward+` 的 2556×1180 实际视口，不冒充 iPhone 长时性能。

## 5. iOS 构建与产物完整性

- Xcode 工程：`build/ios/SichuanMahjong-2.6.1-ios-xcode/SichuanMahjongIOS.xcodeproj`。
- Release App：`build/ios/DerivedData-2.6.1/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`，大小约 `436 MB`。
- Xcode Release：`BUILD SUCCEEDED`。首次命令因导出工程的 Distribution 标识与开发签名冲突失败；指定 `Apple Development` 后重建成功，未复用旧 App。
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`。
- 短版本/构建：`2.6.1/2.6.1`。
- 主程序和 `SichuanMahjong.Godot.framework`：均为 Mach-O arm64。
- 签名：`Apple Development: donachen2027@outlook.com (MN54CC5STV)`，Team `FCB4ZVWWD8`；`codesign --verify --deep --strict` 通过。
- 描述文件截止日期：`2026-07-20T12:32:52Z`。
- Xcode 源 PCK 和 App 内 PCK 的 SHA-256 均为 `d9fcc4f4b92f54ffdf465d230972cfc53c58e146a6e5b75f2740ab4671d2c6d1`。
- 最终 PCK 确认包含 `SichuanTableStage3D.gd/.gdc` 和 `SichuanTile3D.gd/.gdc`。

## 6. 真机证据

- 设备：`dona‘s iPhone`，iPhone 15，CoreDevice ID `516E99D2-18B6-5DD8-94E1-6993510A036D`。
- 覆盖安装：通过；`devicectl` 返回 App installed。
- 安装库版本：`2.6.1/2.6.1`，通过。
- 自动启动：待设备解锁复测；当前 iOS 明确返回 `Locked`。
- 60 秒进程存活：待启动成功后复测。

## 7. 证据边界与人工验收

自动证据最强层级已到“新 App 覆盖安装，手机安装库确认 2.6.1”。手机解锁后还必须补“自动启动 + PID + 60 秒存活”。

以下项目必须由用户在真机人工完成，不由安装或桌面 Metal 数据替代：

1. 完整打一局，确认定缺、出牌、碰/杠/胡/过、AI 点炮胡牌展示与结算。
2. 连续 20 次操作左上展开/缩进、AI 提示、难度、明牌，观察是否每次只执行一次。
3. 连续运行至少 10 分钟，评估帧率、发热、耗电、牌面可读性和触控手感。
