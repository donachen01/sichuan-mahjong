# 四川麻将 2.6.28 iOS 发布报告

## 用户问题与修正

- 用户截图显示：东、西出牌时，激活红色方向片会透过透明计数镜片进入余牌数字圆圈；北、南不会。
- 根因是旧四方向网格不对称：东/西内缘使用 `y=±0.20`，进入透明镜片半径 `0.365`；北/南内缘使用 `x=±0.38`，停在镜片外。
- 四个真实 3D 状态片现统一使用半径 `0.460` 的分段圆弧切口，完整避让半径 `0.455` 的古铜计数环。没有改成不透明遮盖，也没有使用 2D 贴片掩盖问题。
- 激活色继续精确锁定为 `#A13D2D`；中心四边黄色外线继续保持删除状态。

## 几何、渲染与回归证据

- Blender 确定性生成 SHA-256：`5584990ba79587f7fef28ecd1c57ebefce433de47ae0ce221ded00e88b8fe717`。
- 中心 GLB：`9` 个静态对象、`4` 个材质、`1,044` 三角面。
- Godot 导入后的四个状态片逐顶点门禁：距中心最小半径均不低于 `0.458`；最终资产实测 `0.4600`。
- Apple M1 Pro / Metal 4.0 / Forward+ 四方向截图像素门禁：余牌圆圈探针内红色像素均为 `0`；外圈黄色像素均为 `0`；激活红采样相对 `#A13D2D` 最大通道误差为 `0`。
- 四方向近景：`evidence/ui_center_counter_clearance_2_6_28/metal_counter_clearance_four_seats_center_crop_20260804.png`。
- 固定发布清单：`27/27 PASS`，日志位于 `full_manifest_logs/`。

## iOS 构建与产物

- Godot iOS 导出：PASS；NativeAOT 已嵌入。
- Xcode `Release-iphoneos`：`BUILD SUCCEEDED`，Apple Development 签名通过。
- App 标识：`com.chendong.sichuanmahjong.iosdev`；版本/构建号：`2.6.28/2.6.28`。
- App 主程序：arm64 Mach-O；`SichuanMahjong.Godot.framework`：arm64 动态框架，包含 `SichuanCSharpRuntime` 与 `EvaluateDiscardCandidate`。
- 导出 PCK 与签名 App 内 PCK SHA-256 一致：`47f3c36b83f53db035f0250d0868d8d90bb4b76758c188d5a769f93d5fd5c878`。
- 对签名 App 内 PCK 挂载检查：中心模型 `9` 对象、`1,044` 三角面、四状态片最小半径 `0.4600`，`PACKAGED_IOS_CENTER_MODEL_PASS`。
- IPA：`build/ios/SichuanMahjong-2.6.28-development.ipa`，`97,383,879` bytes，SHA-256 `fbeff09087f96487a2d4245c1afc42a1b329d3376331ad40cb11a0bad1b6339b`，ZIP 完整性通过。

## iPhone 安装状态

- 目标设备：`dona‘s iPhone`，iPhone 15，设备已配对。
- 远程覆盖安装成功；设备应用清单读回 `com.chendong.sichuanmahjong.iosdev`，版本/构建号为 `2.6.28/2.6.28`。
- 首次和第二次远程启动均被 iOS 以 `Locked` 拒绝；这是设备锁屏状态，不是应用崩溃。等待设备解锁后重试启动和延时进程检查。

## 签名期限与验收边界

- 描述文件：`iOS Team Provisioning Profile: com.chendong.sichuanmahjong.iosdev`，Team `FCB4ZVWWD8`。
- 到期时间：`2026-08-06 20:25:19 CST`。这是个人开发签名，自用安装在到期后需要重新签名并安装。
- 当前最强证据已到真实 iPhone 安装与设备侧版本读回；设备解锁前尚未取得本轮前台启动和延时 PID 证据。完整一局、真实手指连续触控和手机上的最终视觉感受仍属于人工验收边界。
