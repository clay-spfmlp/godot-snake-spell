extends Node

@export var snake_scene : PackedScene

#game variables
var score_p1 : int = 0
var score_p2 : int = 0
var game_started : bool = false
var wall_wrapping_enabled : bool = false

# Player status
var p1_alive : bool = true
var p2_alive : bool = true

#grid variables
var cells : int = 20
var cell_size : int = 50

#food variables
var food_pos : Vector2
var regen_food : bool = true

#player 1 snake variables
var old_data_p1 : Array
var snake_data_p1 : Array
var snake_p1 : Array
var move_direction_p1 : Vector2
var can_move_p1: bool = true

#player 2 snake variables  
var old_data_p2 : Array
var snake_data_p2 : Array
var snake_p2 : Array
var move_direction_p2 : Vector2
var can_move_p2: bool = true

#movement vectors
var start_pos_p1 = Vector2(5, 9)
var start_pos_p2 = Vector2(15, 9)
var up = Vector2(0, -1)
var down = Vector2(0, 1)
var left = Vector2(-1, 0)
var right = Vector2(1, 0)

func _ready():
	new_game()
	
func new_game():
	get_tree().paused = false
	get_tree().call_group("segments", "queue_free")
	$GameOverMenu.hide()
	
	score_p1 = 0
	score_p2 = 0
	p1_alive = true
	p2_alive = true
	
	update_hud()
	
	move_direction_p1 = up
	move_direction_p2 = up
	can_move_p1 = true
	can_move_p2 = true
	
	generate_snakes()
	move_food()

func update_hud():
	var status_p1 = "ALIVE" if p1_alive else "DEAD"
	var status_p2 = "ALIVE" if p2_alive else "DEAD"
	$Hud.get_node("ScoreLabel").text = "P1: " + str(score_p1) + " (" + status_p1 + ") | P2: " + str(score_p2) + " (" + status_p2 + ")"
	
func generate_snakes():
	# Clear player 1 data
	old_data_p1.clear()
	snake_data_p1.clear()
	snake_p1.clear()
	
	# Clear player 2 data
	old_data_p2.clear()
	snake_data_p2.clear()
	snake_p2.clear()
	
	# Generate player 1 snake (green)
	for i in range(3):
		add_segment_p1(start_pos_p1 + Vector2(0, i))
		
	# Generate player 2 snake (blue)
	for i in range(3):
		add_segment_p2(start_pos_p2 + Vector2(0, i))
		
func add_segment_p1(pos):
	snake_data_p1.append(pos)
	var SnakeSegment = snake_scene.instantiate()
	SnakeSegment.position = (pos * cell_size) + Vector2(0, cell_size)
	add_child(SnakeSegment)
	snake_p1.append(SnakeSegment)
	
func add_segment_p2(pos):
	snake_data_p2.append(pos)
	var SnakeSegment = snake_scene.instantiate()
	SnakeSegment.position = (pos * cell_size) + Vector2(0, cell_size)
	# Change color for player 2 (blue)
	var panel_style = SnakeSegment.get_theme_stylebox("panel").duplicate()
	panel_style.bg_color = Color.BLUE
	panel_style.border_color = Color.DARK_BLUE
	SnakeSegment.add_theme_stylebox_override("panel", panel_style)
	add_child(SnakeSegment)
	snake_p2.append(SnakeSegment)

func _process(delta):
	move_snakes()
	
func move_snakes():
	# Player 1 controls (WASD - only if alive)
	if can_move_p1 and p1_alive:
		if Input.is_action_just_pressed("move_down") and move_direction_p1 != up:
			move_direction_p1 = down
			can_move_p1 = false
			if not game_started:
				start_game()
		if Input.is_action_just_pressed("move_up") and move_direction_p1 != down:
			move_direction_p1 = up
			can_move_p1 = false
			if not game_started:
				start_game()
		if Input.is_action_just_pressed("move_left") and move_direction_p1 != right:
			move_direction_p1 = left
			can_move_p1 = false
			if not game_started:
				start_game()
		if Input.is_action_just_pressed("move_right") and move_direction_p1 != left:
			move_direction_p1 = right
			can_move_p1 = false
			if not game_started:
				start_game()
	
	# Player 2 controls (Arrow Keys - only if alive)
	if can_move_p2 and p2_alive:
		if Input.is_key_pressed(KEY_DOWN) and move_direction_p2 != up:
			move_direction_p2 = down
			can_move_p2 = false
			if not game_started:
				start_game()
		if Input.is_key_pressed(KEY_UP) and move_direction_p2 != down:
			move_direction_p2 = up
			can_move_p2 = false
			if not game_started:
				start_game()
		if Input.is_key_pressed(KEY_LEFT) and move_direction_p2 != right:
			move_direction_p2 = left
			can_move_p2 = false
			if not game_started:
				start_game()
		if Input.is_key_pressed(KEY_RIGHT) and move_direction_p2 != left:
			move_direction_p2 = right
			can_move_p2 = false
			if not game_started:
				start_game()

func start_game():
	game_started = true
	$MoveTimer.start()

func _on_move_timer_timeout():
	if p1_alive:
		can_move_p1 = true
	if p2_alive:
		can_move_p2 = true
	
	# Move player 1 snake (only if alive)
	if p1_alive:
		old_data_p1 = [] + snake_data_p1
		snake_data_p1[0] += move_direction_p1
		for i in range(len(snake_data_p1)):
			if i > 0:
				snake_data_p1[i] = old_data_p1[i - 1]
			snake_p1[i].position = (snake_data_p1[i] * cell_size) + Vector2(0, cell_size)
	
	# Move player 2 snake (only if alive)
	if p2_alive:
		old_data_p2 = [] + snake_data_p2
		snake_data_p2[0] += move_direction_p2
		for i in range(len(snake_data_p2)):
			if i > 0:
				snake_data_p2[i] = old_data_p2[i - 1]
			snake_p2[i].position = (snake_data_p2[i] * cell_size) + Vector2(0, cell_size)
	
	check_collisions()
	check_food_eaten()
	
func check_collisions():
	var p1_just_died = false
	var p2_just_died = false
	
	# Only check collisions for alive players
	if p1_alive:
		# Handle wall collision for player 1 based on wrapping setting
		if wall_wrapping_enabled:
			# Wrap around edges for player 1
			if snake_data_p1[0].x < 0:
				snake_data_p1[0].x = cells - 1
			elif snake_data_p1[0].x > cells - 1:
				snake_data_p1[0].x = 0
			if snake_data_p1[0].y < 0:
				snake_data_p1[0].y = cells - 1
			elif snake_data_p1[0].y > cells - 1:
				snake_data_p1[0].y = 0
			
			# Update visual position after wrapping
			snake_p1[0].position = (snake_data_p1[0] * cell_size) + Vector2(0, cell_size)
		else:
			# Check bounds for player 1 - die if hit wall
			if snake_data_p1[0].x < 0 or snake_data_p1[0].x > cells - 1 or snake_data_p1[0].y < 0 or snake_data_p1[0].y > cells - 1:
				p1_just_died = true
		
		# Check self collision for player 1
		for i in range(1, len(snake_data_p1)):
			if snake_data_p1[0] == snake_data_p1[i]:
				p1_just_died = true
	
	if p2_alive:
		# Handle wall collision for player 2 based on wrapping setting
		if wall_wrapping_enabled:
			# Wrap around edges for player 2
			if snake_data_p2[0].x < 0:
				snake_data_p2[0].x = cells - 1
			elif snake_data_p2[0].x > cells - 1:
				snake_data_p2[0].x = 0
			if snake_data_p2[0].y < 0:
				snake_data_p2[0].y = cells - 1
			elif snake_data_p2[0].y > cells - 1:
				snake_data_p2[0].y = 0
			
			# Update visual position after wrapping
			snake_p2[0].position = (snake_data_p2[0] * cell_size) + Vector2(0, cell_size)
		else:
			# Check bounds for player 2 - die if hit wall
			if snake_data_p2[0].x < 0 or snake_data_p2[0].x > cells - 1 or snake_data_p2[0].y < 0 or snake_data_p2[0].y > cells - 1:
				p2_just_died = true
		
		# Check self collision for player 2
		for i in range(1, len(snake_data_p2)):
			if snake_data_p2[0] == snake_data_p2[i]:
				p2_just_died = true
	
	# Check collision between players (only if both are alive)
	if p1_alive and p2_alive:
		if snake_data_p1[0] == snake_data_p2[0]:
			# Head-to-head collision - both die
			p1_just_died = true
			p2_just_died = true
		else:
			# Check P1 head vs P2 body
			for pos in snake_data_p2:
				if snake_data_p1[0] == pos:
					p1_just_died = true
			# Check P2 head vs P1 body
			for pos in snake_data_p1:
				if snake_data_p2[0] == pos:
					p2_just_died = true
	
	# Kill players and hide their snakes
	if p1_just_died:
		p1_alive = false
		hide_snake(snake_p1)
	if p2_just_died:
		p2_alive = false
		hide_snake(snake_p2)
	
	# Update HUD if anyone died
	if p1_just_died or p2_just_died:
		update_hud()
	
	# End game only if both players are dead
	if not p1_alive and not p2_alive:
		end_game()

func hide_snake(snake_segments):
	for segment in snake_segments:
		segment.modulate.a = 0.3  # Make snake semi-transparent when dead
		
func check_food_eaten():
	var food_eaten = false
	
	# Check if player 1 eats food (only if alive)
	if p1_alive and snake_data_p1[0] == food_pos:
		score_p1 += 1
		add_segment_p1(old_data_p1[-1])
		food_eaten = true
	
	# Check if player 2 eats food (only if alive)
	if p2_alive and snake_data_p2[0] == food_pos:
		score_p2 += 1
		add_segment_p2(old_data_p2[-1])
		food_eaten = true
	
	if food_eaten:
		update_hud()
		move_food()
	
func move_food():
	while regen_food:
		regen_food = false
		food_pos = Vector2(randi_range(0, cells - 1), randi_range(0, cells - 1))
		# Check against alive snakes only
		if p1_alive:
			for i in snake_data_p1:
				if food_pos == i:
					regen_food = true
		if p2_alive:
			for i in snake_data_p2:
				if food_pos == i:
					regen_food = true
	$Food.position = (food_pos * cell_size)+ Vector2(0, cell_size)
	regen_food = true

func end_game():
	$MoveTimer.stop()
	game_started = false
	get_tree().paused = true
	
	# Determine winner
	var winner_message = ""
	if score_p1 > score_p2:
		winner_message = "Player 1 Wins! Final Score: P1: " + str(score_p1) + " - P2: " + str(score_p2)
	elif score_p2 > score_p1:
		winner_message = "Player 2 Wins! Final Score: P1: " + str(score_p1) + " - P2: " + str(score_p2)
	else:
		winner_message = "It's a tie! Final Score: P1: " + str(score_p1) + " - P2: " + str(score_p2)
	
	print(winner_message)  # For now, print to console
	$GameOverMenu.show()

func _on_game_over_menu_restart():
	new_game()
