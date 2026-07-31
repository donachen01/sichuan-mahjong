# 四川麻将 2.6.15 Android 启动稳定性修复验证报告

日期：2026-08-01

## 结论

Android `2.6.15` / `versionCode 275` 已在免费的官方 Android Emulator（Android 15、ARM64）完成正式 APK 安装、版本读回、正常启动、C# runtime 绑定、牌桌显示、定缺触控、手牌打出和超过 95 秒的同 PID 稳定性验证。最终正常设备状态下 PID `2001` 连续存活 `01:56`，崩溃扫描为空。

最终 APK：`build/android/SichuanMahjong-2.6.15-release.apk`

- 大小：`150166278` bytes
- SHA-256：`7c0c84ed1bb504a1eeb869967f5316689ffaf21791946bfaad153a8c0aad77a5`
- 包名：`com.chendong.sichuanmahjong`
- 版本：`2.6.15` / `275`
- ABI：`arm64-v8a`
- 签名：APK Signature Scheme v2 / v3 通过
- 证书 SHA-256：`9ca9ba45de9a950e19f140e2d706d0fe187e90070601d162becf8848b6a75600`
- ZIP 完整性、zipalign：通过

## 根因与 A/B 证据

1. `2.6.14` 正式 APK 在官方模拟器中以 `forward_plus` / Vulkan 启动，出现 `QueuePresentKHR failed with error: 5`；应用长时间黑屏，C# runtime 约 27 至 33 秒后才进入 ready。
2. 未替换 Mono 原生库的基础导出包约 2 秒进入主循环，但引擎标识为非 Mono，并明确报错无法加载 `res://scripts/ai/SichuanCSharpRuntime.cs`。因此不能通过删除 Mono 原生库换取表面上的快速启动。
3. 作为 Mono 原生库来源且已知可用的旧 Android 包，其 Manifest 使用 `gl_compatibility`。当前四川包此前强制使用 `forward_plus`，与 Android 低兼容性运行环境不匹配。
4. 修复后 APK 的 `assets/_cl_` 固定包含 `--rendering-method` 和 `gl_compatibility`。设备日志读回 `usesVulkan(): false`、`renderer: gl_compatibility (CommandLine)`，并继续加载同一 Godot .NET/Mono 原生库和全部 C# runtime 内容。

## 模拟器设备验证

设备：官方 Android Emulator `Codex_Sichuan_API35`

- Android：15
- ABI：`arm64-v8a`
- 图形：Android Emulator OpenGL ES Translator / Apple M1 Pro
- 安装：`adb install -r` 成功
- 设备包信息：`versionName=2.6.15`、`versionCode=275`、`primaryCpuAbi=arm64-v8a`
- 正常冷启动：`am start -W` 成功，C# runtime 约 2 秒 ready
- 运行时：`usesVulkan(): false`、`renderer: gl_compatibility (CommandLine)`
- 交互：通过 Android touchscreen 输入完成定缺，并在本家回合打出一张缺门手牌；牌局继续推进
- 稳定性：同一 PID `2001` 存活 `01:56`
- 日志：无 `FATAL EXCEPTION`、`Fatal signal`、应用 ANR、应用进程死亡、`QueuePresentKHR` 或 Godot force quit

主要证据：

- `final_artifact_reinstall/install.txt`
- `final_artifact_reinstall/package.txt`
- `final_artifact_reinstall/relaunch_after_boot_settle.txt`
- `final_artifact_reinstall/runtime_milestones_over_95s.txt`
- `final_artifact_reinstall/process_elapsed_over_95s.txt`
- `final_artifact_reinstall/crash_scan_over_95s.txt`
- `final_artifact_reinstall/screen_relaunch_15s.png`
- `final_artifact_reinstall/screen_after_touch.png`
- `final_artifact_reinstall/screen_after_discard_touch.png`
- `final_artifact_reinstall/screen_over_95s.png`

## 冷启动环境边界

在模拟器刚完成系统启动、系统资源 overlay 和启动广播仍在更新时，曾立即安装并启动 APK。Android 在 C# 主循环开始后触发 Activity 资源配置重建，Surface 被回收，Godot 随后主动 force quit。等待系统启动收尾后，对同一已安装最终 APK 重新冷启动，应用正常运行并通过上述 `01:56` 稳定性与触控验证。该记录保留在 `final_artifact_reinstall/logcat_15s.txt`，用于区分“模拟器系统仍在启动”的环境状态和正式包的正常设备状态；后续自动化不得只等待 `sys.boot_completed=1`，还必须等待设备配置稳定。

## 源码与牌体回归

固定清单 `docs/ui_rework/emerald_final_runner_manifest_V1.txt` 本轮从头执行：`27/27 PASS`。

其中包括：

- 触控、定缺、反应按钮与 UI 恢复合同
- 四川规则与计分
- C# 合同和 `AI.Core` Release 编译
- 3D 牌桌、牌体质量和牌资源
- 碰、明杠、暗杠、加杠共享同一实体模型及三轴等比缩放
- 四档空间布局、相机和灯光

因此本次 Android 渲染后端修复没有改变规则、计分、AI、牌体尺寸、碰杠厚度、布局或触控合同。

## 未覆盖范围

- 本版本只重新发布 Android；iOS 未重新构建、签名或安装。
- 官方模拟器证据不替代用户具体 Android 真机的最终主观画面和整局长时体验；APK 已满足发布前的本机真实 Android runtime 门槛。
