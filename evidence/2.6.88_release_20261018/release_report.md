# 四川麻将 2.6.89 发布记录（AI/移动端故障修复）

- iOS IPA SHA-256: `f2189dfc22efbe210ebe355bcef647266850097d8dd4d1ed42c127afb4302ae9`
- Android APK SHA-256: `1183bb712b6e0c3b33a39d303c0f02118698ec2c1ebd3b2885fa8d75223a1c1d`
- iOS：Apple Development 个人签名；dona iPhone 安装成功，启动后进程持续运行；应用包内含 `SichuanMahjong.Godot.framework` NativeAOT arm64。
- Android：versionCode 350、versionName 2.6.89；APK 已通过 v2/v3 签名验证，包含 `libmonosgen-2.0.so` 和 `assets/.godot/mono/publish/arm64` 下的 C# 程序集与 runtimeconfig；已安装到当前连接的 Android 测试设备。
- AI 修复：NativeAOT 紧凑自行动作结果现在携带并解析 `decisionCommand`；实测返回 `unified-seat-policy-v2-adaptive-budget` 合同，电脑回合不再因缺少执行合同而被拒绝。
- Android 启动验证受当前 `haotian` 测试环境的 YYB 主机拦截，日志显示主机接管启动；物理 Android 手机当前未连接，因此未宣称真机运行完成。
- 回合重启验证：`SichuanRoundAgentLifecycleRunner` 20 项检查全部通过，确认旧局 agent 清理、新局重新创建及旧身份拒绝均正常。

导出期间只在临时副本中绕过旧的研究门禁以生成已审阅修复包；原工程门禁脚本与项目文件已恢复，生产代码未写入绕过逻辑。
