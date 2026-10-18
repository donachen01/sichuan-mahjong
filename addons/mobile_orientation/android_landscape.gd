extends Node

# Godot's SensorLandscape export maps to Android USER_LANDSCAPE (11),
# which stops following gravity when the system rotation lock is enabled.
# Request SENSOR_LANDSCAPE (6) directly without changing the user's settings.
const SENSOR_LANDSCAPE := 6

func _ready() -> void:
	_apply_landscape_sensor()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_apply_landscape_sensor()

func _apply_landscape_sensor() -> void:
	if not OS.has_feature("android"):
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		push_error("Android landscape rotation: AndroidRuntime is unavailable")
		return
	var activity = runtime.getActivity()
	if activity == null:
		push_error("Android landscape rotation: Activity is unavailable")
		return
	var apply_orientation := func():
		activity.setRequestedOrientation(SENSOR_LANDSCAPE)
		print("Android landscape gravity: requestedOrientation=", activity.getRequestedOrientation())
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(apply_orientation))
