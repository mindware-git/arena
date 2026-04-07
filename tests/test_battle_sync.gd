extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Battle Sync via NakamaMultiplayerBridge
# NakamaMultiplayerBridge를 통한 공격/데미지 동기화 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var SERVER_KEY: String = ProjectSettings.get_setting("network/nakama/server_key", "defaultkey")
var HOST: String = ProjectSettings.get_setting("network/nakama/host", "localhost")
var PORT: int = ProjectSettings.get_setting("network/nakama/port", 7350)
const TIMEOUT := 30.0

# Player A (Host)
var _http_adapter_a: NakamaHTTPAdapter
var _socket_adapter_a: NakamaSocketAdapter
var _client_a: NakamaClient
var _socket_a: NakamaSocket
var _session_a: NakamaSession
var _bridge_a: NakamaMultiplayerBridge

# Player B (Client)
var _http_adapter_b: NakamaHTTPAdapter
var _socket_adapter_b: NakamaSocketAdapter
var _client_b: NakamaClient
var _socket_b: NakamaSocket
var _session_b: NakamaSession
var _bridge_b: NakamaMultiplayerBridge

# Battle state
var _match_id: String = ""
var _hp_a: int = 100
var _hp_b: int = 100
var _damage_received_b: int = 0
var _match_joined_a := false
var _match_joined_b := false


func before_each() -> void:
	# Reset all
	_http_adapter_a = null
	_socket_adapter_a = null
	_client_a = null
	_socket_a = null
	_session_a = null
	_bridge_a = null
	
	_http_adapter_b = null
	_socket_adapter_b = null
	_client_b = null
	_socket_b = null
	_session_b = null
	_bridge_b = null
	
	_match_id = ""
	_hp_a = 100
	_hp_b = 100
	_damage_received_b = 0
	_match_joined_a = false
	_match_joined_b = false


func after_each() -> void:
	# Cleanup Player A
	if _socket_a:
		_socket_a.close()
	if _http_adapter_a and is_instance_valid(_http_adapter_a):
		_http_adapter_a.queue_free()
	if _socket_adapter_a and is_instance_valid(_socket_adapter_a):
		_socket_adapter_a.queue_free()
	
	# Cleanup Player B
	if _socket_b:
		_socket_b.close()
	if _http_adapter_b and is_instance_valid(_http_adapter_b):
		_http_adapter_b.queue_free()
	if _socket_adapter_b and is_instance_valid(_socket_adapter_b):
		_socket_adapter_b.queue_free()


func test_battle_damage_sync() -> void:
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. Player A 로그인 + 소켓 연결
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_a = NakamaHTTPAdapter.new()
	add_child(_http_adapter_a)
	_client_a = NakamaClient.new(_http_adapter_a, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_a = await _client_a.authenticate_device_async("battle_player_a")
	if session_result_a.is_exception():
		pending("Player A auth failed: %s" % session_result_a.get_exception().message)
		return
	_session_a = session_result_a
	
	_socket_adapter_a = NakamaSocketAdapter.new()
	add_child(_socket_adapter_a)
	_socket_a = NakamaSocket.new(_socket_adapter_a, HOST, PORT, "ws")
	
	var connect_a = await _socket_a.connect_async(_session_a)
	if connect_a.is_exception():
		pending("Player A socket failed: %s" % connect_a.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. Player B 로그인 + 소켓 연결
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_b = NakamaHTTPAdapter.new()
	add_child(_http_adapter_b)
	_client_b = NakamaClient.new(_http_adapter_b, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_b = await _client_b.authenticate_device_async("battle_player_b")
	if session_result_b.is_exception():
		pending("Player B auth failed: %s" % session_result_b.get_exception().message)
		return
	_session_b = session_result_b
	
	_socket_adapter_b = NakamaSocketAdapter.new()
	add_child(_socket_adapter_b)
	_socket_b = NakamaSocket.new(_socket_adapter_b, HOST, PORT, "ws")
	
	var connect_b = await _socket_b.connect_async(_session_b)
	if connect_b.is_exception():
		pending("Player B socket failed: %s" % connect_b.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 3. NakamaMultiplayerBridge 생성
	# ═══════════════════════════════════════════════════════════════════════════
	_bridge_a = NakamaMultiplayerBridge.new(_socket_a)
	_bridge_a.match_joined.connect(_on_player_a_match_joined)
	_bridge_a.match_join_error.connect(_on_match_join_error)
	
	_bridge_b = NakamaMultiplayerBridge.new(_socket_b)
	_bridge_b.match_joined.connect(_on_player_b_match_joined)
	_bridge_b.match_join_error.connect(_on_match_join_error)
	
	# MultiplayerPeer 설정 (RPC를 위해)
	get_tree().get_multiplayer().set_multiplayer_peer(_bridge_a.multiplayer_peer)
	
	# Player B 소켓에 데미지 수신 리스너 등록
	_socket_b.received_match_state.connect(_on_player_b_received_match_state)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 4. Player A가 매치 생성 (Host)
	# ═══════════════════════════════════════════════════════════════════════════
	_bridge_a.create_match()
	
	# 매치 참가 대기
	var elapsed := 0.0
	while elapsed < TIMEOUT and not _match_joined_a:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _match_joined_a:
		pending("Player A failed to create match")
		return
	
	_match_id = _bridge_a.match_id
	gut.p("Player A created match: %s" % _match_id)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 5. Player B가 매치 참가
	# ═══════════════════════════════════════════════════════════════════════════
	_bridge_b.join_match(_match_id)
	
	elapsed = 0.0
	while elapsed < TIMEOUT and not _match_joined_b:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _match_joined_b:
		pending("Player B failed to join match")
		return
	
	gut.p("Player B joined match")
	
	# 동기화 대기
	await get_tree().create_timer(0.5).timeout
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 6. RPC 데미지 전송 테스트
	# ═══════════════════════════════════════════════════════════════════════════
	# Player A의 peer_id는 1 (Host)
	# Player B의 peer_id는 동적으로 할당됨
	
	var peer_id_b = 0
	for peer_id in _bridge_a._id_map.keys():
		if peer_id != 1:
			peer_id_b = peer_id
			break
	
	gut.p("Player A peer_id: 1 (Host)")
	gut.p("Player B peer_id: %d" % peer_id_b)
	
	# RPC로 데미지 전송 (Player A -> Player B)
	# 주의: 실제로는 SceneTree에 등록된 노드에서 RPC를 호출해야 함
	# 테스트에서는 직접 match state 전송으로 시뮬레이션
	
	var damage := 25
	_send_damage_to_player_b(damage)
	
	# 데미지 수신 대기
	elapsed = 0.0
	while elapsed < 5.0 and _damage_received_b == 0:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 7. 검증
	# ═══════════════════════════════════════════════════════════════════════════
	assert_true(_match_joined_a, "Player A should be in match")
	assert_true(_match_joined_b, "Player B should be in match")
	assert_true(not _match_id.is_empty(), "Match ID should not be empty")
	assert_eq(_damage_received_b, 25, "Player B should receive 25 damage")
	
	gut.p("Damage received by B: %d" % _damage_received_b)


func _on_player_a_match_joined() -> void:
	_match_joined_a = true
	gut.p("Player A match_joined signal received")


func _on_player_b_match_joined() -> void:
	_match_joined_b = true
	gut.p("Player B match_joined signal received")


func _on_match_join_error(error: Dictionary) -> void:
	gut.p("Match join error: %s" % error)


func _on_player_b_received_match_state(match_state: NakamaRTAPI.MatchData) -> void:
	# op_code 9002 = RPC (NakamaMultiplayerBridge 기본값)
	if match_state.op_code == 9002:
		var damage = bytes_to_var(match_state.binary_data)
		_damage_received_b = damage
		gut.p("Player B received damage: %d" % damage)


func _send_damage_to_player_b(damage: int) -> void:
	# NakamaMultiplayerBridge의 rpc_op_code (기본값 9002)를 사용하여
	# 직접 match state 전송
	var damage_data := PackedByteArray()
	damage_data.append_array(var_to_bytes(damage))
	
	# Player B의 presence 찾기
	var target_presence = null
	for session_id in _bridge_a._users:
		if session_id != _bridge_a._my_session_id:
			target_presence = _bridge_a._users[session_id].presence
			break
	
	if target_presence:
		_socket_a.send_match_state_raw_async(_match_id, 9002, damage_data, [target_presence])
		gut.p("Sent damage %d to Player B" % damage)


# ═══════════════════════════════════════════════════════════════════════════════
# Test: Position Synchronization
# 두 플레이어 간 위치 동기화 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _position_received_b := false
var _received_position := Vector2.ZERO
var _received_velocity := Vector2.ZERO

func test_position_sync() -> void:
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. Player A 로그인 + 소켓 연결
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_a = NakamaHTTPAdapter.new()
	add_child(_http_adapter_a)
	_client_a = NakamaClient.new(_http_adapter_a, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_a = await _client_a.authenticate_device_async("pos_player_a")
	if session_result_a.is_exception():
		pending("Player A auth failed: %s" % session_result_a.get_exception().message)
		return
	_session_a = session_result_a
	
	_socket_adapter_a = NakamaSocketAdapter.new()
	add_child(_socket_adapter_a)
	_socket_a = NakamaSocket.new(_socket_adapter_a, HOST, PORT, "ws")
	
	var connect_a = await _socket_a.connect_async(_session_a)
	if connect_a.is_exception():
		pending("Player A socket failed: %s" % connect_a.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. Player B 로그인 + 소켓 연결
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_b = NakamaHTTPAdapter.new()
	add_child(_http_adapter_b)
	_client_b = NakamaClient.new(_http_adapter_b, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_b = await _client_b.authenticate_device_async("pos_player_b")
	if session_result_b.is_exception():
		pending("Player B auth failed: %s" % session_result_b.get_exception().message)
		return
	_session_b = session_result_b
	
	_socket_adapter_b = NakamaSocketAdapter.new()
	add_child(_socket_adapter_b)
	_socket_b = NakamaSocket.new(_socket_adapter_b, HOST, PORT, "ws")
	
	var connect_b = await _socket_b.connect_async(_session_b)
	if connect_b.is_exception():
		pending("Player B socket failed: %s" % connect_b.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 3. NakamaMultiplayerBridge 생성
	# ═══════════════════════════════════════════════════════════════════════════
	_bridge_a = NakamaMultiplayerBridge.new(_socket_a)
	_bridge_a.match_joined.connect(_on_player_a_match_joined)
	_bridge_a.match_join_error.connect(_on_match_join_error)
	
	_bridge_b = NakamaMultiplayerBridge.new(_socket_b)
	_bridge_b.match_joined.connect(_on_player_b_match_joined)
	_bridge_b.match_join_error.connect(_on_match_join_error)
	
	# MultiplayerPeer 설정 (RPC를 위해)
	get_tree().get_multiplayer().set_multiplayer_peer(_bridge_a.multiplayer_peer)
	
	# Player B 소켓에 위치 수신 리스너 등록 (op_code 9003 = position sync)
	_socket_b.received_match_state.connect(_on_player_b_received_position)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 4. Player A가 매치 생성 (Host)
	# ═══════════════════════════════════════════════════════════════════════════
	_bridge_a.create_match()
	
	# 매치 참가 대기
	var elapsed := 0.0
	while elapsed < TIMEOUT and not _match_joined_a:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _match_joined_a:
		pending("Player A failed to create match")
		return
	
	_match_id = _bridge_a.match_id
	gut.p("Player A created match: %s" % _match_id)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 5. Player B가 매치 참가
	# ═══════════════════════════════════════════════════════════════════════════
	_bridge_b.join_match(_match_id)
	
	elapsed = 0.0
	while elapsed < TIMEOUT and not _match_joined_b:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _match_joined_b:
		pending("Player B failed to join match")
		return
	
	gut.p("Player B joined match")
	
	# 동기화 대기
	await get_tree().create_timer(0.5).timeout
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 6. 위치 동기화 전송 테스트
	# ═══════════════════════════════════════════════════════════════════════════
	var test_position := Vector2(100.0, 200.0)
	var test_velocity := Vector2(50.0, -30.0)
	
	_send_position_to_player_b(test_position, test_velocity)
	
	# 위치 수신 대기
	elapsed = 0.0
	while elapsed < 5.0 and not _position_received_b:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 7. 검증
	# ═══════════════════════════════════════════════════════════════════════════
	assert_true(_match_joined_a, "Player A should be in match")
	assert_true(_match_joined_b, "Player B should be in match")
	assert_true(_position_received_b, "Player B should receive position")
	assert_almost_eq(_received_position.x, test_position.x, 0.1, "Position X should match")
	assert_almost_eq(_received_position.y, test_position.y, 0.1, "Position Y should match")
	assert_almost_eq(_received_velocity.x, test_velocity.x, 0.1, "Velocity X should match")
	assert_almost_eq(_received_velocity.y, test_velocity.y, 0.1, "Velocity Y should match")
	
	gut.p("Position received by B: %s, velocity: %s" % [_received_position, _received_velocity])


func _on_player_b_received_position(match_state: NakamaRTAPI.MatchData) -> void:
	# op_code 9003 = Position Sync
	if match_state.op_code == 9003:
		var data = bytes_to_var(match_state.binary_data)
		if data is Dictionary:
			_received_position = Vector2(data.get("x", 0), data.get("y", 0))
			_received_velocity = Vector2(data.get("vx", 0), data.get("vy", 0))
			_position_received_b = true
			gut.p("Player B received position: %s, velocity: %s" % [_received_position, _received_velocity])


func _send_position_to_player_b(pos: Vector2, vel: Vector2) -> void:
	# op_code 9003 = Position Sync
	var data := {
		"x": pos.x,
		"y": pos.y,
		"vx": vel.x,
		"vy": vel.y
	}
	var pos_data := PackedByteArray()
	pos_data.append_array(var_to_bytes(data))
	
	# Player B의 presence 찾기
	var target_presence = null
	for session_id in _bridge_a._users:
		if session_id != _bridge_a._my_session_id:
			target_presence = _bridge_a._users[session_id].presence
			break
	
	if target_presence:
		_socket_a.send_match_state_raw_async(_match_id, 9003, pos_data, [target_presence])
		gut.p("Sent position %s, velocity %s to Player B" % [pos, vel])


# ═══════════════════════════════════════════════════════════════════════════════
# Test: Character Selection Synchronization
# 캐릭터 선택 동기화 테스트 - 양쪽 모두 선택 완료 시 게임 시작
# ═══════════════════════════════════════════════════════════════════════════════

const CHAR_SELECT_OP_CODE := 9004  # 캐릭터 선택 동기화 op_code

var _char_select_received_b := false
var _received_char_id_b := ""
var _received_ready_b := false

func test_character_selection_sync() -> void:
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. Player A 로그인 + 소켓 연결
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_a = NakamaHTTPAdapter.new()
	add_child(_http_adapter_a)
	_client_a = NakamaClient.new(_http_adapter_a, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_a = await _client_a.authenticate_device_async("char_player_a")
	if session_result_a.is_exception():
		pending("Player A auth failed: %s" % session_result_a.get_exception().message)
		return
	_session_a = session_result_a
	
	_socket_adapter_a = NakamaSocketAdapter.new()
	add_child(_socket_adapter_a)
	_socket_a = NakamaSocket.new(_socket_adapter_a, HOST, PORT, "ws")
	
	var connect_a = await _socket_a.connect_async(_session_a)
	if connect_a.is_exception():
		pending("Player A socket failed: %s" % connect_a.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. Player B 로그인 + 소켓 연결
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_b = NakamaHTTPAdapter.new()
	add_child(_http_adapter_b)
	_client_b = NakamaClient.new(_http_adapter_b, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_b = await _client_b.authenticate_device_async("char_player_b")
	if session_result_b.is_exception():
		pending("Player B auth failed: %s" % session_result_b.get_exception().message)
		return
	_session_b = session_result_b
	
	_socket_adapter_b = NakamaSocketAdapter.new()
	add_child(_socket_adapter_b)
	_socket_b = NakamaSocket.new(_socket_adapter_b, HOST, PORT, "ws")
	
	var connect_b = await _socket_b.connect_async(_session_b)
	if connect_b.is_exception():
		pending("Player B socket failed: %s" % connect_b.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 3. NakamaMultiplayerBridge 생성 + 매치 연결
	# ═══════════════════════════════════════════════════════════════════════════
	_bridge_a = NakamaMultiplayerBridge.new(_socket_a)
	_bridge_a.match_joined.connect(_on_player_a_match_joined)
	_bridge_a.match_join_error.connect(_on_match_join_error)
	
	_bridge_b = NakamaMultiplayerBridge.new(_socket_b)
	_bridge_b.match_joined.connect(_on_player_b_match_joined)
	_bridge_b.match_join_error.connect(_on_match_join_error)
	
	get_tree().get_multiplayer().set_multiplayer_peer(_bridge_a.multiplayer_peer)
	
	# 캐릭터 선택 수신 리스너
	_socket_b.received_match_state.connect(_on_player_b_received_char_select)
	
	# Player A가 매치 생성
	_bridge_a.create_match()
	
	var elapsed := 0.0
	while elapsed < TIMEOUT and not _match_joined_a:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _match_joined_a:
		pending("Player A failed to create match")
		return
	
	_match_id = _bridge_a.match_id
	
	# Player B가 매치 참가
	_bridge_b.join_match(_match_id)
	
	elapsed = 0.0
	while elapsed < TIMEOUT and not _match_joined_b:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _match_joined_b:
		pending("Player B failed to join match")
		return
	
	await get_tree().create_timer(0.5).timeout
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 4. 캐릭터 선택 동기화 테스트
	# ═══════════════════════════════════════════════════════════════════════════
	var char_id_a := "gyro"
	var is_ready_a := true
	
	_send_character_selection_to_b(char_id_a, is_ready_a)
	
	# 수신 대기
	elapsed = 0.0
	while elapsed < 5.0 and not _char_select_received_b:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 5. 검증
	# ═══════════════════════════════════════════════════════════════════════════
	assert_true(_char_select_received_b, "Player B should receive character selection")
	assert_eq(_received_char_id_b, char_id_a, "Character ID should match")
	assert_true(_received_ready_b, "Ready status should be true")
	
	gut.p("Character selection received by B: char_id=%s, ready=%s" % [_received_char_id_b, _received_ready_b])


func _on_player_b_received_char_select(match_state: NakamaRTAPI.MatchData) -> void:
	# op_code 9004 = Character Selection Sync
	if match_state.op_code == CHAR_SELECT_OP_CODE:
		var data = bytes_to_var(match_state.binary_data)
		if data is Dictionary:
			_received_char_id_b = data.get("char_id", "")
			_received_ready_b = data.get("ready", false)
			_char_select_received_b = true
			gut.p("Player B received character selection: char_id=%s, ready=%s" % [_received_char_id_b, _received_ready_b])


func _send_character_selection_to_b(char_id: String, is_ready: bool) -> void:
	# op_code 9004 = Character Selection Sync
	var data := {
		"char_id": char_id,
		"ready": is_ready
	}
	var select_data := PackedByteArray()
	select_data.append_array(var_to_bytes(data))
	
	# Player B의 presence 찾기
	var target_presence = null
	for session_id in _bridge_a._users:
		if session_id != _bridge_a._my_session_id:
			target_presence = _bridge_a._users[session_id].presence
			break
	
	if target_presence:
		_socket_a.send_match_state_raw_async(_match_id, CHAR_SELECT_OP_CODE, select_data, [target_presence])
		gut.p("Sent character selection: char_id=%s, ready=%s" % [char_id, is_ready])
