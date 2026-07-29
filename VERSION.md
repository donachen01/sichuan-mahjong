# 版本

当前应用版本：`2.6.9`

`2.6.9` 是 Blender 连续胡桃木托盘与深森林绿绒面材质升级版：重新生成连续圆角木框、内嵌深绿皮革 gasket、纵向木纹浮雕和更接近目标图的青绿色短绒 PBR 桌布；不改变规则、计分、AI、牌局几何和触控合同。

## 版本维护规则

- 每次正式发布同步更新 `project.godot`、`export_presets.cfg`、`VERSION.md` 与 `README.md`。
- Android 当前配置使用 `version/name=2.6.9`、`version/code=269`，产物文件名包含版本号。
- iOS 当前使用短版本号和构建版本 `2.6.9`，产物目录名包含版本号。
- 构建产物保留在 `build/android/` 与 `build/ios/`，验证证据保留在 `evidence/`。
- 版本完成标准区分源码测试、构建、签名、安装、启动和真机完整流程，不以其中一层替代另一层。
