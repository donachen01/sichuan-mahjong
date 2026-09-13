# 四川麻将碰杠牌模型一致性验证报告

日期：2026-07-31

## 结论

碰、明杠、暗杠、加杠与普通麻将牌共用唯一的 `res://res/art/3d/mahjong_tile_body.glb`。基础实体尺寸为 `0.42×0.24×0.58`；所有副露落定后统一使用三轴相同的 `MELD_SCALE=1.12`，对应世界尺寸 `0.4704×0.2688×0.6496`，厚长比保持不变。没有碰牌专用模型、杠牌专用薄模型或子节点非等比压缩。

手牌、弃牌和副露为适配各座位透视与手机可读性保留不同的整体显示倍率，但每一类倍率都同时作用于宽、厚、长三轴；它们是同一实体的等比例显示，不是不同模型。

## 新增门禁

- `SichuanTableStage3D` 暴露 `meld_model_geometry=peng_ming_gang_an_gang_add_gang_share_one_model_uniform_scale_only` 合同。
- `Sichuan3DTableStageRunner` 对普通碰与暗杠基础局面、四座位碰/明杠/加杠矩阵分别验证：
  - 每张副露根节点均为 `Vector3.ONE × MELD_SCALE`；
  - 牌身和翡翠背层 Mesh 资源实例完全相同；
  - `MahjongTileBody`、`MahjongTileBack` 子节点均保持 `Vector3.ONE`，禁止单独压薄；
  - 暗杠中间两张只物理翻转同一实体，并保持实体绿背朝上；
  - 动画起始的 `0.82` 倍和落定的 `1.0` 倍均为三轴同步缩放。

## 真实 Metal Forward+ 证据

环境：Godot 4.6.2 .NET、Metal 4.0、Forward+、Apple M1 Pro、`2556×1179`。

- 四座位碰/明杠/加杠同屏：`metal/meld-source-matrix_2556x1179.png`
- 本家最大四组副露：`metal/max-meld_2556x1179.png`
- 右家碰与明杠混合：`metal/right-meld_2556x1179.png`
- 碰动作落定：`metal/motion-peng_2556x1179.png/frame_041.png`
- 明杠动作落定：`metal/motion-melded-gang_2556x1179.png/frame_041.png`
- 加杠动作落定：`metal/motion-add-gang_2556x1179.png/frame_041.png`
- 暗杠动作落定：`metal/motion-an-gang_2556x1179.png/frame_041.png`

画面复核确认白色牌身、绿色树脂背层、圆角、接触阴影和逐张牌边界均保留；最大副露与侧家混合副露没有因牌体加厚产生穿插或区域重叠。

## 回归

固定清单 `docs/ui_rework/emerald_final_runner_manifest_V1.txt` 从头执行，结果 `27/27 PASS`。日志在 `full_manifest_logs_final/`，覆盖布局、触控、规则、计分、3D 牌桌、牌体、四档空间布局、相机构图、灯光与 C# Release 编译。

自动化与本机画面可以证明模型、缩放合同和渲染结果；手机上的主观观感、真实手指操作和完整牌局仍需人工验收。
