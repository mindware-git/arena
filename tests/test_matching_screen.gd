extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: MatchingScreen.gd - Matchmaking UI
# 매칭 화면의 UI 및 매칭 로직 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _matching_screen: MatchingScreen
var _timeout_called: bool = false
var _cancel_signal_received: bool = false

func before_each() -> void:
	_matching_screen = MatchingScreen.new()
	add_child(_matching_screen)


func after_each() -> void:
	if _matching_screen:
		_matching_screen.queue_free()
		_matching_screen = null


func test_initial_ui_setup() -> void:
	# UI 요소들이 생성되었는지 확인
	assert_not_null(_matching_screen.get_node_or_null("Label"), "Should have title label")
	assert_not_null(_matching_screen.get_node_or_null("Label2"), "Should have time label")
	assert_not_null(_matching_screen.get_node_or_null("Label3"), "Should have status label")
	assert_not_null(_matching_screen.get_node_or_null("Button"), "Should have cancel button")
	
	# 플레이어 슬롯 컨테이너 확인
	var slots_container = _matching_screen.get_node_or_null("HBoxContainer")
	assert_not_null(slots_container, "Should have player slots container")
	
	# 초기 상태 확인
	var title_label = _matching_screen.get_node("Label")
	assert_eq(title_label.text, "매칭 중...", "Should show matching title")
	
	var status_label = _matching_screen.get_node("Label3")
	assert_eq(status_label.text, "플레이어 찾는 중...", "Should show searching status")


func test_time_display() -> void:
	var time_label = _matching_screen.get_node("Label2")
	
	# 초기 시간
	assert_eq(time_label.text, "00:00", "Should start at 00:00")
	
	# 시간 업데이트 시뮬레이션
	_matching_screen._elapsed_time = 65.5  # 1분 5.5초
	_matching_screen._update_time_display()
	assert_eq(time_label.text, "01:05", "Should display 01:05")
	
	_matching_screen._elapsed_time = 3661.0  # 1시간 1분 1초
	_matching_screen._update_time_display()
	assert_eq(time_label.text, "61:01", "Should display 61:01")


func test_matching_timeout() -> void:
	# 타임아웃 설정 확인
	assert_eq(_matching_screen._matching_timeout, 30.0, "Should have 30 second timeout")
	
	# 타임아웃 시뮬레이션
	_matching_screen._is_matching = true
	_matching_screen._elapsed_time = 30.1  # 타임아웃 초과
	_timeout_called = false
	_matching_screen.connect("timeout_occurred", Callable(self, "_on_timeout"))
	
	# _process에서 타임아웃 감지 (직접 호출)
	_matching_screen._process(0.1)
	
	assert_true(_timeout_called, "Timeout should emit timeout_occurred signal")


func _on_timeout() -> void:
	_timeout_called = true


func test_retry_logic() -> void:
	# 재시도 카운트 초기화 확인
	assert_eq(_matching_screen._retry_count, 0, "Retry count should start at 0")
	assert_eq(_matching_screen._max_retries, 3, "Max retries should be 3")
	
	# 재시도 증가
	_matching_screen._retry_count = 2
	assert_eq(_matching_screen._retry_count, 2, "Retry count should be settable")


func test_player_slots_creation() -> void:
	var slots_container = _matching_screen.get_node("HBoxContainer")
	
	# 슬롯들이 생성되었는지 확인
	var player1_slot = slots_container.get_child(0)
	var vs_label = slots_container.get_child(1)
	var player2_slot = slots_container.get_child(2)
	
	assert_not_null(player1_slot, "Should have player 1 slot")
	assert_not_null(vs_label, "Should have VS label")
	assert_not_null(player2_slot, "Should have player 2 slot")
	
	# VS 라벨 확인
	assert_eq(vs_label.text, "VS", "VS label should show VS")
	
	# 플레이어 슬롯 구조 확인
	var p1_content = player1_slot.get_child(0)
	assert_eq(p1_content.get_child_count(), 3, "Player slot should have 3 children (avatar, name, status)")


func test_cancel_button() -> void:
	var cancel_btn = _matching_screen.get_node("Button")
	
	# 초기 상태
	assert_eq(cancel_btn.text, "취소", "Cancel button should show 취소")
	assert_false(cancel_btn.disabled, "Cancel button should be enabled")
	
	# 매칭 중 상태 변경 시뮬레이션
	_matching_screen._is_matching = true
	cancel_btn.text = "취소"
	cancel_btn.disabled = false
	
	# 취소 버튼 클릭 시뮬레이션
	_cancel_signal_received = false
	_matching_screen.connect("transition_requested", Callable(self, "_on_cancel_transition"))
	
	cancel_btn.emit_signal("pressed")
	
	assert_true(_cancel_signal_received, "Cancel should trigger transition")


func _on_cancel_transition(screen) -> void:
	_cancel_signal_received = true


func test_ui_full_rect_preset() -> void:
	assert_eq(_matching_screen.anchors_preset, Control.PRESET_FULL_RECT, "Should use full rect preset")


func test_matching_states() -> void:
	# 초기 상태
	assert_false(_matching_screen._is_matching, "Should not be matching initially")
	assert_eq(_matching_screen._elapsed_time, 0.0, "Elapsed time should start at 0")
	
	# 매칭 시작
	_matching_screen._start_matching()
	assert_true(_matching_screen._is_matching, "Should be matching after start")
	assert_eq(_matching_screen._elapsed_time, 0.0, "Elapsed time should reset on start")