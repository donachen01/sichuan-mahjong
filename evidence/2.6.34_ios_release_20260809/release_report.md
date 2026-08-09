# 四川麻将 2.6.34 发布报告

## 交付范围

- 默认老手基线改为 `bone_ash`；`hell` 明确为允许透视信息的围剿挑战，不再作为自然老手行为基线。
- 统一 4 番封顶、杠分、过胡锁、活跃付款人、查叫、花猪和呼叫转移合同。
- 桌面与 iOS 的 `bone_ash` 共用完整 C# 决策；iOS 仅压缩返回数据，不自动启用轻量牌理。
- 碰、直杠、暗杠、补杠与过牌使用同尺度的反事实价值参与最终动作选择；杠分支包含补牌、抢杠概率、番型、结算、路线和首打风险。
- 弃牌排序保留合法、定缺与极端防守闸门，同时允许满足净收益、向听和风险门槛的大牌路线进入速听同层比较。
- 公开信息模型增加手切/摸切、筋线与断张、孤张活性、根和定缺竞争；验收同时记录 Brier、ECE 与逐动作后悔值。

## 同状态对照

复现输入及完整价值分解见 `../ai_action_compare_20260809_same_state.md`。

- 桌面 `bone_ash`：弃 `4`，总分 4125，`mobileSpeedMode=false`，`forceLightweight=false`。
- iOS `bone_ash`：弃 `4`，总分 4125；与桌面动作和价值一致，仅 `compactResult=true`。
- 显式轻量诊断：弃 `4`，总分 4075；不是默认手机路径。
- `hell`：弃 `4`，总分 10120；分差来自 oracle 牌墙和围剿目标。

## 验证证据

- AI Core/CLI Release 构建：0 warning，0 error。
- C# Smoke：exit 0；精确牌形穷举 131,841 状态无失败，统一动作与精确结算测试通过。
- 四川规则聚焦回归：34/34。
- Godot C# runtime/NativeAOT 合同：29/29。
- 版本一致性：`2.6.34` / Android `versionCode=294`。
- Godot iOS 导出：成功。
- Xcode Release 真机目标构建：`BUILD SUCCEEDED`。
- App：`build/ios/DerivedData-2.6.34/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`。
- Bundle ID：`com.chendong.sichuanmahjong.iosdev`。
- 版本/构建号：`2.6.34 / 2.6.34`。
- 架构：arm64。
- `codesign --verify --deep --strict`：通过。
- 主程序 SHA-256：`e1180dcc67bf5bf99c89f9be046192e83db884860efad5842b443734ba9af297`。
- PCK SHA-256：`cce7f0907ea685bbe62d535cfcd6090542165518f629a83520931faf043045e3`。
- 最终 Xcode 日志：`build_logs/xcode_release_final.log`。

## 真机状态

- 目标设备：`dona‘s iPhone`，iPhone 15，CoreDevice ID `516E99D2-18B6-5DD8-94E1-6993510A036D`。
- 设备已配对并开启开发者模式，但本轮最后一次 CoreDevice 探测仍为 `State=unavailable`，此前详情为 `tunnelState=unavailable`、`ddiServicesAvailable=false`。
- 两次安装调用均未进入设备服务；最终错误为 CoreDevice 1011，无法定位当前可用设备。
- 因此本轮最强证据到“iOS arm64 签名 App 构建成功并验证产物”层，尚未达到“真机安装、启动、关键牌局”层，不能把安装写成已完成。
- 设备解锁并恢复 CoreDevice 通道（同一局域网或 USB 连接并信任）后，可直接覆盖安装本报告中的 2.6.34 App，无需重新修改代码。

本报告记录的是本次聚焦验证和设备状态，不建立新的固定回归清单。
