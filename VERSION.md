# 版本

当前应用版本：`2.6.15`

`2.6.15` 是 Android 启动稳定性修复版：Android 导出单独使用 `gl_compatibility` 渲染后端，避免在不稳定或不完整的 Vulkan 实现上启动后黑屏；iOS 及其他移动平台保留既有 Forward+ 配置。Godot .NET/Mono 原生库、C# 运行时与牌局资源必须同时保留，规则、计分、AI、牌体尺寸、布局和触控合同不变。

## 版本维护规则

- 每次正式发布同步更新 `project.godot`、`export_presets.cfg`、`VERSION.md` 与 `README.md`。
- Android 当前配置使用 `version/name=2.6.15`、`version/code=275`，产物文件名包含版本号。
- iOS 当前配置使用短版本号和构建版本 `2.6.15`；本版本只重新发布 Android，iOS 不以配置更新替代重新构建和设备验证。
- 构建产物保留在 `build/android/` 与 `build/ios/`，验证证据保留在 `evidence/`。
- 版本完成标准区分源码测试、构建、签名、安装、启动和真机完整流程，不以其中一层替代另一层。
