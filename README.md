# 四川麻将新版工程

目标目录：`/Volumes/AI/Codex/四川麻将工程_20260701_v2`

这是从成熟内江麻将工程复制出的独立四川麻将新版工程。内江工程仅作为只读底稿，老四川工程仅作为规则、旧实现和测试样例参考；当前工程的代码、测试、AI Core、Android/iOS 打包都在本目录内维护。

## 当前版本

- 应用名：四川麻将新版
- 版本：`2.2.0`
- Godot：`4.6.2.stable.mono`
- Android 包名：`com.chendong.sichuanmahjong`
- iOS Bundle ID：`com.chendong.sichuanmahjong.iosdev`
- Godot C# assembly：`SichuanMahjong.Godot`
- C# AI Core assembly：`SichuanMahjong.AI.Core`

## 当前规则范围

当前主规则已切换为四川麻将三门牌血战到底基线：

- 三门牌：条、筒、万
- 开局定缺
- 缺门牌必须先打
- 血战到底
- 一炮多响
- 抢杠胡
- 查叫
- 花猪
- 退杠
- 呼叫转移
- 四川番型与 3 番封顶结算基线

内江专属入口已在当前规则模式下关闭或替换：

- 报叫、报杠默认关闭
- 两门牌计数已改为三门 27 类牌计数
- 内江经典模式不再作为可选默认模式
- 内江结算入口不作为当前四川规则路径

说明：少量兼容函数、历史证据和旧命名还保留在非主路径、历史文档或打包 workaround 中，便于追溯迁移来源；当前规则入口、测试和打包产物均按四川新版执行。

## 主要结构

- `autoload/GameState.gd`：主状态机、规则流程、结算、AI 调用入口
- `scripts/core/`：四川规则判定、番型、查叫/花猪/退杠等核心逻辑
- `scripts/ai/`：Godot AI 桥接、四川 GDScript AI 辅助、C# runtime 绑定
- `dotnet/AI.Core/`：C# AI Core
- `dotnet/AI.Core.Cli/`：C# AI 诊断与主机传输入口
- `dotnet/AI.Core.Smoke/`：C# AI smoke 测试
- `tests/current/`：当前四川回归测试
- `tools/`：AI Core 构建、Android/iOS 导出脚本
- `build/android/`：Android APK 输出
- `build/ios/`：iOS Xcode 工程输出
- `evidence/`：迁移和打包证据、AI 压测输出

## 常用验证命令

所有命令都显式使用绝对路径。

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/SichuanRuleRegressionRunner.gd'
```

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/SichuanUiSixIssuesRunner.gd'
```

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/sichuan_ding_que_regression.gd'
```

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/sichuan_ai_pressure_benchmark.gd' -- --rounds=2 --max-steps=2000 --preset=bone_ash --output='/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/sichuan_ai_pressure_smoke.json' --csv-output='/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/sichuan_ai_pressure_smoke.csv'
```

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/build_ai_core.sh'
```

```bash
/opt/homebrew/opt/dotnet/libexec/dotnet build '/Volumes/AI/Codex/四川麻将工程_20260701_v2/SichuanMahjong.Godot.csproj' -c Debug
```

## 紧凑立体牌桌 UI 开发快照

当前 `2.2.0` 已完成“蜀锦玉案”高端中式会所牌桌：保留紧凑立体布局、四向麻将牌独立轨道和零重叠合同，统一使用暖象牙白厚牌、深玉绿牌背、左上高光与右下投影。桌面由程序化回纹、云雷纹、菱格锦纹、卷草纹和缠枝纹共同构成 5.5% 暗纹层，左上暖玉柔光和四周暗角在不压低牌面可读性的前提下提升材质层次。

零重叠压力合同：

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/SichuanDenseTableLayoutRunner.gd'
```

四档视觉证据位于：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_1365x768.png`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_2048x1152.png`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_2400x1080.png`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_2556x1179.png`

`2.2.0` 已完成源码回归、四档 Metal 视觉截图、Android release 导出与签名校验、iOS Xcode/NativeAOT 导出和 arm64 开发签名构建。安装与启动仍独立以实际设备在线状态为准，不用构建成功代替真机验收。

## Android 打包

Debug APK：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_android_debug.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-2.2.0-direct-debug.apk`

Release APK：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_android_release.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-2.2.0-release.apk`

Release 脚本会读取本机签名文件：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/signing/release_keystore_info.txt`

当前 release 脚本仍保留一个 Godot Mono Android native library 的校验替换 workaround，来源记录在 `evidence/1.0.42_to_1.0.44_github_diff/`。这是打包链路 workaround，不代表当前规则或工程身份仍属于内江麻将。

## iPhone / Xcode 自用安装

导出 Xcode 工程：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_ios_xcode_project.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/ios/SichuanMahjong-2.2.0-ios-xcode/SichuanMahjongIOS.xcodeproj`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/ios/DerivedData-2.2.0/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`（arm64 个人开发签名 App）

自用安装流程：

1. 在 Mac 上安装完整 Xcode，而不只是 Command Line Tools。
2. 打开上面的 `SichuanMahjongIOS.xcodeproj`。
3. 在 Xcode 里登录 Apple ID。
4. 将 Team 切到个人开发者团队。
5. 保持或按需修改 Bundle ID：`com.chendong.sichuanmahjong.iosdev`。
6. iPhone 打开开发者模式并信任本机。
7. Xcode 选择真机后 Run。

该流程用于个人自用安装，不走 App Store，不需要购买开发者年费；免费个人签名通常需要定期重新安装。

## 当前已验证

2.2.0 核心与发布验收：

- 四川规则 `32/32`、定缺 `7/7`、C# 移动合同 `29/29`、AI 解释 UI `9/9`、界面六问题 `7/7` 全部通过。
- C# 精确牌形穷举 131,841 状态无失败；19 组 PDF 黄金牌例全部通过。
- 30 局非透视门禁平均裁判分差 `158.18`、严重错误率 `4.42%`，优于冻结旧版 `628.48` 和 `16.45%`。
- 200 局真实 C# 对局（100 局非透视 + 100 局骨灰透视）全部自然结束：`forced_stop=0`、非法动作 `0`、本地 AI fallback `0`。
- 10,517 次实际出牌综合平均裁判分差 `74.01`，严重错误率 `1.91%`，Top-1 一致率 `81.93%`。
- 线上出牌、碰、杠、胡、过由 C# 决策；C# 失败时明确报错，不使用 GDScript 简化 AI 自动代打。
- Android release APK：`com.chendong.sichuanmahjong`，`versionCode=220`，`versionName=2.2.0`，arm64，v2/v3 签名验证通过后才视为完成。
- iOS Release App：`com.chendong.sichuanmahjong.iosdev`，版本 `2.2.0`，arm64 NativeAOT，完成个人开发者签名和 `codesign --deep --strict` 后再进入真机安装验收。
- iOS 真机：已安装到配对的 iPhone 15；多次自动启动均因手机保持锁屏而被 iOS 拒绝，未取得本版真机启动和完整触控对局证据。

完整验收数据见 `测试数据统计/PDF16份落地验收_20260713/README.md`。Godot headless 测试和导出仍会输出编辑器退出时的 RID/ObjectDB/resource leak 警告；真机完整一局仍需解锁手机后人工验收。
