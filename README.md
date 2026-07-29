# 四川麻将新版工程

目标目录：`/Volumes/AI/Codex/四川麻将工程_20260701_v2`

这是从成熟内江麻将工程复制出的独立四川麻将新版工程。内江工程仅作为只读底稿，老四川工程仅作为规则、旧实现和测试样例参考；当前工程的代码、测试、AI Core、Android/iOS 打包都在本目录内维护。

## 当前版本

- 应用名：四川麻将新版
- 版本：`2.6.9`
- Godot：`4.6.2.stable.mono`
- Android 包名：`com.chendong.sichuanmahjong`
- iOS Bundle ID：`com.chendong.sichuanmahjong.iosdev`
- Godot C# assembly：`SichuanMahjong.Godot`
- C# AI Core assembly：`SichuanMahjong.AI.Core`

## 当前规则范围

当前主规则已切换为四川麻将三门牌血战到底基线：

- 三门牌：条、筒、万
- 开局定缺
- 缺门牌必须先打
- 血战到底
- 一炮多响
- 抢杠胡
- 查叫
- 花猪
- 杠钱独立即时结算（流局不退税）
- 呼叫转移
- 四川番型与 4 番（16 倍）封顶结算基线；自摸固定加 1 底、杠钱独立即时结算

内江专属入口已在当前规则模式下关闭或替换：

- 报叫、报杠默认关闭
- 两门牌计数已改为三门 27 类牌计数
- 内江经典模式不再作为可选默认模式
- 内江结算入口不作为当前四川规则路径

说明：少量兼容函数、历史证据和旧命名还保留在非主路径、历史文档或打包 workaround 中，便于追溯迁移来源；当前规则入口、测试和打包产物均按四川新版执行。

## 主要结构

- `autoload/GameState.gd`：主状态机、规则流程、结算、AI 调用入口
- `scripts/core/`：四川规则判定、番型、查叫/花猪/退杠等核心逻辑
- `scripts/ai/`：Godot AI 桥接、四川 GDScript AI 辅助、C# runtime 绑定
- `dotnet/AI.Core/`：C# AI Core
- `dotnet/AI.Core.Cli/`：C# AI 诊断与主机传输入口
- `dotnet/AI.Core.Smoke/`：C# AI smoke 测试
- `tests/current/`：当前四川回归测试
- `tools/`：AI Core 构建、Android/iOS 导出脚本
- `build/android/`：Android APK 输出
- `build/ios/`：iOS Xcode 工程输出
- `evidence/`：迁移和打包证据、AI 压测输出

## 常用验证命令

所有命令都显式使用绝对路径。

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/SichuanRuleRegressionRunner.gd'
```

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/SichuanUiSixIssuesRunner.gd'
```

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/sichuan_ding_que_regression.gd'
```

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/sichuan_ai_pressure_benchmark.gd' -- --rounds=2 --max-steps=2000 --preset=bone_ash --output='/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/sichuan_ai_pressure_smoke.json' --csv-output='/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/sichuan_ai_pressure_smoke.csv'
```

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/build_ai_core.sh'
```

```bash
/opt/homebrew/opt/dotnet/libexec/dotnet build '/Volumes/AI/Codex/四川麻将工程_20260701_v2/SichuanMahjong.Godot.csproj' -c Debug
```

## 透视地狱老手算法恢复

`2.2.1` 修复了透视地狱模式此前使用独立简化评分、绕开正式教程老手决策栈的问题。现在透视信息只作为老手决策之上的精确攻防增益：合法候选、定缺强制、成叫/净分期望、清一色路线、刻子保护和路线连续性均来自正式老手引擎；三家 AI 仍共享人类手牌、其他 AI 手牌和精确牌墙，用于避免玩家胡牌、降低点炮并进行协同压制。出牌与碰/杠/胡/过反应共享连续牌脑，不再出现“刚拆刻又碰回”的独立通路冲突。

## 参考蓝桌 3D 与旧功能恢复

`2.6.9` 完成 Blender 桌体材质升级：连续圆角温暖胡桃木托盘、连续深绿皮革 gasket、纵向木纹浮雕和更接近目标图的青绿色短绒 PBR 桌布；不改变规则、计分、AI、牌局几何和触控合同。2.6.8 的杠上花、自摸结算和暗杠四背回归继续保留。

`2.6.2` 依据最终目标图完成第二次空间校准：中央余牌和四家弃牌整体上移，本家碰杠移至手牌左侧并按副露数量动态调整手牌，三家 AI 字面方向统一旋转 180°；AI 点炮胡牌保留原手牌，只在旁边增加胡牌张与唯一来源箭头。四家姓名框按外围轨道重排，左上缩进态改成 76×76 加粗汉堡图标，展开为不遮挡牌局的横向工具条。最终 4 状态×4 分辨率 Metal 矩阵、全量回归和独立设计复核记录见 `docs/ui_rework/四川麻将目标图布局二次校准验收报告_V1.md`。

`2.6.1` 对照商业目标图校正三家 AI 暗手牌姿：左右牌列沿桌边向远端收敛、向本家前景外扩，对家水平居中，牌背保留象牙顶沿、厚度和接触阴影；AI 点炮胡牌只展示唯一胡牌张和来源箭头。带符号的透视量化与第二轮独立设计复评已通过，详见 `docs/ui_rework/四川麻将对手牌姿与点炮展示验收报告_V1.md`。

`2.6.0` 将参考蓝桌 3D 改造按七道量化门禁正式收口：长焦透视构图、四家牌组排布、暖中性牌体与高对比字面、夏日蓝桌材质、左上主光/右下阴影/AO、四家 HUD 和全部旧功能均通过双设计师复核；胡牌状态新增明确的来源玩家文字与箭头，AI 面板、工具栏和响应状态保持真实输入与快照合同。桌面 Metal 600 帧性能压力门槛、全量回归以及 iOS 构建/签名/安装分层验收记录见 `docs/ui_rework/四川麻将动效触控性能与iOS交付验收报告_V1.md`。

`2.5.0` 按成熟移动麻将参考图提取并落地蓝色桌面、深蓝外沿、绿色牌背、中性白牌面和条/筒/万定缺色；本家及三家 AI 的暗手均竖立，本家副露靠近玩家边缘，胡牌后整手倒下并分离胡牌张，以金色箭头标明点炮来源。自摸/胡与取消按钮、明牌动态刷新、选牌和最新弃牌反馈已恢复，左上工具栏增加触摸级模拟鼠标抑制，避免同步重排期间误触相邻按钮。规则、计分和 AI 决策链不变。

`2.4.0` 将实际牌局表现层重构为“3D 牌桌世界 + 2D 原生 HUD”：Blender 确定性生成的倒角象牙牌体和深色会所桌体、Godot 透视相机、蜀锦程序化材质、左上单投影主光，以及真实的牌墙/手牌/副露/弃牌空间层次。这一版未消耗 Tripo3D 额度，规则、计分、AI 和原操作回调均保持不变；可通过 `ui/mahjong_3d_enabled=false` 回退到原 2D 表现层。

`2.3.0` 将主牌桌升级为“蜀锦玉案”商业成熟效果：在不改动规则、计分、AI 和已验证触控通路的前提下，增加固定视角浅透视桌体、深色厚边与旧铜内沿、四家原创玉印身份层、中央四向风盘，并把碰/杠/胡/过改为大型浮空圆印按钮。四档横屏比例保持无黑边、无裁切和大牌面可读性。

`2.2.2` 修复 iOS 将同一次物理触摸同时发送为 `ScreenTouch` 和模拟 `MouseButton` 时，左上展开/缩进入口及 AI 提示、难度、明牌按钮被执行两次而呈现为“偶尔按不动”的问题。现在第二个跨来源重复事件会被消费但不重复执行；连续真实触摸仍逐次立即生效。

## 紧凑立体牌桌 UI 开发快照

`2.2.2` 继续保留 `2.2.0` 已完成的“蜀锦玉案”高端中式会所牌桌：紧凑立体布局、四向麻将牌独立轨道和零重叠合同，统一使用暖象牙白厚牌、深玉绿牌背、左上高光与右下投影。桌面由程序化回纹、云雷纹、菱格锦纹、卷草纹和缠枝纹共同构成 5.5% 暗纹层，左上暖玉柔光和四周暗角在不压低牌面可读性的前提下提升材质层次。

零重叠压力合同：

```bash
'/Applications/Godot.NET.app/Contents/MacOS/Godot' --headless --path '/Volumes/AI/Codex/四川麻将工程_20260701_v2' --script 'res://tests/current/SichuanDenseTableLayoutRunner.gd'
```

四档视觉证据位于：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_1365x768.png`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_2048x1152.png`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_2400x1080.png`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/evidence/ui_2.2.0_20260716/table_2556x1179.png`

`2.2.0` 的四档 Metal 视觉截图继续作为牌桌视觉基线；`2.2.2` 新增左上工具栏 iOS 双事件与连续真实触摸回归，并重新执行 iOS Xcode/NativeAOT 导出、arm64 开发签名、真机安装与启动验收。安装与启动独立以实际设备在线状态为准，不用构建成功代替真机验收。

## Android 打包

Debug APK：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_android_debug.sh'
```

当前 Android Release 产物（`2.6.9`）：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-2.6.9-release.apk`
- 包名：`com.chendong.sichuanmahjong`
- 版本：`versionCode=269`、`versionName=2.6.9`
- ABI：`arm64-v8a`
- 文件大小：`766,713,674` bytes
- SHA-256：`f26539e862853685a04cad413209e94b452bcb3a688494de304655a5b4cb74ac`
- `apksigner verify --verbose`：v2/v3 通过；`aapt dump badging` 核对 `versionCode=269`、`versionName=2.6.9`、`minSdk=24`、`targetSdk=35`

Release APK：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_android_release.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/SichuanMahjong-<版本>-release.apk`

Release 脚本会读取本机签名文件：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/android/signing/release_keystore_info.txt`

当前 release 脚本仍保留一个 Godot Mono Android native library 的校验替换 workaround，来源记录在 `evidence/1.0.42_to_1.0.44_github_diff/`。这是打包链路 workaround，不代表当前规则或工程身份仍属于内江麻将。

## iPhone / Xcode 自用安装

导出 Xcode 工程：

```bash
/bin/zsh '/Volumes/AI/Codex/四川麻将工程_20260701_v2/tools/export_ios_xcode_project.sh'
```

输出：

- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/ios/SichuanMahjong-2.6.9-ios-xcode/SichuanMahjongIOS.xcodeproj`
- `/Volumes/AI/Codex/四川麻将工程_20260701_v2/build/ios/DerivedData-2.6.9/Build/Products/Release-iphoneos/SichuanMahjongIOS.app`（完成个人开发签名构建后生成）
- `xcodebuild`：`BUILD SUCCEEDED`；成品主程序为 `arm64`，`codesign --deep --strict` 通过
- `Info.plist`：Bundle ID `com.chendong.sichuanmahjong.iosdev`，短版本/构建版本均为 `2.6.9`
- 成品 PCK SHA-256：`a03d95f8d23a96ae0369eb47cbb62f584349a3b9a0d6720b0e246c1c5612df82`

自用安装流程：

1. 在 Mac 上安装完整 Xcode，而不只是 Command Line Tools。
2. 打开上面的 `SichuanMahjongIOS.xcodeproj`。
3. 在 Xcode 里登录 Apple ID。
4. 将 Team 切到个人开发者团队。
5. 保持或按需修改 Bundle ID：`com.chendong.sichuanmahjong.iosdev`。
6. iPhone 打开开发者模式并信任本机。
7. Xcode 选择真机后 Run。

该流程用于个人自用安装，不走 App Store，不需要购买开发者年费；免费个人签名通常需要定期重新安装。

## 当前已验证

2.6.9 连续胡桃木托盘与深森林绿绒面发布：

- Android Release APK 已导出并通过 v2/v3 签名校验，版本 `269/2.6.9`；当前 `adb devices -l` 没有 Android 设备，因此未做 Android 真机安装。
- iOS Release App 已完成 Xcode/NativeAOT arm64 编译和个人开发签名；安装命令已对已配对的 iPhone 15 返回成功，随后启动重试返回成功，但 CoreDevice 隧道随后进入 `connecting`，尚未取得稳定的设备版本/PID 查询证据。
- 本轮最强证据到 iOS 成品签名和安装命令成功；完整一局、真实触控手感、长时性能与稳定启动仍需设备重新显示 `available` 后复核。

2.6.8 杠上花、暗杠四背与参考翡翠织纹桌布：

- 使用真实 `GameState` 状态覆盖“本家暗杠二条、补到牌墙最后一张一条、合法完成牌型”的完整链路：余牌变为 0 后，公开快照仍提供自摸入口，执行结果为 `gang_self_draw`。
- 该用例的胡牌直接结算为杠上花 1 番：基础 2 分、每家固定另加 1 分，即每家付 3 分；暗杠钱另算，每家再付 2 分。普通自摸与杠上花的 0–4 番逐档付款表也全部通过。
- 暗杠四张牌全部以分离的翡翠牌背展示；3D 主桌与 2D 回退桌统一使用参考翡翠绿、细密交叉织纹与边缘低浮雕云纹，不生成品牌文字。Metal 视觉证据位于 `evidence/ui_reference_green_20260724/`。
- 四川规则 `33/33`、四川计分、胡/取消触控、HUD 状态、结算 UI、恢复 UI、桌体材质、高端视觉和 3D 桌面合同均通过；C# Release 构建为 `0 warning / 0 error`。
- Android `2.6.8` Release APK 已通过 `zipalign`、v2/v3 签名、压缩完整性、版本及 ARM64 Mono 原生库校验；SHA-256 为 `19625dbbd28936dd02006e7eb3f5facc3ca1d2f00203f06ac6a4697c8f69cacb`。
- iOS `2.6.8/2.6.8` 已完成 Xcode/NativeAOT Release 开发签名构建；主程序和 C# framework 均为 `arm64`，`codesign --deep --strict` 通过，PCK SHA-256 为 `bcd3ef0782ec4abe31ae6e00036ff0006fa21b4f77ea3f104a3c3ddebfed2464`。
- `2.6.8/2.6.8` 已覆盖安装到 `dona‘s iPhone`（iPhone 15）；设备安装数据库确认版本正确，应用启动成功，延时检查时进程 PID `41785` 仍然存活。
- 当前没有 Android 设备连接；Android 最强证据到已签名安装包完整性。iOS 自动化证据已到真机安装、设备版本查询、启动和进程存活；完整一局与真实触控手感仍由用户在手机上人工验收。

2.6.7 结算明细对齐与全面毛绒桌布：

- 结算最终收分继续以权威总账为准；牌墙流局时，已胡玩家收到的查大叫现在独立显示为“查大叫收益（已胡）”，所有有符号明细相加严格等于顶部和左侧最终收分。
- 截图等价回归已覆盖 `自摸 +4 + 暗杠 +6 + 已胡查大叫 +1 = 最终 +11`，并防止自摸固定加底被重复展示或重复计入。
- 3D 主桌与 2D 回退桌移除菱格、云纹、回纹和卷草等几何图案，统一使用覆盖整张桌面的细密交错短绒、顺逆毛明暗与高粗糙度毛毡；Metal 证据位于 `evidence/ui_settlement_plush_20260724/`。
- 四川计分专项、四川规则 `32/32`、结算 UI、恢复 UI、桌体材质、高端视觉及 3D 桌面聚焦合同均通过；C# Release 构建为 `0 warning / 0 error`。
- Android `2.6.7` Release APK 已通过 `zipalign`、v2/v3 签名、压缩完整性、版本及 ARM64 Mono 原生库校验；SHA-256 为 `785be42d19502863fc461d2a33baad3be436994679d0e86eda86a9bba7acb56f`。
- iOS `2.6.7/2.6.7` 已完成 Xcode/NativeAOT Release 开发签名构建；主程序和 C# framework 均为 `arm64`，`codesign --deep --strict` 通过，PCK SHA-256 为 `1231b54870b4741a0b4a0448215649d7d134d5281c61f17f54ec8a304b523852`。
- `2.6.7/2.6.7` 已覆盖安装到 `dona‘s iPhone`（iPhone 15）；设备安装数据库确认版本正确，应用启动成功，延时检查时进程 PID `41393` 仍然存活。
- 当前没有 Android 设备连接；Android 最强证据到已签名安装包完整性。iOS 自动化证据已到真机安装、设备版本查询、启动和进程存活；完整一局、真实触控手感与长时性能仍由用户在手机上人工验收。

2.6.6 对手明暗牌、自摸展示、退出交互与副露箭头修正：

- 三家对手暗手共用同一套翡翠牌背材质；明牌模式同时平铺亮明上家、对家、下家。
- AI 自摸整手平扣牌背；本家自摸整手正面平铺，并在自摸张上显示唯一旋转金色标记。
- 左上展开工具栏提供 156 px 宽的“退出游戏”按钮和二次确认；iOS 确认后走平台支持的进程退出通路。
- 碰、杠来源箭头统一为小号亮蓝色，固定在第二张副露牌正上方；最终 Metal 证据位于 `evidence/ui_five_corrections_20260723/final/`。
- 3D 桌面、明暗牌、自摸归属、箭头定位和退出触控聚焦合同均通过。
- iOS `2.6.6/2.6.6` 已完成 Xcode/NativeAOT Release 开发签名构建；主程序和 C# framework 均为 `arm64`，`codesign --deep --strict` 通过，PCK SHA-256 为 `f7adb184bfaf0423d92cc35cb8b3cd90e95c9364eeef14c63cf4e79ca838a4b6`。
- `2.6.6/2.6.6` 已覆盖安装到 `dona‘s iPhone`（iPhone 15），设备安装数据库确认版本正确，并成功启动 `com.chendong.sichuanmahjong.iosdev`，进程 PID 为 `37060`。
- Android `2.6.6` Release APK 已完成导出、zipalign 校验、v2/v3 签名验证和压缩结构校验；包名 `com.chendong.sichuanmahjong`，`versionCode=266`，仅包含 `arm64-v8a` 原生架构。
- Android APK SHA-256 为 `3a5a611fe230a797fb820c6873a57de69cb79eafa1c0fd93278a70d2c85e84cf`；当前没有 Android 设备连接，因此本轮最强证据到已签名安装包完整性，未包含 Android 真机安装、启动和完整牌局。

2.6.5 暗纹、自摸扣牌、碰杠来源与计分重构：

- 桌面新增低对比蜀锦菱格、云浪和回纹暗纹；最终本机 Metal 证据位于 `evidence/ui_scoring_texture_20260723/table_1365x768_v2.png`。
- 自摸后整手麻将平扣到桌面，全部只显示统一翡翠牌背；证据位于 `evidence/ui_scoring_texture_20260723/self-draw_1365x768_v2.png`。
- 碰、明杠、补杠按实际 `from_seat` 标识来源牌，以座位区分颜色的大箭头和“上家出/对家出/下家出/本家出”标签展示；证据位于 `evidence/ui_scoring_texture_20260723/right-meld_1365x768_v2.png`。
- 四川计分专项覆盖 11 种基础牌型、带根、杠上花、抢杠胡、杠上炮、0～4 番封顶、自摸固定加底、三类杠钱、呼叫转移、花猪和查大叫，专项 Runner 通过；原四川规则回归 `32/32` 通过。
- 3D 桌面、材质、结算 UI、恢复 UI、触控目标和高端桌面视觉共 6 组聚焦 Runner 全部通过；Godot 项目导入/解析退出码为 0。
- C# AI Core Release 构建为 `0 warning / 0 error`；精确牌形穷举 `131,841` 状态无失败，19 组 PDF 黄金牌例继续通过。
- iOS `2.6.5/2.6.5` 已完成 Xcode/NativeAOT Release 开发签名构建；主程序为 `arm64`，`codesign --deep --strict` 通过。
- `2.6.5/2.6.5` 已覆盖安装到 `dona‘s iPhone`（iPhone 15），`devicectl` 查询确认设备安装版本并成功启动 `com.chendong.sichuanmahjong.iosdev`。
- 自动化证据最强到真机安装和启动成功；完整一局、真实触控手感、长时性能、发热与耗电仍由用户在手机上人工体验验收。

2.6.3 历史 UI 核心验收与 iOS 发布进度：

- 3D 牌桌合同覆盖四家手牌、副露、弃牌、牌墙、明牌开/关、上下家居中、最新弃牌、本家选牌与屏幕点击映射；2D 回退合同独立通过。
- Blender 5.2 确定性生成两个核心 GLB；V1 核心资产 `Tripo 调用=0`、`外部费用=0`。
- 最终目标图二次校准的 Metal 证据位于 `evidence/ui_target_layout_20260719/final_matrix/`：`table`、`3d-reveal`、`ai-discard-win`、`max-meld` 四种状态覆盖 1365×768、2048×1152、2400×1080、2556×1179 四档横屏，共 16 张。

- 商业成熟视觉、高端牌桌、布局、动效、触控、六项 UI、恢复功能、紧密牌局和 iOS 字体聚焦回归全部通过。当前 Godot Runner `27/27`，四档摄像机合同 `4/4`。
- 本轮六项布局/状态合同全部通过；独立设计最终复核 `24/25`，P0/P1/P2 均为 0。目标图比例项为 4/5，其余空间秩序、牌姿真实性、状态完整性和移动端可读性均为 5/5。

- 四川规则 `32/32`、定缺 `7/7`、C# 移动合同 `29/29`、AI 解释 UI `9/9`、界面六问题 `7/7` 全部通过。
- C# 精确牌形穷举 131,841 状态无失败；19 组 PDF 黄金牌例全部通过。
- 30 局非透视门禁平均裁判分差 `158.18`、严重错误率 `4.42%`，优于冻结旧版 `628.48` 和 `16.45%`。
- 200 局真实 C# 对局（100 局非透视 + 100 局骨灰透视）全部自然结束：`forced_stop=0`、非法动作 `0`、本地 AI fallback `0`。
- 10,517 次实际出牌综合平均裁判分差 `74.01`，严重错误率 `1.91%`，Top-1 一致率 `81.93%`。
- 线上出牌、碰、杠、胡、过由 C# 决策；C# 失败时明确报错，不使用 GDScript 简化 AI 自动代打。
- 透视地狱先继承完整老手候选和路线，再叠加精确全牌攻防；新增四组降智回归全部通过。
- 100 局透视地狱审计全部自然结束：`forced_stop=0`，5,403 次实际出牌全部匹配 C# 决策并带有老手主线和路线诊断；平均老手裁判分 98.89、Top-1 一致率 84.82%、严重错误率 0.46%、点炮率 21.25%。
- 左上工具栏 iOS 双事件压力回归连续 10 次进程执行全部通过；每次内部连续 12 轮覆盖展开、AI 提示、难度、明牌和缩进，并验证连续真实触摸不会被去重误拦截。
- Android 版本配置：`com.chendong.sichuanmahjong`，`versionCode=263`，`versionName=2.6.3`；本轮未重新导出 Android APK。
- iOS 2.6.3 Xcode 工程和 NativeAOT 当时已重新导出，但当轮因 provisioning profile 缺失而停在签名前；该历史阻塞已在后续版本解除。

完整验收数据见 `测试数据统计/PDF16份落地验收_20260713/README.md`。Godot headless 测试和导出仍会输出编辑器退出时的 RID/ObjectDB/resource leak 警告；真机完整一局仍需解锁手机后人工验收。
