extends Control

# Room Creation Scene - Allows hosts to create new game rooms

@onready var room_name_input = $MainPanel/MainContainer/RoomNameSection/RoomNameInput
@onready var public_button = $MainPanel/MainContainer/VisibilitySection/VisibilityButtons/PublicButton
@onready var private_button = $MainPanel/MainContainer/VisibilitySection/VisibilityButtons/PrivateButton
@onready var room_code_text = $MainPanel/MainContainer/RoomCodeSection/RoomCodeDisplay/RoomCodeText
@onready var create_room_button = $MainPanel/MainContainer/ButtonContainer/CreateRoomButton

var is_public: bool = true
var generated_room_code: String = ""
var player_name: String = ""

func _ready():
	print("🏠 Room Creation scene loaded")
	
	# Get player name from previous scene or use default
	if get_tree().has_meta("player_name"):
		player_name = get_tree().get_meta("player_name")
	else:
		player_name = "Player"
	
	# Generate and display room code
	generate_new_room_code()
	
	# Set initial visibility selection
	update_visibility_buttons()
	
	# Connect to RoomManager signals
	var room_manager = get_node("/root/RoomManager")
	room_manager.room_created.connect(_on_room_created)

func generate_new_room_code():
	var room_manager = get_node("/root/RoomManager")
	generated_room_code = room_manager.generate_room_code()
	room_code_text.text = generated_room_code
	print("🔑 Generated room code: ", generated_room_code)

func update_visibility_buttons():
	if is_public:
		public_button.modulate = Color(1.2, 1.2, 1.2)  # Highlight selected
		private_button.modulate = Color(0.8, 0.8, 0.8)  # Dim unselected
	else:
		public_button.modulate = Color(0.8, 0.8, 0.8)  # Dim unselected
		private_button.modulate = Color(1.2, 1.2, 1.2)  # Highlight selected

func update_create_button():
	# Enable create button only if room name is provided
	var room_name = room_name_input.text.strip_edges()
	create_room_button.disabled = room_name.length() == 0

# Signal handlers
func _on_room_name_input_text_changed(_new_text: String):
	update_create_button()

func _on_public_button_pressed():
	is_public = true
	update_visibility_buttons()
	print("🌐 Room set to public")

func _on_private_button_pressed():
	is_public = false
	update_visibility_buttons()
	print("🔒 Room set to private")

func _on_create_room_button_pressed():
	var room_name = room_name_input.text.strip_edges()
	
	if room_name.length() == 0:
		print("❌ Room name cannot be empty")
		return
	
	print("🚀 Creating room: ", room_name, " (", "Public" if is_public else "Private", ")")
	
	# Disable button to prevent double-creation
	create_room_button.disabled = true
	create_room_button.text = "Creating..."
	
	# Create room through RoomManager
	var game_settings = {
		"mode": "classic",  # Default for now, will be configurable later
		"difficulty": "medium",
		"wall_wrapping": false
	}
	
	var room_manager = get_node("/root/RoomManager")
	var room_code = room_manager.create_room(room_name, player_name, is_public, game_settings)
	
	if room_code != "":
		print("✅ Room created successfully: ", room_code)
		# Room creation successful, signal will handle transition
	else:
		print("❌ Failed to create room")
		create_room_button.disabled = false
		create_room_button.text = "🚀 Create Room"

func _on_room_created(room_code: String):
	print("🎉 Room created signal received: ", room_code)
	
	# Store room info for the lobby
	get_tree().set_meta("room_code", room_code)
	get_tree().set_meta("is_host", true)
	get_tree().set_meta("player_name", player_name)
	
	# Transition to lobby
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_back_button_pressed():
	print("⬅️ Going back to multiplayer menu")
	get_tree().change_scene_to_file("res://scenes/lobby.tscn") 