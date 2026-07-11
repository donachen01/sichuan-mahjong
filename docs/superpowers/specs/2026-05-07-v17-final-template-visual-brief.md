# V17 Final Template 视觉制作说明

> 状态：待用户审阅  
> 日期：2026-05-07  
> 用途：制作最终目标模板图，不直接修改 Godot 工程  

## 1. 一句话目标

保留原 V17 精修图的面板大小、区域布局、区域尺寸、牌局内容和信息密度，将其视觉风格重绘为新参考图的高质感绿色牌桌效果，形成后续 Godot 实现的唯一目标模板。

## 2. 输入参考

### 2.1 布局参考

原 V17 精修图。

它负责：

- 画布比例
- 面板大小
- 各区域位置
- 各区域尺寸
- 麻将牌数量
- 麻将牌排列
- 玩家信息卡位置
- 下一局按钮位置
- 中心五块十字结构
- 底部手牌、碰杠区、胡牌槽结构

### 2.2 风格参考

新绿色牌桌参考图。

它负责：

- 深绿色牌桌背景
- 中心偏亮、四周偏暗的光照
- 桌布绒布质感
- 嵌入式凹槽/压线面板
- 厚实麻将牌
- 鲜亮绿色牌背
- 奶油白牌面
- 深绿半透明信息牌
- 高光、倒角、投影
- 手游级精致卡通 3D 质感

## 3. 硬约束

制作最终模板图时必须遵守：

- 不改变原 V17 精修图的区域布局。
- 不改变原 V17 精修图的各面板大小。
- 不改变原 V17 精修图的牌数量。
- 不改变原 V17 精修图的手牌、弃牌、碰杠牌、胡牌槽位置。
- 不改变原 V17 精修图的玩家信息卡位置。
- 不新增新参考图中的房号、时间、聊天、日历、灯泡、菜单等功能按钮。
- 不加入顶部木质桌沿。
- 不加入左侧木质桌沿。
- 不加入右侧木质桌沿。
- 不加入大面积木地板或房间背景。
- 不保留“豆包 AI 生成”等水印。
- 不生成无关装饰文字。
- 不把中心五块十字结构改成新参考图那种大空桌面。

## 4. 需要改变的内容

### 4.1 背景

原 V17 精修图的平面深绿背景改为新参考图那种更真实的绿色牌桌底：

- 中心略亮。
- 四周略暗。
- 轻微绒布纹理。
- 有柔和空间光。
- 不做木质外框。

### 4.2 中心五块十字结构

保留原 V17 精修图五块十字结构的位置和大小，但视觉上改为嵌入式凹槽：

- 面板不再像浅色白板浮在桌上。
- 使用深浅绿分层。
- 边缘有压线、内阴影、柔光高光。
- 五块区域仍清楚分开。
- 中心风位牌保留原位置和大小，但质感改为厚实浮雕牌。

### 4.3 顶部动态牌区

保留原 V17 精修图顶部的三段结构：

- 左侧碰杠板
- 中间手牌/牌背长板
- 右侧胡牌单槽

改为新参考图风格：

- 牌背更鲜亮。
- 牌体更厚。
- 背板更像桌面凹槽。
- 胡牌槽保持橙色/暖色，但更有高光和厚度。

### 4.4 左右动态牌区

保留原 V17 精修图的左右竖向牌列和底板尺寸。

改为新参考图风格：

- 绿色牌背有明显厚度。
- 竖向牌与桌面有接触阴影。
- 长条底板从浅绿白板改为嵌入式牌槽。
- 不加入木质侧边。

### 4.5 底部我方动态牌区

保留原 V17 精修图底部三段结构：

- 左侧碰杠板
- 中间手牌长板
- 右侧胡牌单槽

改为新参考图风格：

- 手牌更像厚实实体麻将牌。
- 牌面奶油白，边缘柔和倒角。
- 手写/粗笔画牌字更清晰、有力量。
- 牌底有明显接触阴影。
- 底板更像桌面内嵌托盘。

### 4.6 玩家信息卡

保留原 V17 精修图四家信息卡的位置和信息结构。

改为新参考图风格：

- 深绿半透明卡片。
- 高光边框。
- 头像框更像插画头像卡。
- 分数更清楚。
- 庄标、定缺标有小浮雕牌质感。

### 4.7 按钮与角标

保留原 V17 精修图按钮位置和含义。

改为新参考图风格：

- 深绿/灰绿半透明按钮。
- 圆角更大。
- 有内高光和外投影。
- 下一局按钮不改变位置和尺寸。
- 左上 `+` 保持简洁，但质感更像新参考图的菜单按钮。

## 5. 推荐生成提示词

### 5.1 中文主提示词

以一张 2048x1152 横屏手游麻将牌桌 UI 为基础，严格保留原图所有区域布局、面板大小、麻将牌数量、麻将牌位置、玩家信息卡位置、按钮位置和内容结构。不要改变构图，不要重新设计布局。

将视觉风格重绘为高质感绿色牌桌手游界面：深绿色绒布牌桌背景，中心柔和亮光，四周轻微暗角，桌布有细腻绒布纹理。所有浅色面板改为嵌入牌桌的凹槽式绿色面板，带内阴影、压线、高光和柔和边缘。麻将牌为厚实 3D 卡通麻将牌，奶油白牌面，绿色侧边，圆润倒角，清晰接触阴影，牌背为鲜亮绿色。玩家信息卡为深绿半透明卡片，带高光边框和插画头像框。按钮为圆润 3D 半透明深绿按钮，带高光、倒角和投影。整体精致、清晰、手机游戏级、卡通 3D 但不幼稚。

不要加入顶部木质桌沿，不要加入左右木质桌沿，不要加入房号时间聊天日历灯泡等新按钮，不要加入木地板，不要添加水印，不要改变牌局信息。

### 5.2 英文辅助提示词

2048x1152 landscape mobile mahjong game UI. Preserve the original V17 layout exactly: same panel sizes, same regions, same tile counts, same tile positions, same player info card positions, same next-round button position, same dense mahjong table composition. Do not redesign the layout.

Restyle it as a polished green felt mahjong table mobile game UI: deep emerald felt background, soft center lighting, subtle vignette, fine fabric texture, inset groove panels instead of flat pale boards, soft inner shadows, bevels and highlights. Thick rounded 3D cartoon mahjong tiles with warm ivory faces, green sides, clear contact shadows and soft highlights. Bright green tile backs. Player info cards are dark translucent green panels with glossy borders and illustration avatar frames. Buttons are rounded glossy dark-green 3D controls with bevels, highlights and shadows. Premium mobile game quality, refined cartoon 3D, readable, tactile, cohesive.

No top wooden rail, no left wooden rail, no right wooden rail, no room/time/chat/calendar/lightbulb buttons, no wooden floor, no watermark, no extra text, no layout changes.

### 5.3 负面提示词

- 不要改变布局
- 不要移动任何区域
- 不要改变面板大小
- 不要改变牌数量
- 不要减少信息密度
- 不要大空桌面
- 不要顶部木框
- 不要左右木框
- 不要房号时间 UI
- 不要聊天/日历/灯泡按钮
- 不要水印
- 不要扁平 UI
- 不要灰绿色白板
- 不要赌场霓虹风
- 不要冷蓝科技风
- 不要真实 3D 建模透视变形

## 6. 模板图验收标准

模板图通过后，才能进入 Godot 实施计划。

通过条件：

- 第一眼仍然看得出是原 V17 精修图的布局。
- 区域尺寸、面板大小、内容密度与原 V17 精修图一致。
- 第一眼又明显具有新参考图的绿色牌桌质感。
- 中心区域不再是浅色白板，而是桌面嵌入式凹槽。
- 麻将牌厚度、倒角、阴影明显增强。
- 顶部、左右、底部动态牌区没有换位置。
- 没有新增木质桌沿。
- 没有新增新参考图里的额外功能按钮。
- 没有水印。

## 7. 输出建议

最终模板图建议保存为：

`docs/ui_baseline/mockups/v17_final_template_green_table_style_v1.png`

如果需要多轮修正，按版本递增：

- `v17_final_template_green_table_style_v2.png`
- `v17_final_template_green_table_style_v3.png`

只有用户明确确认某一版模板后，才进入 Godot 实施计划。
