extends SceneTree
func _init() -> void:
	await process_frame
	var runtime = load("res://scripts/ai/SichuanCSharpRuntime.cs").new()
	root.add_child(runtime)
	var passed := not bool(runtime.get("DecisionAuditEnabled"))
	# The compiled Release property rejects this request. The error is expected.
	runtime.set("DecisionAuditEnabled", true)
	passed = passed and not bool(runtime.get("DecisionAuditEnabled"))
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/hu_income_cost_20260930/book_reaction.json"))
	for variant in ["bucket_local_candidate_v1", "gang_branch_candidate_v1"]:
		payload["policyVariant"] = variant
		var reply = JSON.parse_string(str(runtime.call("AnalyzeReactionJson", JSON.stringify(integer_payload(payload)))))
		passed = passed and reply is Dictionary and not bool(reply.get("ok", true)) and str(reply.get("error", "")) == "experimental_policy_not_in_production_build"
	passed = passed and str(runtime.call("GetDecisionAuditPath")).is_empty()
	print("COMPILED_RELEASE_BOUNDARY recording_cannot_enable_experimental_policy_rejected_no_file=", passed)
	runtime.queue_free()
	quit(0 if passed else 1)
func integer_payload(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = integer_payload(value[key])
		return result
	if value is Array:
		return value.map(integer_payload)
	if value is float and value == floor(value):
		return int(value)
	return value
