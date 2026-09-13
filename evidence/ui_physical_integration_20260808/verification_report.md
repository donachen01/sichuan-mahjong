# 四川麻将 2.6.32 物理一体化视觉改造验证报告

日期：2026-08-08

## 用户目标

在不改变已确认桌布颜色和干净短绒底色的前提下，统一牌桌主界面的线条、阴影、光照、材质、中心器、HUD、桌框和最新弃牌提示，使画面读成一个物理空间。

## 问题矩阵

| 项目 | 状态 | 实现与证据 |
| --- | --- | --- |
| 牌墙黑色长阴影 | 已验证 | 主光更靠近顶光，阴影不透明度 `0.94 -> 0.64`，环境光 `0.16 -> 0.22`，SSAO 收敛；Metal 三宽高比无纯黑围栏形态。 |
| 白牌过曝、绿背落黑 | 已验证 | 白牌统一为非发光暖象牙 PBR，绿背改为宽高光低清漆 PBR，移除本家/对家局部 emission；牌专用补光改为暖中性。 |
| 桌面工程辅助线感 | 已验证 | 外边界变细、变浅并进一步下沉；完整中心矩形删除，替换为八段短转角压痕。 |
| 中心器黑贴片/玻璃割裂 | 已验证 | 保持九对象与既有四方向几何，降低玻璃清漆、透射和金属反差，抬起烟玉暗部；密集弃牌画面仍保持层级。 |
| 四边桌框一体性 | 已验证 | 收窄并提亮皮革胶边，木框改为更中性的暖胡桃木和更高粗糙度；三宽高比均形成连续框体。 |
| HUD 多套边框与双重光晕 | 已验证 | 收敛为单一墨玉外壳、默认低对比青铜边、活动态单层 2px 古金边；移除持续呼吸闪烁和活动光晕，180ms 入场结束后关闭逐帧处理。 |
| 最新弃牌悬浮金色宝石 | 已验证 | 改为静态低矮古铜折角，尺寸约 `0.22` 世界单位，贴近牌面、无投影、无持续旋转；密集弃牌画面仍可定位。 |
| 桌布颜色与短绒底色保持 | 已验证 | `felt_basecolor.png`、`felt_normal.png`、`felt_orm.png` 哈希保持原值；本轮没有改写桌布生成算法。 |
| iPhone 2.6.32 真机画面 | 未验证 | 本轮没有导出、签名、安装或启动 iOS 2.6.32。 |

## 核心参数

- 环境光：`A9B79C / 0.22`
- 主光：`FFF1E1 / 0.79`，旋转 `(-70, -170, -6)`
- 主光阴影：opacity `0.64`，blur `1.90`，唯一实时投影光
- 牌专用补光：`DED8CC / 1.30`，无投影，只作用于麻将牌渲染层
- 牌桌 GLB：`16` 对象，生成前 `9576` 三角面
- 中心器 GLB：`9` 对象，`4` 材质，`1044` 三角面

## 聚焦验证

以下是本轮修改直接相关的单项测试，不是后续默认固定回归清单：

- `SichuanLightingQualityRunner`：PASS
- `SichuanTableMaterialQualityRunner`：PASS
- `SichuanTileVisualQualityRunner`：PASS
- `SichuanPremiumTableVisualContractRunner`：PASS
- `Sichuan3DTableStageRunner`：PASS
- `SichuanHudStateIntegrityRunner`：PASS
- `SichuanVersionConsistencyRunner`：PASS
- `SichuanTableMotionContractRunner`：PASS
- `SichuanTableLayoutContractRunner`：PASS
- `SichuanTableTouchTargetRunner`：PASS
- `SichuanCameraCompositionRunner`：PASS

新增门禁直接检查：四个座位牌在 180ms 入场后停止 `_process`；根版本文件、Godot 与 macOS/Android/iOS 导出版本一致；中心器烟玉玻璃、石墨底与古铜环的导入材质值能区分 2.6.31；桌体十二段凹槽 AABB 和胶边内外尺寸与 Blender 作者值一致。

Godot 版本：`4.6.2.stable.mono`。部分 HUD Runner 退出时仍输出既有 CanvasItem/ObjectDB/resource 清理诊断，但退出码均为 `0`，没有将警告写成测试通过条件。

## 构建与确定性

- `dotnet build SichuanMahjong.Godot.sln -c Release --no-restore`：成功，`0 warning / 0 error`
- `git diff --check`：通过
- 牌桌 GLB 连续 Blender 5.2 重建 SHA-256：`98d7428bc608d92d4e0016ee82beef652e6932271afbad445c4540788f9b1eba`
- 中心器 GLB 连续 Blender 5.2 重建 SHA-256：`e4ef734495269c5eeee9798c92ea492dbb2cb538706f9f2736e18e787259fdd3`
- 桌布 BaseColor SHA-256：`8e7b8686250a0b9bee7a5b907d3cb417201353f891f640e667114d4ada26f798`
- 桌布 Normal SHA-256：`34ba96033230cf094efe718035e19c72b260fbeaeaa03509986a1a023daa1848`
- 桌布 ORM SHA-256：`d8685cb6dde53f6a3889b7289dabf8e2d25fb17c05b663044deb418d63f4bdf9`

## Metal 成品

渲染环境：Apple M1 Pro / Metal 4.0 / Forward+

- `table_1365x768.png`
- `table_2048x1152.png`
- `table_2556x1179.png`
- `discard_pressure_warm_fill_2048x1152.png`

人工检查重点：牌墙阴影不再读成纯黑洞槽；白牌保留暖灰阶和倒角；绿背暗面可辨色；桌面完整中心矩形已消失；四边框体连续；HUD 无双重光晕；铜色弃牌标记不遮挡字面；三个宽高比无文字或控件重叠。

## 版本与结论边界

- Godot/macOS/iOS 版本名：`2.6.32`
- Android `versionName`：`2.6.32`
- Android `versionCode`：`292`
- 当前最强证据：源码合同、C# Release 构建、确定性 Blender 资产、Godot 真实 Metal 多分辨率成品。
- 尚不能声称：iOS 2.6.32 已导出、签名、安装、启动或在 iPhone 上完成触控与完整牌局验证。
