extends Node
class_name MatchService

var api_client: ApiClient


func create_instant_match(mode: String, fleet_payload: Dictionary) -> Dictionary:
	var body := {
		"mode": mode.to_lower(),
		"fleet": fleet_payload,
	}
	var response := await api_client.send_request(
		"/matches/instant",
		HTTPClient.METHOD_POST,
		body
	)
	return _finalize(response)


func create_local_match(
	host_fleet: Dictionary,
	guest_fleet: Dictionary,
	guest_username: String
) -> Dictionary:
	var body := {
		"mode": "local",
		"fleet": host_fleet,
		"opponent_fleet": guest_fleet,
		"opponent_username": guest_username,
	}
	var response := await api_client.send_request(
		"/matches/instant",
		HTTPClient.METHOD_POST,
		body
	)
	return _finalize(response)


func fetch_match(match_id: String) -> Dictionary:
	var response := await api_client.send_request(
		"/matches/%s" % match_id,
		HTTPClient.METHOD_GET
	)
	return _finalize(response)


func coin_ack(match_id: String) -> Dictionary:
	return _finalize(
		await api_client.send_request(
			"/matches/%s/coin_ack" % match_id,
			HTTPClient.METHOD_POST
		)
	)


func submit_placement(match_id: String, placements: Array) -> Dictionary:
	var body := {"placements": placements}
	return _finalize(
		await api_client.send_request(
			"/matches/%s/placement" % match_id,
			HTTPClient.METHOD_POST,
			body
		)
	)


func mark_ready(match_id: String) -> Dictionary:
	return _finalize(
		await api_client.send_request(
			"/matches/%s/ready" % match_id,
			HTTPClient.METHOD_POST
		)
	)


func build_default_placements(fleet: Array) -> Array:
	var placements: Array = []
	for index in fleet.size():
		placements.append({
			"ship_index": index,
			"x": index * 2,
			"y": 0,
			"rotation": 0,
		})
	return placements


func _finalize(response: Dictionary) -> Dictionary:
	var result := response.duplicate(true)
	if not result.has("error"):
		result["error"] = ""
	if result.success:
		MatchContext.apply_snapshot(result.data)
	return result
