# 3D 资产说明

本目录中的核心 GLB 由 Blender 5.2 LTS 脚本确定性生成。

| 资产 | 来源 | 外部生成费用 | 用途 |
|---|---|---:|---|
| `mahjong_tile_body.glb` | Blender 5.2 脚本 | 0 | 共享倒角暖象牙麻将牌体 |
| `sichuan_table.glb` | Blender 5.2 脚本 | 0 | 墨玉绒面桌、黑木桌沿、旧铜嵌线 |
| `sichuan_table_v2.glb` | `tools/3d/generate_sichuan_table_v2.py` | 0 | 深森林绿短绒 PBR、连续圆角温暖胡桃木托盘边框、内嵌深绿皮革 gasket、低对比分区凹槽与纵向木纹浮雕 |
| `sichuan_center_compass_v2.glb` | `tools/3d/generate_sichuan_center_compass_v2.py` | 0 | 1,044 三角面、9 对象、4 材质的齐平亮面玻璃四向嵌件；Blender 提供连续烟熏翡翠玻璃、石墨方向发丝线、无黄色/旧铜描边的干净外缘、低高光古铜计数环、玻璃镜片，以及使用半径 0.460 分段圆弧切口避让 0.455 古铜计数环、经 Filmic 显示补偿后输出 `#A13D2D` 的真实 3D 状态片；状态片严格复用分隔线角度，东/西跨度为 124.48292°、南/北为 55.51708°；Godot 仅叠加动态余牌数字与方向字 |

V2 桌体的 BaseColor、Normal、ORM 贴图位于 `res/art/materials/table_v2/`；桌布为 2048，皮革和温暖胡桃木为 1024，适合移动端。Godot 主路径保留 GLB 的 PBR surface material，不得再用运行时单色材质覆盖。

重新生成：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/3d/generate_sichuan_table_v2.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/3d/generate_sichuan_center_compass_v2.py
```

V1/V2 核心牌局没有调用 Tripo3D 或其他付费生成服务。所有 V2 网格和纹理由仓库脚本原创生成；API Key 只保存在 macOS 钥匙串，不属于工程资产。当前 V2 桌框不再使用四段拼接、亮铜嵌线或缝线装饰，避免接缝和高亮抢占牌局主体。
