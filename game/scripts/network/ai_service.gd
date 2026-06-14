extends Node
class_name AiService

var api_client: ApiClient

## Server responds in ~12s (Ollama) or immediately (fallback); 20s gives enough headroom.
const ADMIRAL_TURN_TIMEOUT_SEC := 20.0
const NARRATOR_TURN_TIMEOUT_SEC := 30.0  # gTTS adds a short external HTTP call
const DEBUG_JSON_MAX_CHARS := 12000

var _admiral_http: HTTPRequest
var _narrator_http: HTTPRequest
var _audio_player: AudioStreamPlayer

# Resolve calls awaiting _admiral_http
var _admiral_resolve: Callable


func _ready() -> void:
	_admiral_http = HTTPRequest.new()
	_admiral_http.timeout = ADMIRAL_TURN_TIMEOUT_SEC
	add_child(_admiral_http)
	_admiral_http.request_completed.connect(_on_admiral_completed)

	_narrator_http = HTTPRequest.new()
	_narrator_http.timeout = NARRATOR_TURN_TIMEOUT_SEC
	add_child(_narrator_http)
	_narrator_http.request_completed.connect(_on_narrator_completed)

	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)


# ── Admiral turn ────────────────────────────────────────────────────────────────

func request_admiral_turn(game_state: Dictionary) -> Dictionary:
	var url := api_client.BASE_URL + "/ai/admiral_turn"
	var headers := _auth_headers()
	var payload := JSON.stringify({"game_state": game_state})

	var err := _admiral_http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		return {"success": false, "status": 0, "data": {}, "error": "Failed to start admiral request (%s)." % error_string(err)}

	var completed: Array = await _admiral_http.request_completed
	var result: int    = completed[0]
	var code: int      = completed[1]
	var body: PackedByteArray = completed[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "status": code, "data": {}, "error": "Admiral HTTP transport error (result %d)." % result}

	var text := body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		data = {}
	var success := code >= 200 and code < 300
	var response := {"success": success, "status": code, "data": data}
	if not success:
		response["error"] = str((data as Dictionary).get("detail", "Request failed with status %d." % code))
	return response


func _on_admiral_completed(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	pass  # Handled inline via await in request_admiral_turn


# ── Narrator turn (fire-and-forget) ─────────────────────────────────────────────

func request_narrator_turn(game_state: Dictionary) -> void:
	var err := _narrator_http.request(
		api_client.BASE_URL + "/ai/narrator_turn",
		_auth_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({"game_state": game_state})
	)
	if err == ERR_BUSY:
		return  # Previous narrator request still in flight


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


# ── Helpers ──────────────────────────────────────────────────────────────────────

func _auth_headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if NetworkManager.auth_token != "":
		headers.append("Authorization: Bearer %s" % NetworkManager.auth_token)
	return headers
