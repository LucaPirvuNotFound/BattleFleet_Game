extends Node
class_name AuthService

var api_client: ApiClient


func register_user(username: String, email: String, password: String) -> Dictionary:
	var payload := {
		"username": username,
		"email": email,
		"password": password,
	}
	var response := await api_client.send_request(
		"/auth/register",
		HTTPClient.METHOD_POST,
		payload
	)
	return _finalize_response(response)


func login_user(username: String, password: String) -> Dictionary:
	var payload := {
		"username": username,
		"password": password,
	}
	var response := await api_client.send_request(
		"/auth/login",
		HTTPClient.METHOD_POST,
		payload
	)
	var result := _finalize_response(response)

	if result.success:
		var token := str(result.data.get("access_token", ""))
		if token.is_empty():
			result["success"] = false
			result["error"] = "Login succeeded but no access token was returned."
		else:
			NetworkManager.set_auth_token(token)
	elif result.has("error"):
		NetworkManager.clear_auth_token()

	return result


func _finalize_response(response: Dictionary) -> Dictionary:
	var result := response.duplicate(true)
	if not result.has("error"):
		result["error"] = ""
	if result.success and result.data.has("message"):
		result["message"] = str(result.data["message"])
	return result
