# 四川麻将 2.6.48 皮肤化动作按钮交付记录

日期：2026-08-22

## 修正目标

上一版只是统一平涂样式，未满足“每个桌布皮肤设计同款碰、杠、胡按钮”的要求。本版改为六套独立、真实材质的圆形动作徽章：

- 使用每套桌布自身 `albedo_2k.jpg` 作为按钮面材质，而非仅混合色值。
- 结构统一为一层布面圆章、一圈老铜金属包边和大号中文字；没有圈中圈和方形背景。
- 切换桌布时，碰、杠、胡、取消同步切换对应的绉绒、亚麻、暖绒、暗纹、缎面或格绒按钮面。
- 仅改界面资源与动作栏渲染，玩法、计分、触控矩形、动作信号不变。

## 视觉核验

- 深翡翠绉绒动作栏：`visual/deep_emerald_action_badges.png`
- 青黛格绒动作栏：`visual/teal_check_action_badges.png`
- 两张同一操作场景截图可见圆章材质与纹理随皮肤切换，格纹按钮面与细绒按钮面不同。

## 工程验证

- Godot 导入六张新材质动作按钮：通过。
- `SichuanPremiumTableVisualContractRunner.gd`：通过，覆盖深翡翠与香槟缎面的真实纹理资源切换。
- `SichuanActionBarLayoutRunner.gd`：通过。
- `SichuanVersionConsistencyRunner.gd`：通过。
- `dotnet build SichuanMahjong.Godot.sln -c Release --nologo`：0 警告、0 错误。
- Xcode Release 构建和签名验证：通过。

## 真机安装

- 两台已连接 iPhone 均成功安装；应用查询均为 `2.6.48`。
- 自动启动被设备锁屏拒绝（CoreDevice 的 `Locked` 原因），并非应用崩溃。解锁手机后可直接打开应用验证界面。

产物：`build/ios/SichuanMahjong-2.6.48-signed.ipa`
