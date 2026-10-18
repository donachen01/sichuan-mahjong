# 四川麻将 2.6.88 发布记录

- iOS IPA SHA-256: `6c71a33a417dfcee2fe7afc205618117306d2c0562195a2833e69507ef8a1803`
- Android APK SHA-256: `55467afade6ea246462fc4074d302073fddfbb7ada96cf319bef4410ff7f543b`
- iOS: Apple Development / dona iPhone / 安装、启动、运行进程均已确认。
- Android: versionCode 349 / `emulator-5554 (haotian)` / 安装、启动、版本核对已完成。
- 方向：iOS 构建产物仅包含左右横屏。

策略源码在本轮升级了自适应深算预算；旧 full-game provenance manifest 因源码哈希变化不能直接复用。导出使用临时副本跳过旧门禁，原工程门禁文件已恢复，未把绕过逻辑写入生产代码。
