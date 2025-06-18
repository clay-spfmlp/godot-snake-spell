extends Control

# Main menu
@onready var main_menu_panel = $MainMenuPanel
@onready var single_player_button = $MainMenuPanel/VBoxContainer/SinglePlayerButton

# Single player
@onready var single_player_panel = $SinglePlayerPanel
@onready var sp_name_input = $SinglePlayerPanel/VBoxContainer/PlayerNamePanel/PlayerName/SPNameInput
@onready var selected_color_label = $SinglePlayerPanel/VBoxContainer/ColorPanel/ColorSection/SelectedColorLabel
@onready var classic_button = $SinglePlayerPanel/VBoxContainer/ClassicButton
@onready var sp_back_button = $SinglePlayerPanel/VBoxContainer/SPBackButton

# Multiplayer
@onready var multiplayer_panel = $MultiplayerPanel
@onready var name_input = $MultiplayerPanel/VBoxContainer/PlayerNamePanel/PlayerName/NameInput
@onready var host_button = $MultiplayerPanel/VBoxContainer/HostButton
@onready var join_button = $MultiplayerPanel/VBoxContainer/JoinButton
@onready var mp_back_button = $MultiplayerPanel/VBoxContainer/MPBackButton

# Game lobby
@onready var game_panel = $GamePanel
@onready var game_section = $GamePanel/GameSection
@onready var lobby_selected_color_label = $GamePanel/GameSection/ColorPanel/ColorSection/SelectedColorLabel
@onready var player_list = $GamePanel/GameSection/PlayerListPanel/PlayerList
@onready var ready_button = $GamePanel/GameSection/ButtonContainer/ReadyButton
@onready var start_button = $GamePanel/GameSection/ButtonContainer/StartButton
@onready var add_ai_button = $GamePanel/GameSection/ButtonContainer/AddAIButton
@onready var status_label = $GamePanel/GameSection/StatusLabel

@onready var settings_panel = $GamePanel/GameSection/SettingsPanel
@onready var mode_option = $GamePanel/GameSection/SettingsPanel/SettingsContainer/ModeContainer/ModeOption
@onready var difficulty_option = $GamePanel/GameSection/SettingsPanel/SettingsContainer/DifficultyContainer/DifficultyOption
@onready var wrapping_option = $GamePanel/GameSection/SettingsPanel/SettingsContainer/WrappingContainer/WrappingOption

var is_host = false
var in_multiplayer_room = false
var is_ready = false
var ready_players = {}  # Track which players are ready
var ai_player_count = 0  # Track number of AI players added
var ai_players = {}  # Track AI player data {peer_id: {name, color, ready}}

# Game settings
var selected_game_mode = "classic"
var selected_difficulty = "medium"
var wall_wrapping_enabled = false

# Color selection
var selected_snake_color = "green"
var mp_selected_snake_color = ""  # No color selected initially
var used_colors = {}  # Track colors used by other players
var lobby_color_buttons = {}  # Store references to lobby color buttons
var color_x_overlays = {}  # Store X overlay instances for unavailable colors

var color_names = {
	"green": "Classic Green",
	"blue": "Ocean Blue", 
	"red": "Fire Red",
	"purple": "Royal Purple",
	"orange": "Sunset Orange",
	"yellow": "Golden Yellow",
	"pink": "Hot Pink",
	"cyan": "Electric Cyan"
}

var color_values = {
	"green": {"bg": Color(0.192157, 0.654902, 0, 0.784314), "border": Color(0.270588, 0.580392, 0, 1), "head_bg": Color(0.15, 0.55, 0, 0.9), "head_border": Color(0.1, 0.4, 0, 1)},
	"blue": {"bg": Color(0.0, 0.4, 0.8, 0.8), "border": Color(0.0, 0.3, 0.6, 1), "head_bg": Color(0.0, 0.35, 0.7, 0.9), "head_border": Color(0.0, 0.25, 0.5, 1)},
	"red": {"bg": Color(0.8, 0.2, 0.2, 0.8), "border": Color(0.6, 0.1, 0.1, 1), "head_bg": Color(0.7, 0.15, 0.15, 0.9), "head_border": Color(0.5, 0.1, 0.1, 1)},
	"purple": {"bg": Color(0.6, 0.2, 0.8, 0.8), "border": Color(0.4, 0.1, 0.6, 1), "head_bg": Color(0.5, 0.15, 0.7, 0.9), "head_border": Color(0.3, 0.1, 0.5, 1)},
	"orange": {"bg": Color(0.9, 0.5, 0.1, 0.8), "border": Color(0.7, 0.4, 0.0, 1), "head_bg": Color(0.8, 0.45, 0.05, 0.9), "head_border": Color(0.6, 0.3, 0.0, 1)},
	"yellow": {"bg": Color(0.9, 0.9, 0.2, 0.8), "border": Color(0.7, 0.7, 0.0, 1), "head_bg": Color(0.8, 0.8, 0.15, 0.9), "head_border": Color(0.6, 0.6, 0.0, 1)},
	"pink": {"bg": Color(0.9, 0.4, 0.7, 0.8), "border": Color(0.7, 0.2, 0.5, 1), "head_bg": Color(0.8, 0.35, 0.6, 0.9), "head_border": Color(0.6, 0.15, 0.4, 1)},
	"cyan": {"bg": Color(0.0, 0.8, 0.8, 0.8), "border": Color(0.0, 0.6, 0.6, 1), "head_bg": Color(0.0, 0.7, 0.7, 0.9), "head_border": Color(0.0, 0.5, 0.5, 1)}
}

func _ready():
	# Wait a frame for autoloads to be ready
	await get_tree().process_frame
	
	# Check if we're coming from the room system
	var room_code = ""
	var is_room_host = false
	var player_name = ""
	
	if get_tree().has_meta("room_code"):
		room_code = get_tree().get_meta("room_code")
		is_room_host = get_tree().get_meta("is_host", false)
		player_name = get_tree().get_meta("player_name", "")
		
		print("🏠 Entering lobby for room: ", room_code, " (Host: ", is_room_host, ")")
		
		# Set up room-based multiplayer
		setup_room_multiplayer(room_code, is_room_host, player_name)
		return
	
	# Original lobby setup for non-room multiplayer
	setup_original_lobby()

func setup_room_multiplayer(room_code: String, is_room_host: bool, player_name: String):
	# Hide main menu and single player panels
	main_menu_panel.visible = false
	single_player_panel.visible = false
	multiplayer_panel.visible = false
	
	# Show game lobby
	game_panel.visible = true
	
	# Set up room-specific state
	is_host = is_room_host
	in_multiplayer_room = true
	
	# Update the title to show room code
	var title_label = $GamePanel/GameSection/Title
	if title_label:
		title_label.text = "🐍 Snake Spell - Room " + room_code
	
	# Set up NetworkManager for room-based multiplayer
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		network_manager.player_info["name"] = player_name
		network_manager.player_info["color"] = ""  # No color selected yet
		
		if is_room_host:
			# Host creates the multiplayer server immediately
			var error = network_manager.create_game()
			if error == OK:
				print("🌐 Room host created multiplayer server")
				# Auto-assign green color to host by default
				if multiplayer.multiplayer_peer != null:
					var host_id = multiplayer.get_unique_id()
					mp_selected_snake_color = "green"
					used_colors["green"] = host_id
					network_manager.player_info["color"] = "green"
					lobby_selected_color_label.text = "Selected: " + color_names["green"]
					print("🎨 Auto-assigned green color to host")
					update_lobby_color_buttons()
			else:
				print("❌ Failed to create multiplayer server for room host: ", error)
		
		# Connect network manager signals for room-based multiplayer
		network_manager.player_connected.connect(_on_player_connected)
		network_manager.player_disconnected.connect(_on_player_disconnected)
		network_manager.connection_failed.connect(_on_connection_failed)
		network_manager.connection_succeeded.connect(_on_connection_succeeded)
		network_manager.server_disconnected.connect(_on_server_disconnected)
		# Connect to color update signal if it exists
		if network_manager.has_signal("player_color_updated"):
			network_manager.player_color_updated.connect(_on_player_color_updated)
		# Connect to ready update signal if it exists
		if network_manager.has_signal("player_ready_updated"):
			network_manager.player_ready_updated.connect(_on_player_ready_updated)
	
	# Get room info from RoomManager
	var room_manager = get_node("/root/RoomManager")
	var current_room = room_manager.get_current_room()
	if current_room:
		# Apply room settings to the lobby
		apply_room_settings(current_room)
		
		# Update player list with room players
		update_room_player_list(current_room)
	
	# Set up UI based on host status
	if is_room_host:
		setup_host_ui()
	else:
		setup_client_ui()
	
	# Connect to RoomManager signals
	room_manager.player_joined_room.connect(_on_room_player_joined)
	room_manager.player_left_room.connect(_on_room_player_left)
	
	# Restore preserved AI players and player colors
	restore_preserved_ai_players()
	restore_preserved_player_colors()
	
	# Initialize lobby state (but preserve restored AI players and player colors)
	initialize_room_lobby_state()
	
	# Reset for new game if returning from a previous game
	reset_for_new_game()

func setup_original_lobby():
	# Store references to lobby color buttons
	lobby_color_buttons = {
		"green": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/GreenButton,
		"blue": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/BlueButton,
		"red": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/RedButton,
		"purple": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/PurpleButton,
		"orange": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/OrangeButton,
		"yellow": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/YellowButton,
		"pink": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/PinkButton,
		"cyan": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/CyanButton
	}
	
	# Initially disable all lobby color buttons and ready button
	update_lobby_color_buttons()
	ready_button.disabled = true
	
	# Initially hide game settings panels (will be shown for host)
	settings_panel.visible = false
	
	# Initialize dropdown options
	setup_dropdown_options()
	
	# Set initial message
	lobby_selected_color_label.text = "Select a color to continue"
	
	# Initialize multiplayer button states
	update_multiplayer_button_states()
	
	# Connect network manager signals
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		network_manager.player_connected.connect(_on_player_connected)
		network_manager.player_disconnected.connect(_on_player_disconnected)
		network_manager.connection_failed.connect(_on_connection_failed)
		network_manager.connection_succeeded.connect(_on_connection_succeeded)
		network_manager.server_disconnected.connect(_on_server_disconnected)
		# Connect to color update signal if it exists
		if network_manager.has_signal("player_color_updated"):
			network_manager.player_color_updated.connect(_on_player_color_updated)
		# Connect to ready update signal if it exists
		if network_manager.has_signal("player_ready_updated"):
			network_manager.player_ready_updated.connect(_on_player_ready_updated)
	else:
		print("ERROR: NetworkManager autoload not found!")

func apply_room_settings(room):
	var settings = room.game_settings
	
	# Apply game mode
	selected_game_mode = settings.get("mode", "classic")
	
	# Apply difficulty
	selected_difficulty = settings.get("difficulty", "medium")
	
	# Apply wall wrapping
	wall_wrapping_enabled = settings.get("wall_wrapping", false)
	
	# Update UI to reflect settings
	update_settings_ui()

func update_settings_ui():
	# Update dropdown selections to match room settings
	match selected_game_mode:
		"classic":
			mode_option.selected = 0
		"random":
			mode_option.selected = 1
	
	match selected_difficulty:
		"easy":
			difficulty_option.selected = 0
		"medium":
			difficulty_option.selected = 1
		"hard":
			difficulty_option.selected = 2
	
	# Update wall wrapping
	wrapping_option.selected = 0 if wall_wrapping_enabled else 1

func update_room_player_list(room):
	# If host, create custom player entries with remove buttons
	if is_host:
		# Hide the ItemList and create custom entries
		player_list.visible = false
		
		# Create or get the custom player container
		var player_container = player_list.get_parent().get_node_or_null("CustomPlayerContainer")
		if not player_container:
			player_container = VBoxContainer.new()
			player_container.name = "CustomPlayerContainer"
			player_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			player_container.offset_left = player_list.offset_left
			player_container.offset_top = player_list.offset_top
			player_container.offset_right = player_list.offset_right
			player_container.offset_bottom = player_list.offset_bottom
			player_container.add_theme_constant_override("separation", 5)
			player_list.get_parent().add_child(player_container)
		
		# Clear existing entries
		for child in player_container.get_children():
			child.queue_free()
		
		# Add human players using the room system
		if has_node("/root/NetworkManager"):
			var network_manager = get_node("/root/NetworkManager")
			# Add human players from NetworkManager
			for peer_id in network_manager.players:
				add_player_entry(player_container, peer_id, false)
		
		# Add AI players
		for ai_peer_id in ai_players:
			add_player_entry(player_container, ai_peer_id, true)
	else:
		# Client view - use simple ItemList
		player_list.visible = true
		
		# Hide custom container if it exists
		var player_container = player_list.get_parent().get_node_or_null("CustomPlayerContainer")
		if player_container:
			player_container.visible = false
		
		# Clear the existing list
		player_list.clear()
		
		# For room-based multiplayer, show NetworkManager players instead of room players
		if has_node("/root/NetworkManager"):
			var network_manager = get_node("/root/NetworkManager")
			
			# Add human players from NetworkManager
			for peer_id in network_manager.players:
				var player_name = network_manager.players[peer_id]["name"]
				var player_color = network_manager.players[peer_id].get("color", "")
				var display_text = player_name
				var color_display = ""
				
				# Add color indicator if player has selected a color
				if player_color != "":
					var color_name = color_names.get(player_color, player_color)
					color_display = " [" + color_name + "]"
				
				# Mark host
				if peer_id == 1:  # Host is always peer ID 1
					display_text += " (Host)"
				
				player_list.add_item(display_text + color_display)
		else:
			# Fallback: Add human players from room
			for player_name in room.current_players:
				var display_text = player_name
				if room.is_host(player_name):
					display_text += " (Host)"
				
				player_list.add_item(display_text)
		
		# Add AI players from lobby
		for ai_peer_id in ai_players:
			var ai_data = ai_players[ai_peer_id]
			var ai_name = ai_data["name"]
			var ai_color = ai_data.get("color", "")
			var ai_status = " 🤖"
			var color_display = ""
			
			# Add color indicator for AI
			if ai_color != "":
				var color_name = color_names.get(ai_color, ai_color)
				color_display = " [" + color_name + "]"
			
			player_list.add_item(ai_name + color_display + ai_status)
	
	# Update status (include AI players in count)
	var human_player_count = 0
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		human_player_count = network_manager.get_player_count()
	else:
		human_player_count = room.get_player_count()
	
	var player_count = human_player_count + ai_players.size()
	var max_players = room.max_players
	status_label.text = "Players: " + str(player_count) + "/" + str(max_players)
	
	# Update start button availability for host
	if is_host:
		update_start_button_state()

func setup_host_ui():
	start_button.visible = true
	start_button.disabled = true  # Will be enabled when players are ready
	ready_button.visible = false
	add_ai_button.visible = true
	settings_panel.visible = true
	
	# Initialize dropdown options for host
	setup_dropdown_options()

func setup_client_ui():
	start_button.visible = false
	ready_button.visible = true
	ready_button.disabled = true  # Will be enabled when color is selected
	add_ai_button.visible = false
	settings_panel.visible = false

func initialize_room_lobby_state():
	# Initialize color system
	lobby_color_buttons = {
		"green": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/GreenButton,
		"blue": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/BlueButton,
		"red": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/RedButton,
		"purple": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/PurpleButton,
		"orange": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/OrangeButton,
		"yellow": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/YellowButton,
		"pink": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/PinkButton,
		"cyan": $GamePanel/GameSection/ColorPanel/ColorSection/ColorButtons/CyanButton
	}
	
	# Reset state (but preserve restored AI players and their colors)
	var preserved_ai_players = ai_players.duplicate(true)
	var preserved_ai_count = ai_player_count
	# Preserve host's current color selection
	var preserved_host_color = mp_selected_snake_color
	
	used_colors.clear()
	ready_players.clear()
	ai_players.clear()
	ai_player_count = 0
	is_ready = false
	mp_selected_snake_color = ""
	
	# Restore preserved data if it existed
	if not preserved_ai_players.is_empty():
		ai_players = preserved_ai_players
		ai_player_count = preserved_ai_count
		# Restore AI colors to used_colors
		for ai_peer_id in ai_players:
			var ai_data = ai_players[ai_peer_id]
			var ai_color = ai_data.get("color", "")
			if ai_color != "":
				used_colors[ai_color] = ai_peer_id
		print("🤖 Preserved ", ai_players.size(), " AI players during initialization")
	
	# Restore host's color selection if they had one, otherwise assign green
	if is_host:
		if preserved_host_color != "" and not used_colors.has(preserved_host_color):
			# Host had a manual selection and it's still available
			mp_selected_snake_color = preserved_host_color
			used_colors[preserved_host_color] = 1  # Host is always peer ID 1
			if has_node("/root/NetworkManager"):
				var network_manager = get_node("/root/NetworkManager")
				network_manager.player_info["color"] = preserved_host_color
			lobby_selected_color_label.text = "Selected: " + color_names[preserved_host_color]
			print("🎨 Host color preserved: ", preserved_host_color)
		elif not used_colors.has("green"):
			# No preserved color or it's taken, default to green if available
			mp_selected_snake_color = "green"
			used_colors["green"] = 1  # Host is always peer ID 1
			if has_node("/root/NetworkManager"):
				var network_manager = get_node("/root/NetworkManager")
				network_manager.player_info["color"] = "green"
			lobby_selected_color_label.text = "Selected: " + color_names["green"]
			print("🎨 Host auto-assigned green color during initialization")
	
	# Update UI
	update_lobby_color_buttons()
	if mp_selected_snake_color == "":
		lobby_selected_color_label.text = "Select a color to continue"

func restore_preserved_ai_players():
	# Restore AI players that were preserved when returning from a game
	var preserved_ai = get_tree().get_meta("preserved_ai_players", {})
	print("🔍 DEBUG: Checking for preserved AI players. Found: ", preserved_ai)
	print("🔍 DEBUG: Is host: ", is_host)
	print("🔍 DEBUG: In multiplayer room: ", in_multiplayer_room)
	
	if not preserved_ai.is_empty() and is_host:
		print("🔄 Restoring ", preserved_ai.size(), " preserved AI players")
		
		# Restore the AI players and their data
		for ai_peer_id in preserved_ai:
			var ai_data = preserved_ai[ai_peer_id]
			ai_players[ai_peer_id] = ai_data
			print("🤖 Restoring AI: ", ai_peer_id, " -> ", ai_data)
			
			# Restore color usage
			var ai_color = ai_data.get("color", "")
			if ai_color != "":
				used_colors[ai_color] = ai_peer_id
			
			# Update AI player count
			var ai_name = ai_data.get("name", "AIBot")
			var name_parts = ai_name.split("AIBot")
			if name_parts.size() > 1 and name_parts[1].is_valid_int():
				var ai_number = name_parts[1].to_int()
				ai_player_count = max(ai_player_count, ai_number)
		
		print("🤖 Restored AI players: ", ai_players.keys())
		print("🎨 Restored used colors: ", used_colors.keys())
		print("🔢 AI player count: ", ai_player_count)
		
		# Clean up the preserved data
		get_tree().remove_meta("preserved_ai_players")
	else:
		if preserved_ai.is_empty():
			print("⚠️ No preserved AI players found")
		if not is_host:
			print("⚠️ Not host, skipping AI restoration")

func restore_preserved_player_colors():
	# Restore human player colors that were preserved when returning from a game
	var preserved_colors = get_tree().get_meta("preserved_player_colors", {})
	print("🎨 Checking for preserved player colors. Found: ", preserved_colors)
	
	if not preserved_colors.is_empty():
		if has_node("/root/NetworkManager"):
			var network_manager = get_node("/root/NetworkManager")
			var my_id = 0
			if multiplayer.multiplayer_peer != null:
				my_id = multiplayer.get_unique_id()
			
			# Restore my own color if preserved
			if preserved_colors.has(my_id):
				var my_preserved_color = preserved_colors[my_id]
				print("🎨 Restoring my color: ", my_preserved_color)
				
				# Only restore if the color isn't already taken by AI
				if not used_colors.has(my_preserved_color):
					mp_selected_snake_color = my_preserved_color
					used_colors[my_preserved_color] = my_id
					network_manager.player_info["color"] = my_preserved_color
					lobby_selected_color_label.text = "Selected: " + color_names[my_preserved_color]
					print("🎨 Successfully restored player color: ", my_preserved_color)
				else:
					print("🎨 Preserved color ", my_preserved_color, " is now taken, will fallback to auto-assignment")
		
		# Clean up the preserved data
		get_tree().remove_meta("preserved_player_colors")
	else:
		print("🎨 No preserved player colors found")

func reset_for_new_game():
	# Reset lobby state for a new game while maintaining room connection
	print("🔄 Resetting lobby for new game")
	
	# Preserve AI players and their colors (don't clear them)
	# Re-add AI players to NetworkManager with their existing colors
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		for ai_peer_id in ai_players:
			var ai_data = ai_players[ai_peer_id]
			network_manager.add_ai_player(ai_peer_id, ai_data)
			# Ensure AI colors remain in used_colors
			var ai_color = ai_data.get("color", "")
			if ai_color != "":
				used_colors[ai_color] = ai_peer_id
		print("🤖 Preserved ", ai_players.size(), " AI players with their colors")
	
	# Reset ready states (but keep AI players ready)
	ready_players.clear()
	for ai_peer_id in ai_players:
		ready_players[ai_peer_id] = true  # AI players are always ready
	is_ready = false
	
	# Reset start button state
	if is_host:
		start_button.disabled = true
		status_label.text = "Waiting for players to get ready..."
	
	# Update UI to reflect reset state
	update_lobby_color_buttons()
	
	# Update player list to show current state
	var room_manager = get_node("/root/RoomManager")
	var current_room = room_manager.get_current_room()
	if current_room:
		update_room_player_list(current_room)
	
	print("🔄 Lobby reset complete - ready for new game")

# Room event handlers
func _on_room_player_joined(player_name: String):
	print("🎉 Player joined room: ", player_name)
	
	# Update player list
	var room_manager = get_node("/root/RoomManager")
	var current_room = room_manager.get_current_room()
	if current_room:
		update_room_player_list(current_room)

func _on_room_player_left(player_name: String):
	print("👋 Player left room: ", player_name)
	
	# Update player list
	var room_manager = get_node("/root/RoomManager")
	var current_room = room_manager.get_current_room()
	if current_room:
		update_room_player_list(current_room)

func _on_name_input_text_changed(new_text):
	# Limit name to 15 characters
	if new_text.length() > 15:
		new_text = new_text.substr(0, 15)
		name_input.text = new_text
		name_input.caret_column = new_text.length()
	
	# Update button states based on name validity
	update_multiplayer_button_states()
	
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").player_info["name"] = new_text

func update_multiplayer_button_states():
	var name_text = name_input.text.strip_edges()
	var is_valid_name = name_text.length() > 0 and name_text.length() <= 15
	
	host_button.disabled = not is_valid_name
	join_button.disabled = not is_valid_name
	
	if name_text.length() == 0:
		host_button.tooltip_text = "Enter a player name to host"
		join_button.tooltip_text = "Enter a player name to join"
	elif name_text.length() > 15:
		host_button.tooltip_text = "Player name too long (max 15 characters)"
		join_button.tooltip_text = "Player name too long (max 15 characters)"
	else:
		host_button.tooltip_text = ""
		join_button.tooltip_text = ""

func _on_host_button_pressed():
	if not has_node("/root/NetworkManager"):
		status_label.text = "NetworkManager not available!"
		return
	
	# Validate player name
	var player_name = name_input.text.strip_edges()
	if player_name.length() == 0:
		status_label.text = "Please enter a player name!"
		return
	if player_name.length() > 15:
		status_label.text = "Player name too long (max 15 characters)!"
		return
	
	var network_manager = get_node("/root/NetworkManager")
	var port = network_manager.DEFAULT_PORT  # Use default port 7000
	
	network_manager.player_info["name"] = player_name
	network_manager.player_info["color"] = ""  # No color selected yet
	var error = network_manager.create_game(port)
	
	if error == OK:
		is_host = true
		in_multiplayer_room = true
		used_colors.clear()  # Reset used colors
		ready_players.clear()  # Reset ready states
		ai_players.clear()  # Reset AI players
		ai_player_count = 0
		is_ready = false
		mp_selected_snake_color = ""
		show_lobby()
		status_label.text = "Hosting game..."
		start_button.visible = true  # Show start button for host
		start_button.disabled = true  # Disabled until someone is ready
		ready_button.visible = false  # Hide ready button for host
		add_ai_button.visible = true  # Show AI button for host
		settings_panel.visible = true  # Show settings panel for host
		
		# Auto-assign color to host
		if multiplayer.multiplayer_peer != null:
			auto_assign_color_to_player(multiplayer.get_unique_id())
	else:
		var error_msg = ""
		match error:
			22:  # ERR_ALREADY_IN_USE
				error_msg = "Server port is already in use!"
			37:  # ERR_CANT_CREATE
				error_msg = "Cannot create server. Check firewall/permissions."
			_:
				error_msg = "Failed to create server (Error: " + str(error) + ")"
		
		status_label.text = error_msg
		print("Server creation failed: ", error_msg)

func _on_join_button_pressed():
	if not has_node("/root/NetworkManager"):
		status_label.text = "NetworkManager not available!"
		return
	
	# Validate player name
	var player_name = name_input.text.strip_edges()
	if player_name.length() == 0:
		status_label.text = "Please enter a player name!"
		return
	if player_name.length() > 15:
		status_label.text = "Player name too long (max 15 characters)!"
		return
	
	var network_manager = get_node("/root/NetworkManager")
	var address = "127.0.0.1"  # Default to localhost
	var port = network_manager.DEFAULT_PORT  # Use default port 7000
	
	network_manager.player_info["name"] = player_name
	network_manager.player_info["color"] = ""  # No color selected yet
	var error = network_manager.join_game(address, port)
	
	if error == OK:
		is_host = false
		in_multiplayer_room = true
		used_colors.clear()  # Reset used colors
		ready_players.clear()  # Reset ready states
		is_ready = false
		mp_selected_snake_color = ""
		show_lobby()
		status_label.text = "Connecting to game..."
		start_button.visible = false  # Hide start button for clients
		ready_button.visible = true  # Show ready button for clients
		ready_button.disabled = true  # Disabled until color selected
		add_ai_button.visible = false  # Hide AI button for clients
		settings_panel.visible = false  # Hide settings panel for clients
		update_lobby_color_buttons()  # Enable color selection

func _on_start_button_pressed():
	if not has_node("/root/NetworkManager"):
		return
	
	var network_manager = get_node("/root/NetworkManager")
	
	# Check if we're in a room-based multiplayer session
	var room_manager = get_node("/root/RoomManager")
	if in_multiplayer_room and room_manager.is_in_room():
		# Room-based multiplayer start
		var current_room = room_manager.get_current_room()
		if not current_room:
			return
		if not is_host:
			return
		
		var total_players = current_room.get_player_count() + ai_players.size()
		if total_players >= 2:
			# Update room settings with current lobby settings
			var game_settings = {
				"mode": selected_game_mode,
				"difficulty": selected_difficulty,
				"wall_wrapping": wall_wrapping_enabled
			}
			room_manager.update_room_settings(game_settings)
			
			# Start the game through RoomManager
			room_manager.start_room_game()
	else:
		# Legacy multiplayer start
		var total_players = network_manager.get_player_count() + ai_players.size()
		if is_host and total_players >= 2:
			# Pass game settings to the networked game
			var game_settings = {
				"mode": selected_game_mode,
				"difficulty": selected_difficulty,
				"wall_wrapping": wall_wrapping_enabled
			}
			network_manager.start_game.rpc(game_settings)

func _on_add_ai_button_pressed():
	if not is_host or not in_multiplayer_room:
		return
	
	# Limit to 7 AI players (8 total with host)
	if ai_players.size() >= 7:
		status_label.text = "Maximum AI players reached (7)"
		return
	
	# Find available color for AI (prefer non-green colors to leave green for host)
	var available_colors = []
	var color_priority = ["blue", "red", "purple", "orange", "yellow", "pink", "cyan", "green"]  # Green last
	
	for color in color_priority:
		if not used_colors.has(color):
			available_colors.append(color)
	
	if available_colors.is_empty():
		status_label.text = "No colors available for AI player"
		return
	
	# Create AI player
	ai_player_count += 1
	var ai_name = "AIBot" + str(ai_player_count)
	var ai_color = available_colors[0]  # Take first available color (non-green preferred)
	var ai_peer_id = 1000 + ai_player_count  # Use high IDs for AI players
	
	# Add AI player data
	var ai_data = {
		"name": ai_name,
		"color": ai_color,
		"ready": true  # AI players are always ready
	}
	ai_players[ai_peer_id] = ai_data
	
	# Add to NetworkManager
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").add_ai_player(ai_peer_id, ai_data)
	
	# Mark color as used
	used_colors[ai_color] = ai_peer_id
	ready_players[ai_peer_id] = true
	
	# Update UI
	update_lobby_color_buttons()
	update_player_list()
	update_start_button_state()
	
	print("Added AI player: ", ai_name, " with color: ", ai_color)
	status_label.text = "Added " + ai_name + " (" + color_names[ai_color] + ")"

func _on_back_button_pressed():
	# Clean up networking
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").remove_multiplayer_peer()
	
	# Clean up room if we're in one
	var room_manager = get_node("/root/RoomManager")
	if room_manager.is_in_room():
		room_manager.leave_room()
		# Navigate back to room system
		get_tree().change_scene_to_file("res://scenes/multiplayer_menu.tscn")
		return
	
	# Legacy multiplayer cleanup
	show_multiplayer_menu()
	is_host = false
	in_multiplayer_room = false
	used_colors.clear()
	ready_players.clear()
	is_ready = false
	mp_selected_snake_color = ""
	update_lobby_color_buttons()

# Menu navigation functions
func show_main_menu():
	main_menu_panel.visible = true
	single_player_panel.visible = false
	multiplayer_panel.visible = false
	game_panel.visible = false

func show_single_player_menu():
	main_menu_panel.visible = false
	single_player_panel.visible = true
	multiplayer_panel.visible = false
	game_panel.visible = false

func show_multiplayer_menu():
	main_menu_panel.visible = false
	single_player_panel.visible = false
	multiplayer_panel.visible = true
	game_panel.visible = false

func show_lobby():
	main_menu_panel.visible = false
	single_player_panel.visible = false
	multiplayer_panel.visible = false
	game_panel.visible = true
	# Game settings panels visibility will be set by host/join functions
	update_player_list()

# Button handlers for main menu
func _on_single_player_button_pressed():
	show_single_player_menu()

func _on_multiplayer_button_pressed():
	print("🌐 Opening multiplayer room system")
	
	# Navigate to the new room-based multiplayer system
	get_tree().change_scene_to_file("res://scenes/multiplayer_menu.tscn")

# Button handlers for single player
func _on_color_button_pressed(color: String):
	selected_snake_color = color
	selected_color_label.text = "Selected: " + color_names[color]
	print("Selected snake color: ", color)

func _on_lobby_color_button_pressed(color: String):
	var my_id = 0
	if multiplayer.multiplayer_peer != null:
		my_id = multiplayer.get_unique_id()
	
	if not in_multiplayer_room or (used_colors.has(color) and used_colors[color] != my_id):
		return  # Can't select if not in room or color is taken by someone else
	
	# Remove previous color selection from used colors if we had one
	if mp_selected_snake_color != "":
		used_colors.erase(mp_selected_snake_color)
	
	mp_selected_snake_color = color
	lobby_selected_color_label.text = "Selected: " + color_names[color]
	print("Selected multiplayer snake color: ", color)
	
	# Mark this color as used by us
	if multiplayer.multiplayer_peer != null:
		used_colors[color] = multiplayer.get_unique_id()
	update_lobby_color_buttons()
	sync_player_colors()
	
	# Enable ready button now that color is selected
	if not is_host:
		ready_button.disabled = false

func _on_ready_button_pressed():
	if not in_multiplayer_room or mp_selected_snake_color == "":
		return
	
	is_ready = not is_ready
	
	if is_ready:
		ready_button.text = "❌ Not Ready"
	else:
		ready_button.text = "✅ Ready Up"
	
	# Sync ready state with other players
	sync_player_ready_state()
	update_start_button_state()

func _on_classic_button_pressed():
	print("Starting classic single player mode with color: ", selected_snake_color)
	# Store the selected color and wall wrapping setting globally so the game can access it
	var game_data = {}
	game_data["selected_snake_color"] = selected_snake_color
	game_data["wall_wrapping"] = false  # Single player defaults to no wall wrapping for now
	get_tree().set_meta("game_data", game_data)
	
	get_tree().change_scene_to_file("res://scenes/single_player.tscn")

func _on_sp_back_button_pressed():
	show_main_menu()

# Button handler for multiplayer back
func _on_mp_back_button_pressed():
	show_main_menu()

func update_player_list():
	if not has_node("/root/NetworkManager"):
		return
	
	var network_manager = get_node("/root/NetworkManager")
	
	# Clear the existing list
	player_list.clear()
	
	# If host, create custom player entries with remove buttons
	if is_host:
		# Hide the ItemList and create custom entries
		player_list.visible = false
		
		# Create or get the custom player container
		var player_container = player_list.get_parent().get_node_or_null("CustomPlayerContainer")
		if not player_container:
			player_container = VBoxContainer.new()
			player_container.name = "CustomPlayerContainer"
			player_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			player_container.offset_left = player_list.offset_left
			player_container.offset_top = player_list.offset_top
			player_container.offset_right = player_list.offset_right
			player_container.offset_bottom = player_list.offset_bottom
			player_container.add_theme_constant_override("separation", 5)
			player_list.get_parent().add_child(player_container)
		
		# Clear existing entries
		for child in player_container.get_children():
			child.queue_free()
		
		# Add human players
		for peer_id in network_manager.players:
			add_player_entry(player_container, peer_id, false)
		
		# Add AI players
		for ai_peer_id in ai_players:
			add_player_entry(player_container, ai_peer_id, true)
	else:
		# Client view - use simple ItemList
		player_list.visible = true
		
		# Hide custom container if it exists
		var player_container = player_list.get_parent().get_node_or_null("CustomPlayerContainer")
		if player_container:
			player_container.visible = false
		
		# Add human players to ItemList
		for peer_id in network_manager.players:
			var player_name = network_manager.players[peer_id]["name"]
			var player_color = network_manager.players[peer_id].get("color", "")
			var ready_status = ""
			var color_display = ""
			
			# Add color indicator if player has selected a color
			if player_color != "":
				var color_name = color_names.get(player_color, player_color)
				color_display = " [" + color_name + "]"
			
			if peer_id == 1:  # Host
				ready_status = " (Host)"
			elif ready_players.has(peer_id) and ready_players[peer_id]:
				ready_status = " ✅"
			else:
				ready_status = " ⏳"
			
			player_list.add_item(player_name + color_display + ready_status)
		
		# Add AI players to ItemList
		for ai_peer_id in ai_players:
			var ai_data = ai_players[ai_peer_id]
			var ai_name = ai_data["name"]
			var ai_color = ai_data.get("color", "")
			var ai_status = " 🤖✅"  # AI players are always ready
			var color_display = ""
			
			# Add color indicator for AI
			if ai_color != "":
				var color_name = color_names.get(ai_color, ai_color)
				color_display = " [" + color_name + "]"
			
			player_list.add_item(ai_name + color_display + ai_status)
	
	# Update start button availability for host
	if is_host:
		update_start_button_state()

func add_player_entry(container: VBoxContainer, peer_id: int, is_ai: bool):
	var network_manager = get_node("/root/NetworkManager")
	
	# Create horizontal container for player entry
	var entry_container = HBoxContainer.new()
	entry_container.custom_minimum_size.y = 40
	
	# Get player info
	var player_name = ""
	var player_color = ""
	var ready_status = ""
	var color_display = ""
	var can_remove = true
	
	if is_ai:
		var ai_data = ai_players[peer_id]
		player_name = ai_data["name"]
		player_color = ai_data.get("color", "")
		ready_status = " 🤖✅"
	else:
		player_name = network_manager.players[peer_id]["name"]
		player_color = network_manager.players[peer_id].get("color", "")
		
		if peer_id == 1:  # Host (can't remove themselves)
			ready_status = " (Host)"
			can_remove = false
		elif ready_players.has(peer_id) and ready_players[peer_id]:
			ready_status = " ✅"
		else:
			ready_status = " ⏳"
	
	# Add color indicator
	if player_color != "":
		var color_name = color_names.get(player_color, player_color)
		color_display = " [" + color_name + "]"
	
	# Create player label
	var player_label = Label.new()
	player_label.text = player_name + color_display + ready_status
	player_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1, 1))
	player_label.add_theme_font_size_override("font_size", 20)
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_container.add_child(player_label)
	
	# Add remove button if allowed
	if can_remove:
		var remove_button = Button.new()
		remove_button.text = "❌"
		remove_button.custom_minimum_size = Vector2(40, 40)
		remove_button.tooltip_text = "Remove " + player_name
		
		# Style the remove button
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color(0.8, 0.2, 0.2, 0.8)
		button_style.border_color = Color(0.6, 0.1, 0.1, 1)
		button_style.border_width_left = 2
		button_style.border_width_top = 2
		button_style.border_width_right = 2
		button_style.border_width_bottom = 2
		button_style.corner_radius_top_left = 5
		button_style.corner_radius_top_right = 5
		button_style.corner_radius_bottom_left = 5
		button_style.corner_radius_bottom_right = 5
		remove_button.add_theme_stylebox_override("normal", button_style)
		
		# Connect the remove button
		if is_ai:
			remove_button.pressed.connect(_on_remove_ai_player.bind(peer_id))
		else:
			remove_button.pressed.connect(_on_remove_player.bind(peer_id))
		
		entry_container.add_child(remove_button)
	
	container.add_child(entry_container)

func _on_player_connected(peer_id, player_info):
	print("Player joined: ", player_info["name"])
	
	# Auto-assign a color if they don't have one
	if not player_info.has("color") or player_info["color"] == "":
		auto_assign_color_to_player(peer_id)
	else:
		# Track their existing color
		used_colors[player_info["color"]] = peer_id
		update_lobby_color_buttons()
	
	# Track their ready state if they have one
	if player_info.has("ready"):
		ready_players[peer_id] = player_info["ready"]
		update_start_button_state()
	
	update_player_list()

func _on_player_disconnected(peer_id):
	print("Player left: ", peer_id)
	remove_player_locally(peer_id)

func _on_connection_succeeded():
	print("Successfully connected to server")
	status_label.text = "Connected! Waiting for host to start..."
	
	# Auto-assign a color to this client
	if multiplayer.multiplayer_peer != null:
		auto_assign_color_to_player(multiplayer.get_unique_id())

func _on_connection_failed():
	print("Failed to connect to server")
	status_label.text = "Connection failed!"
	show_multiplayer_menu()
	in_multiplayer_room = false
	used_colors.clear()
	ready_players.clear()
	is_ready = false
	mp_selected_snake_color = ""
	update_lobby_color_buttons()

func _on_server_disconnected():
	print("Server disconnected")
	status_label.text = "Server disconnected!"
	show_multiplayer_menu()
	is_host = false
	in_multiplayer_room = false
	used_colors.clear()
	ready_players.clear()
	is_ready = false
	mp_selected_snake_color = ""
	update_lobby_color_buttons() 

func update_lobby_color_buttons():
	# If not in multiplayer room, disable all color buttons
	if not in_multiplayer_room:
		for color in lobby_color_buttons:
			var button = lobby_color_buttons[color]
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5, 1)  # Dim the button
			# Remove any X overlay
			if color_x_overlays.has(color):
				color_x_overlays[color].queue_free()
				color_x_overlays.erase(color)
		lobby_selected_color_label.text = "Join a room to select color"
		return
	
	# Update button availability based on used colors
	for color in lobby_color_buttons:
		var button = lobby_color_buttons[color]
		
		# Get unique ID safely - use a placeholder if multiplayer not ready
		var my_id = 0
		if multiplayer.multiplayer_peer != null:
			my_id = multiplayer.get_unique_id()
		
		if used_colors.has(color) and used_colors[color] != my_id:
			# Color is taken by another player
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5, 1)
			# Add X overlay if not already present
			if not color_x_overlays.has(color):
				var x_overlay = preload("res://scenes/color_x_overlay.tscn").instantiate()
				button.add_child(x_overlay)
				color_x_overlays[color] = x_overlay
		elif used_colors.has(color) and used_colors[color] == my_id:
			# This is our selected color
			button.disabled = false
			button.modulate = Color(1.2, 1.2, 1.2, 1)  # Slightly brighter to show selection
			# Remove X overlay if present
			if color_x_overlays.has(color):
				color_x_overlays[color].queue_free()
				color_x_overlays.erase(color)
		else:
			# Color is available
			button.disabled = false
			button.modulate = Color(1, 1, 1, 1)
			# Remove X overlay if present
			if color_x_overlays.has(color):
				color_x_overlays[color].queue_free()
				color_x_overlays.erase(color)

func sync_player_colors():
	# Sync color selections with other players
	if not has_node("/root/NetworkManager") or not in_multiplayer_room:
		return
	
	var network_manager = get_node("/root/NetworkManager")
	if mp_selected_snake_color != "":
		network_manager.player_info["color"] = mp_selected_snake_color
		# Notify other players of color change
		if multiplayer.multiplayer_peer != null:
			network_manager.update_player_color(multiplayer.get_unique_id(), mp_selected_snake_color)

func sync_player_ready_state():
	# Sync ready state with other players
	if not has_node("/root/NetworkManager") or not in_multiplayer_room:
		return
	
	var network_manager = get_node("/root/NetworkManager")
	network_manager.player_info["ready"] = is_ready
	# Notify other players of ready state change
	if multiplayer.multiplayer_peer != null:
		network_manager.update_player_ready(multiplayer.get_unique_id(), is_ready)

func update_start_button_state():
	if not is_host:
		return
	
	# Count ready players (excluding host) + AI players
	var ready_count = 0
	for peer_id in ready_players:
		if ready_players[peer_id]:
			ready_count += 1
	
	# AI players are always ready
	ready_count += ai_players.size()
	
	# Enable start button if at least one player is ready
	start_button.disabled = ready_count == 0
	
	if ready_count > 0:
		var total_players = ready_count + 1  # +1 for host
		status_label.text = "Ready to start! (" + str(total_players) + " total players)"
	else:
		status_label.text = "Waiting for players to get ready..."

func _on_player_color_updated(peer_id: int, color: String):
	var my_id = 0
	if multiplayer.multiplayer_peer != null:
		my_id = multiplayer.get_unique_id()
	
	if peer_id != my_id:
		# Remove any previous color selection by this player
		var colors_to_remove = []
		for existing_color in used_colors.keys():
			if used_colors[existing_color] == peer_id:
				colors_to_remove.append(existing_color)
		
		for old_color in colors_to_remove:
			used_colors.erase(old_color)
		
		# Add their new color selection
		if color != "":
			used_colors[color] = peer_id
		
		update_lobby_color_buttons()

func _on_player_ready_updated(peer_id: int, ready_state: bool):
	var my_id = 0
	if multiplayer.multiplayer_peer != null:
		my_id = multiplayer.get_unique_id()
	
	if peer_id != my_id:
		ready_players[peer_id] = ready_state
		update_start_button_state()
		update_player_list()

# Game mode and difficulty handlers
func _on_mode_option_item_selected(index: int):
	match index:
		0:
			selected_game_mode = "classic"
		1:
			selected_game_mode = "random"
	print("Selected game mode: ", selected_game_mode)

func _on_difficulty_option_item_selected(index: int):
	match index:
		0:
			selected_difficulty = "easy"
		1:
			selected_difficulty = "medium"
		2:
			selected_difficulty = "hard"
	print("Selected difficulty: ", selected_difficulty)

func _on_wrapping_option_item_selected(index: int):
	match index:
		0:
			wall_wrapping_enabled = true
		1:
			wall_wrapping_enabled = false
	print("Wall wrapping: ", "Enabled" if wall_wrapping_enabled else "Disabled")

func get_next_available_color() -> String:
	# List of colors in priority order (green first for host, others after)
	var color_priority = ["green", "blue", "red", "purple", "orange", "yellow", "pink", "cyan"]
	
	# Find the first color that's not used
	for color in color_priority:
		if not used_colors.has(color):
			return color
	
	# If all colors are used, return empty string
	return ""

func auto_assign_color_to_player(peer_id: int):
	# Auto-assign a color to a player
	var available_color = get_next_available_color()
	if available_color != "":
		used_colors[available_color] = peer_id
		
		# Update the player's color in NetworkManager
		if has_node("/root/NetworkManager"):
			var network_manager = get_node("/root/NetworkManager")
			var my_id = 0
			if multiplayer.multiplayer_peer != null:
				my_id = multiplayer.get_unique_id()
			
			if peer_id == my_id:
				# This is us
				mp_selected_snake_color = available_color
				lobby_selected_color_label.text = "Auto-assigned: " + color_names[available_color]
				network_manager.player_info["color"] = available_color
				ready_button.disabled = false  # Enable ready button now that we have a color
			else:
				# Another player
				network_manager.players[peer_id]["color"] = available_color
			
			# Notify other players of the color assignment
			network_manager.update_player_color(peer_id, available_color)
		
		update_lobby_color_buttons()
		update_player_list()
		print("Auto-assigned color ", available_color, " to player ", peer_id)
		return true
	else:
		print("No available colors for player ", peer_id)
		return false

func _on_remove_player(peer_id: int):
	if not is_host or peer_id == 1:  # Can't remove host
		return
	
	print("Host removing player: ", peer_id)
	
	# Remove from NetworkManager and kick the player
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		network_manager.kick_player(peer_id)
	
	# Clean up locally
	remove_player_locally(peer_id)

func _on_remove_ai_player(ai_peer_id: int):
	if not is_host:
		return
	
	print("Host removing AI player: ", ai_peer_id)
	
	# Remove AI player data
	if ai_players.has(ai_peer_id):
		var ai_data = ai_players[ai_peer_id]
		var ai_color = ai_data.get("color", "")
		
		# Free up the color
		if ai_color != "" and used_colors.has(ai_color):
			used_colors.erase(ai_color)
		
		# Remove from AI players
		ai_players.erase(ai_peer_id)
		ready_players.erase(ai_peer_id)
		
		# Remove from NetworkManager
		if has_node("/root/NetworkManager"):
			get_node("/root/NetworkManager").remove_ai_player(ai_peer_id)
		
		# Update UI
		update_lobby_color_buttons()
		update_player_list()
		update_start_button_state()
		
		status_label.text = "Removed " + ai_data["name"]

func remove_player_locally(peer_id: int):
	# Clean up player data locally (called when player is removed/disconnected)
	var colors_to_remove = []
	for color in used_colors.keys():
		if used_colors[color] == peer_id:
			colors_to_remove.append(color)
	
	for color in colors_to_remove:
		used_colors.erase(color)
	
	ready_players.erase(peer_id)
	update_lobby_color_buttons()
	update_player_list()
	update_start_button_state()

func setup_dropdown_options():
	# Initialize dropdown options
	mode_option.clear()
	difficulty_option.clear()
	wrapping_option.clear()
	
	# Add options to mode dropdown
	mode_option.add_item("🐍 Classic Mode")
	mode_option.add_item("🎲 Random Mode")
	
	# Add options to difficulty dropdown
	difficulty_option.add_item("🐌 Easy (Slow)")
	difficulty_option.add_item("🚀 Medium (Normal)")
	difficulty_option.add_item("⚡ Hard (Fast)")
	
	# Add options to wrapping dropdown
	wrapping_option.add_item("🔄 Enabled")
	wrapping_option.add_item("🚫 Disabled")
	
	# Set default selections
	mode_option.selected = 0  # Classic Mode
	difficulty_option.selected = 1  # Medium
	wrapping_option.selected = 1  # Disabled
	
	# Connect signals
	if not mode_option.item_selected.is_connected(_on_mode_option_item_selected):
		mode_option.item_selected.connect(_on_mode_option_item_selected)
	if not difficulty_option.item_selected.is_connected(_on_difficulty_option_item_selected):
		difficulty_option.item_selected.connect(_on_difficulty_option_item_selected)
	if not wrapping_option.item_selected.is_connected(_on_wrapping_option_item_selected):
		wrapping_option.item_selected.connect(_on_wrapping_option_item_selected)
