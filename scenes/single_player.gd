extends Node

@export var snake_scene : PackedScene
@export var snake_head_scene : PackedScene
@export var snake_tail_scene : PackedScene

#game variables
var score : int = 0
var game_started : bool = false
var player_alive : bool = true

#grid variables
var cells : int = 20
var cell_size : int = 50

#food variables
var food_pos : Vector2
var regen_food : bool = true

#snake variables
var old_data : Array
var snake_data : Array
var snake : Array
var move_direction : Vector2
var can_move: bool = true

# Color variables
var selected_color = "green"
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

#movement vectors
var start_pos = Vector2(10, 10)
var up = Vector2(0, -1)
var down = Vector2(0, 1)
var left = Vector2(-1, 0)
var right = Vector2(1, 0)

func _ready():
	print("Single player game starting...")
	
	# Get selected color from lobby
	if get_tree().has_meta("game_data"):
		var game_data = get_tree().get_meta("game_data")
		if "selected_snake_color" in game_data:
			selected_color = game_data["selected_snake_color"]
	
	print("Using snake color: ", selected_color)
	new_game()
	
func new_game():
	get_tree().paused = false
	get_tree().call_group("segments", "queue_free")
	$GameOverMenu.hide()
	
	score = 0
	player_alive = true
	game_started = false
	
	update_hud()
	
	move_direction = up
	can_move = true
	
	generate_snake()
	move_food()
	
	# Start the game automatically after a short delay
	await get_tree().create_timer(0.5).timeout
	start_game()

func update_hud():
	var status = "ALIVE" if player_alive else "DEAD"
	$Hud.get_node("ScorePanel/ScoreLabel").text = "Score: " + str(score) + " (" + status + ")"
	
func generate_snake():
	# Clear snake data
	old_data.clear()
	snake_data.clear()
	snake.clear()
	
	# Generate snake with head, body, and tail
	for i in range(3):
		var pos = start_pos + Vector2(0, i)
		if i == 0:
			add_segment(pos, true, false)  # Head
		elif i == 2:
			add_segment(pos, false, true)  # Tail
		else:
			add_segment(pos, false, false)  # Body
	
	print("Snake generated with ", snake_data.size(), " segments at positions: ", snake_data)
		
func add_segment(pos, is_head: bool = false, is_tail: bool = false):
	snake_data.append(pos)
	var SnakeSegment
	
	if is_head:
		SnakeSegment = snake_head_scene.instantiate()
		# Apply head colors
		apply_head_color(SnakeSegment)
	elif is_tail:
		SnakeSegment = snake_tail_scene.instantiate()
		# Set pivot point to center for proper rotation
		SnakeSegment.pivot_offset = Vector2(25, 25)
		# Apply body colors to tail
		apply_body_color(SnakeSegment)
	else:
		SnakeSegment = snake_scene.instantiate()
		# Apply body colors
		apply_body_color(SnakeSegment)
	
	SnakeSegment.position = (pos * cell_size) + Vector2(0, cell_size)
	
	# Rotate tail to point away from body
	if is_tail and snake_data.size() >= 2:
		var tail_direction = get_tail_direction()
		SnakeSegment.rotation = get_rotation_for_direction(tail_direction)
	
	add_child(SnakeSegment)
	snake.append(SnakeSegment)
	print("Added segment at grid pos: ", pos, " screen pos: ", SnakeSegment.position)

func apply_body_color(segment):
	var colors = color_values[selected_color]
	var panel_style = segment.get_theme_stylebox("panel").duplicate()
	panel_style.bg_color = colors["bg"]
	panel_style.border_color = colors["border"]
	segment.add_theme_stylebox_override("panel", panel_style)

func apply_head_color(segment):
	var colors = color_values[selected_color]
	var panel_style = segment.get_theme_stylebox("panel").duplicate()
	panel_style.bg_color = colors["head_bg"]
	panel_style.border_color = colors["head_border"]
	segment.add_theme_stylebox_override("panel", panel_style)

func get_tail_direction() -> Vector2:
	if snake_data.size() < 2:
		return down  # Default direction
	
	# Tail should point away from the second-to-last segment
	var tail_pos = snake_data[-1]
	var body_pos = snake_data[-2]
	return tail_pos - body_pos

func get_rotation_for_direction(direction: Vector2) -> float:
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

func _process(_delta):
	move_snake()
	
func move_snake():
	# Player controls (WASD - only if alive)
	if can_move and player_alive:
		if Input.is_action_just_pressed("move_down") and move_direction != up:
			move_direction = down
			can_move = false
			if not game_started:
				start_game()
		if Input.is_action_just_pressed("move_up") and move_direction != down:
			move_direction = up
			can_move = false
			if not game_started:
				start_game()
		if Input.is_action_just_pressed("move_left") and move_direction != right:
			move_direction = left
			can_move = false
			if not game_started:
				start_game()
		if Input.is_action_just_pressed("move_right") and move_direction != left:
			move_direction = right
			can_move = false
			if not game_started:
				start_game()

func start_game():
	game_started = true
	$MoveTimer.start()
	print("Game started! Timer running.")

func _on_move_timer_timeout():
	print("Timer timeout - moving snake")
	if player_alive:
		can_move = true
	
	# Move snake (only if alive)
	if player_alive:
		old_data = [] + snake_data
		snake_data[0] += move_direction
		for i in range(len(snake_data)):
			if i > 0:
				snake_data[i] = old_data[i - 1]
			snake[i].position = (snake_data[i] * cell_size) + Vector2(0, cell_size)
			
			# Update tail rotation
			if i == snake_data.size() - 1 and snake_data.size() >= 2:
				# Ensure pivot point is set
				snake[i].pivot_offset = Vector2(25, 25)
				var tail_direction = snake_data[i] - snake_data[i-1]
				snake[i].rotation = get_rotation_for_direction(tail_direction)
		
		print("Snake head moved to: ", snake_data[0])
	
	check_collisions()
	check_food_eaten()

func check_collisions():
	# Only check collisions for alive player
	if player_alive:
		# Check bounds
		if snake_data[0].x < 0 or snake_data[0].x > cells - 1 or snake_data[0].y < 0 or snake_data[0].y > cells - 1:
			player_alive = false
		
		# Check self collision
		for i in range(1, len(snake_data)):
			if snake_data[0] == snake_data[i]:
				player_alive = false
				break
	
	# Update HUD and check game over
	update_hud()
	
	if not player_alive:
		game_over()

func check_food_eaten():
	if player_alive and snake_data[0] == food_pos:
		score += 1
		add_segment(old_data[-1], false, false)  # Add body segment
		update_snake_visuals()  # Update head/tail visuals
		move_food()
		update_hud()

func update_snake_visuals():
	# Update the visual appearance of head and tail
	for i in range(snake.size()):
		var current_segment = snake[i]
		current_segment.queue_free()
		
		var new_segment
		if i == 0:
			new_segment = snake_head_scene.instantiate()  # Head
			apply_head_color(new_segment)
		elif i == snake.size() - 1:
			new_segment = snake_tail_scene.instantiate()  # Tail
			# Set pivot point to center for proper rotation
			new_segment.pivot_offset = Vector2(25, 25)
			apply_body_color(new_segment)
			# Rotate tail to point away from body
			if snake_data.size() >= 2:
				var tail_direction = snake_data[i] - snake_data[i-1]
				new_segment.rotation = get_rotation_for_direction(tail_direction)
		else:
			new_segment = snake_scene.instantiate()  # Body
			apply_body_color(new_segment)
			
		new_segment.position = (snake_data[i] * cell_size) + Vector2(0, cell_size)
		add_child(new_segment)
		snake[i] = new_segment

func move_food():
	while regen_food:
		regen_food = false
		food_pos = Vector2(randi_range(0, cells - 1), randi_range(0, cells - 1))
		
		# Make sure food doesn't spawn on snake
		if player_alive:
			for i in snake_data:
				if food_pos == i:
					regen_food = true
					break
	
	$Food.position = (food_pos * cell_size) + Vector2(0, cell_size)
	print("Food placed at grid position: ", food_pos, " screen position: ", $Food.position)
	regen_food = true

func game_over():
	$MoveTimer.stop()
	get_tree().paused = true
	$GameOverMenu.show()

func _on_game_over_menu_restart():
	new_game() 
