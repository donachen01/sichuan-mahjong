extends Control

const MAIN_SCENE_PATH := "res://scenes/table/MainSceneV2.tscn"
const SPLASH_SECONDS := 3.0

@onready var splash_image: TextureRect = %SplashImage
@onready var title_label: Label = %TitleLabel
@onready var loading_label: Label = %LoadingLabel
@onready var version_label: Label = %VersionLabel
@onready var dice_left: Label = %DiceLeft
@onready var dice_right: Label = %DiceRight
@onready var credit_label: Label = %CreditLabel

var _elapsed := 0.0
var _dice_faces := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--stage6-release-performance"):
		var probe_script := load("res://tools/Stage6ReleasePerformanceProbe.gd") as Script
		if probe_script == null:
			push_error("Stage 6 release performance probe script is missing")
			get_tree().quit(1)
			return
		var probe := probe_script.new() as Node
		get_tree().root.add_child.call_deferred(probe)
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1, 1, 1, 0)
	version_label.text = _app_version_text()
	splash_image.pivot_offset = get_viewport_rect().size * 0.5
	dice_left.pivot_offset = dice_left.size * 0.5
	dice_right.pivot_offset = dice_right.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(splash_image, "scale", Vector2(1.035, 1.035), SPLASH_SECONDS).from(Vector2(1.0, 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(credit_label, "modulate:a", 1.0, 0.45).from(0.0).set_delay(0.4)
	_start_dice_bounce(dice_left, 0.0, 0.0)
	_start_dice_bounce(dice_right, 0.16, 1.0)
	await get_tree().create_timer(SPLASH_SECONDS).timeout
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _process(delta: float) -> void:
	_elapsed += delta
	_update_die_face(dice_left, 0, 3.2)
	_update_die_face(dice_right, 1, 2.8)


func _start_dice_bounce(label: Label, delay: float, phase: float) -> void:
	var bounce := create_tween().set_loops()
	bounce.tween_interval(delay)
	bounce.tween_method(_tween_dice.bind(label, phase), 0.0, 1.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bounce.tween_method(_tween_dice.bind(label, phase), 1.0, 0.0, 0.44).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	bounce.tween_interval(0.22)


func _tween_dice(weight: float, label: Label, phase: float) -> void:
	var y_offset := lerpf(0.0, -18.0, weight)
	var rotation := deg_to_rad(lerpf(-4.0, 7.0, weight) * cos(_elapsed * 3.0 + phase))
	var scale_boost := 1.0 + 0.06 * weight
	label.position.y = y_offset
	label.rotation = rotation
	label.scale = Vector2(scale_boost, scale_boost)


func _update_die_face(label: Label, offset: int, speed: float) -> void:
	var index := int(floor(_elapsed * speed) + offset) % _dice_faces.size()
	label.text = _dice_faces[index]


func _app_version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version == "":
		return ""
	return "版本 v%s" % version
