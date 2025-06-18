extends Node

# Room Manager Singleton for Jackbox-style multiplayer rooms
# Handles room creation, discovery, joining, and persistence

signal room_created(room_code: String)
signal room_joined(room_code: String)
signal room_left(room_code: String)
signal room_list_updated(rooms: Array)
signal player_joined_room(player_name: String)
signal player_left_room(player_name: String)

# Room data structure
class Room:
	var code: String
	var name: String
	var host_name: String
	var host_id: int
	var is_public: bool
	var max_players: int
	var current_players: Array[String] = []
	var game_settings: Dictionary = {}
	var created_time: float
	var host_ip: String = ""
	
	func _init(room_code: String, room_name: String, host: String, host_peer_id: int, public: bool = true):
		code = room_code
		name = room_name
		host_name = host
		host_id = host_peer_id
		is_public = public
		max_players = 8  # Default, can be changed based on game mode
		current_players.append(host)
		created_time = Time.get_unix_time_from_system()
	
	func get_player_count() -> int:
		return current_players.size()
	
	func is_full() -> bool:
		return get_player_count() >= max_players
	
	func can_join() -> bool:
		return not is_full()
	
	func add_player(player_name: String) -> bool:
		if can_join() and not current_players.has(player_name):
			current_players.append(player_name)
			return true
		return false
	
	func remove_player(player_name: String) -> bool:
		if current_players.has(player_name):
			current_players.erase(player_name)
			return true
		return false
	
	func is_host(player_name: String) -> bool:
		return host_name == player_name
	
	func to_dict() -> Dictionary:
		return {
			"code": code,
			"name": name,
			"host_name": host_name,
			"host_id": host_id,
			"is_public": is_public,
			"max_players": max_players,
			"current_players": current_players,
			"player_count": get_player_count(),
			"game_settings": game_settings,
			"created_time": created_time,
			"host_ip": host_ip
		}

# Current room state
var current_room: Room = null
var discovered_rooms: Dictionary = {}  # room_code -> Room
var local_player_name: String = ""
var is_host: bool = false

# Room discovery settings
var discovery_enabled: bool = false
var discovery_timer: Timer
var room_broadcast_port: int = 7001
var room_discovery_port: int = 7002

# UDP networking
var broadcast_socket: UDPServer
var discovery_socket: UDPServer
var is_broadcasting: bool = false

func _ready():
	print("🏠 RoomManager initialized")
	setup_discovery_timer()
	setup_networking()

func setup_discovery_timer():
	discovery_timer = Timer.new()
	discovery_timer.wait_time = 4.0  # Auto-refresh every 4 seconds
	discovery_timer.timeout.connect(_on_discovery_timer_timeout)
	add_child(discovery_timer)

func setup_networking():
	# Initialize UDP sockets
	broadcast_socket = UDPServer.new()
	discovery_socket = UDPServer.new()
	
	# Start listening for room broadcasts
	var listen_result = discovery_socket.listen(room_discovery_port, "127.0.0.1")
	if listen_result == OK:
		print("🔍 Listening for room broadcasts on port ", room_discovery_port)
	else:
		print("❌ Failed to start discovery listener on port ", room_discovery_port)

func _process(_delta):
	# Process incoming room broadcasts
	if discovery_socket.is_listening():
		discovery_socket.poll()
		if discovery_socket.is_connection_available():
			var peer = discovery_socket.take_connection()
			var packet = peer.get_packet()
			if packet.size() > 0:
				# Use a placeholder IP since we can't get the actual remote address
				# In a real network setup, this would be handled differently
				process_room_broadcast(packet.get_string_from_utf8(), "127.0.0.1")

func process_room_broadcast(data: String, sender_ip: String):
	print("📡 Received broadcast from ", sender_ip, ": ", data)
	
	# Parse the data
	var json = JSON.new()
	var parse_result = json.parse(data)
	
	if parse_result != OK:
		print("❌ Failed to parse broadcast data")
		return
	
	var message_data = json.data
	var message_type = message_data.get("type", "room_info")
	
	match message_type:
		"room_info":
			handle_room_info_broadcast(message_data)
		"room_discovery_request":
			handle_room_discovery_request(message_data, sender_ip)
		"general_discovery_request":
			handle_general_discovery_request(message_data, sender_ip)
		"room_discovery_response":
			handle_room_discovery_response(message_data)
		_:
			# Assume it's room info if no type specified (backward compatibility)
			handle_room_info_broadcast(message_data)

func handle_room_info_broadcast(room_data: Dictionary):
	if room_data.has("code") and room_data.has("is_public") and room_data["is_public"]:
		# Create or update room in discovered list
		var room_code = room_data["code"]
		
		# Don't add our own room to the discovered list
		if current_room and current_room.code == room_code:
			return
		
		# Create a room object from the broadcast data
		var room = Room.new(
			room_data["code"],
			room_data["name"],
			room_data["host_name"],
			room_data["host_id"],
			room_data["is_public"]
		)
		room.max_players = room_data.get("max_players", 8)
		room.current_players = room_data.get("current_players", [])
		room.game_settings = room_data.get("game_settings", {})
		room.created_time = room_data.get("created_time", 0)
		
		discovered_rooms[room_code] = room
		print("🏠 Added/Updated room: ", room_code, " - ", room.name)
		
		# Emit updated room list
		room_list_updated.emit(get_public_rooms())

func handle_room_discovery_request(request_data: Dictionary, sender_ip: String):
	var requested_code = request_data.get("room_code", "")
	var requester = request_data.get("requester", "Unknown")
	
	print("🔍 Received discovery request for room: ", requested_code, " from ", requester)
	
	# Check if we have this room (either hosting it or know about it)
	if current_room and current_room.code == requested_code:
		# We're hosting this room, send response
		send_room_discovery_response(current_room, sender_ip)
	elif discovered_rooms.has(requested_code):
		# We know about this room, send response
		send_room_discovery_response(discovered_rooms[requested_code], sender_ip)

func handle_general_discovery_request(request_data: Dictionary, sender_ip: String):
	var requester = request_data.get("requester", "Unknown")
	print("🔍 Received general discovery request from ", requester)
	
	# If we're hosting a public room, respond with our room info
	if current_room and current_room.is_public:
		send_room_discovery_response(current_room, sender_ip)

func handle_room_discovery_response(response_data: Dictionary):
	print("📨 Received room discovery response")
	
	# Process the room info from the response
	if response_data.has("room_info"):
		handle_room_info_broadcast(response_data["room_info"])

func send_room_discovery_response(room: Room, target_ip: String):
	var response_data = {
		"type": "room_discovery_response",
		"room_info": room.to_dict(),
		"responder": local_player_name
	}
	
	var json_string = JSON.stringify(response_data)
	
	# Send directly to the requester
	var udp = PacketPeerUDP.new()
	udp.connect_to_host(target_ip, room_discovery_port)
	
	var packet = json_string.to_utf8_buffer()
	var result = udp.put_packet(packet)
	
	if result == OK:
		print("📨 Sent room discovery response to ", target_ip)
	else:
		print("❌ Failed to send discovery response: ", result)
	
	udp.close()

# Generate a 4-character alphanumeric room code
func generate_room_code() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code = ""
	for i in range(4):
		code += chars[randi() % chars.length()]
	
	# Ensure uniqueness (basic check)
	while discovered_rooms.has(code):
		code = ""
		for j in range(4):
			code += chars[randi() % chars.length()]
	
	return code

# Create a new room (host)
func create_room(room_name: String, player_name: String, is_public: bool = true, game_settings: Dictionary = {}) -> String:
	var room_code = generate_room_code()
	var host_id = multiplayer.get_unique_id()
	
	current_room = Room.new(room_code, room_name, player_name, host_id, is_public)
	current_room.game_settings = game_settings
	
	# Set max players based on game mode
	var game_mode = game_settings.get("mode", "classic")
	match game_mode:
		"classic":
			current_room.max_players = 8
		_:
			current_room.max_players = 4  # Default for other modes
	
	local_player_name = player_name
	is_host = true
	
	# Add to discovered rooms for local reference
	discovered_rooms[room_code] = current_room
	
	print("🏠 Created room: ", room_code, " - ", room_name, " (", "Public" if is_public else "Private", ")")
	
	# Start broadcasting if public
	if is_public:
		start_room_broadcasting()
	
	room_created.emit(room_code)
	return room_code

# Join an existing room
func join_room(room_code: String, player_name: String) -> bool:
	# First check if we have the room in our discovered list
	if discovered_rooms.has(room_code):
		var room = discovered_rooms[room_code]
		if room.can_join():
			if room.add_player(player_name):
				current_room = room
				local_player_name = player_name
				is_host = false
				
				print("🏠 Joined room: ", room_code, " - ", room.name)
				room_joined.emit(room_code)
				player_joined_room.emit(player_name)
				
				# Start networking for this room
				setup_room_networking(room)
				return true
	
	# If not found locally, try to discover it by sending a direct query
	print("🔍 Room ", room_code, " not found locally, sending discovery request...")
	send_room_discovery_request(room_code)
	
	# Wait a moment for response (this is a simplified approach)
	await get_tree().create_timer(1.0).timeout
	
	# Try again after discovery attempt
	if discovered_rooms.has(room_code):
		var room = discovered_rooms[room_code]
		if room.can_join():
			if room.add_player(player_name):
				current_room = room
				local_player_name = player_name
				is_host = false
				
				print("🏠 Joined room after discovery: ", room_code, " - ", room.name)
				room_joined.emit(room_code)
				player_joined_room.emit(player_name)
				
				setup_room_networking(room)
				return true
	
	return false

func send_room_discovery_request(room_code: String):
	var request_data = {
		"type": "room_discovery_request",
		"room_code": room_code,
		"requester": local_player_name
	}
	
	var json_string = JSON.stringify(request_data)
	broadcast_to_network(json_string)
	print("🔍 Sent discovery request for room: ", room_code)

func setup_room_networking(room: Room):
	# Set up networking for the joined room
	print("🌐 Setting up networking for room: ", room.code)
	
	# Store room info for the lobby
	get_tree().set_meta("room_info", room.to_dict())
	
	# Set up actual game networking through NetworkManager
	if NetworkManager:
		# Set player info in NetworkManager
		NetworkManager.player_info = {"name": local_player_name}
		
		if is_host:
			# Host creates the game server
			var result = NetworkManager.create_game()
			if result == OK:
				print("🌐 Host created game server for room: ", room.code)
			else:
				print("❌ Failed to create game server: ", result)
		else:
			# Client joins the host's server
			# We need to get the host's IP address from the room discovery
			var host_ip = room.host_ip if room.has("host_ip") else "127.0.0.1"
			var result = NetworkManager.join_game(host_ip)
			if result == OK:
				print("🌐 Client connecting to host at: ", host_ip)
			else:
				print("❌ Failed to connect to host: ", result)

# Add function to handle room-to-game transition
func start_room_game():
	if current_room and is_host:
		# Prepare game settings for NetworkManager
		var game_settings = current_room.game_settings.duplicate()
		
		# Add room-specific settings
		game_settings["room_code"] = current_room.code
		game_settings["room_name"] = current_room.name
		
		# Start the game through NetworkManager
		NetworkManager.start_game.rpc(game_settings)
		print("🎮 Starting game for room: ", current_room.code)

# Add function to get host IP for networking
func get_host_ip_for_room(_room: Room) -> String:
	# In a real implementation, this would come from the room discovery
	# For now, we'll use localhost for local network testing
	return "127.0.0.1"

# Update room with host networking info
func update_room_host_info(ip_address: String):
	if current_room and is_host:
		current_room.host_ip = ip_address
		print("🌐 Updated room host IP: ", ip_address)

# Leave current room
func leave_room():
	if current_room:
		var room_code = current_room.code
		current_room.remove_player(local_player_name)
		
		# Emit player left signal
		player_left_room.emit(local_player_name)
		
		# If we're the host, the room should be destroyed
		if is_host:
			destroy_room()
		else:
			current_room = null
			is_host = false
		
		print("🏠 Left room: ", room_code)
		room_left.emit(room_code)

# Destroy room (host only)
func destroy_room():
	if current_room and is_host:
		var room_code = current_room.code
		
		# Stop broadcasting
		stop_room_broadcasting()
		
		# Remove from discovered rooms
		discovered_rooms.erase(room_code)
		
		current_room = null
		is_host = false
		
		print("🏠 Destroyed room: ", room_code)

# Start discovering public rooms
func start_room_discovery():
	if not discovery_enabled:
		discovery_enabled = true
		discovery_timer.start()
		print("🔍 Started room discovery")

# Stop discovering rooms
func stop_room_discovery():
	if discovery_enabled:
		discovery_enabled = false
		discovery_timer.stop()
		print("🔍 Stopped room discovery")

# Get list of public rooms
func get_public_rooms() -> Array[Room]:
	var public_rooms: Array[Room] = []
	for room in discovered_rooms.values():
		if room.is_public:
			public_rooms.append(room)
	return public_rooms

# Room broadcasting (for public rooms)
func start_room_broadcasting():
	if current_room and current_room.is_public and not is_broadcasting:
		is_broadcasting = true
		print("📡 Started broadcasting room: ", current_room.code)
		
		# Start broadcasting timer
		var broadcast_timer = Timer.new()
		broadcast_timer.wait_time = 2.0  # Broadcast every 2 seconds
		broadcast_timer.timeout.connect(_broadcast_room_info)
		broadcast_timer.autostart = true
		add_child(broadcast_timer)

func stop_room_broadcasting():
	is_broadcasting = false
	print("📡 Stopped broadcasting room")
	
	# Remove broadcast timer
	for child in get_children():
		if child is Timer and child.timeout.is_connected(_broadcast_room_info):
			child.queue_free()

func _broadcast_room_info():
	if current_room and current_room.is_public and is_broadcasting:
		var room_data = current_room.to_dict()
		
		# Add message type for proper handling
		var broadcast_message = {
			"type": "room_info"
		}
		
		# Merge room data into the message
		for key in room_data:
			broadcast_message[key] = room_data[key]
		
		var json_string = JSON.stringify(broadcast_message)
		
		# Broadcast to local network
		broadcast_to_network(json_string)

func broadcast_to_network(data: String):
	# Create a UDP socket for broadcasting
	var udp = PacketPeerUDP.new()
	
	# Enable broadcasting
	udp.connect_to_host("255.255.255.255", room_discovery_port)
	
	# Send the data
	var packet = data.to_utf8_buffer()
	var result = udp.put_packet(packet)
	
	if result == OK:
		print("📡 Broadcasted room info to network")
	else:
		print("❌ Failed to broadcast room info: ", result)
	
	udp.close()

# Discovery timer callback
func _on_discovery_timer_timeout():
	if discovery_enabled:
		refresh_room_list()

# Manually refresh room list
func refresh_room_list():
	print("🔄 Refreshing room list...")
	
	# Clear old rooms (older than 30 seconds)
	var current_time = Time.get_unix_time_from_system()
	var rooms_to_remove = []
	
	for room_code in discovered_rooms:
		var room = discovered_rooms[room_code]
		if current_time - room.created_time > 30:  # 30 second timeout
			rooms_to_remove.append(room_code)
	
	for room_code in rooms_to_remove:
		discovered_rooms.erase(room_code)
		print("🗑️ Removed stale room: ", room_code)
	
	# Send a general discovery request
	send_general_discovery_request()
	
	# Emit the current list
	room_list_updated.emit(get_public_rooms())

func send_general_discovery_request():
	var request_data = {
		"type": "general_discovery_request",
		"requester": local_player_name
	}
	
	var json_string = JSON.stringify(request_data)
	broadcast_to_network(json_string)
	print("🔍 Sent general room discovery request")

# Get current room info
func get_current_room() -> Room:
	return current_room

# Check if player is in a room
func is_in_room() -> bool:
	return current_room != null

# Get room by code
func get_room(room_code: String) -> Room:
	return discovered_rooms.get(room_code, null)

# Update room settings (host only)
func update_room_settings(new_settings: Dictionary):
	if current_room and is_host:
		current_room.game_settings = new_settings
		print("🎮 Updated room settings: ", new_settings) 
