extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# Online.gd
# Autoload singleton for Nakama server connectivity
# Responsibilities:
#   - Nakama client 생성/관리
#   - 세션 인증 및 복원
#   - 소켓 연결/재연결 처리
# Autoload load order:
#   1. Online: Nakama 서버 연결
#   2. OnlineMatch: 매칭/플레이어 상태
#   3. GameManager: 게임 루프/상태 머신
# ═══════════════════════════════════════════════════════════════════════════════

# For developers to set from the outside, for example:
#   Online.nakama_host = 'nakama.example.com'
#   Online.nakama_scheme = 'https'
var nakama_server_key: String = 'defaultkey'
var nakama_host: String = 'localhost'
var nakama_port: int = 7350
var nakama_scheme: String = 'http'

# For other scripts to access:
var nakama_client: NakamaClient
var nakama_session: NakamaSession
var nakama_socket: NakamaSocket

# Internal variable for initializing the socket.
var _nakama_socket_connecting: bool = false
var _is_connected: bool = false
var _session_failed_count: int = 0
var _client_host: String = ""

signal session_changed (nakama_session)
signal session_connected (nakama_session)
signal socket_connected (nakama_socket)
signal connection_failed (error_message: String)
signal disconnected ()


func _set_readonly_variable(_value) -> void:
	pass


func _ready() -> void:
	# Don't stop processing messages from Nakama when the game is paused.
	Nakama.process_mode = Node.PROCESS_MODE_ALWAYS


func get_nakama_client() -> NakamaClient:
	if nakama_client == null or _client_host != nakama_host:
		nakama_client = Nakama.create_client(
			nakama_server_key,
			nakama_host,
			nakama_port,
			nakama_scheme,
			Nakama.DEFAULT_TIMEOUT,
			NakamaLogger.LOG_LEVEL.ERROR)
		_client_host = nakama_host

	return nakama_client


func set_nakama_session(_nakama_session: NakamaSession) -> void:
	nakama_session = _nakama_session

	emit_signal("session_changed", nakama_session)

	if nakama_session and not nakama_session.is_exception() and not nakama_session.is_expired():
		emit_signal("session_connected", nakama_session)


func connect_nakama_socket() -> void:
	if nakama_socket != null:
		return
	if _nakama_socket_connecting:
		return
	_nakama_socket_connecting = true

	var new_socket = Nakama.create_socket_from(nakama_client)
	await new_socket.connect_async(nakama_session)
	
	nakama_socket = new_socket
	nakama_socket.connect("closed", Callable(self, "_on_socket_closed"))
	_nakama_socket_connecting = false
	_is_connected = true
	emit_signal("socket_connected", nakama_socket)


func _on_socket_closed() -> void:
	_is_connected = false
	if nakama_socket:
		nakama_socket.disconnect("closed", Callable(self, "_on_socket_closed"))
	emit_signal("disconnected")


func is_nakama_socket_connected() -> bool:
	return nakama_socket != null && nakama_socket.is_connected_to_host()


func get_connection_status() -> String:
	if not nakama_session or nakama_session.is_exception():
		return "not_authenticated"
	if not nakama_socket or not nakama_socket.is_connected_to_host():
		return "socket_disconnected"
	return "connected"
