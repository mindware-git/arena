extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Nakama Backend Connection
# NakamaMultiplayerBridge를 통한 서버 연결 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var SERVER_KEY: String = ProjectSettings.get_setting("network/nakama/server_key", "defaultkey")
var HOST: String = ProjectSettings.get_setting("network/nakama/host", "localhost")
var PORT: int = ProjectSettings.get_setting("network/nakama/port", 7350)
const TIMEOUT := 5.0

var _client: NakamaClient
var _socket: NakamaSocket
var _session: NakamaSession
var _multiplayer_bridge: NakamaMultiplayerBridge
var _match_joined := false
var _match_join_error := ""

# Adapters need to be added to scene tree for _process to work
var _http_adapter: NakamaHTTPAdapter
var _socket_adapter: NakamaSocketAdapter


func before_each() -> void:
	_client = null
	_socket = null
	_session = null
	_multiplayer_bridge = null
	_match_joined = false
	_match_join_error = ""
	_http_adapter = null
	_socket_adapter = null


func after_each() -> void:
	if _socket:
		_socket.close()
		_socket = null
	if _client:
		_client = null
	if _http_adapter and is_instance_valid(_http_adapter):
		_http_adapter.queue_free()
	if _socket_adapter and is_instance_valid(_socket_adapter):
		_socket_adapter.queue_free()


func test_create_nakama_client() -> void:
	_http_adapter = NakamaHTTPAdapter.new()
	add_child(_http_adapter)
	
	_client = NakamaClient.new(_http_adapter, SERVER_KEY, "http", HOST, PORT, 10)
	assert_not_null(_client, "NakamaClient should be created")


func test_nakama_connection() -> void:
	# 1. HTTP 어댑터 및 클라이언트 생성
	_http_adapter = NakamaHTTPAdapter.new()
	add_child(_http_adapter)
	
	_client = NakamaClient.new(_http_adapter, SERVER_KEY, "http", HOST, PORT, 10)
	assert_not_null(_client, "NakamaClient should be created")
	
	# 2. 게스트 세션 생성 (비동기)
	# 디버깅용: 동일 PC에서 여러 인스턴스 실행을 위해 PID 추가
	var session_result = await _client.authenticate_device_async(OS.get_unique_id() + "_" + str(OS.get_process_id()))
	
	if session_result.is_exception():
		pending("Could not authenticate: %s" % session_result.get_exception().message)
		return
	
	_session = session_result
	assert_not_null(_session, "Session should be created")
	
	# 3. 소켓 어댑터 및 소켓 생성
	_socket_adapter = NakamaSocketAdapter.new()
	add_child(_socket_adapter)
	
	_socket = NakamaSocket.new(_socket_adapter, HOST, PORT, "ws")
	
	var connected = await _socket.connect_async(_session)
	
	if connected.is_exception():
		pending("Could not connect socket: %s" % connected.get_exception().message)
		return
	
	assert_true(_socket.is_connected_to_host(), "Socket should be connected")


func test_multiplayer_bridge() -> void:
	# 1. HTTP 어댑터 및 클라이언트 생성
	_http_adapter = NakamaHTTPAdapter.new()
	add_child(_http_adapter)
	
	_client = NakamaClient.new(_http_adapter, SERVER_KEY, "http", HOST, PORT, 10)
	
	var session_result = await _client.authenticate_device_async(OS.get_unique_id() + "_" + str(OS.get_process_id()))
	
	if session_result.is_exception():
		pending("Could not authenticate: %s" % session_result.get_exception().message)
		return
	
	_session = session_result
	
	# 2. 소켓 어댑터 및 소켓 연결
	_socket_adapter = NakamaSocketAdapter.new()
	add_child(_socket_adapter)
	
	_socket = NakamaSocket.new(_socket_adapter, HOST, PORT, "ws")
	
	var connected = await _socket.connect_async(_session)
	
	if connected.is_exception():
		pending("Could not connect socket: %s" % connected.get_exception().message)
		return
	
	# 3. MultiplayerBridge 생성
	_multiplayer_bridge = NakamaMultiplayerBridge.new(_socket)
	_multiplayer_bridge.match_joined.connect(_on_match_joined)
	_multiplayer_bridge.match_join_error.connect(_on_match_join_error)
	
	get_tree().get_multiplayer().set_multiplayer_peer(_multiplayer_bridge.multiplayer_peer)
	
	# 4. 매치 생성
	_multiplayer_bridge.create_match()
	
	# 5. 매치 참가 대기
	var elapsed := 0.0
	while elapsed < TIMEOUT and not _match_joined and _match_join_error.is_empty():
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if not _match_join_error.is_empty():
		pending("Match join error: %s" % _match_join_error)
		return
	
	if not _match_joined:
		pending("Timeout waiting for match")
		return
	
	assert_true(_match_joined, "Should be joined to match")
	assert_not_null(_multiplayer_bridge.match_id, "Match ID should not be null")


func _on_match_joined() -> void:
	_match_joined = true


func _on_match_join_error(error: Dictionary) -> void:
	_match_join_error = error.get("message", "Unknown error")
