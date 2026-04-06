extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Multiplayer Flow Integration
# 전체 멀티플레이 흐름 통합 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _main_scene: Node2D
var _current_screen: Control


func before_each() -> void:
	# Main 씬 시뮬레이션
	_main_scene = Node2D.new()
	add_child(_main_scene)


func after_each() -> void:
	# Cleanup screens first
	if _current_screen and is_instance_valid(_current_screen):
		_current_screen.queue_free()
		_current_screen = null
	
	# Then cleanup main scene
	if _main_scene and is_instance_valid(_main_scene):
		_main_scene.queue_free()
		_main_scene = null


func test_splash_to_login_flow() -> void:
	# SplashScreen 생성
	var splash = SplashScreen.new()
	_main_scene.add_child(splash)
	_current_screen = splash
	
	# 초기 상태 확인
	var title_label = splash.get_node("Label")
	assert_eq(title_label.text, "ARENA", "Should show ARENA title")
	
	# 터치 시작 버튼 클릭
	var start_btn = splash.get_node("Button")
	assert_eq(start_btn.text, "TOUCH TO START", "Should have start button")
	
	# 시그널 연결
	transition_received = false
	next_screen = null
	splash.connect("transition_requested", Callable(self, "_on_screen_transition"))
	
	# 버튼 클릭
	start_btn.emit_signal("pressed")
	
	# LoginScreen으로 전환되는지 확인
	assert_true(transition_received, "Should emit transition_requested signal")
	assert_not_null(next_screen, "Should provide next screen")
	assert_true(next_screen is LoginScreen, "Next screen should be LoginScreen")


func test_login_error_handling() -> void:
	# LoginScreen 생성
	var login = LoginScreen.new()
	_main_scene.add_child(login)
	_current_screen = login
	
	# 초기 상태 확인
	var status_label = login.get_node("Label2")
	assert_eq(status_label.text, "Nakama 서버 연결 중...", "Should show connecting status")
	
	# 에러 시뮬레이션
	login._show_error("Connection failed")
	
	# 에러 표시 확인
	assert_eq(status_label.text, "Connection failed", "Should show error message")
	assert_eq(login._retry_count, 1, "Retry count should increase")
	
	# 최대 재시도 초과 시뮬레이션
	login._retry_count = login._max_retries
	transition_received = false
	login.connect("transition_requested", Callable(self, "_on_screen_transition"))
	
	login._show_error("Max retries")
	
	# SplashScreen으로 돌아가는지 확인 (타이머 후)
	await get_tree().create_timer(4.1).timeout
	assert_true(transition_received, "Should transition after max retries")


func test_lobby_to_matching_flow() -> void:
	# LobbyScreen 생성
	var lobby = LobbyScreen.new()
	_main_scene.add_child(lobby)
	_current_screen = lobby
	
	# PLAY 버튼 찾기
	var play_btn = null
	for child in lobby.get_children():
		if child is VBoxContainer:
			for subchild in child.get_children():
				if subchild is Button and subchild.text == "▶ PLAY":
					play_btn = subchild
					break
	
	assert_not_null(play_btn, "Should have PLAY button")
	
	# 시그널 연결
	transition_received = false
	lobby.connect("transition_requested", Callable(self, "_on_screen_transition"))
	
	# 버튼 클릭
	play_btn.emit_signal("pressed")
	
	# MatchingScreen으로 전환되는지 확인
	assert_true(transition_received, "Should emit transition_requested signal")
	assert_not_null(next_screen, "Should provide next screen")
	assert_true(next_screen is MatchingScreen, "Next screen should be MatchingScreen")


func test_matching_timeout_flow() -> void:
	# MatchingScreen 생성
	var matching = MatchingScreen.new()
	_main_scene.add_child(matching)
	_current_screen = matching
	
	# 매칭 시작
	matching._start_matching()
	assert_true(matching._is_matching, "Should be in matching state")
	
	# 타임아웃 시뮬레이션
	matching._elapsed_time = matching._matching_timeout + 1.0
	
	# _process에서 타임아웃 감지
	matching._process(0.1)
	
	# 타임아웃 처리 확인
	assert_false(matching._is_matching, "Should stop matching after timeout")
	assert_eq(matching._retry_count, 1, "Retry count should increase")


func test_matching_cancel_flow() -> void:
	# MatchingScreen 생성
	var matching = MatchingScreen.new()
	_main_scene.add_child(matching)
	_current_screen = matching
	
	# 취소 버튼 찾기
	var cancel_btn = matching.get_node("Button")
	assert_eq(cancel_btn.text, "취소", "Should have cancel button")
	
	# 시그널 연결
	transition_received = false
	matching.connect("transition_requested", Callable(self, "_on_screen_transition"))
	
	# 취소 버튼 클릭
	cancel_btn.emit_signal("pressed")
	
	# LobbyScreen으로 돌아가는지 확인
	assert_true(transition_received, "Should emit transition_requested signal")
	assert_not_null(next_screen, "Should provide next screen")
	assert_true(next_screen is LobbyScreen, "Next screen should be LobbyScreen")
	
	# Clean up the lobby screen
	if next_screen and is_instance_valid(next_screen):
		next_screen.queue_free()
		next_screen = null


func test_online_match_state_transitions() -> void:
	# 초기 상태
	assert_eq(OnlineMatch.get_match_state(), OnlineMatch.MatchState.LOBBY, "Should start in LOBBY")
	assert_eq(OnlineMatch.get_match_mode(), OnlineMatch.MatchMode.NONE, "Should start with NONE mode")
	
	# leave() 호출
	OnlineMatch.leave()
	assert_eq(OnlineMatch.get_match_state(), OnlineMatch.MatchState.LOBBY, "Should stay in LOBBY after leave")
	assert_eq(OnlineMatch.players.size(), 0, "Should clear players after leave")


var transition_received: bool = false
var next_screen = null

func _on_screen_transition(screen) -> void:
	transition_received = true
	# Free previous screen if exists
	if next_screen and is_instance_valid(next_screen):
		next_screen.queue_free()
	next_screen = screen