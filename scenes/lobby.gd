extends Control

# Main menu
@onready var main_menu_panel = $MainMenuPanel
@onready var single_player_button = $MainMenuPanel/VBoxContainer/SinglePlayerButton
@onready var multiplayer_button = $MainMenuPanel/VBoxContainer/MultiplayerButton

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
@onready var selected_mode_label = $GamePanel/GameSection/GameModePanel/GameModeSection/SelectedModeLabel
@onready var selected_difficulty_label = $GamePanel/GameSection/DifficultyPanel/DifficultySection/SelectedDifficultyLabel
@onready var game_mode_panel = $GamePanel/GameSection/GameModePanel
@onready var difficulty_panel = $GamePanel/GameSection/DifficultyPanel

var is_host = false
var in_multiplayer_room = false
var is_ready = false
var ready_players = {}  # Track which players are ready
var ai_player_count = 0  # Track number of AI players added
var ai_players = {}  # Track AI player data {peer_id: {name, color, ready}}

# Game settings
var selected_game_mode = "classic"
var selected_difficulty = "medium"

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
	game_mode_panel.visible = false
	difficulty_panel.visible = false
	
	# Set initial message
	lobby_selected_color_label.text = "Select a color to continue"
	
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

func _on_name_input_text_changed(new_text):
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").player_info["name"] = new_text

func _on_host_button_pressed():
	if not has_node("/root/NetworkManager"):
		status_label.text = "NetworkManager not available!"
		return
	
	var network_manager = get_node("/root/NetworkManager")
	var port = network_manager.DEFAULT_PORT  # Use default port 7000
	
	network_manager.player_info["name"] = name_input.text
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
		game_mode_panel.visible = true  # Show game mode selection for host
		difficulty_panel.visible = true  # Show difficulty selection for host
		update_lobby_color_buttons()  # Enable color selection
		
		# Auto-assign color to host
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
	
	var network_manager = get_node("/root/NetworkManager")
	var address = "127.0.0.1"  # Default to localhost
	var port = network_manager.DEFAULT_PORT  # Use default port 7000
	
	network_manager.player_info["name"] = name_input.text
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
		game_mode_panel.visible = false  # Hide game mode selection for clients
		difficulty_panel.visible = false  # Hide difficulty selection for clients
		update_lobby_color_buttons()  # Enable color selection

func _on_start_button_pressed():
	if not has_node("/root/NetworkManager"):
		return
	
	var network_manager = get_node("/root/NetworkManager")
	var total_players = network_manager.get_player_count() + ai_players.size()
	if is_host and total_players >= 2:
		# Pass game settings to the networked game
		var game_settings = {
			"mode": selected_game_mode,
			"difficulty": selected_difficulty
		}
		network_manager.start_game.rpc(game_settings)

func _on_add_ai_button_pressed():
	if not is_host or not in_multiplayer_room:
		return
	
	# Limit to 6 AI players (8 total with 2 humans max)
	if ai_players.size() >= 6:
		status_label.text = "Maximum AI players reached (6)"
		return
	
	# Find available color for AI
	var available_colors = []
	for color in color_names.keys():
		if not used_colors.has(color):
			available_colors.append(color)
	
	if available_colors.is_empty():
		status_label.text = "No colors available for AI player"
		return
	
	# Create AI player
	ai_player_count += 1
	var ai_name = "AIBot" + str(ai_player_count)
	var ai_color = available_colors[0]  # Take first available color
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
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").remove_multiplayer_peer()
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
	show_multiplayer_menu()

# Button handlers for single player
func _on_color_button_pressed(color: String):
	selected_snake_color = color
	selected_color_label.text = "Selected: " + color_names[color]
	print("Selected snake color: ", color)

func _on_lobby_color_button_pressed(color: String):
	if not in_multiplayer_room or (used_colors.has(color) and used_colors[color] != multiplayer.get_unique_id()):
		return  # Can't select if not in room or color is taken by someone else
	
	# Remove previous color selection from used colors if we had one
	if mp_selected_snake_color != "":
		used_colors.erase(mp_selected_snake_color)
	
	mp_selected_snake_color = color
	lobby_selected_color_label.text = "Selected: " + color_names[color]
	print("Selected multiplayer snake color: ", color)
	
	# Mark this color as used by us
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
	# Store the selected color globally so the game can access it
	var game_data = {}
	game_data["selected_snake_color"] = selected_snake_color
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
	player_list.clear()
	
	# Add human players
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
	
	# Add AI players
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
	print("Player left")
	# Remove their color from used colors
	var colors_to_remove = []
	for color in used_colors.keys():
		if used_colors[color] == peer_id:
			colors_to_remove.append(color)
	
	for color in colors_to_remove:
		used_colors.erase(color)
	
	# Remove their ready state
	ready_players.erase(peer_id)
	update_start_button_state()
	update_lobby_color_buttons()
	update_player_list()

func _on_connection_succeeded():
	print("Successfully connected to server")
	status_label.text = "Connected! Waiting for host to start..."
	
	# Auto-assign a color to this client
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
		var my_id = multiplayer.get_unique_id()
		
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
		network_manager.update_player_color(multiplayer.get_unique_id(), mp_selected_snake_color)

func sync_player_ready_state():
	# Sync ready state with other players
	if not has_node("/root/NetworkManager") or not in_multiplayer_room:
		return
	
	var network_manager = get_node("/root/NetworkManager")
	network_manager.player_info["ready"] = is_ready
	# Notify other players of ready state change
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
	if peer_id != multiplayer.get_unique_id():
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
	if peer_id != multiplayer.get_unique_id():
		ready_players[peer_id] = ready_state
		update_start_button_state()
		update_player_list()

# Game mode and difficulty handlers
func _on_classic_mode_button_pressed():
	selected_game_mode = "classic"
	selected_mode_label.text = "Selected: Classic Mode"
	print("Selected game mode: ", selected_game_mode)

func _on_difficulty_button_pressed(difficulty: String):
	selected_difficulty = difficulty
	var difficulty_names = {
		"easy": "Easy (Slow)",
		"medium": "Medium (Normal)",
		"hard": "Hard (Fast)"
	}
	selected_difficulty_label.text = "Selected: " + difficulty_names[difficulty]
	print("Selected difficulty: ", difficulty)

func get_next_available_color() -> String:
	# List of colors in priority order
	var available_colors = ["green", "blue", "red", "purple", "orange", "yellow", "pink", "cyan"]
	
	# Find the first color that's not used
	for color in available_colors:
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
			if peer_id == multiplayer.get_unique_id():
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
