# Deep Emerald orthographic UI shell kit

These PNGs are original project assets generated deterministically with Blender
5.2 LTS by `tools/3d/generate_sichuan_ui_shells_v2.py`.

- `hud_shell.png`: transparent lacquer/copper player-panel shell. Godot owns
  player name, score, avatar, dealer/won/turn state and ding-que content.
- `action_hu.png`, `action_gang.png`, `action_peng.png`, `action_pass.png`:
  transparent circular seal surfaces. Godot owns labels, focus, pressed state,
  animation, reduced motion and touch rectangles.
- `ding_que_tiao.png`, `ding_que_tong.png`, `ding_que_wan.png`: transparent
  jade-seal shells without decorative dots. Godot keeps the live 条/筒/万
  glyph, modal touch target, explicit-selection focus ring and 140 ms submit
  feedback.
- `settlement_panel_9slice.png`: 1024×640 deep-emerald, ink-jade and aged-
  copper nine-slice shell for the full four-player ledger. Godot owns every
  name, score, hand, fan label, payer and signed detail row. Its editable
  Blender source is `source_assets/ui/settlement/settlement_panel_9slice.blend`.

Regenerate:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/3d/generate_sichuan_ui_shells_v2.py
```

To regenerate only the settlement shell without touching the other audited
runtime textures, append `-- --settlement-only`.

To regenerate only the three ding-que shells, append `-- --ding-que-only`.

These are decorative runtime resources, not screenshots of third-party games.
