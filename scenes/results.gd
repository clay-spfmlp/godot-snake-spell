extends Control

signal back_to_lobby_requested

@onready var winner_label = $ResultsContainer/WinnerPanel/WinnerContainer/WinnerLabel
@onready var winner_score = $ResultsContainer/WinnerPanel/WinnerContainer/WinnerScore
@onready var score_list = $ResultsContainer/ScoreboardPanel/ScoreboardContainer/ScoreList
@onready var back_to_lobby_button = $ResultsContainer/ButtonContainer/BackToLobbyButton
@onready var main_menu_button = $ResultsContainer/ButtonContainer/MainMenuButton

var is_host = false

func _ready():
	# Check if we're the host to show the back to lobby button
	if multiplayer.is_server():
		is_host = true
		back_to_lobby_button.visible = true
		main_menu_button.text = "🚪 Leave Game"
	else:
		back_to_lobby_button.visible = false
		main_menu_button.text = "🏠 Main Menu"

func display_results(final_scores: Dictionary, winner_info: Dictionary):
	print("🏆 Displaying game results...")
	
	# Display winner
	if winner_info.has("name") and winner_info.has("score"):
		winner_label.text = "🥇 Winner: " + winner_info["name"]
		winner_score.text = "Final Score: " + str(winner_info["score"])
	else:
		winner_label.text = "🏁 Game Complete"
		winner_score.text = "No winner determined"
	
	# Sort players by score (highest first)
	var sorted_players = []
	for peer_id in final_scores:
		var player_name = get_player_name(peer_id)
		sorted_players.append({
			"name": player_name,
			"score": final_scores[peer_id],
			"peer_id": peer_id
		})
	
	# Sort by score descending
	sorted_players.sort_custom(func(a, b): return a.score > b.score)
	
	# Display scoreboard
	score_list.clear()
	for i in range(sorted_players.size()):
		var player = sorted_players[i]
		var position = i + 1
		var medal = ""
		
		match position:
			1: medal = "🥇"
			2: medal = "🥈" 
			3: medal = "🥉"
			_: medal = str(position) + "."
		
		var score_text = medal + " " + player.name + " - " + str(player.score) + " points"
		score_list.add_item(score_text)

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
	
	# Fallback
	return "Player " + str(peer_id)

func _on_back_to_lobby_button_pressed():
	if is_host:
		# Host sends everyone back to lobby via signal
		back_to_lobby_requested.emit()
	
func _on_main_menu_button_pressed():
	# Disconnect from multiplayer and go to main menu
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").remove_multiplayer_peer()
	
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")

 
