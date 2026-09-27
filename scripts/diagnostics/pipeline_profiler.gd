extends RefCounted

# Opt-in, bounded timings. Nested spans are inclusive and must not be added together.
static var enabled: bool = OS.get_environment("SICHUAN_PROFILE_PIPELINE") == "1" or OS.get_cmdline_user_args().has("--profile-pipeline")
static var _samples: Dictionary = {}
const SAMPLE_LIMIT := 256


static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func record(category: String, started_usec: int) -> void:
	if not enabled or started_usec == 0:
		return
	var samples: Array = _samples.get(category, [])
	if samples.size() >= SAMPLE_LIMIT:
		samples.pop_front()
	samples.append(maxi(0, Time.get_ticks_usec() - started_usec))
	_samples[category] = samples


static func reset() -> void:
	_samples.clear()


static func summary() -> Dictionary:
	var result := {}
	for category in _samples:
		var values: Array = _samples[category].duplicate()
		values.sort()
		var total := 0.0
		for value in values:
			total += float(value)
		result[category] = {
			"samples": values.size(), "mean_us": total / values.size(),
			"p50_us": values[int((values.size() - 1) * 0.5)],
			"p95_us": values[int(ceil((values.size() - 1) * 0.95))],
			"max_us": values[-1],
		}
	return result


static func save(path: String = "user://pipeline_profile.json") -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"units": "microseconds", "spans": "inclusive", "timings": summary()}, "  "))
	return OK
