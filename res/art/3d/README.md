# 3D 资产说明

本目录中的核心 GLB 由 `tools/3d/generate_mahjong_assets.py` 使用 Blender 确定性生成。

| 资产 | 来源 | 外部生成费用 | 用途 |
|---|---|---:|---|
| `mahjong_tile_body.glb` | Blender 5.2 脚本 | 0 | 共享倒角暖象牙麻将牌体 |
| `sichuan_table.glb` | Blender 5.2 脚本 | 0 | 墨玉绒面桌、黑木桌沿、旧铜嵌线 |

V1 核心牌局没有调用 Tripo3D 或其他付费生成服务。API Key 只保存在 macOS 钥匙串，不属于工程资产。
