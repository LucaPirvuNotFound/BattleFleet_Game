extends Node
class_name AiService

var api_client: ApiClient

## Server should respond within ~12s (Ollama) or fallback; don't wait 90s on a hung Pi.
const ADMIRAL_TURN_TIMEOUT_SEC := 20.0
const DEBUG_JSON_MAX_CHARS := 12000


func request_admiral_turn(game_state: Dictionary) -> Dictionary:
	var body := {"game_state": game_state}
	_print_debug_json("[AiService] REQUEST POST /ai/admiral_turn", body)

	var response := await api_client.send_request(
		"/ai/admiral_turn",
		HTTPClient.METHOD_POST,
		body,
		ADMIRAL_TURN_TIMEOUT_SEC
	)

	var log_payload: Dictionary = response.duplicate(true)
	if log_payload.has("data") and log_payload["data"] is Dictionary:
		log_payload["data"] = log_payload["data"]
	_print_debug_json(
		"[AiService] RESPONSE status=%d success=%s" % [
			int(response.get("status", 0)),
			str(response.get("success", false))
		],
		log_payload
	)
	if not response.get("success", false):
		print("[AiService] ERROR: %s" % str(response.get("error", "unknown")))

	return response


func _print_debug_json(label: String, data: Variant) -> void:
	var text := JSON.stringify(data, "\t")
	if text.length() > DEBUG_JSON_MAX_CHARS:
		text = text.substr(0, DEBUG_JSON_MAX_CHARS) + "\n... [truncated, total %d chars]" % text.length()
	print("%s\n%s" % [label, text])
