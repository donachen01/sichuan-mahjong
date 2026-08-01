# 版本

当前应用版本：`2.6.16`

`2.6.16` 修正开局投骰与定缺交接、定缺印章文字/装饰/初始焦点、本家倒牌视觉尺寸、碰杠与手牌的统一 18 张共享布局，以及 iOS 结算关闭后的下一局触控路径。Android 继续使用已验证的 `gl_compatibility` 发布后端，iOS 保留 Forward+。

## 版本维护规则

- 每次正式发布同步更新 `project.godot`、`export_presets.cfg`、`VERSION.md` 与 `README.md`。
- Android 当前配置使用 `version/name=2.6.16`、`version/code=276`，产物文件名包含版本号。
- iOS 当前配置使用短版本号和构建版本 `2.6.16`；设备安装、启动与真机牌局验证必须和构建证据分层记录。
- 构建产物保留在 `build/android/` 与 `build/ios/`，验证证据保留在 `evidence/`。
- 版本完成标准区分源码测试、构建、签名、安装、启动和真机完整流程，不以其中一层替代另一层。
