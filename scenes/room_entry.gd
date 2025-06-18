extends Panel

# Room Entry - Individual room display in the public rooms browser

signal room_join_requested(room_code: String)

@onready var room_code_label = $MainContainer/RoomInfoContainer/RoomHeader/RoomCodeLabel
@onready var room_name_label = $MainContainer/RoomInfoContainer/RoomHeader/RoomNameLabel
@onready var game_mode_label = $MainContainer/RoomInfoContainer/RoomDetailsContainer/GameModeLabel
@onready var difficulty_label = $MainContainer/RoomInfoContainer/RoomDetailsContainer/DifficultyLabel
@onready var players_label = $MainContainer/RoomInfoContainer/RoomDetailsContainer/PlayersLabel
@onready var join_button = $MainContainer/JoinButton

var room_data: Dictionary = {}
var player_name: String = ""

func setup_room_data(room, requesting_player_name: String):
	room_data = room.to_dict() if room.has_method("to_dict") else room
	player_name = requesting_player_name
	
	# Update UI with room information
	update_room_display()

func update_room_display():
	# Room code and name
	room_code_label.text = "[" + room_data.get("code", "????") + "]"
	room_name_label.text = room_data.get("name", "Unnamed Room")
	
	# Game settings
	var settings = room_data.get("game_settings", {})
	var mode = settings.get("mode", "classic")
	var difficulty = settings.get("difficulty", "medium")
	
	# Format game mode
	match mode:
		"classic":
			game_mode_label.text = "🎮 Classic Mode"
		"random":
			game_mode_label.text = "🎲 Random Mode"
		_:
			game_mode_label.text = "🎮 " + mode.capitalize() + " Mode"
	
	# Format difficulty
	match difficulty:
		"easy":
			difficulty_label.text = "🐌 Easy"
		"medium":
			difficulty_label.text = "🚀 Medium"
		"hard":
			difficulty_label.text = "⚡ Hard"
		_:
			difficulty_label.text = "⚡ " + difficulty.capitalize()
	
	# Player count
	var current_players = room_data.get("player_count", 0)
	var max_players = room_data.get("max_players", 8)
	players_label.text = "👥 " + str(current_players) + "/" + str(max_players) + " players"
	
	# Disable join button if room is full or player is already in it
	var current_player_list = room_data.get("current_players", [])
	var is_full = current_players >= max_players
	var already_joined = current_player_list.has(player_name)
	
	join_button.disabled = is_full or already_joined
	
	if is_full:
		join_button.text = "🚫 Room Full"
	elif already_joined:
		join_button.text = "✅ Already Joined"
	else:
		join_button.text = "🚀 Join Room"

func set_joining_state(is_joining: bool):
	join_button.disabled = is_joining
	if is_joining:
		join_button.text = "Joining..."
	else:
		update_room_display()  # Reset to normal state

func _on_join_button_pressed():
	var room_code = room_data.get("code", "")
	if room_code != "":
		print("🚀 Requesting to join room: ", room_code)
		room_join_requested.emit(room_code)
	else:
		print("❌ Invalid room code") 