extends Control

# Public Rooms Browser - Displays available public rooms for joining

@onready var status_label = $MainPanel/MainContainer/StatusLabel
@onready var rooms_list = $MainPanel/MainContainer/RoomsScrollContainer/RoomsList
@onready var refresh_button = $MainPanel/MainContainer/HeaderContainer/RefreshButton

var player_name: String = ""
var room_entry_scene = preload("res://scenes/room_entry.tscn")

func _ready():
	print("🌐 Public Rooms Browser loaded")
	
	# Get player name from previous scene or use default
	if get_tree().has_meta("player_name"):
		player_name = get_tree().get_meta("player_name")
	else:
		player_name = "Player"
	
	# Connect to RoomManager signals
	var room_manager = get_node("/root/RoomManager")
	room_manager.room_list_updated.connect(_on_room_list_updated)
	room_manager.room_joined.connect(_on_room_joined)
	
	# Start room discovery
	room_manager.start_room_discovery()
	
	# Initial refresh
	refresh_rooms()

func _exit_tree():
	# Stop room discovery when leaving this scene
	var room_manager = get_node("/root/RoomManager")
	room_manager.stop_room_discovery()

func refresh_rooms():
	print("🔄 Refreshing room list...")
	status_label.text = "Searching for public rooms..."
	refresh_button.disabled = true
	refresh_button.text = "🔄 Refreshing..."
	
	# Clear existing room entries
	clear_room_list()
	
	# Request fresh room list from RoomManager
	var room_manager = get_node("/root/RoomManager")
	room_manager.refresh_room_list()

func clear_room_list():
	# Remove all existing room entries
	for child in rooms_list.get_children():
		child.queue_free()

func _on_room_list_updated(rooms: Array):
	print("📋 Room list updated, found ", rooms.size(), " public rooms")
	
	# Re-enable refresh button
	refresh_button.disabled = false
	refresh_button.text = "🔄 Refresh"
	
	# Clear existing entries
	clear_room_list()
	
	if rooms.size() == 0:
		status_label.text = "No public rooms found. Create one or try refreshing!"
		return
	
	status_label.text = "Found " + str(rooms.size()) + " public room" + ("s" if rooms.size() != 1 else "")
	
	# Create room entries
	for room in rooms:
		create_room_entry(room)

func create_room_entry(room):
	# Create room entry UI
	var room_entry = room_entry_scene.instantiate()
	rooms_list.add_child(room_entry)
	
	# Configure the room entry with room data
	room_entry.setup_room_data(room, player_name)
	
	# Connect join signal
	room_entry.room_join_requested.connect(_on_room_join_requested)

func _on_room_join_requested(room_code: String):
	print("🚀 Attempting to join room: ", room_code)
	
	# Disable all join buttons to prevent double-joining
	for child in rooms_list.get_children():
		if child.has_method("set_joining_state"):
			child.set_joining_state(true)
	
	# Attempt to join through RoomManager
	var room_manager = get_node("/root/RoomManager")
	var success = room_manager.join_room(room_code, player_name)
	
	if not success:
		print("❌ Failed to join room: ", room_code)
		# Re-enable join buttons
		for child in rooms_list.get_children():
			if child.has_method("set_joining_state"):
				child.set_joining_state(false)

func _on_room_joined(room_code: String):
	print("🎉 Successfully joined room: ", room_code)
	
	# Store room info for the lobby
	get_tree().set_meta("room_code", room_code)
	get_tree().set_meta("is_host", false)
	get_tree().set_meta("player_name", player_name)
	
	# Navigate to lobby
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_refresh_button_pressed():
	refresh_rooms()

func _on_back_button_pressed():
	print("⬅️ Going back to join options")
	get_tree().change_scene_to_file("res://scenes/join_options.tscn") 