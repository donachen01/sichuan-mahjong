# 四川麻将新版工程

目标目录：`/Volumes/AI/Codex/四川麻将工程_20260701_v2`

这是从成熟内江麻将工程复制出的独立四川麻将新版工程。内江工程仅作为只读底稿，老四川工程仅作为规则、旧实现和测试样例参考；当前工程的代码、测试、AI Core、Android/iOS 打包都在本目录内维护。

## 当前版本

- 应用名：四川麻将新版
- 版本：`2.1.0`
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

## Android 打包

Debug APK：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_android_debug.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-2.1.0-direct-debug.apk`

Release APK：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_android_release.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-2.1.0-release.apk`

Release 脚本会读取本机签名文件：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/signing/release_keystore_info.txt`

当前 release 脚本仍保留一个 Godot Mono Android native library 的校验替换 workaround，来源记录在 `evidence/1.0.42_to_1.0.44_github_diff/`。这是打包链路 workaround，不代表当前规则或工程身份仍属于内江麻将。

## iPhone / Xcode 自用安装

导出 Xcode 工程：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_ios_xcode_project.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/ios/SichuanMahjong-2.1.0-ios-xcode/SichuanMahjongIOS.xcodeproj`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/ios/SichuanMahjong-2.1.0-ios-personal.ipa`（个人开发者签名归档包）

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

2.1.0 优化与发布验收已通过：

- 四川规则回归：`RULE REGRESSION OK: 26/26`
- UI 六问题回归：`VERIFY SIX ISSUES OK: 6/6`
- 定缺专项：`RULE REGRESSION OK: 6/6`
- 独立出牌评分器回归通过；线上 AI 分数不参与裁判评分
- 候选骨灰透视 AI 与冻结旧版 AI 完成同种子 100 局对战：候选组 36 局打完、14 局流局；旧版组 6 局打完、44 局流局；两组 `forced_stop=0`
- 候选 AI 独立评分复测 30 局：1,508 次出牌，平均分 `99.1227`，裁判第一选择命中率 `85.013%`
- C# AI Core Release build + smoke：0 warnings / 0 errors
- Godot C# Debug build：0 warnings / 0 errors
- Android release APK：包名 `com.chendong.sichuanmahjong`，`versionCode=210`，`versionName=2.1.0`，通过 APK Signature Scheme v2/v3 验签
- iOS Release App：Bundle ID `com.chendong.sichuanmahjong.iosdev`，版本 `2.1.0`，通过 Xcode 自动个人开发者签名和 `codesign --deep --strict`
- iOS 真机：已安装到配对的 iPhone 15，`devicectl` 启动成功，启动 5 秒后进程仍在运行

Godot headless 测试和导出会输出若干编辑器退出时的 RID/ObjectDB/resource leak 警告；这些警告发生在无窗口编辑器退出阶段。当前已分别用独立 C# 构建、签名产物检查、真机安装和真机启动验证发布链路。真机上的完整一局人工操作仍需以实际触控体验作为最终人工验收。
