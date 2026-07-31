# Changelog

## 2.6.14 - 2026-07-31

- 为碰、明杠、暗杠和加杠增加统一实体模型门禁：全部副露必须复用 `0.42×0.24×0.58` 的同一 GLB 牌身和翡翠背层，禁止类型专属薄模型或子节点非等比缩放。
- 验证所有副露在静止和动作落定状态都使用三轴一致的 `MELD_SCALE`；碰/杠动作起始缩放也保持三轴同步，不改变牌体厚长比。
- 增加四座位碰杠矩阵、最大副露、右家混合碰杠以及碰、明杠、加杠、暗杠真实 Metal Forward+ 证据；保留既有牌距、布局和触控合同。

## 2.6.13 - 2026-07-31

- 唯一的 3D 麻将牌实体尺寸由 `0.42×0.18×0.58` 统一调整为 `0.42×0.24×0.58`，解决远端胡牌后平扣牌身在手机透视中像纸片的问题。
- 翡翠背层从 `0.055` 按原占比同步加厚到 `0.074`，保留象牙牌身、绿色树脂层、倒角、接触阴影和逐牌分界。
- AI 自摸、AI 点炮胡后的保留暗手和暗杠中间牌只旋转同一实体，不使用姿态专属非等比缩放；同步修正翻扣离桌高度与牌面标记高度。
- 三家平扣、三家普通立牌与暗杠状态完成真实 Metal Forward+ 复核，固定清单 `27/27` 通过；不改变相机、牌距、规则、计分、AI 或触控合同。

## 2.6.12 - 2026-07-31

- 修复 Android `2.6.11` 瘦身时过度删减启动资源的回归：正式包恢复 Godot .NET 脚本内容，并停止对已导入运行资源进行二次删除。
- 保留导出阶段的目录排除和调试符号排除，在恢复启动完整性的同时继续控制 APK 体积。
- 左家、对家、右家普通站立暗手的可见大面与实体绿层统一复用同一个 `#178B32` PBR 翡翠材质，删除对家专用无光照亮绿大面和专用亮绿实体层。
- 自摸、点炮胡后保留暗手与暗杠中间牌继续按平扣姿态显示明亮绿色背面；不改变相机、灯光、规则、计分、AI、布局和触控合同。

## 2.6.11 - 2026-07-30

- 碰、杠来源标记统一为贴牌的天蓝色短杆小箭头，去除黄色、渐变、阴影、描边与来源座位文字。
- 胡牌来源标记缩小为单一简洁天蓝箭头，不再显示“上家/对家/下家点炮”文字。
- 上家、下家胡牌结果整体向各自桌面轨道收回，并增加本家手牌安全边界，避免胡牌牌列侵占本家操作区。
- 胡牌暗手和暗杠扣牌统一使用与正常暗手相同的稳定墨绿牌背，不再受特殊状态材质偏色影响。
- Android 发布链路排除测试、证据、工具、文档、设计源资产和调试符号；独立裁判对 5 项用户验收全部给出 `PASS`。

## 2.6.10 - 2026-07-29

- 中心余牌计数与八边形罗盘底盘合并为一个静态实体显示；四家弃牌河统一从各自玩家视角的左上角起牌。
- 新摸牌改为紧贴牌面的固定纯蓝小号 3D 菱形，绕桌面世界竖直轴旋转；不再使用渐变受光材质。
- 选中手牌移除勾号、光环与叠加图案，仅保留物理抬升；暗杠固定为第 1、4 张亮牌、第 2、3 张扣牌。
- 碰、杠来源牌改为参考图风格的金黄色短杆小箭头，固定在第二张副露牌面，不显示“谁家出”的文字。
- 保留并发布连续胡桃木托盘、深森林绿短绒桌面与本轮 3D 牌局视觉回归；不改变规则、计分、AI、牌局几何和触控合同。

## 2.6.9 - 2026-07-29

- Blender 重新生成连续圆角温暖胡桃木托盘边框，移除四段拼接、亮铜细边和装饰缝线。
- 桌框与绒面之间改为连续深绿皮革 gasket，增加纵向木纹浮雕，中心/外圈分区槽保持低对比凹槽。
- 深森林绿桌布重新校准青绿色中间调，保留短绒 PBR、微纤维法线和高粗糙度质感；不改变规则、计分、AI、牌局几何和触控合同。
- 完成 Blender 生成、Godot 导入、聚焦桌体/灯光回归和固定清单 `27/27` 全量回归。

## 2.6.8 - 2026-07-24

- 新增真实牌局状态回归：本家暗杠后补到牌墙最后一张、合法完成牌型时，操作快照必须提供自摸入口，执行后必须按“杠上花”结算；避免把余牌归零误判为不能胡。
- 暗杠展示改为四张清晰分离的翡翠牌背，扩大副露组内间距，消除中间两张重叠或看似消失的问题。
- 自摸计分新增普通自摸与杠上花 0–4 番逐档表格回归；继续执行 4 番封顶、基础分按 `底分 × 2^番数`、每名付款者固定另加 1 底，杠钱保持独立即时结算。
- 3D 主桌和 2D 回退桌统一改为翡翠绿色、细密交叉织纹与边缘低浮雕云纹；不生成参考产品的品牌文字。

## 2.6.7 - 2026-07-24

- 修复牌墙流局结算中“最终收分包含查大叫，但明细没有显示”的不一致；已胡玩家收到的查大叫现在使用独立明细行展示。
- 增加结算账本对齐保护：所有可见明细的有符号合计必须等于顶部和左侧的本局最终增减；未来新增但未专门适配的结算事件会明确显示为账本调整，不再产生无解释差额。
- 3D 主桌和 2D 回退桌面移除菱格、云纹、回纹、印章环等几何暗纹，改为覆盖全桌的程序化短绒纤维、交错绒向和低频顺逆毛明暗。
- 新增牌墙流局、已胡玩家查大叫与明细合计回归，并更新桌布材质合同和 Metal 视觉证据。

## 2.6.6 - 2026-07-23

- 对家暗手不再使用单独的高亮平面材质，三家对手统一使用同一套深翡翠牌背；暗手牌姿仍与桌面保持严格 90°。
- 明牌模式改为把上家、对家、下家三手牌全部平铺亮明，解决左右两家牌面竖立后侧视不可读的问题。
- 自摸结果按归属区分：AI 自摸整手平扣并只显示牌背；本家自摸整手正面平铺，且在真实自摸张上保留唯一旋转金色标记。
- 左上展开工具栏用明确的“退出游戏”按钮替代孤立的 `×`；增加二次确认，并在 iOS 上使用平台支持的退出实现。
- 碰和杠的来源标记统一为小号亮蓝卡通箭头，固定在第二张副露牌正上方，同时保留来源座位文字用于辨识。
- 补齐 Android 2.6.6 arm64 Release APK；包名 `com.chendong.sichuanmahjong`、`versionCode=266`，并完成 zipalign、APK v2/v3 签名和压缩结构校验。

## 2.6.5 - 2026-07-23

- 蓝色桌布新增分辨率无关的蜀锦菱纹、印章环与云纹暗花，保留微纤维和前后景色阶，不使用遮挡牌面的亮色贴花。
- 自摸结果不再翻开整手牌：全部手牌平扣在桌面并使用稳定一致的翡翠牌背；点炮胡的既有亮牌和来源标记保持不变。
- 碰、明杠与补杠在来源牌上显示带座位颜色、方向和中文座位名的放大箭头；暗杠和自家来源不显示误导标记。
- 四川计分重构为底分×`2^番数`、4 番封顶；补齐平胡、大对子、清一色、小七对、金钩钓、清对、将对、龙七对、清七对、清金钩钓和十八罗汉基准番。
- 自摸不加番、每家固定另加 1 底；带根、杠上花、抢杠胡、杠上炮各加 1 番，龙七对内置根不重复计算。
- 直杠、补杠、暗杠改为当场独立结算；杠上炮把该次全部杠钱从开杠者转给胡牌者；流局不退税，花猪固定按 4 番向下叫玩家赔付，未叫者向下叫及已胡玩家查大叫。

## 2.6.3 - 2026-07-22

- 对家、上家、下家暗手统一正放为与桌面严格 90° 的立牌，移除原有朝桌心轻微内倾；实体翡翠背、象牙玩家侧正面、牌间距和座位方向保持不变。
- 选中的牌改用独立天青色三叶旋轮，以 `96°/s` 旋转并悬在牌上沿之外；不再显示整张半透明底色，且与 `120°/s` 金色摸牌钻锥可同时显示而不重叠。
- 本家手牌增加紧贴实体牌身的稳定暖白正面，真实 Metal 2048×1152 量测与弃牌白色的中位亮度差为 `0.9/255`；字面、牌厚、阴影和点击映射不变。
- 当前 Godot Runner `27/27`、四档摄像机构图 `4/4` 和 C# Release 构建通过；iOS 发布证据记录于 `docs/ui_rework/四川麻将直立牌旋转选牌与牌面亮度验收报告_V1.md`。

## 2.6.2 - 2026-07-19

- 依据用户最终目标图把中央余牌与四家弃牌整体上移，收回牌局核心视觉重心，同时保持四家牌河、中央计数和副露互不遮挡。
- 本家碰杠固定在手牌左侧，并按副露数量动态右移/收紧剩余手牌；四组副露压力状态仍保留完整牌面和移动端安全边距。
- 三家 AI 手牌字面按座位方向统一校正 180°；AI 点炮胡牌改为保留原暗手，在旁边独立显示胡牌张和唯一来源箭头。
- 四家姓名框按商业目标的外围轨道重排；左上缩进态改为 76×76 加粗汉堡图标，展开为横向三按钮工具条，修复宽度收缩一帧滞后导致的 iOS 偶发点不中。
- AI 紧凑提示条上移，最低分辨率不再覆盖本家牌面；最终 4 状态×4 分辨率 Metal 矩阵、24 个非摄像机 Godot Runner/四档摄像机、C# Release 与独立设计复核均作为发布门禁。

## 2.6.1 - 2026-07-18

- 依据商业目标图重做上家、下家暗手的有向透视：两列沿桌边向远端收敛、向本家前景外扩，消除向桌心收拢的倒 V；对家牌列保持水平。
- 三家暗手采用约 74° 的竖立牌姿，并增加分牌可见的象牙顶沿、深绿牌背、实体厚度和桌面接触阴影。
- AI 点炮胡牌改为只展示 1 张胡牌张和 1 个来源箭头；AI 自摸、本家胡牌、规则、计分和 AI 决策通路保持不变。
- 新增带符号的前景位移量化，避免只比较绝对夹角导致方向相反仍假通过；最终四档 Metal 图 8/8、目标图指标、24 个非摄像机 Runner、4 档摄像机合同和 C# Release 构建全部通过。
- 第一轮独立设计复评因左右倒 V 以 15/20 否决；重做后的第二轮为 18/20，所有核心项不低于 4，P0/P1 为 0。

## 2.6.0 - 2026-07-18

- 按七阶段量化门禁完成参考蓝桌 3D 商业质量收口；摄像机、空间排布、牌体字面、桌体材质、灯光/AO、HUD/旧功能和最终交付均保留独立验收报告。
- 扩大四家 HUD 和身份徽章，分离庄家、已胡、响应/出牌状态槽；已胡玩家保留姓名与分数辨识，点炮胡牌增加来源玩家文字和唯一方向箭头。
- 定缺使用三个 224 px 圆印；响应胡、自摸与取消、已胡不可点击、明牌稳定节点刷新、左上工具栏 iOS 双事件去重、AI 拖动/展开和 0%–100% 透明度均通过压力合同。
- 4 状态 × 4 分辨率真实 Metal 矩阵 16/16 通过；双设计师最终均为 23/25、无 P0/P1；全量 Godot Runner 29/29，AI.Core 构建 0 warning / 0 error。
- 新增真实 Metal 600 帧性能采样和分层 iOS 发布门禁，不以桌面帧率、构建或自动启动替代手机完整一局的人工手感、发热与持续帧率。

## 2.5.0 - 2026-07-18

- 按用户提供的成熟移动麻将截图提取桌面、外沿、牌背、牌面和定缺按钮色板，形成 `四川麻将参考蓝桌色彩与3D摆牌提炼_V1.md` 并将 3D 主桌切换为明亮蓝桌方向。
- 本家与 AI 暗手统一使用竖立牌架姿态；本家副露贴近玩家边缘；牌面增大并拉开中心距，在手机上保留清晰的单牌分隔与可读字面。
- 恢复已胡状态表现：整手牌平放亮明、胡牌张独立留缝，点炮胡使用金色方向箭头标明来源玩家；暗杠仍保持扣牌。
- 修复 3D 牌节点复用时未重新配置造成的明牌、选牌、刚摸牌、最新弃牌和胡牌状态滞留；恢复自摸/胡与取消按钮的实时显示、真实触控和 iOS 跨输入去重。
- 将定缺层升级为真正的高层级模态界面，条/筒/万使用大尺寸圆形玻璃印，同时阻止定缺期间点击穿透到左上工具栏或牌桌。
- 19 组当前 Godot Runner、C# Release 构建和 AI.Core Smoke 全部通过；四分辨率 Metal 截图像素检查 4/4 通过。

## 2.4.0 - 2026-07-18

- 将牌桌、牌墙、四家手牌、副露和弃牌从 2D 表现层重构为 Godot 真实 3D 世界，保留玩家信息、AI 提示、操作按钮、定缺和结算为高清 2D HUD。
- 新增 Blender 5.2 确定性资产管线，生成倒角暖象牙牌体、墨玉桌面、黑木桌沿和旧铜嵌线；核心牌局资产不调用 Tripo3D，外部生成费用为 0。
- 新增程序化蜀锦暗纹、深玉绿牌背、左上暖光、单投影主光与手机友好的无刚体 Tween 动画管线。
- 明牌开关直接驱动对手 3D 牌面/牌背；本家手牌放大并保持投影点击映射，选中、新摸、AI 建议、风险和最新弃牌均有独立形状反馈。
- 新增 3D 数据合同与 2D 回退合同，并保留左上工具栏 iOS 跨输入去重、规则、计分和 AI 决策链不变。

## 2.2.2 - 2026-07-17

- 修复 iPhone 左上角展开/缩进入口和内部 AI 提示、难度、明牌按钮偶发失效：iOS 同一次物理触摸产生的 `ScreenTouch` 与模拟 `MouseButton` 不再把同一开关连续执行两次。
- 去重仅作用于短时间内同一按钮的跨输入来源重复事件，连续真实触摸和桌面鼠标连续点击仍可逐次立即生效。
- 新增 iOS 双事件压力回归，连续 12 轮覆盖展开、AI 提示、难度、明牌和缩进，并补充连续真实触摸不被误拦截的合同。

## 2.2.1 - 2026-07-17

- 修复透视地狱模式绕开正式老手决策栈的问题：现在先运行完整老手候选、路线与净分判断，再叠加全牌可见条件下的防点炮、阻止玩家胡牌和三家协同约束。
- 将透视地狱的合法出牌候选限制为老手引擎的合法候选集合，确保定缺阶段只打缺门牌。
- 将清一色规划、路线连续性、净分期望、刻子保护和完整解释字段接入透视地狱排序，避免明显清一色不走、拆刻后又碰回等降智行为。
- 透视地狱出牌与碰/杠/胡/过反应共用同一个连续牌脑，并取消反应阶段的轻量化老手旁路。
- 新增清一色继承、刻子保护、定缺合法候选和“拆刻后又碰回”四组回归；C# 精确牌形穷举 131,841 状态和四川规则/移动合同继续通过。
- 完成 100 局透视地狱实战审计：全部自然结束、无强制中止，5,403 次出牌平均老手裁判分 98.89、Top-1 一致率 84.82%、严重错误率 0.46%，所有实际选择均带有老手主线与路线诊断。

## 2.2.0 - 2026-07-16

- 将 AI 决策建议框改为可在安全桌面范围内任意拖动的浮动玻璃面板，并持久化归一化位置。
- 将三档透明度按钮替换为 40%-92%、1% 步进的连续清透比例条。
- 修复左上明牌开关的鼠标/触摸真实命中分发，开、关可反复切换。
- 隐藏中心余牌区的东西南北字样，右下操作区只保留暗金边框与碰/杠/胡/过操作按钮。
- 程序化蜀锦材质同时融合回纹、云雷纹、菱格锦纹、卷草纹和缠枝纹，整层暗纹保持 5.5% 墨量。
- 统一左上暖玉柔光、中央微亮、右下沉降与四周暗角，不使用中央大圆形亮斑。

## 1.0.59 - 2026-07-01

- Backed up the current working tree and prior Android artifacts to the AI volume before cleanup.
- Removed tracked legacy regression evidence under `测试数据统计` and retired old one-off/monolithic test runners that are no longer part of the current Neijiang release gate.
- Updated the README and current regression map so release validation points at `tests/current/*`, C# smoke, Python tooling tests, and fixed-seed AI pressure runs.
- Preserved the 1.0.58 realtime AI rule set and keep-ready defense behavior; this release is focused on cleanup, verification, and packaging hygiene.

## 1.0.58 - 2026-07-01

- Changed the formal AI turn/reaction path to compute against the current realtime table state by default, while preserving explicit native-async test coverage for the async backend.
- Defined Neijiang AI stage evaluation by wall count, discard progress, exposed meld pressure, and likely-ready pressure so early/middle/late strategy is no longer ambiguous.
- Tuned opening route judgment for pinghu, qidui, qingyise, and five-pair concealed hands, including pass protection for qidui/long-qidui potential before committing to calls.
- Added a late-wall keep-ready guard after hard-defense overrides so the final discarded tile does not break a ready hand when a higher-score ready candidate has acceptable danger.
- Verified the selected release rule set with 30 fixed-seed realtime bone-ash AI rounds: `forced_stop_rounds=0`, average discard quality `95.15`, A/B acceptable rate `93.71%`, D/E error rate `4.64%`, and E-level blunders `24/668`.

## 1.0.57 - 2026-06-28

- Added automated long-term AI pressure-evaluation output for score delta, deal-in rate, deal-in loss, draw/battle-end distribution, phase counts, and final debug snapshots across all-AI benchmark runs.
- Added turn-quality diagnostics and training-index fields for selected danger, mode consistency, expected-net gaps, route alternatives, opportunity-loss flags, and candidate quality scores.
- Fixed C# discard selection so strategy-aware sorted candidates update the actual chosen tile, score, shanten, live-ukeire, and explain reasons instead of only reordering diagnostics.
- Tuned long-term EV policy so medium trailing positions stay balanced unless the score gap or final stretch justifies chase mode.
- Verified 300 fixed-seed automated pressure rounds with `forced_stop_rounds=0`; the final fixed-seed score path stayed unchanged, while the selection path and diagnostics are now internally aligned for further batch tuning.

## 1.0.56 - 2026-06-28

- Added `AIContextCache` for C# discard decisions, covering stage, round goal, strategy mode, hand analysis, attack eligibility, opponent danger, tile danger, score situation, risk tolerance, dirty flags, explain reason codes, and module timing.
- Added old-hand strategy evaluators for `attack`, `balanced`, `defense`, `fold`, and `chase`, plus strategic deal-in risk adjustment without hardcoding a fixed discard.
- Passed score, round, hand-version, and visible-version context through the Godot C# bridge, native runtime, CLI fallback, and decision cache fingerprint so score-aware strategy cannot reuse stale cached decisions.
- Added smoke coverage for AI context stage/explain/performance output and score-driven strategy mode switching.
- Re-ran the opening bao-jiao/bao-gang stall regressions covering AI-only bao-jiao, AI bao-gang, human bao-jiao/bao-gang, stale AI turn rejection, native C# contract mapping, and UI turn-resume paths.

## 1.0.55 - 2026-06-26

- Fixed a reported bao-jiao/bao-gang stall where an AI turn could reuse a stale cached discard `tile_id` after the hand changed, causing the table to stop when the opposite AI should discard.
- AI turn execution now rejects cached decisions that are no longer executable and refreshes the decision once against the current hand before giving up.
- Added a regression case for the reported shape: human dealer already declared bao-jiao/bao-gang, opposite AI already declared bao-jiao, and the AI turn recovers from a stale discard cache by discarding the legal drawn tile.

## 1.0.54 - 2026-06-25

- Fixed a real opening bao-jiao UI stall where stale draw-transition state could hide the human `报叫` and `过` controls after an AI player declared bao-jiao.
- Added a live MainScene replay that uses the real AI manager and Godot timers to reproduce AI bao-jiao before the human opening prompt, then verifies the buttons are visible.
- Added UI regression coverage for a reported AI discard-reaction path so AI bao-jiao followed by AI reaction does not leave the table stuck.

## 1.0.53 - 2026-06-25

- Fixed the opening AI bao-jiao/bao-gang completion path so the state broadcast happens after advancing to dealer first discard, preventing the UI from holding a stale no-action snapshot.
- Added UI regression coverage for AI opening bao-jiao with bao-gang where the human player is not also declaring, then continued the round until the human draws and discards.
- Added matching UI regression coverage for the AI opening bao-jiao-only path, including intermediate AI turns before control returns to the human player.

## 1.0.52 - 2026-06-24

- Fixed the opening bao-jiao/bao-gang dialog flow so the top-right close button cancels instead of silently submitting, and an explicit `确认报叫` button submits the selected bao-gang choices.
- Added current smoke coverage for a real opening deal where the human declares opening bao-jiao with selected bao-gang keys and the AI dealer proceeds to first discard.
- Added UI regression coverage for the bao-gang dialog cancel/confirm path and refreshed helper-text assertions to match the current in-game wording.

## 1.0.51 - 2026-06-23

- Preserved the AI-mode contract by mapping legacy cheating-level entrypoints to the `hell` preset and legacy advanced entrypoints back to `bone_ash`.
- Recognized `hell_challenge_direct_sync_delivery` as a direct hell challenge backend so synchronous hell decisions keep the same oracle execution/diagnostic path as direct and async hell decisions.
- Added current smoke coverage for legacy AI-level preset mapping and direct hell challenge sync-delivery recognition.

## 1.0.50 - 2026-06-18

- Fixed an opening bao-jiao/bao-gang stall where AI declarations could recursively advance the opening review queue and leave the round stuck before dealer first discard.
- Kept bao-jiao/bao-gang judgment backend-owned: C# still decides AI declarations, while Godot only advances the reviewed queue and executes the returned action.
- Added current smoke coverage for AI opening declaration stopping at the human prompt, and for human pass resuming queued AI review before dealer first discard.

## 1.0.49 - 2026-05-21

- Fixed reported bao-gang stalls by sending the declared `bao_gang_tiles` whitelist to C# as `baoGangTileTypes`.
- C# now independently forces reported bao-gang for both self-draw gang and discard-reaction gang, even if the frontend mandatory marker is missing.
- Added regression evidence for the two suspected stuck cases: reported self-draw an-gang and reported reaction melded gang.

## 1.0.42 - 2026-05-20

- Reworked the bao-jiao AI stall fix so the frontend no longer substitutes a discard decision; it remains a legality guard and rejects illegal original-hand discards.
- Fixed the C#/Godot discard contract for bao-jiao turns by mapping backend tile-type decisions to the actual just-drawn tile id when the hand contains duplicate same-type tiles.
- Added native hell-challenge coverage proving the backend returns `bao_jiao_route` for bao-jiao turns and the mapped Godot discard id is the last-draw tile.

## 1.0.41 - 2026-05-20

- Fixed a bao-jiao AI stall where the backend could recommend discarding an original locked hand tile and the frontend rejected it without progressing the turn.
- Bao-jiao AI now falls back to discarding the just-drawn tile when a discard recommendation would violate the bao-jiao lock, while still blocking discard if that draw is a mandatory bao-gang tile.
- Added regression coverage using the same locked-tile plus just-drawn-tile shape from the stalled AI turn.

## 1.0.40 - 2026-05-20

- Disabled runtime diagnostic export, AI analysis/training logs, and auto-learning file persistence for the practical-use Android package.
- Hid diagnostic export, hell-marking, tuning, and opponent-hand developer buttons from the in-game floating tools.
- Kept the 0.5-3.0 second randomized AI table pacing from 1.0.39.

## 1.0.39 - 2026-05-20

- Slowed visible AI table actions with a randomized 0.5-3.0 second thinking delay for turns and reactions.
- Kept C# AI decision quality unchanged; this release only adjusts table pacing and Android package metadata.

## 1.0.38 - 2026-05-19

- Fixed hell-challenge async discard decisions so C# callback results are checked by the same oracle path as synchronous discards before the tile is played.
- Enlarged the bao-gang selection dialog with bigger title text, option rows, and option fonts for phone readability.
- Strengthened bao-jiao lock, mid-hand risk, and hell-challenge regression coverage for discard and oracle behavior.

## 1.0.30 - 2026-05-15

- Improved discard/action responsiveness by separating stale AI calculations from current human input and adding safer async decision signatures.
- Added belief-cache diagnostics and performance-oriented posterior reuse without changing the core AI scoring contracts.
- Tuned early offensive hand-shape evaluation so strong pair-heavy starts keep higher-value routes instead of over-breaking useful groups.
- Added player-selected bao-gang declarations during bao-jiao, with backend validation and mandatory future gang enforcement.

## 1.0.26 - 2026-05-13

- Restyled the main action buttons into large circular mahjong controls with primary yellow-orange and secondary green variants.
- Restored selected-hand AI explanation details so the discard helper shows C# candidate comparisons, posterior reasons, risk reasons, and expected-score deltas.
- Enlarged the AI discard helper into a wider phone-readable prompt with larger outlined text.
- Added UI regression coverage for circular action buttons and C# candidate detail display in the helper panel.

## 1.0.25 - 2026-05-13

- Set this snapshot as the new stable development base after the `1.0.24` baseline.
- Refined the main table presentation, including a larger center wall-count disc, no desktop frame line, and a simplified right-side control stack with a top-right exit button.
- Fixed Neijiang Mahjong flow priorities so opening bao-jiao decisions block automatic dealer discard until resolved.
- Fixed self-hu and settlement UI details so self-hu no longer shows discard guidance and Neijiang settlement no longer displays stale missing-suit text.
- Updated Android package metadata and export scripts so generated APK filenames include the version number.

## 1.0.4 - 2026-05-10

- Replaced the self-hu source text label with the same arrow-style claim marker used elsewhere.
- Reduced the left and right opponent meld tiles a little more so the side meld areas feel less oversized.
- Updated the contract and preview capture to lock the new claim badge and smaller side meld size.

## 1.0.3 - 2026-05-10

- Centered the AI discard helper on the main board and made the prompt reason line readable on mobile.
- Updated the discard hint preview to show a short reason directly under the recommended tile text.
- Bumped the tracked source and Android package versions to keep the release metadata in sync.

## 1.0.2 - 2026-05-10

- Enlarged the floating AI discard helper and reduced it to centered direct content so the hint stays readable on mobile.
- Replaced the recommended-tile outline marker with a continuously rotating cone centered on the suggested tile.
- Updated the V17 layout contract to lock the helper panel readability rules and cone marker behavior.

## 1.0.1 - 2026-05-10

- Tuned the opposite player's hand, meld, and winning-tile lane to sit closer to the player info area without overlapping it.
- Reduced left/right opponent meld tile scale and recalculated side winning-tile slots so the tile stays inside the frame.
- Updated the V17 layout contract to lock the new opponent lane spacing and side winning-tile behavior.

## 1.0.0 - 2026-05-10

- Created the first GitHub-ready source snapshot for the Neijiang Mahjong Godot project.
- Added repository hygiene for Godot, .NET, Android build outputs, export artifacts, and signing files.
- Recorded the baseline app version and version-management workflow.
