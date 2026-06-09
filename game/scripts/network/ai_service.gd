extends Node
class_name AiService

var api_client: ApiClient


func request_admiral_turn(game_state: Dictionary) -> Dictionary:
	var body := {"game_state": game_state}
	var response := await api_client.send_request(
		"/ai/admiral_turn",
		HTTPClient.METHOD_POST,
		body
	)
	return response
