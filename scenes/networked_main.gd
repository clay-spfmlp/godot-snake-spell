extends Node

@export var snake_scene : PackedScene
@export var snake_head_scene : PackedScene
@export var snake_tail_scene : PackedScene

#game variables
var game_started : bool = false
var move_count : int = 0  # Track number of moves to prevent immediate game over

# AI variables
var ai_enabled : bool = false
var ai_timer : float = 0.0
var ai_direction_timer : float = 0.0
var ai_directions = [up, right, down, left]  # Clockwise circle
var ai_current_direction_index : int = 0
var ai_steps_in_direction : int = 0
var ai_steps_per_side : int = 3  # 3x3 circle pattern

#grid variables
var cells : int = 20  # Same as single player for proper window fit
var cell_size : int = 50  # Same as single player for consistent look

#food variables
var food_pos : Vector2
var regen_food : bool = true

# Network player data - keyed by peer_id
var player_scores = {}
var player_snakes = {}  # Contains snake data, segments, direction, etc.
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
	
	# Set difficulty-based speed
	var difficulty = settings.get("difficulty", "medium")
	var speed_settings = {
		"easy": 0.15,    # Slow
		"medium": 0.1,   # Normal
		"hard": 0.06     # Fast
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
		
		# Get color name for this player
		var color_name = get_color_name_for_index(color_index)
		
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
			"ai_current_direction_index": 0
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
		0: return Vector2(5, 5)      # Top-left area
		1: return Vector2(15, 5)     # Top-right area
		2: return Vector2(5, 15)     # Bottom-left area
		3: return Vector2(15, 15)    # Bottom-right area
		4: return Vector2(10, 3)     # Top-center
		5: return Vector2(3, 10)     # Left-center
		6: return Vector2(17, 10)    # Right-center
		7: return Vector2(10, 17)    # Bottom-center
		_: return Vector2(10, 10)    # Center fallback

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
			add_segment_for_player(peer_id, pos, true, false)  # Head
		elif i == 2:
			add_segment_for_player(peer_id, pos, false, true)  # Tail
		else:
			add_segment_for_player(peer_id, pos, false, false)  # Body
	
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
		return down  # Default direction
	
	# Use the exact same calculation as single player
	var tail_pos = snake_info.data[-1]
	var body_pos = snake_info.data[-2]
	return tail_pos - body_pos

func get_rotation_for_direction(direction: Vector2) -> float:
	# Using the exact same rotation values as single player (which works correctly)
	if direction == up:
		return 0  # Point up (pointed end up)
	elif direction == down:
		return PI  # Point down (pointed end down)
	elif direction == left:
		return -PI/2  # Point left
	elif direction == right:
		return PI/2  # Point right
	else:
		return 0  # Default

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
			add_segment_for_player(peer_id, pos, true, false)  # Head
		elif i == snake_info.data.size() - 1:
			add_segment_for_player(peer_id, pos, false, true)  # Tail
		else:
			add_segment_for_player(peer_id, pos, false, false)  # Body

func _process(delta):
	if ai_enabled:
		handle_ai_input(delta)
	else:
		handle_input()
	
	# Handle AI players created from lobby (server-side only)
	if multiplayer.is_server():
		handle_lobby_ai_players(delta)

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
	if sender_id == 0:  # Called locally
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
		sync_game_state.rpc_id(sender_id, player_scores, player_snakes, alive_players, food_pos, game_started)

@rpc("authority", "reliable")
func sync_game_state(scores, snakes, alive, food_position, started):
	player_scores = scores
	player_snakes = snakes
	alive_players = alive
	food_pos = food_position
	game_started = started
	
	# Recreate visual elements for clients
	get_tree().call_group("segments", "queue_free")
	for peer_id in player_snakes:
		var snake_info = player_snakes[peer_id]
		snake_info.segments.clear()
		# Recreate segments with proper types
		for i in range(snake_info.data.size()):
			var pos = snake_info.data[i]
			if i == 0:
				add_segment_for_player(peer_id, pos, true, false)  # Head
			elif i == snake_info.data.size() - 1:
				add_segment_for_player(peer_id, pos, false, true)  # Tail
			else:
				add_segment_for_player(peer_id, pos, false, false)  # Body
	
	update_hud()
	$Food.position = (food_pos * cell_size) + Vector2(0, cell_size)

func _on_move_timer_timeout():
	if not multiplayer.is_server():
		return
	
	move_count += 1
	print("🎮 Move #", move_count)
	
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
	sync_game_state.rpc(player_scores, player_snakes, alive_players, food_pos, game_started)

func move_snake_for_player(peer_id: int):
	var snake_info = player_snakes[peer_id]
	
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
		
		# Check bounds
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
	
	# Make snake semi-transparent
	var snake_info = player_snakes[peer_id]
	for segment in snake_info.segments:
		segment.modulate.a = 0.3

func check_food_eaten():
	for peer_id in player_snakes:
		if not alive_players.get(peer_id, false):
			continue
			
		var snake_info = player_snakes[peer_id]
		if snake_info.data[0] == food_pos:
			player_scores[peer_id] += 1
			# Add the tail position to the snake data so it grows
			snake_info.data.append(snake_info.old_data[-1])
			add_segment_for_player(peer_id, snake_info.old_data[-1], false, false)  # Add body segment
			update_snake_visuals_for_player(peer_id)  # Update head/tail visuals
			move_food()
			update_hud()
			print("🍎 Player ", peer_id, " ate food! Snake length now: ", snake_info.data.size())
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
	var hud_text = ""
	var player_list = network_manager.get_player_list()
	
	# Add human players
	for i in range(player_list.size()):
		var peer_id = player_list[i]
		var player_name = network_manager.players[peer_id]["name"]
		var score = player_scores.get(peer_id, 0)
		var status = "ALIVE" if alive_players.get(peer_id, false) else "DEAD"
		
		if i > 0:
			hud_text += " | "
		hud_text += player_name + ": " + str(score) + " (" + status + ")"
	
	# Add AI players
	for peer_id in player_snakes:
		var snake_info = player_snakes[peer_id]
		if snake_info.get("is_ai", false):
			var ai_name = snake_info.get("ai_name", "AIBot")
			var score = player_scores.get(peer_id, 0)
			var status = "ALIVE" if alive_players.get(peer_id, false) else "DEAD"
			
			if hud_text != "":
				hud_text += " | "
			hud_text += ai_name + ": " + str(score) + " (" + status + ")"
	
	$Hud/ScorePanel/ScoreLabel.text = hud_text

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
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func handle_lobby_ai_players(delta):
	# Handle AI logic for lobby-created AI players (server-side only)
	if not game_started:
		return  # Don't move AI until game starts
		
	for peer_id in player_snakes:
		var snake_info = player_snakes[peer_id]
		if not snake_info.get("is_ai", false):
			continue  # Skip non-AI players
		
		if not alive_players.get(peer_id, false):
			continue  # Skip dead AI players
		
		# Smart AI logic with wall avoidance and food seeking
		snake_info.ai_direction_timer += delta
		
		# Make decisions every 0.3 seconds for more responsive AI
		if snake_info.can_move and snake_info.ai_direction_timer >= 0.3:
			snake_info.ai_direction_timer = 0.0
			
			var current_head = snake_info.data[0]
			var current_direction = snake_info.direction
			var best_direction = choose_smart_direction(peer_id, current_head, current_direction)
			
			# Only change direction if it's different and safe
			if best_direction != current_direction and best_direction != -current_direction:
				snake_info.direction = best_direction
				snake_info.can_move = false
				
				print("🤖 AI (", snake_info.get("ai_name", "AIBot"), ") smartly chose direction: ", best_direction)

func choose_smart_direction(peer_id: int, head_pos: Vector2, current_direction: Vector2) -> Vector2:
	var snake_info = player_snakes[peer_id]
	var possible_directions = [up, down, left, right]
	var direction_scores = {}
	
	# Score each possible direction
	for direction in possible_directions:
		# Can't reverse into self
		if direction == -current_direction:
			continue
			
		var next_pos = head_pos + direction
		var score = 0
		
		# Check if this direction is safe (no immediate collision)
		if is_position_safe(peer_id, next_pos):
			score += 100  # Base safety score
			
			# Bonus for staying away from walls
			var wall_distance = get_wall_distance(next_pos, direction)
			score += wall_distance * 10
			
			# Bonus for moving toward food (if it's safe)
			var food_direction = get_food_direction(next_pos)
			if food_direction == direction:
				var food_distance = get_food_distance(next_pos)
				var food_safety = is_food_path_safe(peer_id, next_pos, direction)
				
				if food_safety and food_distance <= 5:  # Only pursue nearby food if path is safe
					score += 50 - (food_distance * 5)  # Closer food = higher bonus
				elif food_safety:
					score += 20  # Small bonus for distant food if safe
			
			# Penalty for getting too close to other snakes
			var snake_danger = get_snake_danger_score(peer_id, next_pos)
			score -= snake_danger
			
			# Look ahead 2-3 steps to avoid traps
			var future_safety = check_future_safety(peer_id, next_pos, direction, 3)
			score += future_safety
			
		else:
			score = -1000  # Immediate danger, avoid at all costs
		
		direction_scores[direction] = score
	
	# Choose the direction with the highest score
	var best_direction = current_direction  # Default to current direction
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

func is_position_safe(peer_id: int, pos: Vector2) -> bool:
	# Check bounds
	if pos.x < 0 or pos.x >= cells or pos.y < 0 or pos.y >= cells:
		return false
	
	# Check collision with own body
	var snake_info = player_snakes[peer_id]
	for body_pos in snake_info.data:
		if pos == body_pos:
			return false
	
	# Check collision with other snakes
	for other_peer_id in player_snakes:
		if other_peer_id == peer_id or not alive_players.get(other_peer_id, false):
			continue
		
		var other_snake = player_snakes[other_peer_id]
		for other_pos in other_snake.data:
			if pos == other_pos:
				return false
	
	return true

func get_wall_distance(pos: Vector2, direction: Vector2) -> int:
	var distance = 0
	var check_pos = pos
	
	# Count how many steps until hitting a wall in this direction
	while check_pos.x >= 0 and check_pos.x < cells and check_pos.y >= 0 and check_pos.y < cells:
		distance += 1
		check_pos += direction
		if distance > 5:  # Don't look too far ahead
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
	var steps_to_check = min(3, get_food_distance(pos))
	var check_pos = pos
	
	for i in range(steps_to_check):
		check_pos += direction
		if not is_position_safe(peer_id, check_pos):
			return false
	
	return true

func get_snake_danger_score(peer_id: int, pos: Vector2) -> int:
	var danger = 0
	
	# Check proximity to other snakes
	for other_peer_id in player_snakes:
		if other_peer_id == peer_id or not alive_players.get(other_peer_id, false):
			continue
		
		var other_snake = player_snakes[other_peer_id]
		for other_pos in other_snake.data:
			var distance = abs(pos.x - other_pos.x) + abs(pos.y - other_pos.y)  # Manhattan distance
			if distance <= 2:
				danger += (3 - distance) * 20  # Higher penalty for closer snakes
	
	return danger

func check_future_safety(peer_id: int, start_pos: Vector2, direction: Vector2, steps: int) -> int:
	var safety_score = 0
	var current_pos = start_pos
	
	# Simulate moving in this direction for several steps
	for i in range(steps):
		current_pos += direction
		
		if is_position_safe(peer_id, current_pos):
			safety_score += 10  # Each safe step ahead is good
			
			# Extra bonus for having multiple escape routes
			var escape_routes = count_escape_routes(peer_id, current_pos)
			safety_score += escape_routes * 5
		else:
			safety_score -= 30  # Future collision is bad
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
