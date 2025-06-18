extends Node

@export var snake_scene: PackedScene
@export var snake_head_scene: PackedScene
@export var snake_tail_scene: PackedScene
@export var bomb_scene: PackedScene
@export var lightning_scene: PackedScene
@export var ice_scene: PackedScene
@export var tool_selector_scene: PackedScene

#game variables
var game_started: bool = false
var move_count: int = 0 # Track number of moves to prevent immediate game over
var wall_wrapping_enabled: bool = false

# Bomb system variables
var bombs_on_grid = {}  # Dictionary of bomb positions -> bomb data
var player_bomb_counts = {}  # Dictionary of peer_id -> remaining bombs
var player_bomb_timers = {}  # Dictionary of peer_id -> time until next bomb
var max_bombs_per_player = 3
var bomb_regen_time = 15.0  # 15 seconds to get new bomb

# Power-up system variables
var powerups_on_grid = {}  # Dictionary of positions -> powerup data (lightning/ice)
var player_tool_counts = {}  # Dictionary of peer_id -> {bombs: int, lightning: int, ice: int}
var player_tool_timers = {}  # Dictionary of peer_id -> {bombs: float, lightning: float, ice: float}
var current_tool_selection = {}  # Dictionary of peer_id -> "bomb"/"lightning"/"ice"
var player_effects = {}  # Dictionary of peer_id -> {speed_boost: float, frozen_time: float}
var max_tools_per_player = 3
var tool_regen_time = 15.0  # 15 seconds to get new tool
var tool_selector_ui = null  # Reference to tool selector UI

# AI variables
var ai_enabled: bool = false
var ai_timer: float = 0.0
var ai_direction_timer: float = 0.0
var ai_directions = [up, right, down, left] # Clockwise circle
var ai_current_direction_index: int = 0
var ai_steps_in_direction: int = 0
var ai_steps_per_side: int = 3 # 3x3 circle pattern

#grid variables
var cells: int = 20 # Same as single player for proper window fit
var cell_size: int = 50 # Same as single player for consistent look

#food variables
var food_pos: Vector2
var regen_food: bool = true

# Network player data - keyed by peer_id
var player_scores = {}
var player_snakes = {} # Contains snake data, segments, direction, etc.
var alive_players = {}

#movement vectors
var up = Vector2(0, -1)
var down = Vector2(0, 1)
var left = Vector2(-1, 0)
var right = Vector2(1, 0)

# Colors for different players - using single player color system
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
	# Check if this should be an AI client via environment variable
	if OS.has_environment("SNAKE_AI_MODE"):
		ai_enabled = true
		var ai_name = OS.get_environment("SNAKE_AI_NAME")
		if ai_name == "":
			ai_name = "AIBot"
		
		# Set AI name in network manager
		if has_node("/root/NetworkManager"):
			var network_manager = get_node("/root/NetworkManager")
			network_manager.player_info["name"] = ai_name
		
		print("🤖 AI Mode Enabled - This client will play automatically as: ", ai_name)
	
	# Apply game settings (difficulty affects speed)
	var game_settings = get_tree().get_meta("game_settings", {})
	apply_game_settings(game_settings)
	
	# Only the server manages game logic
	if multiplayer.is_server():
		start_new_game()
	else:
		# Clients wait for server updates
		request_game_state()

func apply_game_settings(settings: Dictionary):
	print("🎮 Applying game settings: ", settings)
	
	# Set wall wrapping
	wall_wrapping_enabled = settings.get("wall_wrapping", false)
	print("🌐 Wall wrapping: ", "Enabled" if wall_wrapping_enabled else "Disabled")
	
	# Set difficulty-based speed
	var difficulty = settings.get("difficulty", "medium")
	var speed_settings = {
		"easy": 0.15, # Slow
		"medium": 0.1, # Normal
		"hard": 0.06 # Fast
	}
	
	var move_speed = speed_settings.get(difficulty, 0.1)
	$MoveTimer.wait_time = move_speed
	print("⚡ Set game speed to ", move_speed, " seconds (", difficulty, " difficulty)")

@rpc("authority", "call_local", "reliable")
func start_new_game():
	print("🎮 Starting new multiplayer game...")
	get_tree().paused = false
	get_tree().call_group("segments", "queue_free")
	
	# Reset game state
	move_count = 0
	game_started = false
	
	# Reset bomb system
	bombs_on_grid.clear()
	player_bomb_counts.clear()
	player_bomb_timers.clear()
	
	# Reset power-up system
	powerups_on_grid.clear()
	player_tool_counts.clear()
	player_tool_timers.clear()
	current_tool_selection.clear()
	player_effects.clear()
	
	# Clear any existing visuals
	get_tree().call_group("bombs", "queue_free")
	get_tree().call_group("powerups", "queue_free")
	
	# Hide tool selector UI
	if tool_selector_ui:
		tool_selector_ui.visible = false
	
	# Initialize all connected players
	if not has_node("/root/NetworkManager"):
		print("ERROR: NetworkManager not found!")
		return
	
	var network_manager = get_node("/root/NetworkManager")
	var player_ids = network_manager.get_player_list()
	var color_index = 0
	
	print("👥 Human players: ", player_ids.size())
	
	# Add human players
	for peer_id in player_ids:
		player_scores[peer_id] = 0
		alive_players[peer_id] = true
		player_bomb_counts[peer_id] = 0  # Start with 0 bombs (alive players don't get bombs)
		player_bomb_timers[peer_id] = 0.0
		
		# Initialize tool system
		player_tool_counts[peer_id] = {"bombs": 0, "lightning": 0, "ice": 0}
		player_tool_timers[peer_id] = {"bombs": 0.0, "lightning": 0.0, "ice": 0.0}
		current_tool_selection[peer_id] = "bomb"  # Default tool
		player_effects[peer_id] = {"speed_boost": 0.0, "frozen_time": 0.0}
		
		# Get the player's selected color from NetworkManager
		var color_name = "green" # Default fallback
		if network_manager.players.has(peer_id) and network_manager.players[peer_id].has("color"):
			var player_color = network_manager.players[peer_id]["color"]
			if player_color != "" and player_color != null:
				color_name = player_color
				print("👤 Player ", peer_id, " using selected color: ", color_name)
			else:
				print("👤 Player ", peer_id, " has empty color, using fallback: ", color_name)
		else:
			print("👤 Player ", peer_id, " has no color info, using fallback: ", color_name)
		
		# Initialize snake data for this player
		player_snakes[peer_id] = {
			"data": [],
			"old_data": [],
			"segments": [],
			"direction": up,
			"can_move": true,
			"start_pos": get_start_position(color_index),
			"color_name": color_name,
			"is_ai": false
		}
		
		print("👤 Adding human player ", peer_id, " at position ", player_snakes[peer_id].start_pos, " with color ", color_name)
		generate_snake_for_player(peer_id)
		color_index += 1
	
	# Add AI players from lobby
	var ai_players = get_tree().get_meta("ai_players", {})
	print("🤖 AI players: ", ai_players.size())
	
	for ai_peer_id in ai_players:
		var ai_data = ai_players[ai_peer_id]
		player_scores[ai_peer_id] = 0
		alive_players[ai_peer_id] = true
		player_bomb_counts[ai_peer_id] = 0  # Start with 0 bombs (alive players don't get bombs)
		player_bomb_timers[ai_peer_id] = 0.0
		
		# Initialize tool system for AI
		player_tool_counts[ai_peer_id] = {"bombs": 0, "lightning": 0, "ice": 0}
		player_tool_timers[ai_peer_id] = {"bombs": 0.0, "lightning": 0.0, "ice": 0.0}
		current_tool_selection[ai_peer_id] = "bomb"  # Default tool
		player_effects[ai_peer_id] = {"speed_boost": 0.0, "frozen_time": 0.0}
		
		# Use the AI player's selected color from lobby
		var ai_color_name = ai_data["color"]
		
		# Initialize AI snake data
		player_snakes[ai_peer_id] = {
			"data": [],
			"old_data": [],
			"segments": [],
			"direction": up,
			"can_move": true,
			"start_pos": get_start_position(color_index),
			"color_name": ai_color_name,
			"is_ai": true,
			"ai_name": ai_data["name"],
			"ai_direction_timer": 0.0,
			"ai_steps_in_direction": 0,
			"ai_current_direction_index": 0,
			"ai_movement_history": [], # Track recent positions for loop detection
			"ai_direction_history": [], # Track recent directions for pattern detection
			"ai_loop_detection_timer": 0.0, # Timer for clearing old history
			"ai_stuck_counter": 0 # Counter for how long AI has been in same area
		}
		
		print("🤖 Adding AI player ", ai_data["name"], " at position ", player_snakes[ai_peer_id].start_pos, " with color ", ai_color_name)
		generate_snake_for_player(ai_peer_id)
		color_index += 1
		print("🤖 Added AI player to game: ", ai_data["name"])
	
	print("🎯 Total players in game: ", player_snakes.size())
	update_hud()
	move_food()
	
	if multiplayer.is_server():
		print("⏰ Starting move timer...")
		$MoveTimer.start()

func get_start_position(index: int) -> Vector2:
	# Distribute 8 players around the edges of the 20x20 arena with safe spacing
	match index % 8:
		0: return Vector2(5, 5) # Top-left area
		1: return Vector2(15, 5) # Top-right area
		2: return Vector2(5, 15) # Bottom-left area
		3: return Vector2(15, 15) # Bottom-right area
		4: return Vector2(10, 3) # Top-center
		5: return Vector2(3, 10) # Left-center
		6: return Vector2(17, 10) # Right-center
		7: return Vector2(10, 17) # Bottom-center
		_: return Vector2(10, 10) # Center fallback

func get_color_name_for_index(index: int) -> String:
	var color_names = ["green", "blue", "red", "purple", "orange", "yellow", "pink", "cyan"]
	return color_names[index % color_names.size()]

func generate_snake_for_player(peer_id: int):
	var snake_info = player_snakes[peer_id]
	
	# Clear existing data
	snake_info.data.clear()
	snake_info.segments.clear()
	
	# Validate start position
	if snake_info.start_pos == null:
		print("⚠️ Warning: Player ", peer_id, " has null start_pos, using default")
		snake_info.start_pos = Vector2(10, 10)
	
	var start_pos = snake_info.start_pos
	print("🐍 Generating snake for player ", peer_id, " starting at ", start_pos, " with color ", snake_info.color_name)
	
	# Generate snake with head, body, and tail like single player
	for i in range(3):
		var pos = start_pos + Vector2(0, i)
		
		# Ensure position is within bounds
		pos.x = clamp(pos.x, 0, cells - 1)
		pos.y = clamp(pos.y, 0, cells - 1)
		
		snake_info.data.append(pos)
		
		# Add appropriate segment type
		if i == 0:
			add_segment_for_player(peer_id, pos, true, false) # Head
		elif i == 2:
			add_segment_for_player(peer_id, pos, false, true) # Tail
		else:
			add_segment_for_player(peer_id, pos, false, false) # Body
	
	print("🐍 Generated snake for player ", peer_id, " at positions: ", snake_info.data)
	
	# Ensure direction is properly set
	if snake_info.direction == null:
		print("⚠️ Warning: Player ", peer_id, " has null direction after generation, setting to up")
		snake_info.direction = up

func add_segment_for_player(peer_id: int, pos: Vector2, is_head: bool = false, is_tail: bool = false):
	var snake_info = player_snakes[peer_id]
	var SnakeSegment
	
	# Use appropriate scene based on segment type
	if is_head and snake_head_scene != null:
		SnakeSegment = snake_head_scene.instantiate()
	elif is_tail and snake_tail_scene != null:
		SnakeSegment = snake_tail_scene.instantiate()
		# Set pivot point to center for proper rotation
		SnakeSegment.pivot_offset = Vector2(25, 25)
	elif snake_scene != null:
		SnakeSegment = snake_scene.instantiate()
	else:
		print("⚠️ Error: No snake scene assigned! Using fallback Panel.")
		SnakeSegment = Panel.new()
		SnakeSegment.custom_minimum_size = Vector2(50, 50)
	
	# Position segment properly aligned with grid (same as food positioning)
	SnakeSegment.position = (pos * cell_size) + Vector2(0, cell_size)
	
	# Apply appropriate colors
	if is_head:
		apply_head_color(SnakeSegment, snake_info.color_name)
	else:
		apply_body_color(SnakeSegment, snake_info.color_name)
	
	# Rotate tail to point away from body
	if is_tail and snake_info.data.size() >= 2:
		var tail_direction = get_tail_direction_for_player(peer_id)
		var rotation = get_rotation_for_direction(tail_direction)
		SnakeSegment.rotation = rotation
	
	add_child(SnakeSegment)
	snake_info.segments.append(SnakeSegment)

func apply_body_color(segment, color_name: String):
	if not color_values.has(color_name):
		print("⚠️ Warning: Unknown color name: ", color_name, ", using green")
		color_name = "green"
	
	var colors = color_values[color_name]
	var panel_style = segment.get_theme_stylebox("panel")
	
	if panel_style == null:
		print("⚠️ Warning: Segment has no panel stylebox, creating default")
		var style = StyleBoxFlat.new()
		style.bg_color = colors["bg"]
		style.border_color = colors["border"]
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		segment.add_theme_stylebox_override("panel", style)
	else:
		panel_style = panel_style.duplicate()
		panel_style.bg_color = colors["bg"]
		panel_style.border_color = colors["border"]
		segment.add_theme_stylebox_override("panel", panel_style)

func apply_head_color(segment, color_name: String):
	if not color_values.has(color_name):
		print("⚠️ Warning: Unknown color name: ", color_name, ", using green")
		color_name = "green"
	
	var colors = color_values[color_name]
	var panel_style = segment.get_theme_stylebox("panel")
	
	if panel_style == null:
		print("⚠️ Warning: Segment has no panel stylebox, creating default")
		var style = StyleBoxFlat.new()
		style.bg_color = colors["head_bg"]
		style.border_color = colors["head_border"]
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		segment.add_theme_stylebox_override("panel", style)
	else:
		panel_style = panel_style.duplicate()
		panel_style.bg_color = colors["head_bg"]
		panel_style.border_color = colors["head_border"]
		segment.add_theme_stylebox_override("panel", panel_style)

func get_tail_direction_for_player(peer_id: int) -> Vector2:
	var snake_info = player_snakes[peer_id]
	if snake_info.data.size() < 2:
		return down # Default direction
	
	# Use the exact same calculation as single player
	var tail_pos = snake_info.data[-1]
	var body_pos = snake_info.data[-2]
	return tail_pos - body_pos

func get_rotation_for_direction(direction: Vector2) -> float:
	# Using the exact same rotation values as single player (which works correctly)
	if direction == up:
		return 0 # Point up (pointed end up)
	elif direction == down:
		return PI # Point down (pointed end down)
	elif direction == left:
		return -PI / 2 # Point left
	elif direction == right:
		return PI / 2 # Point right
	else:
		return 0 # Default

func update_snake_visuals_for_player(peer_id: int):
	# Update the visual appearance of head and tail after growth
	var snake_info = player_snakes[peer_id]
	
	# Clear all existing segments
	for segment in snake_info.segments:
		segment.queue_free()
	snake_info.segments.clear()
	
	# Recreate all segments with proper types
	for i in range(snake_info.data.size()):
		var pos = snake_info.data[i]
		if i == 0:
			add_segment_for_player(peer_id, pos, true, false) # Head
		elif i == snake_info.data.size() - 1:
			add_segment_for_player(peer_id, pos, false, true) # Tail
		else:
			add_segment_for_player(peer_id, pos, false, false) # Body

func _process(delta):
	if ai_enabled:
		handle_ai_input(delta)
	else:
		handle_input()
	
	# Handle AI players created from lobby (server-side only)
	if multiplayer.is_server():
		handle_lobby_ai_players(delta)
		handle_bomb_regeneration(delta)
		handle_tool_regeneration(delta)
		handle_player_effects(delta)
	


func handle_ai_input(delta):
	var peer_id = multiplayer.get_unique_id()
	
	# Only handle input for alive players
	if not alive_players.get(peer_id, false):
		return
		
	if not player_snakes.has(peer_id):
		return
	
	var snake_info = player_snakes[peer_id]
	
	# AI logic: move in a 3x3 circle pattern
	ai_direction_timer += delta
	
	# Change direction every 1.5 seconds or after moving 3 steps
	if snake_info.can_move and ai_direction_timer >= 1.5:
		ai_direction_timer = 0.0
		ai_steps_in_direction += 1
		
		# After 3 steps in current direction, turn right (clockwise)
		if ai_steps_in_direction >= ai_steps_per_side:
			ai_steps_in_direction = 0
			ai_current_direction_index = (ai_current_direction_index + 1) % ai_directions.size()
		
		var new_direction = ai_directions[ai_current_direction_index]
		
		# Make sure AI doesn't reverse into itself
		if new_direction != -snake_info.direction:
			# Send direction change to server
			change_direction.rpc_id(1, new_direction)
			snake_info.can_move = false
			
			if not game_started:
				request_start_game.rpc_id(1)
			
			print("🤖 AI (", OS.get_environment("SNAKE_AI_NAME"), ") changed direction to: ", new_direction, " (step ", ai_steps_in_direction, "/", ai_steps_per_side, ")")

func handle_input():
	var peer_id = multiplayer.get_unique_id()
	
	# Only handle input for alive players
	if not alive_players.get(peer_id, false):
		return
		
	if not player_snakes.has(peer_id):
		return
		
	var snake_info = player_snakes[peer_id]
	
	if snake_info.can_move:
		var new_direction = Vector2.ZERO
		
		if Input.is_action_just_pressed("move_down") and snake_info.direction != up:
			new_direction = down
		elif Input.is_action_just_pressed("move_up") and snake_info.direction != down:
			new_direction = up
		elif Input.is_action_just_pressed("move_left") and snake_info.direction != right:
			new_direction = left
		elif Input.is_action_just_pressed("move_right") and snake_info.direction != left:
			new_direction = right
		
		if new_direction != Vector2.ZERO:
			# Send direction change to server
			change_direction.rpc_id(1, new_direction)
			snake_info.can_move = false
			
			if not game_started:
				request_start_game.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func change_direction(new_direction: Vector2):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: # Called locally
		sender_id = multiplayer.get_unique_id()
	
	if player_snakes.has(sender_id) and alive_players.get(sender_id, false):
		player_snakes[sender_id].direction = new_direction
		player_snakes[sender_id].can_move = false

@rpc("any_peer", "call_local", "reliable")
func request_start_game():
	if multiplayer.is_server() and not game_started:
		game_started = true
		start_game_for_all.rpc()

@rpc("authority", "call_local", "reliable")
func start_game_for_all():
	game_started = true

@rpc("any_peer", "reliable")
func request_game_state():
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		sync_game_state.rpc_id(sender_id, player_scores, player_snakes, alive_players, food_pos, game_started, bombs_on_grid, player_bomb_counts)

@rpc("authority", "reliable")
func sync_game_state(scores, snakes, alive, food_position, started, bombs_grid = {}, bomb_counts = {}):
	player_scores = scores
	player_snakes = snakes
	alive_players = alive
	food_pos = food_position
	game_started = started
	bombs_on_grid = bombs_grid
	player_bomb_counts = bomb_counts
	
	# Recreate visual elements for clients
	get_tree().call_group("segments", "queue_free")
	for peer_id in player_snakes:
		var snake_info = player_snakes[peer_id]
		snake_info.segments.clear()
		# Recreate segments with proper types
		for i in range(snake_info.data.size()):
			var pos = snake_info.data[i]
			if i == 0:
				add_segment_for_player(peer_id, pos, true, false) # Head
			elif i == snake_info.data.size() - 1:
				add_segment_for_player(peer_id, pos, false, true) # Tail
			else:
				add_segment_for_player(peer_id, pos, false, false) # Body
	
	# Recreate bomb visuals
	get_tree().call_group("bombs", "queue_free")
	for bomb_pos in bombs_on_grid:
		create_bomb_visual(bomb_pos)
	
	update_hud()
	$Food.position = (food_pos * cell_size) + Vector2(0, cell_size)

func _on_move_timer_timeout():
	if not multiplayer.is_server():
		return
	
	move_count += 1
	print("🎮 Move ", move_count)
	
	# Reset movement flags
	for peer_id in player_snakes:
		if alive_players.get(peer_id, false):
			player_snakes[peer_id].can_move = true
	
	# Move all alive snakes
	for peer_id in player_snakes:
		if alive_players.get(peer_id, false):
			move_snake_for_player(peer_id)
	
	# Only check collisions after a few moves to prevent immediate game over
	if move_count > 3:
		check_collisions()
	
	check_food_eaten()
	
	# Send game state to all clients
	sync_game_state.rpc(player_scores, player_snakes, alive_players, food_pos, game_started, bombs_on_grid, player_bomb_counts)

func move_snake_for_player(peer_id: int):
	var snake_info = player_snakes[peer_id]
	
	# Check if player is frozen
	var effects = player_effects.get(peer_id, {"speed_boost": 0.0, "frozen_time": 0.0})
	if effects["frozen_time"] > 0:
		print("🧊 Player ", peer_id, " is frozen, skipping movement (", effects["frozen_time"], "s remaining)")
		return
	
	# Safety check: ensure direction is not null
	if snake_info.direction == null:
		print("⚠️ Warning: Player ", peer_id, " has null direction, setting to up")
		snake_info.direction = up
	
	# Safety check: ensure data array exists and has elements
	if snake_info.data.is_empty():
		print("⚠️ Warning: Player ", peer_id, " has empty data array")
		return
	
	snake_info.old_data = [] + snake_info.data
	snake_info.data[0] += snake_info.direction
	
	for i in range(len(snake_info.data)):
		if i > 0:
			snake_info.data[i] = snake_info.old_data[i - 1]
		if i < snake_info.segments.size():
			snake_info.segments[i].position = (snake_info.data[i] * cell_size) + Vector2(0, cell_size)
	
	# Update tail rotation after movement
	if snake_info.segments.size() > 1:
		var tail_index = snake_info.segments.size() - 1
		var tail_segment = snake_info.segments[tail_index]
		# Use the same calculation as single player: current_tail_pos - previous_segment_pos
		var tail_direction = snake_info.data[tail_index] - snake_info.data[tail_index - 1]
		tail_segment.rotation = get_rotation_for_direction(tail_direction)

func check_collisions():
	var newly_dead = []
	
	for peer_id in player_snakes:
		if not alive_players.get(peer_id, false):
			continue
			
		var snake_info = player_snakes[peer_id]
		
		# Safety check: ensure data exists and has elements
		if snake_info.data.is_empty():
			print("⚠️ Warning: Player ", peer_id, " has empty data during collision check")
			continue
			
		var head_pos = snake_info.data[0]
		
		# Safety check: ensure head_pos is valid
		if head_pos == null:
			print("⚠️ Warning: Player ", peer_id, " has null head position")
			continue
		
		# Handle wall collision based on wrapping setting
		if wall_wrapping_enabled:
			# Wrap around edges
			var wrapped = false
			if head_pos.x < 0:
				snake_info.data[0].x = cells - 1
				wrapped = true
			elif head_pos.x > cells - 1:
				snake_info.data[0].x = 0
				wrapped = true
			if head_pos.y < 0:
				snake_info.data[0].y = cells - 1
				wrapped = true
			elif head_pos.y > cells - 1:
				snake_info.data[0].y = 0
				wrapped = true
			
			# Update visual position after wrapping
			if wrapped and snake_info.segments.size() > 0:
				snake_info.segments[0].position = (snake_info.data[0] * cell_size) + Vector2(0, cell_size)
				print("🌐 Player ", peer_id, " wrapped around to ", snake_info.data[0])
		else:
			# Check bounds - die if hit wall
			if head_pos.x < 0 or head_pos.x > cells - 1 or head_pos.y < 0 or head_pos.y > cells - 1:
				print("💀 Player ", peer_id, " died from bounds collision at ", head_pos, " (grid size: ", cells, "x", cells, ")")
				newly_dead.append(peer_id)
				continue
		
		# Check self collision
		for i in range(1, len(snake_info.data)):
			if snake_info.data[i] != null and head_pos == snake_info.data[i]:
				print("💀 Player ", peer_id, " died from self collision at ", head_pos)
				newly_dead.append(peer_id)
				break
		
		# Check collision with other snakes
		for other_peer_id in player_snakes:
			if other_peer_id == peer_id or not alive_players.get(other_peer_id, false):
				continue
			
			var other_snake = player_snakes[other_peer_id]
			if other_snake.data.is_empty():
				continue
				
			for pos in other_snake.data:
				if pos != null and head_pos == pos:
					print("💀 Player ", peer_id, " died from collision with player ", other_peer_id, " at ", head_pos)
					newly_dead.append(peer_id)
					break
		
		# Check bomb collision
		if bombs_on_grid.has(head_pos):
			var bomb_data = bombs_on_grid[head_pos]
			var placer_id = bomb_data["placer_id"]
			
			print("💥 Player ", peer_id, " hit bomb at ", head_pos, " placed by player ", placer_id)
			
			# Explode the bomb
			explode_bomb(head_pos, placer_id)
	
	# Kill players
	for peer_id in newly_dead:
		kill_player(peer_id)
	
	# Check if game should end - only when ALL players are dead
	var alive_count = 0
	for peer_id in alive_players:
		if alive_players[peer_id]:
			alive_count += 1
	
	# End game only when NO players remain (all are dead)
	if alive_count == 0:
		print("🏁 Game ending - all players are dead!")
		end_game()
	else:
		print("🎮 ", alive_count, " players still alive, game continues")

func kill_player(peer_id: int):
	alive_players[peer_id] = false
	
	# Give dead players their starting tools
	player_bomb_counts[peer_id] = max_bombs_per_player
	player_bomb_timers[peer_id] = 0.0
	player_tool_counts[peer_id] = {"bombs": max_tools_per_player, "lightning": max_tools_per_player, "ice": max_tools_per_player}
	player_tool_timers[peer_id] = {"bombs": 0.0, "lightning": 0.0, "ice": 0.0}
	
	# Show tool selector UI for this player (if it's the local player)
	var local_peer_id = multiplayer.get_unique_id()
	if peer_id == local_peer_id:
		show_tool_selector_ui()
	
	# Make snake semi-transparent
	var snake_info = player_snakes[peer_id]
	for segment in snake_info.segments:
		segment.modulate.a = 0.3
	
	print("💀 Player ", peer_id, " died and received tools: ", player_tool_counts[peer_id])

func check_food_eaten():
	for peer_id in player_snakes:
		if not alive_players.get(peer_id, false):
			continue
			
		var snake_info = player_snakes[peer_id]
		var head_pos = snake_info.data[0]
		
		# Check if snake ate food
		if head_pos == food_pos:
			player_scores[peer_id] += 1
			# Add the tail position to the snake data so it grows
			snake_info.data.append(snake_info.old_data[-1])
			add_segment_for_player(peer_id, snake_info.old_data[-1], false, false) # Add body segment
			update_snake_visuals_for_player(peer_id) # Update head/tail visuals
			move_food()
			update_hud()
			print("🍎 Player ", peer_id, " ate food! Snake length now: ", snake_info.data.size())
			
		# Check if snake ate a powerup
		if powerups_on_grid.has(head_pos):
			var powerup_data = powerups_on_grid[head_pos]
			consume_powerup(peer_id, head_pos, powerup_data)
			break

func move_food():
	while regen_food:
		regen_food = false
		food_pos = Vector2(randi_range(0, cells - 1), randi_range(0, cells - 1))
		
		# Check against all alive snakes
		for peer_id in player_snakes:
			if not alive_players.get(peer_id, false):
				continue
			var snake_info = player_snakes[peer_id]
			for pos in snake_info.data:
				if food_pos == pos:
					regen_food = true
					break
	
	$Food.position = (food_pos * cell_size) + Vector2(0, cell_size)
	regen_food = true

func update_hud():
	if not has_node("/root/NetworkManager"):
		return
		
	var network_manager = get_node("/root/NetworkManager")
	var player_grid = $Hud/ScorePanel/PlayerGrid
	
	# Clear existing player labels
	for child in player_grid.get_children():
		child.queue_free()
	
	var all_players = []
	var player_list = network_manager.get_player_list()
	
	# Collect human players
	for peer_id in player_list:
		var player_name = network_manager.players[peer_id]["name"]
		var score = player_scores.get(peer_id, 0)
		var status = "ALIVE" if alive_players.get(peer_id, false) else "DEAD"
		var color_name = player_snakes.get(peer_id, {}).get("color_name", "")
		
		all_players.append({
			"name": player_name,
			"score": score,
			"status": status,
			"color": color_name,
			"is_ai": false
		})
	
	# Collect AI players
	for peer_id in player_snakes:
		var snake_info = player_snakes[peer_id]
		if snake_info.get("is_ai", false):
			var ai_name = snake_info.get("ai_name", "AIBot")
			var score = player_scores.get(peer_id, 0)
			var status = "ALIVE" if alive_players.get(peer_id, false) else "DEAD"
			var color_name = snake_info.get("color_name", "")
			
			all_players.append({
				"name": ai_name,
				"score": score,
				"status": status,
				"color": color_name,
				"is_ai": true
			})
	
	# Create labels for each player (up to 8 players in 4x2 grid)
	for i in range(min(all_players.size(), 8)):
		var player = all_players[i]
		var player_label = Label.new()
		
		# Format: PlayerName: Score (STATUS) [Bombs if dead]
		var display_text = player.name + ": " + str(player.score)
		
		# Add status with color coding
		if player.status == "ALIVE":
			display_text += " ✅"
			player_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1, 1))
		else:
			display_text += " ❌"
			# Show bomb count for dead players
			var peer_id = get_peer_id_for_player(player)
			if peer_id != -1:
				var bomb_count = player_bomb_counts.get(peer_id, 0)
				display_text += " 💣" + str(bomb_count)
			player_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		
		# Add AI indicator
		if player.is_ai:
			display_text += " 🤖"
		
		player_label.text = display_text
		player_label.add_theme_font_size_override("font_size", 14)
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Load the custom font
		var font = preload("res://assets/MaldiniBold.ttf")
		player_label.add_theme_font_override("font", font)
		
		player_grid.add_child(player_label)

func end_game():
	if not multiplayer.is_server():
		return
		
	$MoveTimer.stop()
	game_started = false
	get_tree().paused = true
	
	# Determine winner
	var best_score = -1
	var winner_peer_id = -1
	
	for peer_id in player_scores:
		var score = player_scores[peer_id]
		if score > best_score:
			best_score = score
			winner_peer_id = peer_id
	
	# Get winner info
	var winner_info = {}
	if winner_peer_id != -1:
		winner_info["name"] = get_player_name(winner_peer_id)
		winner_info["score"] = best_score
	
	show_results.rpc(player_scores, winner_info)

func get_player_name(peer_id: int) -> String:
	# Try to get name from NetworkManager
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		if network_manager.players.has(peer_id):
			return network_manager.players[peer_id]["name"]
		
		# Check AI players
		var ai_players = network_manager.get_ai_players()
		if ai_players.has(peer_id):
			return ai_players[peer_id]["name"]
	
	# Check local AI players
	if player_snakes.has(peer_id):
		var snake_info = player_snakes[peer_id]
		if snake_info.get("is_ai", false):
			return snake_info.get("ai_name", "AIBot")
	
	# Fallback
	return "Player " + str(peer_id)

@rpc("authority", "call_local", "reliable")
func show_results(final_scores: Dictionary, winner_info: Dictionary):
	print("🏆 Showing game results...")
	$Results.visible = true
	$Results.display_results(final_scores, winner_info)

func _on_results_back_to_lobby_requested():
	if multiplayer.is_server():
		# Host sends everyone back to lobby via RPC
		return_to_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func return_to_lobby():
	print("🏠 Returning to lobby...")
	
	# Unpause the game tree so the lobby is interactive
	get_tree().paused = false
	
	# Preserve room information for room-based multiplayer
	var room_manager = get_node("/root/RoomManager")
	if room_manager.is_in_room():
		var current_room = room_manager.get_current_room()
		if current_room:
			# Preserve room metadata so lobby knows we're still in room mode
			get_tree().set_meta("room_code", current_room.code)
			get_tree().set_meta("is_host", room_manager.is_host)
			get_tree().set_meta("player_name", room_manager.local_player_name)
			print("🏠 Preserving room info for return to lobby: ", current_room.code)
	
	# Preserve human player colors (especially the host's selected color)
	var player_colors = {}
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		for peer_id in network_manager.players:
			var player_info = network_manager.players[peer_id]
			if player_info.has("color") and player_info["color"] != "":
				player_colors[peer_id] = player_info["color"]
				print("🎨 Preserving color for player ", peer_id, ": ", player_info["color"])
	
	# Store preserved colors
	if not player_colors.is_empty():
		get_tree().set_meta("preserved_player_colors", player_colors)
		print("🎨 Preserved ", player_colors.size(), " player colors: ", player_colors)
	
	# Preserve AI players for return to lobby 
	var current_ai_players = get_tree().get_meta("ai_players", {})
	print("🔍 DEBUG: Found ai_players metadata: ", current_ai_players)
	
	# Also get AI players from NetworkManager as backup
	var network_ai_players = {}
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		network_ai_players = network_manager.get_ai_players()
		print("🔍 DEBUG: NetworkManager AI players: ", network_ai_players)
	
	# Use whichever source has AI players (prefer NetworkManager as it's more reliable)
	# Create a copy to avoid reference issues when clearing NetworkManager
	var ai_to_preserve = {}
	if not network_ai_players.is_empty():
		ai_to_preserve = network_ai_players.duplicate(true) # Deep copy
		print("🔄 Using NetworkManager AI players as primary source")
	elif not current_ai_players.is_empty():
		ai_to_preserve = current_ai_players.duplicate(true) # Deep copy
		print("🔄 Using metadata AI players as fallback")
	
	# Reset NetworkManager state for new game but keep the server/client connection
	if has_node("/root/NetworkManager"):
		var network_manager = get_node("/root/NetworkManager")
		# Clear AI players from NetworkManager (lobby will re-add them)
		network_manager.clear_ai_players()
		print("🔄 Cleared NetworkManager AI players - lobby will restore them")
	
	# Preserve AI players for the lobby to restore
	print("🔍 DEBUG: Final ai_to_preserve: ", ai_to_preserve)
	print("🔍 DEBUG: ai_to_preserve.is_empty(): ", ai_to_preserve.is_empty())
	print("🔍 DEBUG: ai_to_preserve.size(): ", ai_to_preserve.size())
	
	if not ai_to_preserve.is_empty():
		get_tree().set_meta("preserved_ai_players", ai_to_preserve)
		print("🤖 Preserved ", ai_to_preserve.size(), " AI players for lobby restoration: ", ai_to_preserve.keys())
	else:
		print("⚠️ No AI players found to preserve! ai_to_preserve = ", ai_to_preserve)
	
	# Clear game metadata (but keep preserved AI players and colors)
	get_tree().remove_meta("ai_players")
	get_tree().remove_meta("game_settings")
	
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func handle_lobby_ai_players(delta):
	# Handle AI logic for lobby-created AI players (server-side only)
	if not game_started:
		return # Don't move AI until game starts
		
	for peer_id in player_snakes:
		var snake_info = player_snakes[peer_id]
		if not snake_info.get("is_ai", false):
			continue # Skip non-AI players
		
		if not alive_players.get(peer_id, false):
			continue # Skip dead AI players
		
		# Update loop detection timer
		snake_info.ai_loop_detection_timer += delta
		
		# Clean up old movement history every 2 seconds
		if snake_info.ai_loop_detection_timer >= 2.0:
			snake_info.ai_loop_detection_timer = 0.0
			# Keep only recent 8 moves in history
			if snake_info.ai_movement_history.size() > 8:
				snake_info.ai_movement_history = snake_info.ai_movement_history.slice(-8)
			if snake_info.ai_direction_history.size() > 8:
				snake_info.ai_direction_history = snake_info.ai_direction_history.slice(-8)
		
		# Smart AI logic with wall avoidance and food seeking
		snake_info.ai_direction_timer += delta
		
		# Make decisions every 0.3 seconds for more responsive AI
		if snake_info.can_move and snake_info.ai_direction_timer >= 0.3:
			snake_info.ai_direction_timer = 0.0
			
			var current_head = snake_info.data[0]
			var current_direction = snake_info.direction
			
			# Track current position in movement history
			snake_info.ai_movement_history.append(current_head)
			snake_info.ai_direction_history.append(current_direction)
			
			# Check for loops and repetitive patterns
			var is_looping = detect_movement_loop(snake_info)
			var is_repeating_directions = detect_direction_pattern(snake_info)
			
			var best_direction = choose_smart_direction_with_loop_avoidance(
				peer_id, current_head, current_direction, is_looping, is_repeating_directions
			)
			
			# Only change direction if it's different and safe
			if best_direction != current_direction and best_direction != -current_direction:
				snake_info.direction = best_direction
				snake_info.can_move = false
				
				# Reset stuck counter when successfully changing direction
				snake_info.ai_stuck_counter = 0
				
				print("🤖 AI (", snake_info.get("ai_name", "AIBot"), ") chose direction: ", best_direction,
					  " (Loop:", is_looping, " Pattern:", is_repeating_directions, ")")
			else:
				# Increment stuck counter if unable to change direction
				snake_info.ai_stuck_counter += 1

func choose_smart_direction_with_loop_avoidance(peer_id: int, head_pos: Vector2, current_direction: Vector2, is_looping: bool, is_repeating_directions: bool) -> Vector2:
	var possible_directions = [up, down, left, right]
	var direction_scores = {}
	
	# Calculate dynamic aggressiveness based on alive snakes
	var total_snakes = alive_players.size()
	var aggressiveness_multiplier = get_food_aggressiveness_multiplier(total_snakes)
	
	# 80% of the time, use smart AI. 20% of the time, be less optimal
	var use_smart_ai = randf() < 1
	
	# Get movement and direction history for this AI
	var snake_info = player_snakes[peer_id]
	var movement_history = snake_info.get("ai_movement_history", [])
	var direction_history = snake_info.get("ai_direction_history", [])
	var stuck_counter = snake_info.get("ai_stuck_counter", 0)
	
	# Anti-loop mode: When stuck or looping, prioritize breaking patterns
	var anti_loop_mode = is_looping or is_repeating_directions or stuck_counter > 3
	
	# Score each possible direction
	for direction in possible_directions:
		# Can't reverse into self
		if direction == -current_direction:
			continue
			
		var next_pos = head_pos + direction
		var score = 0
		
		# Check if this direction is safe (no immediate collision)
		if is_position_safe(peer_id, next_pos):
			score += 100 # Base safety score
			
			# Anti-loop penalties and bonuses
			if anti_loop_mode:
				print("🔄 AI in anti-loop mode: stuck=", stuck_counter, " looping=", is_looping, " repeating=", is_repeating_directions)
				
				# Heavy penalty for directions that lead to recently visited positions
				for recent_pos in movement_history:
					if next_pos == recent_pos:
						score -= 200 # Heavy penalty for revisiting positions
				
				# Heavy penalty for recently used directions
				for recent_dir in direction_history:
					if direction == recent_dir:
						score -= 150 # Heavy penalty for repeating directions
				
				# Bonus for completely new directions
				if direction not in direction_history:
					score += 300 # Big bonus for unexplored directions
				
				# Add randomness to break deterministic patterns
				score += randf_range(-50, 50)
				
				# In extreme stuck situations, prioritize any movement over safety
				if stuck_counter > 5:
					score += 400 # Emergency escape bonus
					print("🚨 AI emergency escape mode activated!")
			
			if use_smart_ai and not anti_loop_mode:
				# Smart AI: More aggressive food seeking with strategic planning
				# Bonus for staying away from walls (priority increases with more snakes)
				var wall_distance = get_wall_distance(next_pos, direction)
				var wall_multiplier = 5 + (total_snakes - 1) * 2 # More wall caution with more snakes
				score += wall_distance * wall_multiplier
				
				# Dynamic food bonus based on snake count
				var food_direction = get_food_direction(next_pos)
				if food_direction == direction:
					var food_distance = get_food_distance(next_pos)
					var food_safety = is_food_path_safe(peer_id, next_pos, direction)
					
					var base_food_bonus = 150 * aggressiveness_multiplier
					var distant_food_bonus = 80 * aggressiveness_multiplier
					var risky_food_bonus = 100 * aggressiveness_multiplier
					
					if food_safety and food_distance <= 8:
						score += base_food_bonus - (food_distance * 8 * aggressiveness_multiplier)
					elif food_safety and food_distance <= 15:
						score += distant_food_bonus - (food_distance * 3 * aggressiveness_multiplier)
					elif food_distance <= 5: # Risky food pursuit - less likely with more snakes
						score += risky_food_bonus * aggressiveness_multiplier - (food_distance * 10)
				
				# Additional bonus for getting closer to food (scaled by aggressiveness)
				var current_food_distance = get_food_distance(head_pos)
				var new_food_distance = get_food_distance(next_pos)
				if new_food_distance < current_food_distance:
					score += 60 * aggressiveness_multiplier
				
				# Penalty for getting too close to other snakes (increases with more snakes)
				var snake_danger = get_snake_danger_score(peer_id, next_pos)
				var danger_multiplier = 0.5 + (total_snakes - 1) * 0.3 # More cautious with more snakes
				score -= snake_danger * danger_multiplier
				
				# Look ahead - more cautious planning with more snakes
				var future_steps = 2 + min(total_snakes - 1, 2) # Look 2-4 steps ahead based on snake count
				var future_safety = check_future_safety(peer_id, next_pos, direction, future_steps)
				var safety_weight = 0.5 + (total_snakes - 1) * 0.2 # Higher safety weight with more snakes
				score += future_safety * safety_weight
			elif not anti_loop_mode:
				# Less optimal AI: Food-focused but also scales with snake count
				# Wall avoidance scales with snake count
				var wall_distance = get_wall_distance(next_pos, direction)
				var wall_multiplier = 2 + total_snakes # More wall caution with more snakes
				score += wall_distance * wall_multiplier
				
				# Aggressive food seeking (scaled)
				var food_direction = get_food_direction(next_pos)
				if food_direction == direction:
					var food_distance = get_food_distance(next_pos)
					var food_bonus = 120 * aggressiveness_multiplier
					score += food_bonus - (food_distance * 6 * aggressiveness_multiplier)
				
				# Bonus for getting closer to food (scaled)
				var current_food_distance = get_food_distance(head_pos)
				var new_food_distance = get_food_distance(next_pos)
				if new_food_distance < current_food_distance:
					score += 40 * aggressiveness_multiplier
				
				# Randomness decreases with more snakes (more predictable/safe play)
				var randomness_range = 10 * aggressiveness_multiplier
				score += randf_range(-randomness_range, randomness_range)
			
		else:
			score = -1000 # Immediate danger, avoid at all costs
		
		direction_scores[direction] = score
	
	# Choose the direction with the highest score
	var best_direction = current_direction # Default to current direction
	var best_score = -2000
	
	for direction in direction_scores:
		if direction_scores[direction] > best_score:
			best_score = direction_scores[direction]
			best_direction = direction
	
	# If no good direction found, try to find any safe direction (emergency)
	if best_score < 0:
		for direction in possible_directions:
			if direction != -current_direction:
				var next_pos = head_pos + direction
				if is_position_safe(peer_id, next_pos):
					print("🚨 AI Emergency turn to: ", direction)
					return direction
	
	return best_direction

func get_food_aggressiveness_multiplier(alive_snake_count: int) -> float:
	# Dynamic aggressiveness based on number of alive snakes
	# More snakes = less aggressive food seeking
	# Fewer snakes = more aggressive food seeking
	match alive_snake_count:
		1:
			return 2.0 # Very aggressive when alone
		2:
			return 1.5 # Quite aggressive with one opponent
		3:
			return 1.2 # Moderately aggressive
		4:
			return 1.0 # Balanced (original aggressiveness)
		5:
			return 0.8 # Somewhat cautious
		6:
			return 0.6 # More cautious
		_:
			return 0.5 # Very cautious with many snakes (7+)

func is_position_safe(peer_id: int, pos: Vector2) -> bool:
	# Check bounds - with wall wrapping, out of bounds positions are safe (they wrap)
	if not wall_wrapping_enabled:
		if pos.x < 0 or pos.x >= cells or pos.y < 0 or pos.y >= cells:
			return false
	
	# Normalize position for wall wrapping
	var check_pos = pos
	if wall_wrapping_enabled:
		check_pos.x = ((int(pos.x) % cells) + cells) % cells
		check_pos.y = ((int(pos.y) % cells) + cells) % cells
	
	# Check collision with own body
	var snake_info = player_snakes[peer_id]
	for body_pos in snake_info.data:
		if check_pos == body_pos:
			return false
	
	# Check collision with other snakes
	for other_peer_id in player_snakes:
		if other_peer_id == peer_id or not alive_players.get(other_peer_id, false):
			continue
		
		var other_snake = player_snakes[other_peer_id]
		for other_pos in other_snake.data:
			if check_pos == other_pos:
				return false
	
	return true

func get_wall_distance(pos: Vector2, direction: Vector2) -> int:
	# With wall wrapping enabled, walls are not dangerous
	if wall_wrapping_enabled:
		return 10 # High value since walls don't kill
	
	var distance = 0
	var check_pos = pos
	
	# Count how many steps until hitting a wall in this direction
	while check_pos.x >= 0 and check_pos.x < cells and check_pos.y >= 0 and check_pos.y < cells:
		distance += 1
		check_pos += direction
		if distance > 5: # Don't look too far ahead
			break
	
	return distance

func get_food_direction(pos: Vector2) -> Vector2:
	var food_diff = food_pos - pos
	
	# Return the primary direction toward food
	if abs(food_diff.x) > abs(food_diff.y):
		return Vector2(sign(food_diff.x), 0)
	else:
		return Vector2(0, sign(food_diff.y))

func get_food_distance(pos: Vector2) -> int:
	var distance = abs(food_pos.x - pos.x) + abs(food_pos.y - pos.y)
	return distance

func is_food_path_safe(peer_id: int, pos: Vector2, direction: Vector2) -> bool:
	# Check if moving toward food won't lead into immediate danger
	# Reduced safety checking - only check 1-2 steps ahead instead of 3
	var steps_to_check = min(2, get_food_distance(pos)) # Reduced from 3 to 2
	var check_pos = pos
	
	for i in range(steps_to_check):
		check_pos += direction
		if not is_position_safe(peer_id, check_pos):
			return false
	
	return true

func get_snake_danger_score(peer_id: int, pos: Vector2) -> int:
	var danger = 0
	
	# Check proximity to other snakes (reduced penalty)
	for other_peer_id in player_snakes:
		if other_peer_id == peer_id or not alive_players.get(other_peer_id, false):
			continue
		
		var other_snake = player_snakes[other_peer_id]
		for other_pos in other_snake.data:
			var distance = abs(pos.x - other_pos.x) + abs(pos.y - other_pos.y) # Manhattan distance
			if distance <= 2:
				danger += (3 - distance) * 10 # Reduced penalty from 20 to 10 - be braver around other snakes
	
	return danger

func check_future_safety(peer_id: int, start_pos: Vector2, direction: Vector2, steps: int) -> int:
	var safety_score = 0
	var current_pos = start_pos
	
	# Simulate moving in this direction for several steps
	for i in range(steps):
		current_pos += direction
		
		if is_position_safe(peer_id, current_pos):
			safety_score += 10 # Each safe step ahead is good
			
			# Extra bonus for having multiple escape routes
			var escape_routes = count_escape_routes(peer_id, current_pos)
			safety_score += escape_routes * 5
		else:
			safety_score -= 30 # Future collision is bad
			break
	
	return safety_score

func count_escape_routes(peer_id: int, pos: Vector2) -> int:
	var escape_count = 0
	var directions = [up, down, left, right]
	
	for direction in directions:
		var check_pos = pos + direction
		if is_position_safe(peer_id, check_pos):
			escape_count += 1
	
	return escape_count

func detect_movement_loop(snake_info: Dictionary) -> bool:
	var movement_history = snake_info.ai_movement_history
	
	# Need at least 4 positions to detect a meaningful loop
	if movement_history.size() < 4:
		return false
	
	var current_pos = movement_history[-1]  # Most recent position
	
	# Check if current position was visited recently (within last 4-6 moves)
	var recent_moves_to_check = min(6, movement_history.size() - 1)
	for i in range(1, recent_moves_to_check + 1):
		var past_pos = movement_history[-(i+1)]
		if current_pos == past_pos:
			print("🔄 Loop detected: returned to position ", current_pos, " after ", i, " moves")
			return true
	
	# Check for back-and-forth movement (oscillation)
	if movement_history.size() >= 4:
		var pos1 = movement_history[-1]
		var pos2 = movement_history[-2]
		var pos3 = movement_history[-3]
		var pos4 = movement_history[-4]
		
		# A->B->A->B pattern
		if pos1 == pos3 and pos2 == pos4:
			print("🔄 Oscillation detected: A->B->A->B pattern")
			return true
	
	return false

func detect_direction_pattern(snake_info: Dictionary) -> bool:
	var direction_history = snake_info.ai_direction_history
	
	# Need at least 3 directions to detect a pattern
	if direction_history.size() < 3:
		return false
	
	# Check for repeated direction patterns
	var current_dir = direction_history[-1]
	var recent_dirs = direction_history.slice(-4) if direction_history.size() >= 4 else direction_history
	
	# Count occurrences of current direction in recent history
	var current_dir_count = 0
	for dir in recent_dirs:
		if dir == current_dir:
			current_dir_count += 1
	
	# If same direction used more than 50% of recent moves, it's repetitive
	if current_dir_count > recent_dirs.size() * 0.5:
		print("🔄 Direction pattern detected: ", current_dir, " used ", current_dir_count, "/", recent_dirs.size(), " times")
		return true
	
	# Check for simple alternating patterns (left-right-left-right)
	if direction_history.size() >= 4:
		var dir1 = direction_history[-1]
		var dir2 = direction_history[-2]
		var dir3 = direction_history[-3]
		var dir4 = direction_history[-4]
		
		# Alternating pattern
		if dir1 == dir3 and dir2 == dir4 and dir1 == -dir2:
			print("🔄 Alternating direction pattern detected")
			return true
	
	# Check for clockwise/counterclockwise circles
	if direction_history.size() >= 4:
		var recent_4_dirs = direction_history.slice(-4)
		
		# Clockwise: up->right->down->left
		var clockwise = [up, right, down, left]
		var counterclockwise = [up, left, down, right]
		
		# Check if recent directions match a circular pattern
		for start_idx in range(4):
			var matches_clockwise = true
			var matches_counterclockwise = true
			
			for i in range(4):
				var expected_cw = clockwise[(start_idx + i) % 4]
				var expected_ccw = counterclockwise[(start_idx + i) % 4]
				var actual = recent_4_dirs[i]
				
				if actual != expected_cw:
					matches_clockwise = false
				if actual != expected_ccw:
					matches_counterclockwise = false
			
			if matches_clockwise or matches_counterclockwise:
				print("🔄 Circular pattern detected: ", "clockwise" if matches_clockwise else "counterclockwise")
				return true
	
	return false

func handle_bomb_regeneration(delta):
	# Regenerate bombs for dead players every 15 seconds
	for peer_id in player_bomb_timers:
		if not alive_players.get(peer_id, true):  # Dead players only
			player_bomb_timers[peer_id] += delta
			
			# Give new bomb every 15 seconds if under max
			if player_bomb_timers[peer_id] >= bomb_regen_time:
				var current_bombs = player_bomb_counts.get(peer_id, 0)
				if current_bombs < max_bombs_per_player:
					player_bomb_counts[peer_id] = current_bombs + 1
					player_bomb_timers[peer_id] = 0.0
					print("💣 Player ", peer_id, " received a new bomb (", player_bomb_counts[peer_id], "/", max_bombs_per_player, ")")
					
					# Update HUD to show new bomb count
					update_hud()

func handle_tool_regeneration(delta):
	# Regenerate tools for dead players every 15 seconds
	for peer_id in player_tool_timers:
		if not alive_players.get(peer_id, true):  # Dead players only
			var timers = player_tool_timers[peer_id]
			var counts = player_tool_counts[peer_id]
			
			# Regenerate each tool type
			for tool_type in ["bombs", "lightning", "ice"]:
				timers[tool_type] += delta
				
				if timers[tool_type] >= tool_regen_time:
					if counts[tool_type] < max_tools_per_player:
						counts[tool_type] += 1
						timers[tool_type] = 0.0
						print("🔧 Player ", peer_id, " received new ", tool_type, " (", counts[tool_type], "/", max_tools_per_player, ")")
			
			# Update HUD
			update_hud()

func show_tool_selector_ui():
	if not tool_selector_scene:
		print("⚠️ Tool selector scene not found!")
		return
	
	# Create and position tool selector UI
	if not tool_selector_ui:
		tool_selector_ui = tool_selector_scene.instantiate()
		add_child(tool_selector_ui)
		
		# Position at top right of screen (above the game area)
		tool_selector_ui.position = Vector2(get_viewport().get_visible_rect().size.x - 320, 10)
		
		# Connect button signals
		var bomb_button = tool_selector_ui.get_node("Panel/ButtonContainer/BombButton")
		var lightning_button = tool_selector_ui.get_node("Panel/ButtonContainer/LightningButton")
		var ice_button = tool_selector_ui.get_node("Panel/ButtonContainer/IceButton")
		
		bomb_button.pressed.connect(_on_tool_selected.bind("bomb"))
		lightning_button.pressed.connect(_on_tool_selected.bind("lightning"))
		ice_button.pressed.connect(_on_tool_selected.bind("ice"))
	
	tool_selector_ui.visible = true
	_update_tool_selector_ui()

func _on_tool_selected(tool_type: String):
	var peer_id = multiplayer.get_unique_id()
	current_tool_selection[peer_id] = tool_type
	_update_tool_selector_ui()
	_update_cursor()
	print("🔧 Selected tool: ", tool_type)

func _update_tool_selector_ui():
	if not tool_selector_ui:
		return
	
	var peer_id = multiplayer.get_unique_id()
	var selected_tool = current_tool_selection.get(peer_id, "bomb")
	var counts = player_tool_counts.get(peer_id, {"bombs": 0, "lightning": 0, "ice": 0})
	
	# Update button appearances and text
	var bomb_button = tool_selector_ui.get_node("Panel/ButtonContainer/BombButton")
	var lightning_button = tool_selector_ui.get_node("Panel/ButtonContainer/LightningButton")
	var ice_button = tool_selector_ui.get_node("Panel/ButtonContainer/IceButton")
	
	# Update button text with counts
	bomb_button.text = "💣\nBomb (" + str(counts["bombs"]) + ")"
	lightning_button.text = "⚡\nLightning (" + str(counts["lightning"]) + ")"
	ice_button.text = "🧊\nIce (" + str(counts["ice"]) + ")"
	
	# Highlight selected button
	bomb_button.button_pressed = (selected_tool == "bomb")
	lightning_button.button_pressed = (selected_tool == "lightning")
	ice_button.button_pressed = (selected_tool == "ice")

func _update_cursor():
	var peer_id = multiplayer.get_unique_id()
	var selected_tool = current_tool_selection.get(peer_id, "bomb")
	
	# TODO: Set custom cursor based on selected tool
	# For now, just print the selection
	print("🖱️ Cursor updated for tool: ", selected_tool)



@rpc("any_peer", "reliable")
func request_tool_placement(grid_pos: Vector2, tool_type: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:  # Called locally
		sender_id = multiplayer.get_unique_id()
	
	# Only server processes tool placement
	if not multiplayer.is_server():
		return
	
	# Validate player can place tool
	if alive_players.get(sender_id, true):  # Player is alive
		print("⚠️ Player ", sender_id, " tried to place ", tool_type, " but is still alive")
		return
	
	var counts = player_tool_counts.get(sender_id, {"bombs": 0, "lightning": 0, "ice": 0})
	var tool_count_key = ""
	match tool_type:
		"bomb":
			tool_count_key = "bombs"
		"lightning":
			tool_count_key = "lightning"
		"ice":
			tool_count_key = "ice"
	
	if counts.get(tool_count_key, 0) <= 0:  # No tools available
		print("⚠️ Player ", sender_id, " tried to place ", tool_type, " but has none available")
		return
	
	# Check if position is valid (not on snakes, not on existing items)
	if not is_valid_placement_position(grid_pos):
		print("⚠️ Player ", sender_id, " tried to place ", tool_type, " at invalid position ", grid_pos)
		return
	
	# Place the tool
	place_tool(sender_id, grid_pos, tool_type)

func is_valid_bomb_position(grid_pos: Vector2) -> bool:
	# Check if position is already occupied by a bomb
	if bombs_on_grid.has(grid_pos):
		return false
	
	# Check if position is occupied by any snake
	for peer_id in player_snakes:
		if not alive_players.get(peer_id, false):
			continue  # Skip dead snakes
		
		var snake_info = player_snakes[peer_id]
		for segment_pos in snake_info.data:
			if segment_pos == grid_pos:
				return false
	
	return true

func is_valid_placement_position(grid_pos: Vector2) -> bool:
	# Check if position is already occupied by a bomb
	if bombs_on_grid.has(grid_pos):
		return false
	
	# Check if position is already occupied by a powerup
	if powerups_on_grid.has(grid_pos):
		return false
	
	# Check if position is occupied by any snake
	for peer_id in player_snakes:
		if not alive_players.get(peer_id, false):
			continue  # Skip dead snakes
		
		var snake_info = player_snakes[peer_id]
		for segment_pos in snake_info.data:
			if segment_pos == grid_pos:
				return false
	
	# Check if position is food
	if grid_pos == food_pos:
		return false
	
	return true

func place_tool(placer_id: int, grid_pos: Vector2, tool_type: String):
	# Consume one tool from the player
	var counts = player_tool_counts[placer_id]
	var tool_count_key = ""
	match tool_type:
		"bomb":
			tool_count_key = "bombs"
		"lightning":
			tool_count_key = "lightning"
		"ice":
			tool_count_key = "ice"
	counts[tool_count_key] -= 1
	
	if tool_type == "bomb":
		# Place bomb using existing system
		place_bomb_at_position(placer_id, grid_pos)
	else:
		# Place powerup (lightning or ice)
		place_powerup(placer_id, grid_pos, tool_type)
	
	print("🔧 Player ", placer_id, " placed ", tool_type, " at ", grid_pos, " (", counts[tool_count_key], " remaining)")
	
	# Update tool selector UI
	_update_tool_selector_ui()

func place_bomb_at_position(placer_id: int, grid_pos: Vector2):
	# Create bomb data
	var bomb_data = {
		"placer_id": placer_id,
		"position": grid_pos,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	# Add to bombs grid
	bombs_on_grid[grid_pos] = bomb_data
	
	# Create visual bomb (server-side, will sync to clients)
	create_bomb_visual(grid_pos)
	
	# Sync bomb state to all clients
	sync_bomb_state.rpc(bombs_on_grid, player_bomb_counts)

func place_powerup(placer_id: int, grid_pos: Vector2, powerup_type: String):
	# Create powerup data
	var powerup_data = {
		"placer_id": placer_id,
		"position": grid_pos,
		"type": powerup_type,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	# Add to powerups grid
	powerups_on_grid[grid_pos] = powerup_data
	
	# Create visual powerup (server-side, will sync to clients)
	create_powerup_visual(grid_pos, powerup_type)
	
	# Sync powerup state to all clients
	sync_powerup_state.rpc(powerups_on_grid, player_tool_counts)

func create_powerup_visual(grid_pos: Vector2, powerup_type: String):
	var powerup_instance = null
	
	match powerup_type:
		"lightning":
			if lightning_scene:
				powerup_instance = lightning_scene.instantiate()
			else:
				# Fallback visual
				powerup_instance = ColorRect.new()
				powerup_instance.size = Vector2(cell_size * 0.8, cell_size * 0.8)
				powerup_instance.color = Color.YELLOW
		"ice":
			if ice_scene:
				powerup_instance = ice_scene.instantiate()
			else:
				# Fallback visual
				powerup_instance = ColorRect.new()
				powerup_instance.size = Vector2(cell_size * 0.8, cell_size * 0.8)
				powerup_instance.color = Color.CYAN
	
	if powerup_instance:
		powerup_instance.position = (grid_pos * cell_size) + Vector2(0, cell_size)
		powerup_instance.add_to_group("powerups")
		add_child(powerup_instance)

@rpc("authority", "reliable")
func sync_powerup_state(powerups_grid: Dictionary, tool_counts: Dictionary):
	powerups_on_grid = powerups_grid
	player_tool_counts = tool_counts
	
	# Recreate powerup visuals on clients
	get_tree().call_group("powerups", "queue_free")
	for powerup_pos in powerups_on_grid:
		var powerup_data = powerups_on_grid[powerup_pos]
		create_powerup_visual(powerup_pos, powerup_data["type"])
	
	# Update HUD to show tool counts
	update_hud()

func explode_bomb(bomb_pos: Vector2, placer_id: int):
	print("💥 Bomb exploding at ", bomb_pos, " placed by player ", placer_id)
	
	# Remove the bomb from the grid
	bombs_on_grid.erase(bomb_pos)
	
	# Define 3x3 explosion area
	var explosion_cells = []
	for x in range(-1, 2):  # -1, 0, 1
		for y in range(-1, 2):  # -1, 0, 1
			var explosion_pos = bomb_pos + Vector2(x, y)
			# Keep explosion within bounds
			if explosion_pos.x >= 0 and explosion_pos.x < cells and explosion_pos.y >= 0 and explosion_pos.y < cells:
				explosion_cells.append(explosion_pos)
	
	print("💥 Explosion affects cells: ", explosion_cells)
	
	# Check which snakes are in the explosion
	var killed_players = []
	for peer_id in player_snakes:
		if not alive_players.get(peer_id, false):
			continue  # Skip already dead players
			
		var snake_info = player_snakes[peer_id]
		for segment_pos in snake_info.data:
			if segment_pos in explosion_cells:
				killed_players.append(peer_id)
				print("💥 Player ", peer_id, " caught in explosion at ", segment_pos)
				break  # Only need to kill them once
	
	# Kill affected players and award points to bomb placer
	var points_awarded = 0
	for killed_peer_id in killed_players:
		kill_player(killed_peer_id)
		points_awarded += 10  # +10 points per kill
	
	# Award points to the bomb placer
	if points_awarded > 0:
		player_scores[placer_id] = player_scores.get(placer_id, 0) + points_awarded
		print("🎯 Player ", placer_id, " awarded ", points_awarded, " points for bomb kills!")
	
	# Sync explosion effects to all clients
	sync_bomb_explosion.rpc(bomb_pos, explosion_cells, killed_players, placer_id, points_awarded)

@rpc("authority", "reliable")
func sync_bomb_explosion(bomb_pos: Vector2, explosion_cells: Array, killed_players: Array, placer_id: int, points_awarded: int):
	# Remove bomb visual
	get_tree().call_group("bombs", "queue_free")
	
	# Recreate remaining bomb visuals
	for remaining_bomb_pos in bombs_on_grid:
		create_bomb_visual(remaining_bomb_pos)
	
	# TODO: Add explosion visual effects here if desired
	
	# Update HUD to reflect score changes and deaths
	update_hud()
	
	print("💥 Explosion synced: ", killed_players.size(), " players killed, ", points_awarded, " points to player ", placer_id)

func get_peer_id_for_player(player_data: Dictionary) -> int:
	# Search for peer ID by matching player name and AI status
	if not has_node("/root/NetworkManager"):
		return -1
	
	var network_manager = get_node("/root/NetworkManager")
	
	# Check human players first
	if not player_data.is_ai:
		for peer_id in network_manager.players:
			if network_manager.players[peer_id]["name"] == player_data.name:
				return peer_id
	
	# Check AI players
	if player_data.is_ai:
		for peer_id in player_snakes:
			var snake_info = player_snakes[peer_id]
			if snake_info.get("is_ai", false) and snake_info.get("ai_name", "") == player_data.name:
				return peer_id
	
	return -1  # Not found

func create_bomb_visual(grid_pos: Vector2):
	if not bomb_scene:
		# Create a simple bomb visual if no scene is provided
		var bomb_visual = ColorRect.new()
		bomb_visual.size = Vector2(cell_size * 0.8, cell_size * 0.8)
		bomb_visual.color = Color.RED
		bomb_visual.position = (grid_pos * cell_size) + Vector2(cell_size * 0.1, cell_size * 1.1)
		bomb_visual.add_to_group("bombs")
		add_child(bomb_visual)
	else:
		# Use the bomb scene if provided
		var bomb_instance = bomb_scene.instantiate()
		bomb_instance.position = (grid_pos * cell_size) + Vector2(0, cell_size)
		bomb_instance.add_to_group("bombs")
		add_child(bomb_instance)

@rpc("authority", "reliable")
func sync_bomb_state(bombs_grid: Dictionary, bomb_counts: Dictionary):
	bombs_on_grid = bombs_grid
	player_bomb_counts = bomb_counts
	
	# Recreate bomb visuals on clients
	get_tree().call_group("bombs", "queue_free")
	for bomb_pos in bombs_on_grid:
		create_bomb_visual(bomb_pos)
	
	# Update HUD to show bomb counts
	update_hud()

func consume_powerup(peer_id: int, powerup_pos: Vector2, powerup_data: Dictionary):
	var powerup_type = powerup_data["type"]
	var placer_id = powerup_data["placer_id"]
	
	# Remove powerup from grid
	powerups_on_grid.erase(powerup_pos)
	
	# Immediately remove visual on server
	get_tree().call_group("powerups", "queue_free")
	
	# Recreate remaining powerup visuals on server
	for remaining_powerup_pos in powerups_on_grid:
		var remaining_powerup_data = powerups_on_grid[remaining_powerup_pos]
		create_powerup_visual(remaining_powerup_pos, remaining_powerup_data["type"])
	
	# Apply powerup effect
	match powerup_type:
		"lightning":
			apply_speed_boost(peer_id)
			print("⚡ Player ", peer_id, " consumed lightning - speed boost!")
		"ice":
			apply_freeze_effect(peer_id)
			print("🧊 Player ", peer_id, " consumed ice - frozen!")
	
	# Award points to powerup placer
	player_scores[placer_id] = player_scores.get(placer_id, 0) + 5  # +5 points for powerup consumption
	print("🎯 Player ", placer_id, " awarded 5 points for ", powerup_type, " consumption")
	
	# Sync powerup removal to all clients
	sync_powerup_state.rpc(powerups_on_grid, player_tool_counts)

func apply_speed_boost(peer_id: int):
	# Give snake a speed boost for 10 seconds
	player_effects[peer_id]["speed_boost"] = 10.0
	print("🏃 Player ", peer_id, " is now moving faster!")

func apply_freeze_effect(peer_id: int):
	# Freeze snake for 15 seconds
	player_effects[peer_id]["frozen_time"] = 15.0
	print("🧊 Player ", peer_id, " is now frozen!")

func handle_player_effects(delta):
	# Handle speed boosts and freeze effects
	for peer_id in player_effects:
		var effects = player_effects[peer_id]
		
		# Handle speed boost countdown
		if effects["speed_boost"] > 0:
			effects["speed_boost"] -= delta
			if effects["speed_boost"] <= 0:
				effects["speed_boost"] = 0
				print("🏃 Player ", peer_id, " speed boost ended")
		
		# Handle freeze countdown
		if effects["frozen_time"] > 0:
			effects["frozen_time"] -= delta
			if effects["frozen_time"] <= 0:
				effects["frozen_time"] = 0
				print("🧊 Player ", peer_id, " is no longer frozen")

func _input(event):
	# Handle mouse clicks for tool placement (dead players only)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var peer_id = multiplayer.get_unique_id()
		
		# Only allow tool placement for dead players
		if alive_players.get(peer_id, true):  # Still alive
			return
		
		var mouse_pos = event.position
		var grid_pos = Vector2(
			int(mouse_pos.x / cell_size),
			int((mouse_pos.y - cell_size) / cell_size)  # Offset for UI
		)
		
		print("🖱️ Mouse clicked at: ", mouse_pos, " -> Grid pos: ", grid_pos)
		
		# Validate grid position
		if grid_pos.x >= 0 and grid_pos.x < cells and grid_pos.y >= 0 and grid_pos.y < cells:
			var selected_tool = current_tool_selection.get(peer_id, "bomb")
			var counts = player_tool_counts.get(peer_id, {"bombs": 0, "lightning": 0, "ice": 0})
			
			print("🔧 Attempting to place ", selected_tool, " at ", grid_pos)
			print("🔧 Available tools: ", counts)
			
			# Check if player has selected tool available
			match selected_tool:
				"bomb":
					if counts["bombs"] > 0:
						print("💣 Placing bomb...")
						if multiplayer.is_server():
							request_tool_placement(grid_pos, "bomb")
						else:
							request_tool_placement.rpc_id(1, grid_pos, "bomb")
					else:
						print("⚠️ No bombs available!")
				"lightning":
					if counts["lightning"] > 0:
						print("⚡ Placing lightning...")
						if multiplayer.is_server():
							request_tool_placement(grid_pos, "lightning")
						else:
							request_tool_placement.rpc_id(1, grid_pos, "lightning")
					else:
						print("⚠️ No lightning available!")
				"ice":
					if counts["ice"] > 0:
						print("🧊 Placing ice...")
						if multiplayer.is_server():
							request_tool_placement(grid_pos, "ice")
						else:
							request_tool_placement.rpc_id(1, grid_pos, "ice")
					else:
						print("⚠️ No ice available!")
		else:
			print("⚠️ Click outside grid bounds: ", grid_pos)
