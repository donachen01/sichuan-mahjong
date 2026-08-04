# 深翡翠牌桌 V2 PBR 材质来源

- 生成脚本：`tools/3d/generate_sichuan_table_v2.py`
- 生成器：Blender 5.2 LTS，固定随机种子，可重复执行
- 版权来源：全部由本项目脚本原创生成，不包含参考游戏贴图、Logo、文字或第三方素材
- 桌布：`felt_basecolor / felt_normal / felt_orm`，2048×2048
- 蜀锦审计遮罩：`brocade_mask.png`，2048×2048，仅用于证明纹样空间范围，不绑定运行时材质
- 皮革：`leather_basecolor / leather_normal / leather_orm`，1024×1024
- 黑胡桃：`walnut_basecolor / walnut_normal / walnut_orm`，1024×1024
- ORM 通道：R=AO，G=Roughness，B=Metallic
- 桌布合同：生产 BaseColor 使用均匀森林绿，只保留细密高频纤维变化，不含中心晕染、边缘压暗或大块低频颜色噪声；短绒方向由 Normal 承担，roughness 0.78–0.86，metallic 0。`brocade_mask.png` 仅为历史审计遮罩，不参与生产底色。
- 皮革/木纹只保留低对比颗粒，旧铜为单独 PBR 材质；所有运行时贴图最大 2K。

图像生成工具未参与最终贴图生产；如后续用于事件字概念探索，最终资源仍须人工二次设计并保留分层源文件。
