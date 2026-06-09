extends Node

func _ready() -> void:
	print("[BattleServer] Headless battle server running (ENet port %d)." % BattleNetwork.DEFAULT_PORT)
	print("[BattleServer] Ensure FastAPI is up at %s" % NetworkManager.api_client.BASE_URL)
