extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Online.gd - Nakama Connection Management
# Online 싱글톤의 연결 관리 기능 테스트
# 실제 Nakama 서버를 사용하여 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var SERVER_KEY: String = ProjectSettings.get_setting("network/nakama/server_key", "defaultkey")
var HOST: String = ProjectSettings.get_setting("network/nakama/host", "localhost")
var PORT: int = ProjectSettings.get_setting("network/nakama/port", 7350)

var _http_adapter: NakamaHTTPAdapter
var _client: NakamaClient
var _session: NakamaSession


func before_each() -> void:
	# Reset Online singleton state
	Online.set_nakama_session(null)
	
	# Create HTTP adapter and client
	_http_adapter = NakamaHTTPAdapter.new()
	add_child(_http_adapter)
	_client = NakamaClient.new(_http_adapter, SERVER_KEY, "http", HOST, PORT, 10)


func after_each() -> void:
	# Cleanup
	Online.set_nakama_session(null)
	
	if _http_adapter and is_instance_valid(_http_adapter):
		_http_adapter.queue_free()
		_http_adapter = null
	_client = null
	_session = null


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
	# 실제 서버에 연결해서 세션 생성
	var session_result = await _client.authenticate_device_async("test_online_device")
	
	if session_result.is_exception():
		pending("Could not authenticate: %s" % session_result.get_exception().message)
		return
	
	_session = session_result
	Online.set_nakama_session(_session)
	
	var status = Online.get_connection_status()
	assert_eq(status, "socket_disconnected", "Should return socket_disconnected when session exists but no socket")


var _signal_received: bool = false
var _received_session: NakamaSession = null

func test_session_signals() -> void:
	_signal_received = false
	_received_session = null
	
	Online.connect("session_connected", Callable(self, "_on_session_connected"))
	
	# 실제 서버에 연결해서 세션 생성
	var session_result = await _client.authenticate_device_async("test_online_device_signals")
	
	if session_result.is_exception():
		pending("Could not authenticate: %s" % session_result.get_exception().message)
		return
	
	_session = session_result
	Online.set_nakama_session(_session)
	
	assert_true(_signal_received, "session_connected signal should be emitted")
	assert_not_null(_received_session, "Session should be passed in signal")


func _on_session_connected(session: NakamaSession) -> void:
	_signal_received = true
	_received_session = session
