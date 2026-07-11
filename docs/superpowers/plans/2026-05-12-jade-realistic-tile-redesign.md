# Jade Realistic Tile Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current dark, restrained jade-ceramic Mahjong tile look with a brighter, more realistic green jade tile style that has stronger relief, clearer highlights, and better small-scale readability across hand, discard, meld, and settlement contexts.

**Architecture:** Keep the existing Godot 2D tile pipeline and current tile sizes, but rebuild the generated body textures around a brighter green-jade palette, rebuild symbol proportions and contrast for realistic tile readability, and retune runtime 2D shading to support clearer top highlights and bottom relief. Discard readability stays a first-class acceptance criterion, and scale constants remain conservative adjustments layered on top of stronger assets.

**Tech Stack:** Godot 4 GDScript, Python Pillow asset generators, existing `TileVisual2D` / `HandCanvas2D` renderers, local PNG mockup previews.

---

## File Structure

- Modify `docs/superpowers/specs/2026-05-12-jade-realistic-tile-redesign-design.md`: already written; keep as the design source of truth.
- Create `docs/superpowers/plans/2026-05-12-jade-realistic-tile-redesign.md`: this implementation plan.
- Modify `tools/generate_cartoon_tile_bodies.py`: generate brighter realistic green-jade faces and richer dark-green backs with stronger highlight / relief relationships.
- Modify `tools/generate_cartoon_tile_symbols.py`: increase symbol solidity, contrast, and occupancy so the tiles feel like real printed Mahjong faces.
- Modify `tools/preview_tile_redesign.py`: keep a richer preview sheet that verifies bright-jade hero tiles, hand rows, discard readability, meld rows, backs, selected state, and winning state.
- Modify `scripts/ui/TileVisual2D.gd`: retune front-face inset, rim, top highlight, bottom relief, and state accents around the brighter realistic jade body.
- Modify `scripts/ui/HandCanvas2D.gd`: align hand rendering with `TileVisual2D.gd`, especially highlight, shadow, and occupied area treatment.
- Modify `scripts/game/MainSceneV2.gd`: keep or adjust discard scale constants only after the new brighter assets are assessed against actual readability.
- Regenerate `res/art/ui_3d_cartoon/tile_face_large.png`, `res/art/ui_3d_cartoon/tile_face_table.png`, `res/art/ui_3d_cartoon/tile_back_table.png`, and `res/art/ui_3d_cartoon/tile_symbols/*.png`.
- Regenerate preview outputs under `docs/ui_baseline/mockups/`.

---

### Task 1: Rebuild the Tile Body Generator for Brighter Realistic Jade

**Files:**
- Modify: `tools/generate_cartoon_tile_bodies.py`
- Test: `docs/ui_baseline/mockups/tile_redesign_preview.png`

- [ ] **Step 1: Replace the current warm-jade ceramic palette with brighter realistic green-jade colors**

In `tools/generate_cartoon_tile_bodies.py`, inside `draw_tile()`, set the face palette to a brighter realistic jade range:

```python
    front_top = (210, 234, 220)
    front_mid = (184, 220, 199)
    front_bottom = (146, 191, 167)
    back_top = (42, 110, 79)
    back_mid = (28, 84, 59)
    back_bottom = (18, 63, 44)
```

Expected: the main face is clearly brighter and more jade-green than the current muted ceramic version.

- [ ] **Step 2: Keep the body full inside the tile box**

Ensure `body_rect` stays on the fuller setting:

```python
    body_rect = (
        int(round(5 * scale)),
        int(round(3 * scale)),
        w - int(round(6 * scale)),
        h - int(round(10 * scale)),
    )
```

Do not shrink it further in this task.

- [ ] **Step 3: Increase top highlight strength**

Replace the current `top_wash` fill and blur in `draw_tile()`:

```python
        fill=(250, 255, 251, 62) if not back else (214, 245, 231, 26),
```

and:

```python
    top_wash = top_wash.filter(ImageFilter.GaussianBlur(max(2, int(1.5 * scale))))
```

Expected: the tile reads as brighter and more polished from the top-left.

- [ ] **Step 4: Strengthen the bottom relief for more obvious volume**

Replace the current relief fill:

```python
        fill=(58, 88, 70, 34) if not back else (8, 26, 18, 30),
```

and keep:

```python
    relief = relief.filter(ImageFilter.GaussianBlur(max(2, int(1.6 * scale))))
```

Expected: bottom volume becomes easier to read without creating a thick cartoon lip.

- [ ] **Step 5: Make the rim slightly sharper**

Replace the border color with a darker jade rim:

```python
    border_color = (98, 140, 116, 236) if not back else (124, 168, 138, 214)
```

Expected: tile edges separate more clearly from the table and from each other.

- [ ] **Step 6: Add a subtle upper-left face gloss wedge**

Add this block after the `top_wash` composite:

```python
    gloss = Image.new("RGBA", body_size, (0, 0, 0, 0))
    gloss_draw = ImageDraw.Draw(gloss)
    gloss_draw.rounded_rectangle(
        (int(10 * scale), int(10 * scale), body_size[0] - int(28 * scale), int(20 * scale)),
        radius=max(3, int(5 * scale)),
        fill=(255, 255, 255, 24) if not back else (210, 238, 226, 10),
    )
    gloss = gloss.filter(ImageFilter.GaussianBlur(max(2, int(1.3 * scale))))
    canvas.alpha_composite(gloss, (body_rect[0], body_rect[1]))
```

- [ ] **Step 7: Regenerate body textures**

Run:

```bash
python3 tools/generate_cartoon_tile_bodies.py
```

Expected output:

```text
generated tile bodies in /Users/chendong/Documents/内江麻将工程_20260502_103823_v2/res/art/ui_3d_cartoon
```

---

### Task 2: Rebuild Symbols for Realistic Printed Mahjong Readability

**Files:**
- Modify: `tools/generate_cartoon_tile_symbols.py`
- Test: `docs/ui_baseline/mockups/tile_symbols_matte_contact_sheet.png`

- [ ] **Step 1: Increase symbol contrast for the greener face**

In `tools/generate_cartoon_tile_symbols.py`, update `SUIT_STYLES` to darker, more printed-looking inks:

```python
SUIT_STYLES = {
    "tiao": {
        "ink": (46, 82, 58),
        "shadow": (20, 30, 24, 20),
        "paper_glow": (248, 255, 250, 8),
        "contrast": 1.06,
        "color": 0.92,
        "resize": (0.84, 0.87),
        "offset": (-2, 0),
        "alpha_gain": 1.00,
        "thin_px": 0,
    },
    "tong": {
        "ink": (76, 92, 86),
        "red": (194, 36, 52),
        "blue": (86, 102, 108),
        "shadow": (20, 28, 24, 18),
        "paper_glow": (248, 255, 250, 6),
        "contrast": 1.08,
        "color": 0.94,
        "resize": (0.83, 0.87),
        "offset": (-2, -1),
        "alpha_gain": 1.00,
        "thin_px": 0,
    },
    "wan": {
        "ink": (66, 62, 60),
        "shadow": (18, 18, 18, 16),
        "paper_glow": (248, 255, 250, 4),
        "contrast": 1.06,
        "color": 0.86,
        "resize": (0.83, 0.87),
        "offset": (0, 1),
        "alpha_gain": 0.98,
        "thin_px": 0,
    },
}
```

- [ ] **Step 2: Keep dense ranks full and centered**

Use these rank overrides:

```python
RANK_LAYOUT_OVERRIDES = {
    "tong_1": {"resize": (0.80, 0.82), "offset": (-1, 0), "alpha_gain": 1.02, "thin_px": 0},
    "tong_6": {"resize": (0.81, 0.84), "offset": (-2, -1)},
    "tong_7": {"resize": (0.81, 0.84), "offset": (-2, -1)},
    "tong_8": {"resize": (0.80, 0.83), "offset": (-2, -1)},
    "tong_9": {"resize": (0.80, 0.83), "offset": (-2, -1)},
    "wan_1": {"resize": (0.81, 0.84), "offset": (0, 1)},
    "wan_2": {"resize": (0.82, 0.85), "offset": (0, 1)},
    "wan_3": {"resize": (0.82, 0.85), "offset": (0, 1)},
    "wan_8": {"resize": (0.81, 0.84), "offset": (0, 1)},
    "wan_9": {"resize": (0.81, 0.84), "offset": (0, 1)},
}
```

- [ ] **Step 3: Reduce the recessed feeling**

In `_compose_symbol()`, replace:

```python
    shadow.putalpha(fitted.getchannel("A").filter(ImageFilter.GaussianBlur(0.55)).point(lambda value: int(value * 0.24)))
```

with:

```python
    shadow.putalpha(fitted.getchannel("A").filter(ImageFilter.GaussianBlur(0.45)).point(lambda value: int(value * 0.14)))
```

And replace:

```python
    glow.putalpha(fitted.getchannel("A").filter(ImageFilter.GaussianBlur(0.8)).point(lambda value: int(value * 0.16)))
```

with:

```python
    glow.putalpha(fitted.getchannel("A").filter(ImageFilter.GaussianBlur(0.65)).point(lambda value: int(value * 0.10)))
```

Expected: symbols look printed on the face, not floating inside it.

- [ ] **Step 4: Regenerate symbol assets**

Run:

```bash
python3 tools/generate_cartoon_tile_symbols.py
```

Expected output:

```text
generated /Users/chendong/Documents/内江麻将工程_20260502_103823_v2/res/art/ui_3d_cartoon/tile_symbols
contact_sheet /Users/chendong/Documents/内江麻将工程_20260502_103823_v2/docs/ui_baseline/mockups/tile_symbols_matte_contact_sheet.png
```

---

### Task 3: Retune Runtime Shading for a Brighter, Stronger Relief

**Files:**
- Modify: `scripts/ui/TileVisual2D.gd`
- Modify: `scripts/ui/HandCanvas2D.gd`
- Test: `docs/ui_baseline/mockups/tile_redesign_preview.png`

- [ ] **Step 1: Brighten the face constants in `TileVisual2D.gd`**

Replace these constants in `scripts/ui/TileVisual2D.gd`:

```gdscript
const FACE_COLOR := Color8(186, 221, 198, 255)
const FACE_BACK_COLOR := Color8(28, 84, 59, 255)
const BORDER_COLOR := Color8(98, 140, 116, 226)
const BACK_BORDER_COLOR := Color8(124, 168, 138, 210)
const FACE_INNER_RIM := Color(0.95, 1.0, 0.97, 0.20)
const FACE_INNER_LIGHT := Color(1.0, 1.0, 1.0, 0.16)
const FACE_RIGHT_GLAZE := Color(0.12, 0.20, 0.15, 0.10)
```

- [ ] **Step 2: Strengthen the top and bottom read in `TileVisual2D.gd`**

In `_draw_inset_face_rim()`, use:

```gdscript
var top_highlight := Rect2(
    rim_rect.position + Vector2(2.0, 1.4) * tile_scale,
    Vector2(rim_rect.size.x - 4.0 * tile_scale, maxf(1.0, 2.2 * tile_scale))
)
var lower_shade := Rect2(
    rim_rect.position + Vector2(3.0, rim_rect.size.y - 4.0 * tile_scale),
    Vector2(rim_rect.size.x - 6.0 * tile_scale, maxf(1.0, 3.2 * tile_scale))
)
```

- [ ] **Step 3: Brighten the hand-face constants in `HandCanvas2D.gd`**

Replace:

```gdscript
const TILE_BORDER_COLOR := Color8(98, 140, 116, 220)
const TILE_FACE_COLOR := Color8(186, 221, 198, 255)
const SELECTED_FACE_TINT := Color8(186, 221, 198, 255)
const TILE_INNER_BORDER := Color(0.95, 1.0, 0.97, 0.20)
const TILE_INNER_SHADOW := Color(0.12, 0.20, 0.15, 0.10)
```

Expected: hand tiles now look bright jade rather than muted jade.

- [ ] **Step 4: Increase the hand top wash and bottom contact read**

In `_draw_asset_tile_depth()`, use:

```gdscript
top_wash.bg_color = Color(1.0, 1.0, 1.0, 0.10)
contact_shadow.bg_color = Color(0.0, 0.0, 0.0, 0.11)
```

And keep the existing wider highlight / shadow rectangles from the prior jade pass.

- [ ] **Step 5: Keep selected and winning states restrained**

Do not brighten selected glow. Preserve red border + slight scale as the primary feedback. Winning state should remain softer than selected state.

---

### Task 4: Rebuild Preview Coverage for Bright Jade Review

**Files:**
- Modify: `tools/preview_tile_redesign.py`
- Test: `docs/ui_baseline/mockups/tile_redesign_preview.png`

- [ ] **Step 1: Update preview title and subtitle**

Replace:

```python
draw_label(draw, 48, 28, "Warm Jade Tile Redesign Preview", title_color)
draw_label(draw, 48, 60, "warm jade body / structured symbols / discard readability / selected and winning states", sub_color)
```

with:

```python
draw_label(draw, 48, 28, "Bright Realistic Jade Tile Preview", title_color)
draw_label(draw, 48, 60, "brighter green jade / stronger relief / printed symbols / discard readability", sub_color)
```

- [ ] **Step 2: Keep the discard readability strip**

Do not remove the discard strip added in the previous jade pass. It is required to validate the original user complaint.

- [ ] **Step 3: Regenerate the preview**

Run:

```bash
python3 tools/preview_tile_redesign.py
```

Expected output:

```text
/Users/chendong/Documents/内江麻将工程_20260502_103823_v2/docs/ui_baseline/mockups/tile_redesign_preview.png
```

---

### Task 5: Reassess Center Discard Scale After the Brighter Asset Pass

**Files:**
- Modify: `scripts/game/MainSceneV2.gd`
- Test: `docs/ui_baseline/mockups/tile_redesign_preview.png`

- [ ] **Step 1: Keep the current conservative uplift unless the brighter assets fully solve readability**

Confirm current values:

```gdscript
const CENTER_DISCARD_TOP_SCALE := 0.78
const CENTER_DISCARD_BOTTOM_SCALE := 0.78
const CENTER_DISCARD_SIDE_SCALE := 0.78
```

- [ ] **Step 2: Only if the new brighter assets now feel too large, step back to 0.76**

Use:

```gdscript
const CENTER_DISCARD_TOP_SCALE := 0.76
const CENTER_DISCARD_BOTTOM_SCALE := 0.76
const CENTER_DISCARD_SIDE_SCALE := 0.76
```

Do not change `_discard_fit_scale_for_seat()` overflow protection.

- [ ] **Step 3: If 0.78 still looks right, do not touch these constants**

Expected: we optimize for readability first, not symmetry with older asset packs.

---

### Task 6: Final Verification Pass

**Files:**
- Verify: `tools/generate_cartoon_tile_bodies.py`
- Verify: `tools/generate_cartoon_tile_symbols.py`
- Verify: `tools/preview_tile_redesign.py`
- Verify: `scripts/ui/TileVisual2D.gd`
- Verify: `scripts/ui/HandCanvas2D.gd`
- Verify: `scripts/game/MainSceneV2.gd`

- [ ] **Step 1: Run Python parse checks**

Run:

```bash
PYTHONPYCACHEPREFIX=/private/tmp/pycache python3 -m py_compile tools/generate_cartoon_tile_bodies.py tools/generate_cartoon_tile_symbols.py tools/preview_tile_redesign.py
```

Expected: no output, exit code `0`.

- [ ] **Step 2: Run diff whitespace checks**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 3: Inspect changed files summary**

Run:

```bash
git diff --stat
```

Expected: body generator, symbol generator, runtime GDScript, regenerated tile assets, and preview outputs are the main changes.

- [ ] **Step 4: Prepare final review summary**

Use this checklist before claiming success:

```text
[ ] Face reads brighter than the previous jade pass
[ ] Tile relief is more obvious without becoming chunky
[ ] Symbols feel printed and readable at discard scale
[ ] Center discard no longer feels visually too small
[ ] Hand, discard, meld, and settlement still share one visual language
```
