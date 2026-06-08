extends Node



var auth_token: String = ""
var logged_in_username: String = ""



var api_client: ApiClient

var auth_service: AuthService

var fleet_service: FleetService

var matchmaking_service: MatchmakingService

var match_service: MatchService



var impl: Node = null





func _ready() -> void:

	api_client = preload("res://scripts/network/api_client.gd").new()

	api_client.name = "ApiClient"

	add_child(api_client)



	auth_service = preload("res://scripts/network/auth_service.gd").new()

	auth_service.name = "AuthService"

	auth_service.api_client = api_client

	add_child(auth_service)



	fleet_service = preload("res://scripts/network/fleet_service.gd").new()

	fleet_service.name = "FleetService"

	add_child(fleet_service)



	matchmaking_service = preload("res://scripts/network/matchmaking_service.gd").new()

	matchmaking_service.name = "MatchmakingService"

	matchmaking_service.api_client = api_client

	add_child(matchmaking_service)



	match_service = preload("res://scripts/network/match_service.gd").new()

	match_service.name = "MatchService"

	match_service.api_client = api_client

	add_child(match_service)



	if OS.has_feature("server"):

		impl = preload("res://scripts/ServerImpl.gd").new()

	else:

		impl = preload("res://scripts/ClientImpl.gd").new()



	add_child(impl)





func set_auth_token(token: String) -> void:

	auth_token = token





func clear_auth_token() -> void:

	auth_token = ""
	logged_in_username = ""





func is_logged_in() -> bool:

	return auth_token != ""
