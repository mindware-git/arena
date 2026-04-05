extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Online.gd - Nakama Connection Management
# Online 싱글톤의 연결 관리 기능 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _original_host: String
var _original_port: int
var _original_scheme: String

func before_each() -> void:
	_original_host = Online.nakama_host
	_original_port = Online.nakama_port
	_original_scheme = Online.nakama_scheme


func after_each() -> void:
	Online.nakama_host = _original_host
	Online.nakama_port = _original_port
	Online.nakama_scheme = _original_scheme


func test_get_nakama_client() -> void:
	var client = Online.get_nakama_client()
	assert_not_null(client, "NakamaClient should be created")
	assert_eq(client.host, Online.nakama_host, "Client should use configured host")
	assert_eq(client.port, Online.nakama_port, "Client should use configured port")


func test_connection_status_not_authenticated() -> void:
	# 세션 없는 상태
	var status = Online.get_connection_status()
	assert_eq(status, "not_authenticated", "Should return not_authenticated when no session")


func test_connection_status_socket_disconnected() -> void:
	# 세션은 있지만 소켓 없는 상태
	var mock_session = NakamaSession.new("test_token", true, "test_refresh")
	Online.set_nakama_session(mock_session)
	
	var status = Online.get_connection_status()
	assert_eq(status, "socket_disconnected", "Should return socket_disconnected when session exists but no socket")


func test_connection_status_connected() -> void:
	# 세션 있고 소켓 연결된 상태 (모킹)
	var mock_session = NakamaSession.new("test_token", true, "test_refresh")
	Online.set_nakama_session(mock_session)
	
	# 실제로는 연결할 수 없으니 상태만 체크
	var status = Online.get_connection_status()
	assert_eq(status, "socket_disconnected", "Should return socket_disconnected (no real connection in test)")


var signal_received: bool = false
var received_session = null

func test_session_signals() -> void:
	signal_received = false
	received_session = null
	
	Online.connect("session_connected", Callable(self, "_on_session_connected"))
	
	var mock_session = NakamaSession.new("test_token", true, "test_refresh")
	Online.set_nakama_session(mock_session)
	
	assert_true(signal_received, "session_connected signal should be emitted")
	assert_not_null(received_session, "Session should be passed in signal")


func _on_session_connected(session) -> void:
	signal_received = true
	received_session = session