extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Joystick Double-Tap Dash
# 조이스틱을 빠르게 두 번 터치하면 대시(부스터) 발동
#
# Spec:
# - 조이스틱 릴리즈 → DOUBLE_TAP_WINDOW(0.3초) 이내 재터치 → start_boost()
# - 방향 체크 없음 (타이밍만)
# - 대시 중 조이스틱 릴리즈 → stop_boost()
# - DOUBLE_TAP_WINDOW 초과 시 대시 미발동
# - MP 부족 시 대시 미발동
# ═══════════════════════════════════════════════════════════════════════════════

var _character: Character
var _registry: CharacterRegistry


func before_each() -> void:
	_registry = CharacterRegistry.new()
	_character = Character.new()
	_character.is_controllable = true
	var data := _registry.get_character("gyro")
	_character.init(data)
	add_child(_character)
	await get_tree().process_frame


func after_each() -> void:
	if _character and is_instance_valid(_character):
		_character.queue_free()
	_character = null


# ─────────────────────────────────────────────────────────────────────────────
# Double-Tap Detection
# ─────────────────────────────────────────────────────────────────────────────

func test_double_tap_triggers_boost() -> void:
	# 첫 번째 탭: 조이스틱 눌렀다 뗌
	_character.notify_joystick_pressed()
	_character.notify_joystick_released()
	
	# 짧은 시간 내 두 번째 탭
	_character.notify_joystick_pressed()
	
	assert_true(_character.is_boosting,
		"Double-tap within window should trigger boost")


func test_slow_double_tap_does_not_trigger_boost() -> void:
	# 첫 번째 탭
	_character.notify_joystick_pressed()
	_character.notify_joystick_released()
	
	# DOUBLE_TAP_WINDOW 초과 대기 시뮬레이션
	_character._double_tap_timer = 0.0  # 타이머 만료
	
	# 두 번째 탭 (너무 늦음)
	_character.notify_joystick_pressed()
	
	assert_false(_character.is_boosting,
		"Tap after window expired should NOT trigger boost")


func test_boost_stops_on_joystick_release() -> void:
	# 더블탭으로 부스트 시작
	_character.notify_joystick_pressed()
	_character.notify_joystick_released()
	_character.notify_joystick_pressed()
	
	assert_true(_character.is_boosting, "Should be boosting after double-tap")
	
	# 조이스틱 릴리즈 → 부스트 종료
	_character.notify_joystick_released()
	
	assert_false(_character.is_boosting,
		"Boost should stop when joystick is released")


func test_no_boost_without_mp() -> void:
	# MP를 0으로 소진 (final_max_mp는 카드 보정 후 값이므로 current_mp 사용)
	_character.use_mp(_character.current_mp)
	assert_eq(_character.current_mp, 0, "MP should be 0")
	
	# 더블탭 시도
	_character.notify_joystick_pressed()
	_character.notify_joystick_released()
	_character.notify_joystick_pressed()
	
	assert_false(_character.is_boosting,
		"Should NOT boost without MP")


func test_single_tap_does_not_trigger_boost() -> void:
	# 한 번만 탭 → 부스트 안됨
	_character.notify_joystick_pressed()
	
	assert_false(_character.is_boosting,
		"Single tap should NOT trigger boost")


func test_double_tap_timer_decreases_over_time() -> void:
	# 첫 번째 탭 → 릴리즈
	_character.notify_joystick_pressed()
	_character.notify_joystick_released()
	
	# 타이머가 설정되었는지 확인
	assert_true(_character._double_tap_timer > 0.0,
		"Double-tap timer should be set after release")
	
	# 시간 경과 시뮬레이션
	_character._update_double_tap_timer(0.1)
	
	assert_true(_character._double_tap_timer > 0.0,
		"Timer should still be active after 0.1s (window is 0.3s)")
	
	# 전체 윈도우 경과
	_character._update_double_tap_timer(0.3)
	
	assert_eq(_character._double_tap_timer, 0.0,
		"Timer should be 0 after full window passes")


func test_booster_button_still_works() -> void:
	# 기존 booster 버튼 방식도 여전히 동작하는지 확인
	_character.start_boost()
	
	assert_true(_character.is_boosting,
		"Direct start_boost() should still work")
	
	_character.stop_boost()
	
	assert_false(_character.is_boosting,
		"Direct stop_boost() should still work")


func test_triple_tap_does_not_double_boost() -> void:
	# 더블탭으로 부스트 시작
	_character.notify_joystick_pressed()
	_character.notify_joystick_released()
	_character.notify_joystick_pressed()
	
	assert_true(_character.is_boosting, "Should be boosting")
	
	# 세 번째 탭 (이미 부스팅 중)
	_character.notify_joystick_released()
	
	assert_false(_character.is_boosting,
		"Release during boost should stop boost")


func test_double_tap_with_dead_character_does_nothing() -> void:
	# 캐릭터 사망
	_character.take_damage(_character.character_data.max_hp + 100)
	assert_true(_character.is_dead, "Character should be dead")
	
	# 더블탭 시도
	_character.notify_joystick_pressed()
	_character.notify_joystick_released()
	_character.notify_joystick_pressed()
	
	assert_false(_character.is_boosting,
		"Dead character should NOT boost")
