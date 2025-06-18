extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal connection_failed()
signal connection_succeeded()
signal server_disconnected()
signal player_color_updated(peer_id, color)
signal player_ready_updated(peer_id, ready_state)

const DEFAULT_PORT = 7000
const MAX_CLIENTS = 8

var players = {}
var player_info = {"name": "Player"}
var ai_players = {}  # Store AI player data

var multiplayer_peer

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func join_game(address = "127.0.0.1", port = DEFAULT_PORT):
	# Clean up any existing peer first
	remove_multiplayer_peer()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(address, port)
	if error != OK:
		print("Cannot create client to ", address, ":", port, ". Error code: ", error)
		print("Check if server is running and address/port are correct")
		multiplayer_peer = null
		return error
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Client created, attempting to connect to ", address, ":", port)
	return OK

func create_game(port = DEFAULT_PORT):
	# Clean up any existing peer first
	remove_multiplayer_peer()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		print("Cannot create server on port ", port, ". Error code: ", error)
		print("Error meanings: OK=0, ERR_ALREADY_IN_USE=22, ERR_CANT_CREATE=37")
		print("Try a different port or check if port is already in use")
		multiplayer_peer = null
		return error
	
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Server successfully created on port: ", port)
	players[1] = player_info
	add_player(multiplayer.get_unique_id())
	return OK

func remove_multiplayer_peer():
	if multiplayer_peer:
		multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func _on_player_connected(_id):
	print("Player connected: ", _id)

func _on_player_disconnected(_id):
	print("Player disconnected: ", _id)
	players.erase(_id)
	player_disconnected.emit(_id)

func _on_connected_ok():
	print("Connected to server")
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	add_player.rpc_id(1, peer_id, player_info)
	connection_succeeded.emit()

func _on_connected_fail():
	print("Failed to connect to server")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

@rpc("any_peer", "reliable")
func add_player(peer_id, info = player_info):
	if not players.has(peer_id):
		players[peer_id] = info
	
	if multiplayer.is_server():
		for id in players:
			add_player.rpc(id, players[id])
	
	player_connected.emit(peer_id, info)

@rpc("any_peer", "call_local", "reliable")
func start_game(game_settings = {}):
	# Pass AI player data and game settings to the game scene
	get_tree().set_meta("ai_players", ai_players)
	get_tree().set_meta("game_settings", game_settings)
	get_tree().change_scene_to_file("res://scenes/networked_main.tscn")

@rpc("any_peer", "reliable")
func update_player_color(peer_id: int, color: String):
	if players.has(peer_id):
		players[peer_id]["color"] = color
	
	# Emit signal for local handling
	player_color_updated.emit(peer_id, color)
	
	# Notify all clients about the color change
	if multiplayer.is_server():
		for id in players:
			if id != peer_id:  # Don't send back to the sender
				update_player_color.rpc_id(id, peer_id, color)

@rpc("any_peer", "reliable")
func update_player_ready(peer_id: int, ready_state: bool):
	if players.has(peer_id):
		players[peer_id]["ready"] = ready_state
	
	# Emit signal for local handling
	player_ready_updated.emit(peer_id, ready_state)
	
	# Notify all clients about the ready state change
	if multiplayer.is_server():
		for id in players:
			if id != peer_id:  # Don't send back to the sender
				update_player_ready.rpc_id(id, peer_id, ready_state)

func get_player_list():
	return players.keys()

func get_player_count():
	return players.size()

func add_ai_player(ai_peer_id: int, ai_data: Dictionary):
	ai_players[ai_peer_id] = ai_data
	print("AI player added to NetworkManager: ", ai_data["name"])

func remove_ai_player(ai_peer_id: int):
	ai_players.erase(ai_peer_id)

func get_ai_players():
	return ai_players

func clear_ai_players():
	ai_players.clear()

func kick_player(peer_id: int):
	if not multiplayer.is_server():
		return
	
	print("Kicking player: ", peer_id)
	
	# Remove from players dictionary
	if players.has(peer_id):
		players.erase(peer_id)
	
	# Disconnect the peer
	if multiplayer_peer and multiplayer_peer.has_peer(peer_id):
		multiplayer_peer.disconnect_peer(peer_id)
	
	# Emit disconnection signal
	player_disconnected.emit(peer_id) 
