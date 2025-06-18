extends Control

# Join Options Scene - Allows players to browse public rooms or join with a code

@onready var code_input = $MainPanel/MainContainer/CodeSection/CodeInputContainer/CodeInput
@onready var join_code_button = $MainPanel/MainContainer/CodeSection/CodeInputContainer/JoinCodeButton

var player_name: String = ""

func _ready():
	print("🔍 Join Options scene loaded")
	
	# Get player name from previous scene or use default
	if get_tree().has_meta("player_name"):
		player_name = get_tree().get_meta("player_name")
	else:
		player_name = "Player"
	
	# Connect to RoomManager signals
	var room_manager = get_node("/root/RoomManager")
	if not room_manager.room_joined.is_connected(_on_room_joined):
		room_manager.room_joined.connect(_on_room_joined)
	
	# Set up code input to only accept alphanumeric characters
	if not code_input.text_changed.is_connected(_on_code_input_text_changed):
		code_input.text_changed.connect(_on_code_input_text_changed)

func _on_code_input_text_changed(new_text: String):
	# Convert to uppercase and filter to alphanumeric only
	var filtered_text = ""
	for character in new_text.to_upper():
		if character.is_valid_identifier() or character.is_valid_int():
			filtered_text += character
	
	# Update the input if it was filtered
	if filtered_text != new_text:
		code_input.text = filtered_text
		code_input.caret_column = filtered_text.length()
	
	# Enable/disable join button based on input length
	join_code_button.disabled = filtered_text.length() != 4

func _on_browse_button_pressed():
	print("🌐 Opening public rooms browser")
	
	# Store player name for the browser
	get_tree().set_meta("player_name", player_name)
	
	# Navigate to public rooms browser
	get_tree().change_scene_to_file("res://scenes/public_rooms_browser.tscn")

func _on_join_code_button_pressed():
	var room_code = code_input.text.strip_edges().to_upper()
	
	if room_code.length() != 4:
		print("❌ Room code must be exactly 4 characters")
		return
	
	print("🔑 Attempting to join room with code: ", room_code)
	
	# Disable button to prevent double-joining
	join_code_button.disabled = true
	join_code_button.text = "Joining..."
	
	# Attempt to join room through RoomManager (await because it's async)
	var room_manager = get_node("/root/RoomManager")
	var success = await room_manager.join_room(room_code, player_name)
	
	if not success:
		print("❌ Failed to join room: ", room_code)
		join_code_button.disabled = false
		join_code_button.text = "🚀 Join Room"
		
		# Show error message (could be improved with a popup)
		code_input.placeholder_text = "Room not found or full"
		code_input.text = ""

func _on_room_joined(room_code: String):
	print("🎉 Successfully joined room: ", room_code)
	
	# Store room info for the lobby
	get_tree().set_meta("room_code", room_code)
	get_tree().set_meta("is_host", false)
	get_tree().set_meta("player_name", player_name)
	
	# Navigate to lobby
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_back_button_pressed():
	print("⬅️ Going back to multiplayer menu")
	get_tree().change_scene_to_file("res://scenes/lobby.tscn") 