extends RefCounted
class_name SichuanProtocolCodec

const PROTOCOL_VERSION := 1
const MAX_MESSAGE_BYTES := 65536
# Settlement/fan explanations can legitimately exceed a UI label-sized string.
# The complete packet remains bounded to 64 KiB and dictionary keys stay at 64.
const MAX_STRING_LENGTH := 4096

func encode(message: Dictionary) -> PackedByteArray:
	if not validate_message(message):
		return PackedByteArray()
	var result := JSON.stringify(message).to_utf8_buffer()
	return result if result.size() <= MAX_MESSAGE_BYTES else PackedByteArray()

func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_MESSAGE_BYTES:
		return {"ok": false, "error": "MESSAGE_SIZE"}
	var value = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or not validate_message(value):
		return {"ok": false, "error": "INVALID_MESSAGE"}
	return {"ok": true, "message": value}

func validate_message(message: Dictionary) -> bool:
	if int(message.get("protocol_version", 0)) != PROTOCOL_VERSION:
		return false
	var kind = message.get("kind")
	if not kind is String or kind.is_empty() or kind.length() > 32:
		return false
	return _simple_value(message, 0)

func _simple_value(value: Variant, depth: int) -> bool:
	if depth > 8:
		return false
	if value == null or value is bool or value is int or value is float:
		return true
	if value is String:
		return value.length() <= MAX_STRING_LENGTH
	if value is Array:
		if value.size() > 256: return false
		for item in value:
			if not _simple_value(item, depth + 1): return false
		return true
	if value is Dictionary:
		if value.size() > 128: return false
		for key in value:
			if not key is String or key.length() > 64 or not _simple_value(value[key], depth + 1): return false
		return true
	return false
