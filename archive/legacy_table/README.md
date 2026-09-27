# 旧牌桌源码归档

2026-09-27 从 `scripts/game/MainTable.gd` 与 `scenes/table/MainTable.tscn` 移入。
当前启动链为 SplashScreen → game_mode_select → MainSceneV2；当前源码、测试和工具的资源引用核查没有发现对旧牌桌入口的调用。
原脚本 UID 保留，场景内部脚本路径指向此处。`.gdignore` 将本目录排除出 Godot 的运行资源扫描。
这些文件用于追溯旧界面实现；恢复使用前必须重新核对其四川规则、AI 和触控边界。

`AICoreBridge.gd`、旧 2D 牌显示与 Android 旧原生库来源仍有现行依赖，未归档或删除。
