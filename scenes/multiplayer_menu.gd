extends Control

# Multiplayer Menu - Entry point to the room system

@onready var name_input = $MainPanel/MainContainer/PlayerNameSection/NameInput
@onready var create_room_button = $MainPanel/MainContainer/OptionsContainer/CreateRoomSection/CreateRoomButton
@onready var join_room_button = $MainPanel/MainContainer/OptionsContainer/JoinRoomSection/JoinRoomButton

func _ready():
	print("🌐 Multiplayer Menu loaded")
	
	# Set focus to name input
	name_input.grab_focus()
	
	# Update button states
	update_button_states()

func _on_name_input_text_changed(new_text: String):
	# Limit name to 15 characters
	if new_text.length() > 15:
		new_text = new_text.substr(0, 15)
		name_input.text = new_text
		name_input.caret_column = new_text.length()
	
	# Update button states based on name validity
	update_button_states()

func update_button_states():
	var name_text = name_input.text.strip_edges()
	var is_valid_name = name_text.length() > 0 and name_text.length() <= 15
	
	create_room_button.disabled = not is_valid_name
	join_room_button.disabled = not is_valid_name
	
	if name_text.length() == 0:
		create_room_button.tooltip_text = "Enter a player name to create a room"
		join_room_button.tooltip_text = "Enter a player name to join a room"
	elif name_text.length() > 15:
		create_room_button.tooltip_text = "Player name too long (max 15 characters)"
		join_room_button.tooltip_text = "Player name too long (max 15 characters)"
	else:
		create_room_button.tooltip_text = ""
		join_room_button.tooltip_text = ""

func _on_create_room_button_pressed():
	var player_name = name_input.text.strip_edges()
	
	if player_name.length() == 0:
		print("❌ Player name cannot be empty")
		return
	
	print("🏠 Navigating to room creation with player: ", player_name)
	
	# Store player name for room creation
	get_tree().set_meta("player_name", player_name)
	
	# Navigate to room creation
	get_tree().change_scene_to_file("res://scenes/room_creation.tscn")

func _on_join_room_button_pressed():
	var player_name = name_input.text.strip_edges()
	
	if player_name.length() == 0:
		print("❌ Player name cannot be empty")
		return
	
	print("🔍 Navigating to join options with player: ", player_name)
	
	# Store player name for joining
	get_tree().set_meta("player_name", player_name)
	
	# Navigate to join options
	get_tree().change_scene_to_file("res://scenes/join_options.tscn")

func _on_back_button_pressed():
	print("⬅️ Going back to main menu")
	get_tree().change_scene_to_file("res://scenes/lobby.tscn") 