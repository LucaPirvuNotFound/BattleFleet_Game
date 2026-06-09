extends Node
class_name ApiClient

const BASE_URL := "http://battlefeet.go.ro:8001"

func send_request(
	endpoint: String,
	method: HTTPClient.Method,
	body: Dictionary = {},
	timeout_sec: float = 30.0
) -> Dictionary:
	# Per-request HTTPRequest so long AI calls do not block other API traffic.
	var http := HTTPRequest.new()
	http.timeout = timeout_sec
	add_child(http)

	var url := BASE_URL + endpoint
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])

	if NetworkManager.auth_token != "":
		headers.append("Authorization: Bearer %s" % NetworkManager.auth_token)

	var payload := ""
	if not body.is_empty():
		payload = JSON.stringify(body)

	var request_err := http.request(url, headers, method, payload)
	if request_err != OK:
		http.queue_free()
		return {
			"success": false,
			"status": 0,
			"data": {},
			"error": "Failed to start HTTP request (%s)." % error_string(request_err),
		}

	var completed: Array = await http.request_completed
	http.queue_free()

	var result: int = completed[0]
	var response_code: int = completed[1]
	var response_body: PackedByteArray = completed[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"data": {},
			"error": "HTTP transport error (%s)." % _result_to_string(result),
		}

	var text := response_body.get_string_from_utf8()
	var data := _parse_json_response(text)
	var success := response_code >= 200 and response_code < 300

	var response := {
		"success": success,
		"status": response_code,
		"data": data,
	}
	if not success:
		response["error"] = _extract_error_message(data, response_code)
	return response


func _parse_json_response(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {}
	if parsed is Dictionary:
		return parsed
	return {"_raw": parsed}


func _extract_error_message(data: Dictionary, status_code: int) -> String:
	if data.has("detail"):
		return _format_detail(data["detail"])
	if data.has("message"):
		return str(data["message"])
	return "Request failed with status %d." % status_code


func _format_detail(detail: Variant) -> String:
	if detail is String:
		return detail
	if detail is Array:
		var messages: PackedStringArray = []
		for entry in detail:
			if entry is Dictionary and entry.has("msg"):
				messages.append(str(entry["msg"]))
		if not messages.is_empty():
			return ", ".join(messages)
	return str(detail)


func _result_to_string(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "cannot connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "cannot resolve host"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "no response"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "body size limit exceeded"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "request failed"
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout"
		_:
			return "code %d" % result
