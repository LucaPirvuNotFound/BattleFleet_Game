extends Node

var auth_token: String = ""

var api_client: ApiClient
var auth_service: AuthService

var impl: Node = null


func _ready() -> void:
	api_client = preload("res://scripts/network/api_client.gd").new()
	api_client.name = "ApiClient"
	add_child(api_client)

	auth_service = preload("res://scripts/network/auth_service.gd").new()
	auth_service.name = "AuthService"
	auth_service.api_client = api_client
	add_child(auth_service)

	if OS.has_feature("server"):
		impl = preload("res://scripts/ServerImpl.gd").new()
	else:
		impl = preload("res://scripts/ClientImpl.gd").new()

	add_child(impl)


func set_auth_token(token: String) -> void:
	auth_token = token


func clear_auth_token() -> void:
	auth_token = ""
