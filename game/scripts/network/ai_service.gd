extends Node
class_name AiService

var api_client: ApiClient

var _narrator_http: HTTPRequest
var _audio_player: AudioStreamPlayer


func _ready() -> void:
	# Dedicated HTTP node for narrator so it runs in parallel with admiral requests.
	_narrator_http = HTTPRequest.new()
	_narrator_http.timeout = 90.0
	add_child(_narrator_http)
	_narrator_http.request_completed.connect(_on_narrator_completed)

	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)


# ── Admiral turn ────────────────────────────────────────────────────────────────

func request_admiral_turn(game_state: Dictionary) -> Dictionary:
	var response := await api_client.send_request(
		"/ai/admiral_turn",
		HTTPClient.METHOD_POST,
		{"game_state": game_state}
	)
	return response


# ── Narrator turn (fire-and-forget) ─────────────────────────────────────────────

func request_narrator_turn(game_state: Dictionary) -> void:
	if _narrator_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := api_client.BASE_URL + "/ai/narrator_turn"
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if NetworkManager.auth_token != "":
		headers.append("Authorization: Bearer %s" % NetworkManager.auth_token)
	_narrator_http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify({"game_state": game_state}))


func _on_narrator_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("[Narrator] Request failed — result:%d code:%d" % [result, response_code])
		return

	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return

	var audio_b64: String = str(data.get("audio_b64", ""))
	if audio_b64.is_empty():
		return

	var audio_bytes := Marshalls.base64_to_raw(audio_b64)
	var stream := AudioStreamMP3.new()
	stream.data = audio_bytes

	if _audio_player.playing:
		_audio_player.stop()
	_audio_player.stream = stream
	_audio_player.play()
