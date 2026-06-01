extends Node
class_name MatchmakingService

const POLL_INTERVAL_SEC := 1.0
const MAX_POLL_ATTEMPTS := 120

var api_client: ApiClient
var _poll_cancel_requested: bool = false


func reset_poll_cancel() -> void:
	_poll_cancel_requested = false


func request_poll_cancel() -> void:
	_poll_cancel_requested = true


func join_queue(mode: String, fleet_payload: Dictionary) -> Dictionary:
	var body := {
		"mode": mode.to_lower(),
		"fleet": fleet_payload,
	}
	return await api_client.send_request(
		"/matchmaking/queue",
		HTTPClient.METHOD_POST,
		body
	)


func get_status() -> Dictionary:
	return await api_client.send_request("/matchmaking/status", HTTPClient.METHOD_GET)


func leave_queue() -> Dictionary:
	return await api_client.send_request("/matchmaking/queue", HTTPClient.METHOD_DELETE)


func poll_until_matched() -> Dictionary:
	reset_poll_cancel()
	for _attempt in MAX_POLL_ATTEMPTS:
		if _poll_cancel_requested:
			return _cancelled_poll_result()

		var response := await get_status()
		if _poll_cancel_requested:
			return _cancelled_poll_result()
		if not response.success:
			return _finalize(response)

		var status := str(response.data.get("status", "idle"))
		if status == "matched":
			var match_id := str(response.data.get("match_id", ""))
			return {
				"success": true,
				"status": response.status,
				"data": response.data,
				"match_id": match_id,
				"error": "",
				"cancelled": false,
			}

		if status == "idle":
			return {
				"success": false,
				"status": response.status,
				"data": response.data,
				"match_id": "",
				"error": str(response.data.get("message", "Not in matchmaking queue")),
				"cancelled": false,
			}

		if not await _wait_poll_interval():
			return _cancelled_poll_result()

	return {
		"success": false,
		"status": 0,
		"data": {},
		"match_id": "",
		"error": "Matchmaking timed out",
		"cancelled": false,
	}


func _wait_poll_interval() -> bool:
	var elapsed := 0.0
	while elapsed < POLL_INTERVAL_SEC:
		if _poll_cancel_requested:
			return false
		var step := minf(0.1, POLL_INTERVAL_SEC - elapsed)
		await get_tree().create_timer(step).timeout
		elapsed += step
	return not _poll_cancel_requested


func _cancelled_poll_result() -> Dictionary:
	return {
		"success": false,
		"status": 0,
		"data": {},
		"match_id": "",
		"error": "Matchmaking cancelled",
		"cancelled": true,
	}


func _finalize(response: Dictionary) -> Dictionary:
	var result := response.duplicate(true)
	if not result.has("match_id"):
		result["match_id"] = ""
	if not result.has("error"):
		result["error"] = str(result.get("error", "Matchmaking request failed"))
	return result
