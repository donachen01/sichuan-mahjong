# 当前 3D 资产与生成入口

现用牌桌是已批准的玻璃桌体。Blender 提供几何和源材质，Godot 提供最终皮肤、玻璃参数、灯光、动态文字和触控。

| 资产 | 现行来源与用途 |
|---|---|
| `sichuan_table_v2.glb` | `source_assets/table/launch_glass_v1/launch_glass_table_review.blend`；正式审核导出入口 `tools/3d/generate_current_table.py` |
| `mahjong_tile_body.glb` | 共享 Blender 倒角象牙／翡翠麻将牌体；由牌桌组件复用 |
| `sichuan_center_compass_v2.glb` | `tools/3d/generate_sichuan_center_compass_v2.py`；动态数字与方位由 Godot 叠加 |
| `sichuan_table.glb` | 旧 3D 桌体，仍有非默认显示路径引用，保留 |

现用桌体必须保留 `TableWalnutBase`、`TableFelt`、`WalnutApronRing`、`SingleClearGlassCap`、`InnerGlassEdge`、`RaisedTransparentGlassLip` 六个节点。节点名称中的 Walnut 来自历史沿用名称，不代表最终表面仍是木纹材质。

从批准源重新导出到审核文件：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/3d/generate_current_table.py -- \
  --output /tmp/sichuan_table_review.glb
```

生成器要求指定审核输出，禁止直接写现用 GLB。检查节点、素材依赖和效果后再安装审核结果。2026-09-27 的导出与现用 GLB 字节一致；记录见 `evidence/structure_cleanup_20260927`。

`preview_launch_table_frame.py` 用于新视觉实验，只写 `source_assets/table/launch_glass_experiments`。它不覆盖批准源或游戏模型。

`generate_sichuan_table_v2.py` 保留旧基础桌生成能力，必须通过 `-- --output /tmp/legacy_table_review.glb` 指定审核位置；贴图也写在审核位置，不能再用无参数旧命令覆盖游戏玻璃桌。

现用皮肤由 `SichuanTableSkinCatalog` 与 `SichuanTableStage3D` 解析，`materials/table_v2` 保存通用 PBR 素材。四张内容相同且无现行引用的旧 `sichuan_table_v2_*normal/orm.png` importer 副本已移除；不将源图／运行图或平台资源槽位的相同内容直接视为冗余。

本次没有重新绘制模型、贴图或改变游戏材质效果。
