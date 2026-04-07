extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: LoginScreen.gd - Authentication UI
# 로그인 화면의 UI 및 인증 로직 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _login_screen: LoginScreen
var _original_host: String
var _original_port: int
var _transition_received: bool = false
var _transition_screen: Control = null

func before_each() -> void:
	_original_host = Online.nakama_host
	_original_port = Online.nakama_port
	
	# 테스트용 설정 (실제 서버 연결 방지)
	Online.nakama_host = "invalid.host"
	Online.nakama_port = 9999
	
	_login_screen = add_child_autofree(LoginScreen.new())


func after_each() -> void:
	Online.nakama_host = _original_host
	Online.nakama_port = _original_port
	
	# autofree handles cleanup
	_transition_screen = null
	_login_screen = null


func test_initial_ui_setup() -> void:
	# UI 요소들이 생성되었는지 확인
	assert_not_null(_login_screen.get_node_or_null("Label"), "Should have title label")
	assert_not_null(_login_screen.get_node_or_null("Label2"), "Should have status label")
	assert_not_null(_login_screen.get_node_or_null("Label3"), "Should have loading label")
	
	# 초기 상태 확인
	var status_label = _login_screen.get_node("Label2")
	assert_eq(status_label.text, "Nakama 서버 연결 중...", "Should show connecting status initially")


func test_authentication_retry_logic() -> void:
	# 재시도 카운트 초기화 확인
	assert_eq(_login_screen._retry_count, 0, "Retry count should start at 0")
	assert_eq(_login_screen._max_retries, 3, "Max retries should be 3")
	
	# 재시도 증가 테스트
	_login_screen._retry_count = 1
	assert_eq(_login_screen._retry_count, 1, "Retry count should be settable")


func test_error_display() -> void:
	var status_label = _login_screen.get_node("Label2")
	var loading_label = _login_screen.get_node("Label3")
	
	# 에러 표시 전 초기 상태
	assert_eq(status_label.text, "Nakama 서버 연결 중...", "Should start with connecting")
	
	# 에러 표시 (직접 호출)
	_login_screen._show_error("Test error message")
	
	# 에러 표시 확인
	assert_eq(status_label.text, "Test error message", "Should show error message")
	assert_eq(loading_label.text, "재시도", "Should show retry text")
	
	# 색상 변경 확인 (직접 확인 어려움 - 실제로는 Color 변경됨)
	var status_color = status_label.get_theme_color("font_color")
	assert_true(status_color.r > 0.8, "Error color should be red-ish")


func test_max_retries_exceeded() -> void:
	# 최대 재시도 초과 시뮬레이션
	_login_screen._retry_count = _login_screen._max_retries
	
	_transition_received = false
	_login_screen.connect("transition_requested", Callable(self, "_on_transition_requested"))

	# 에러 표시 (최대 재시도 초과)
	_login_screen._show_error("Max retries exceeded")

	# 시그널이 발생했는지 확인
	await get_tree().create_timer(4.1).timeout

	assert_true(_transition_received, "Should emit transition_requested after max retries")


func _on_transition_requested(screen) -> void:
	_transition_received = true
	# Store and free previous screen
	if _transition_screen and is_instance_valid(_transition_screen):
		_transition_screen.queue_free()
	_transition_screen = screen


func test_loading_animation() -> void:
	var loading_label = _login_screen.get_node("Label3")
	
	# 초기 상태
	assert_eq(loading_label.text, "●", "Should start with single dot")
	
	# 애니메이션 활성화
	_login_screen._is_authenticating = true
	_login_screen._animation_time = 0.0
	
	# _process 시뮬레이션 (직접 호출)
	_login_screen._process(0.5)  # 0.5초 경과
	assert_eq(loading_label.text, "●●", "Should show two dots after 0.5s")
	
	_login_screen._process(0.5)  # 추가 0.5초
	assert_eq(loading_label.text, "●●●", "Should show three dots after 1.0s")
	
	_login_screen._process(0.5)  # 추가 0.5초 (초기화)
	assert_eq(loading_label.text, "●", "Should cycle back to single dot")


func test_ui_full_rect_preset() -> void:
	assert_eq(_login_screen.anchors_preset, Control.PRESET_FULL_RECT, "Should use full rect preset")
