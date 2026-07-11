# 牌桌主界面目标 Mockup Prompt v1

状态：尚未生成成功。当前本机 `OPENAI_API_KEY` 调用图像 API 返回 `401`，提示“该令牌状态不可用”。

## 用途

生成一张“启动页同源风格进入真实游戏后”的牌桌主界面目标图。该图只用于 UI 方向评审，不直接作为游戏资产。

## 目标文件

`docs/ui_baseline/mockups/table_main_3d_cartoon_mockup_v1.png`

## 生成规格

- 尺寸：`2048x1152`
- 比例：`16:9`
- 质量：high
- 类型：UI mockup

## Prompt

```text
Use case: ui-mockup.
Asset type: mobile landscape game UI mockup for a Godot Mahjong game.

Primary request:
Create a realistic 3D cartoon in-game table interface for Neijiang Mahjong, matching the warm cute 3D style of the provided splash screen.

Scene/backdrop:
Warm wooden room, honey-colored wooden Mahjong table with rounded thick frame, green felt tabletop, soft sunlight, cozy cartoon game atmosphere.

Subject:
Real playable Mahjong table screen, not a marketing poster. Bottom foreground has the local player hand with 14 large thick Mahjong tiles, readable tile faces, warm ivory fronts and green side thickness, arranged across the bottom. Center table has discard area with several visible tiles and a recent discard. Four player positions around the table use cute rounded avatar cards attached to screen edges, with large readable score numbers and simple direction tags. Right bottom thumb area has oversized glossy jelly 3D circular action buttons labeled 胡, 过, 碰, 杠, with 胡 as the biggest orange-gold button and 过 as a green button. Top left has compact room/round/time info in a wooden plaque.

Style/medium:
Polished realistic 3D cartoon game UI mockup, soft render, rounded shapes, warm wood, green felt, tactile thick tiles, cute approachable style.

Composition/framing:
16:9 horizontal phone screenshot, actual game UI layout, clear readable hierarchy, no splash title, no promotional text.

Lighting/mood:
Warm sunlight, soft shadows, gentle highlights, cozy.

Color palette:
Honey wood, green felt, ivory tiles, orange-gold highlights, fresh green buttons.

Constraints:
All UI elements must be large and readable on phone; avoid flat dashboard cards; avoid casino neon; avoid dark clutter; avoid watermark; avoid extra logos; Chinese action button text must be clear.
```

## CLI Command

```bash
/Users/chendong/.local/bin/uv run --with openai python /Users/chendong/.codex/skills/.system/imagegen/scripts/image_gen.py generate \
  --size 2048x1152 \
  --quality high \
  --out docs/ui_baseline/mockups/table_main_3d_cartoon_mockup_v1.png \
  --force \
  --prompt '<use prompt above>'
```

