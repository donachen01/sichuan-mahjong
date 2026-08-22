# 内江麻将桌布皮肤素材

本目录的六套 PBR 桌布素材转换自用户本机下载的 Poly Haven 素材：

- `crepe_georgette` → 深翡翠绉绒
- `rough_linen` → 翡翠精纺
- `caban` → 墨绿暖绒
- `quatrefoil_jacquard_fabric` → 黑金暗纹
- `crepe_satin` → 香槟缎面
- `curly_teddy_checkered` → 青黛格绒

来源：[Poly Haven](https://polyhaven.com/)，许可证：[CC0](https://polyhaven.com/license)。

运行时只使用本目录中生成的 2K 漫反射、OpenGL 法线、粗糙度和预览图；原始 4K `.blend` / EXR 文件保留在项目外部，不进入 iOS/Android 安装包。桌面不使用几何位移，避免影响麻将牌的视觉接触面和移动端性能。

重新生成：

```bash
python3 tools/materials/build_polyhaven_table_skins.py
```
