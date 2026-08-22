class_name SichuanTableSkinCatalog
extends RefCounted

const DEFAULT_SKIN_ID := "deep_emerald_crepe"
const TEXTURE_ROOT := "res://res/art/materials/table_skins"

const SKINS: Array[Dictionary] = [
	{
		"id": "deep_emerald_crepe",
		"name": "深翡翠绉绒",
		"subtitle": "细密短绒·推荐",
		"source": "crepe_georgette",
		"albedo_tint": Color("3E6654"),
		"uv_scale": Vector3(3.2, 3.2, 1.0),
		"normal_scale": 0.12,
		"roughness": 0.90,
		"anisotropy": 0.14,
		"light_color": Color("F6E8CF"),
		"rake_energy": 0.55,
		"overhead_energy": 0.35,
		"bounce_energy": 0.52,
	},
	{
		"id": "emerald_linen",
		"name": "翡翠精纺",
		"subtitle": "天然经纬·沉稳",
		"source": "rough_linen",
		"albedo_tint": Color("416B56"),
		"uv_scale": Vector3(3.0, 3.0, 1.0),
		"normal_scale": 0.10,
		"roughness": 0.94,
		"anisotropy": 0.08,
		"light_color": Color("F4E5CE"),
		"rake_energy": 0.88,
		"overhead_energy": 0.94,
		"bounce_energy": 0.92,
	},
	{
		"id": "warm_caban_velvet",
		"name": "墨绿暖绒",
		"subtitle": "厚实柔和·经典",
		"source": "caban",
		"albedo_tint": Color("4C6856"),
		"uv_scale": Vector3(2.8, 2.8, 1.0),
		"normal_scale": 0.10,
		"roughness": 0.96,
		"anisotropy": 0.11,
		"light_color": Color("F8E2C2"),
		"rake_energy": 0.86,
		"overhead_energy": 0.90,
		"bounce_energy": 0.88,
	},
	{
		"id": "black_gold_jacquard",
		"name": "黑金暗纹",
		"subtitle": "低调提花·夜宴",
		"source": "quatrefoil_jacquard_fabric",
		"albedo_tint": Color("2E443B"),
		"uv_scale": Vector3(2.6, 2.6, 1.0),
		"normal_scale": 0.09,
		"roughness": 0.92,
		"anisotropy": 0.10,
		"light_color": Color("F7DDB8"),
		"rake_energy": 1.04,
		"overhead_energy": 1.08,
		"bounce_energy": 0.82,
	},
	{
		"id": "champagne_satin",
		"name": "香槟缎面",
		"subtitle": "暖金柔光·典藏",
		"source": "crepe_satin",
		"albedo_tint": Color("70644A"),
		"uv_scale": Vector3(3.0, 3.0, 1.0),
		"normal_scale": 0.08,
		"roughness": 0.86,
		"anisotropy": 0.18,
		"light_color": Color("FFF0D2"),
		"rake_energy": 0.76,
		"overhead_energy": 0.82,
		"bounce_energy": 0.72,
	},
	{
		"id": "teal_teddy_check",
		"name": "青黛格绒",
		"subtitle": "柔软格纹·趣味",
		"source": "curly_teddy_checkered",
		"albedo_tint": Color("385D64"),
		"uv_scale": Vector3(6.0, 6.0, 1.0),
		"normal_scale": 0.07,
		"roughness": 0.98,
		"anisotropy": 0.06,
		"light_color": Color("E7E2D1"),
		"rake_energy": 0.82,
		"overhead_energy": 0.88,
		"bounce_energy": 0.86,
	},
]


static func all_skins() -> Array[Dictionary]:
	return SKINS.duplicate(true)


static func get_skin(skin_id: String) -> Dictionary:
	for skin in SKINS:
		if str(skin.get("id", "")) == skin_id:
			return skin.duplicate(true)
	return SKINS[0].duplicate(true)


static func has_skin(skin_id: String) -> bool:
	for skin in SKINS:
		if str(skin.get("id", "")) == skin_id:
			return true
	return false


static func texture_path(skin_id: String, filename: String) -> String:
	var resolved_id := skin_id if has_skin(skin_id) else DEFAULT_SKIN_ID
	return "%s/%s/%s" % [TEXTURE_ROOT, resolved_id, filename]
