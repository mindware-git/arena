extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Nakama Matchmaking
# 자동 매치메이킹 테스트 - 두 플레이어가 매칭되는 과정 검증
# ═══════════════════════════════════════════════════════════════════════════════

var SERVER_KEY: String = ProjectSettings.get_setting("network/nakama/server_key", "defaultkey")
var HOST: String = ProjectSettings.get_setting("network/nakama/host", "localhost")
var PORT: int = ProjectSettings.get_setting("network/nakama/port", 7350)
const TIMEOUT := 30.0

# Player A
var _http_adapter_a: NakamaHTTPAdapter
var _socket_adapter_a: NakamaSocketAdapter
var _client_a: NakamaClient
var _socket_a: NakamaSocket
var _session_a: NakamaSession

# Player B
var _http_adapter_b: NakamaHTTPAdapter
var _socket_adapter_b: NakamaSocketAdapter
var _client_b: NakamaClient
var _socket_b: NakamaSocket
var _session_b: NakamaSession

# Match results
var _match_id_a: String = ""
var _match_id_b: String = ""
var _matched_a := false
var _matched_b := false


func before_each() -> void:
	# Reset all variables
	_http_adapter_a = null
	_socket_adapter_a = null
	_client_a = null
	_socket_a = null
	_session_a = null
	
	_http_adapter_b = null
	_socket_adapter_b = null
	_client_b = null
	_socket_b = null
	_session_b = null
	
	_match_id_a = ""
	_match_id_b = ""
	_matched_a = false
	_matched_b = false


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


func test_matchmaking_two_players() -> void:
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. Player A 로그인
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_a = NakamaHTTPAdapter.new()
	add_child(_http_adapter_a)
	_client_a = NakamaClient.new(_http_adapter_a, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_a = await _client_a.authenticate_device_async("test_player_a")
	if session_result_a.is_exception():
		pending("Player A authentication failed: %s" % session_result_a.get_exception().message)
		return
	_session_a = session_result_a
	
	# Player A 소켓 연결
	_socket_adapter_a = NakamaSocketAdapter.new()
	add_child(_socket_adapter_a)
	_socket_a = NakamaSocket.new(_socket_adapter_a, HOST, PORT, "ws")
	
	var connect_a = await _socket_a.connect_async(_session_a)
	if connect_a.is_exception():
		pending("Player A socket connection failed: %s" % connect_a.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. Player B 로그인
	# ═══════════════════════════════════════════════════════════════════════════
	_http_adapter_b = NakamaHTTPAdapter.new()
	add_child(_http_adapter_b)
	_client_b = NakamaClient.new(_http_adapter_b, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result_b = await _client_b.authenticate_device_async("test_player_b")
	if session_result_b.is_exception():
		pending("Player B authentication failed: %s" % session_result_b.get_exception().message)
		return
	_session_b = session_result_b
	
	# Player B 소켓 연결
	_socket_adapter_b = NakamaSocketAdapter.new()
	add_child(_socket_adapter_b)
	_socket_b = NakamaSocket.new(_socket_adapter_b, HOST, PORT, "ws")
	
	var connect_b = await _socket_b.connect_async(_session_b)
	if connect_b.is_exception():
		pending("Player B socket connection failed: %s" % connect_b.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 3. 매치메이커 이벤트 리스너 등록
	# ═══════════════════════════════════════════════════════════════════════════
	_socket_a.received_matchmaker_matched.connect(_on_player_a_matched)
	_socket_b.received_matchmaker_matched.connect(_on_player_b_matched)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 4. 두 플레이어 모두 매치메이커 참가
	# ═══════════════════════════════════════════════════════════════════════════
	# min_count=2, max_count=2 (1vs1)
	var ticket_a = await _socket_a.add_matchmaker_async("*", 2, 2)
	if ticket_a.is_exception():
		pending("Player A matchmaker join failed: %s" % ticket_a.get_exception().message)
		return
	
	var ticket_b = await _socket_b.add_matchmaker_async("*", 2, 2)
	if ticket_b.is_exception():
		pending("Player B matchmaker join failed: %s" % ticket_b.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 5. 매칭 완료 대기
	# ═══════════════════════════════════════════════════════════════════════════
	var elapsed := 0.0
	while elapsed < TIMEOUT and (not _matched_a or not _matched_b):
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _matched_a:
		pending("Player A was not matched within timeout")
		return
	
	if not _matched_b:
		pending("Player B was not matched within timeout")
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 6. 검증
	# ═══════════════════════════════════════════════════════════════════════════
	assert_true(_matched_a, "Player A should be matched")
	assert_true(_matched_b, "Player B should be matched")
	assert_true(not _match_id_a.is_empty(), "Player A should have a match_id")
	assert_true(not _match_id_b.is_empty(), "Player B should have a match_id")
	assert_eq(_match_id_a, _match_id_b, "Both players should be in the same match")
	
	gut.p("Match ID: %s" % _match_id_a)


func _on_player_a_matched(matchmaker_matched) -> void:
	gut.p("Player A matched!")
	_matched_a = true
	
	# 매칭된 방에 참가
	var match = await _socket_a.join_matched_async(matchmaker_matched)
	if not match.is_exception():
		_match_id_a = match.match_id
		gut.p("Player A joined match: %s" % _match_id_a)


func _on_player_b_matched(matchmaker_matched) -> void:
	gut.p("Player B matched!")
	_matched_b = true
	
	# 매칭된 방에 참가
	var match = await _socket_b.join_matched_async(matchmaker_matched)
	if not match.is_exception():
		_match_id_b = match.match_id
		gut.p("Player B joined match: %s" % _match_id_b)
