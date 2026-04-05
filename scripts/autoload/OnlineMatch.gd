extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# OnlineMatch.gd
# Autoload singleton for matchmaking and player session state
# Responsibilities:
#   - 매칭 로직 및 플레이어 대기/준비 상태 관리
#   - Nakama socket 기반 플레이어 입장/퇴장 처리
#   - match state 및 match data serialization
# Autoload load order:
#   1. Online: Nakama 서버 연결
#   2. OnlineMatch: 매칭/플레이어 상태
#   3. GameManager: 게임 루프/상태 머신
# ═══════════════════════════════════════════════════════════════════════════════

# For developers to set from the outside, for example:
#   OnlineMatch.max_players = 8
#   OnlineMatch.client_version = 'v1.2'
var min_players: int = 2
var max_players: int = 2
var client_version: String = 'dev'
var matching_timeout: float = 30.0  # 매칭 타임아웃 (초)

var nakama_multiplayer_bridge: NakamaMultiplayerBridge

# Nakama variables:
var nakama_socket: NakamaSocket
var match_id: String
var matchmaker_ticket: String

var players: Dictionary

enum MatchState {
	LOBBY = 0,
	MATCHING = 1,
	CONNECTING = 2,
	WAITING_FOR_ENOUGH_PLAYERS = 3,
	READY = 4,
	PLAYING = 5,
}
var match_state: int = MatchState.LOBBY

enum MatchMode {
	NONE = 0,
	CREATE = 1,
	JOIN = 2,
	MATCHMAKER = 3,
}
var match_mode: int = MatchMode.NONE

signal error (message)
signal disconnected ()

signal match_joined (match_id, mode)

signal player_joined (player)
signal player_left (player)

signal match_ready (players)
signal match_not_ready ()


# ═══════════════════════════════════════════════════════════════════════════════
# Player Class
# ═══════════════════════════════════════════════════════════════════════════════

class Player:
	var session_id: String
	var peer_id: int
	var username: String

	func _init(_session_id: String, _username: String, _peer_id: int) -> void:
		session_id = _session_id
		username = _username
		peer_id = _peer_id

	static func from_presence(presence: Variant, _peer_id: int) -> Player:
		return Player.new(presence.session_id, presence.username, _peer_id)

	static func from_dict(data: Dictionary) -> Player:
		return Player.new(data['session_id'], data['username'], int(data['peer_id']))

	func to_dict() -> Dictionary:
		return {
			"session_id": session_id,
			"username": username,
			"peer_id": peer_id,
		}


static func serialize_players(_players: Dictionary) -> Dictionary:
	var result := {}
	for key in _players:
		result[key] = _players[key].to_dict()
	return result


static func unserialize_players(_players: Dictionary) -> Dictionary:
	var result := {}
	for key in _players:
		result[key] = Player.from_dict(_players[key])
	return result


func _set_readonly_variable(_value) -> void:
	pass


func _set_nakama_socket(_nakama_socket: NakamaSocket) -> void:
	if nakama_socket == _nakama_socket:
		return

	if nakama_socket:
		nakama_socket.disconnect("closed", Callable(self, "_on_nakama_socket_closed"))

	if nakama_multiplayer_bridge:
		nakama_multiplayer_bridge.disconnect("match_joined", Callable(self, "_on_match_joined"))
		nakama_multiplayer_bridge.disconnect("match_join_error", Callable(self, "_on_match_join_error"))
		nakama_multiplayer_bridge.leave()
		nakama_multiplayer_bridge = null
		get_tree().network_peer = null

	nakama_socket = _nakama_socket

	if nakama_socket:
		nakama_socket.connect("closed", Callable(self, "_on_nakama_socket_closed"))
		nakama_multiplayer_bridge = NakamaMultiplayerBridge.new(nakama_socket)
		nakama_multiplayer_bridge.connect("match_joined", Callable(self, "_on_match_joined"))
		nakama_multiplayer_bridge.connect("match_join_error", Callable(self, "_on_match_join_error"))
		get_tree().network_peer = nakama_multiplayer_bridge.multiplayer_peer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

func create_match(_nakama_socket: NakamaSocket) -> void:
	leave()
	_set_nakama_socket(_nakama_socket)
	match_mode = MatchMode.CREATE

	nakama_multiplayer_bridge.create_match()


func join_match(_nakama_socket: NakamaSocket, _match_id: String) -> void:
	leave()
	_set_nakama_socket(_nakama_socket)
	match_mode = MatchMode.JOIN

	nakama_multiplayer_bridge.join_match(_match_id)


func start_matchmaking(_nakama_socket: NakamaSocket, data: Dictionary = {}) -> void:
	leave()
	_set_nakama_socket(_nakama_socket)
	match_mode = MatchMode.MATCHMAKER

	if data.has('min_count'):
		data['min_count'] = max(min_players, data['min_count'])
	else:
		data['min_count'] = min_players

	if data.has('max_count'):
		data['max_count'] = min(max_players, data['max_count'])
	else:
		data['max_count'] = max_players

	if client_version != '':
		if not data.has('string_properties'):
			data['string_properties'] = {}
		data['string_properties']['client_version'] = client_version

		var query = '+properties.client_version:' + client_version
		if data.has('query'):
			data['query'] += ' ' + query
		else:
			data['query'] = query

	match_state = MatchState.MATCHING
	var result = await nakama_socket.add_matchmaker_async(data.get('query', '*'), data['min_count'], data['max_count'], data.get('string_properties', {}), data.get('numeric_properties', {}))
	if result.is_exception():
		leave()
		emit_signal("error", "Unable to join match making pool")
	else:
		matchmaker_ticket = result.ticket
		nakama_multiplayer_bridge.start_matchmaking(result)


func start_playing() -> void:
	assert(match_state == MatchState.READY)
	match_state = MatchState.PLAYING


func leave(close_socket: bool = false) -> void:
	# Nakama disconnect.
	if nakama_multiplayer_bridge:
		nakama_multiplayer_bridge.leave()
	if nakama_socket:
		if matchmaker_ticket:
			await nakama_socket.remove_matchmaker_async(matchmaker_ticket)
		if close_socket:
			nakama_socket.close()
			_set_nakama_socket(null)

	# Initialize all the variables to their default state.
	match_id = ''
	players = {}
	match_state = MatchState.LOBBY
	match_mode = MatchMode.NONE


func get_match_id() -> String:
	if nakama_multiplayer_bridge:
		return nakama_multiplayer_bridge.match_id
	return ''


func get_match_mode() -> int:
	return match_mode


func get_match_state() -> int:
	return match_state


func get_player_names_by_peer_id() -> Dictionary:
	var result = {}
	for peer_id in players:
		result[peer_id] = players[peer_id].username
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════════

func _on_nakama_socket_closed() -> void:
	leave()
	emit_signal("disconnected")


func _check_enough_players() -> void:
	if players.size() >= min_players:
		match_state = MatchState.READY
		emit_signal("match_ready", players)
	else:
		match_state = MatchState.WAITING_FOR_ENOUGH_PLAYERS
		emit_signal("match_not_ready")


func _on_match_joined() -> void:
	var my_peer_id: int = get_tree().get_network_unique_id()
	var presence: NakamaRTAPI.UserPresence = nakama_multiplayer_bridge.get_user_presence_for_peer(my_peer_id)
	var player = Player.from_presence(presence, my_peer_id)
	players[my_peer_id] = player
	emit_signal("match_joined", nakama_multiplayer_bridge.match_id, match_mode)


@rpc("any_peer")
func _boot_with_error(msg: String) -> void:
	leave()
	emit_signal("error", msg)


@rpc("any_peer")
func _check_client_version(host_client_version: String) -> void:
	if client_version != host_client_version:
		leave()
		emit_signal("error", "Client version doesn't match host")


func _on_network_peer_connected(peer_id: int) -> void:
	if is_multiplayer_authority():
		if match_state == MatchState.PLAYING:
			rpc_id(peer_id, "_boot_with_error", 'Sorry! The match has already begun.')
			return

		if players.size() >= max_players:
			rpc_id(peer_id, "_boot_with_error", "Sorry! The match is full.")
			return

		# Ask the client to check it's client version.
		rpc_id(peer_id, "_check_client_version", client_version)

	var presence: NakamaRTAPI.UserPresence = nakama_multiplayer_bridge.get_user_presence_for_peer(peer_id)
	var player = Player.from_presence(presence, peer_id)
	players[peer_id] = player
	emit_signal("player_joined", player)

	_check_enough_players()


func _on_network_peer_disconnected(peer_id: int) -> void:
	var player = players.get(peer_id)
	if player != null:
		emit_signal("player_left", player)
		players.erase(peer_id)

	_check_enough_players()
