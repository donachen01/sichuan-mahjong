extends SceneTree

const REQUIRED_FILES := [
	"res://res/art/3d/sichuan_table_v2.glb",
	"res://res/art/3d/sichuan_table_v2_felt_basecolor.png",
	"res://res/art/materials/table_v2/felt_basecolor.png",
	"res://res/art/materials/table_v2/felt_normal.png",
	"res://res/art/materials/table_v2/felt_orm.png",
]

func _initialize() -> void:
	var failed := false
	print("package_version=", ProjectSettings.get_setting("application/config/version", ""))
	for path in REQUIRED_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			failed = true
			print("missing=", path, " error=", FileAccess.get_open_error())
			continue
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(file.get_buffer(file.get_length()))
		print("present=", path, " bytes=", file.get_length(), " sha256=", context.finish().hex_encode())
	quit(1 if failed else 0)
