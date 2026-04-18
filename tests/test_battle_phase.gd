extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: BattleScreen Phase State Machine & Defensive Guards
# BattlePhase 상태 머신 및 방어 코드 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _battle: BattleScreen


func before_each() -> void:
	_battle = BattleScreen.new()
	add_child(_battle)
	await get_tree().process_frame


func after_each() -> void:
	if _battle and is_instance_valid(_battle):
		_battle.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# Phase Transitions (싱글플레이)
# ─────────────────────────────────────────────────────────────────────────────

func test_initial_phase_is_none() -> void:
	assert_eq(_battle.get_battle_phase_name(), "NONE",
		"Initial phase should be NONE")


func test_singleplayer_starts_in_playing_phase() -> void:
	_battle.start_battle("gyro")
	
	assert_eq(_battle.get_battle_phase_name(), "PLAYING",
		"Singleplayer should immediately be in PLAYING phase")
	assert_true(_battle.is_battle_active,
		"Battle should be active")
	assert_not_null(_battle.player,
		"Player should be spawned")


func test_multiplayer_starts_in_loading_phase() -> void:
	var enemies: Array[Dictionary] = [
		{"peer_id": 999, "character_id": "shamu"}
	]
	_battle.start_battle("gyro", [], enemies)
	
	assert_eq(_battle.get_battle_phase_name(), "LOADING",
		"Multiplayer should start in LOADING phase (waiting for peer)")
	assert_true(_battle.is_battle_active,
		"Battle should be active")


func test_end_battle_transitions_to_ending() -> void:
	_battle.start_battle("gyro")
	assert_eq(_battle.get_battle_phase_name(), "PLAYING")
	
	_battle.end_battle(0)
	
	# 싱글플레이에서는 end_battle → _transition_to_result 즉시 호출되므로 DONE
	assert_eq(_battle.get_battle_phase_name(), "DONE",
		"Singleplayer end_battle should go directly to DONE")
	assert_false(_battle.is_battle_active,
		"Battle should no longer be active")


func test_end_battle_prevents_duplicate_calls() -> void:
	_battle.start_battle("gyro")
	
	# 첫 번째 호출
	_battle.end_battle(0)
	assert_eq(_battle.get_battle_phase_name(), "DONE")
	
	# 중복 호출 → 무시되어야 함 (에러 없이)
	_battle.end_battle(1)
	assert_eq(_battle.get_battle_phase_name(), "DONE",
		"Duplicate end_battle should be ignored")


# ─────────────────────────────────────────────────────────────────────────────
# Handshake Simulation
# ─────────────────────────────────────────────────────────────────────────────

func test_peer_ready_transitions_to_playing() -> void:
	var enemies: Array[Dictionary] = [
		{"peer_id": 999, "character_id": "shamu"}
	]
	_battle.start_battle("gyro", [], enemies)
	
	assert_eq(_battle.get_battle_phase_name(), "LOADING")
	
	# 상대방 준비 완료 수신 시뮬레이션 (직접 호출)
	_battle._on_peer_battle_ready(999)
	
	assert_eq(_battle.get_battle_phase_name(), "PLAYING",
		"Should transition to PLAYING after peer ready")


func test_peer_ready_ignored_when_not_loading() -> void:
	_battle.start_battle("gyro")
	assert_eq(_battle.get_battle_phase_name(), "PLAYING")
	
	# PLAYING 상태에서 peer_ready → 무시
	_battle._on_peer_battle_ready(999)
	assert_eq(_battle.get_battle_phase_name(), "PLAYING",
		"peer_ready should be ignored when not LOADING")


func test_multiplayer_end_handshake() -> void:
	var enemies: Array[Dictionary] = [
		{"peer_id": 999, "character_id": "shamu"}
	]
	_battle.start_battle("gyro", [], enemies)
	_battle._on_peer_battle_ready(999)
	assert_eq(_battle.get_battle_phase_name(), "PLAYING")
	
	# 내가 먼저 종료 판정
	_battle.end_battle(0)
	assert_eq(_battle.get_battle_phase_name(), "ENDING",
		"Multiplayer end should be ENDING until peer confirms")
	
	# 상대방 종료 확인 수신
	_battle._on_peer_battle_ended(999, 0)
	assert_eq(_battle.get_battle_phase_name(), "DONE",
		"Should transition to DONE after peer confirms end")


func test_peer_ends_first() -> void:
	var enemies: Array[Dictionary] = [
		{"peer_id": 999, "character_id": "shamu"}
	]
	_battle.start_battle("gyro", [], enemies)
	_battle._on_peer_battle_ready(999)
	assert_eq(_battle.get_battle_phase_name(), "PLAYING")
	
	# 상대방이 먼저 종료 통보 → 내 쪽도 종료
	_battle._on_peer_battle_ended(999, 1)
	
	# end_battle(1) 호출됨 → ENDING → _on_peer_battle_ended 재호출되므로 최종 DONE
	assert_true(
		_battle.get_battle_phase_name() == "ENDING" or _battle.get_battle_phase_name() == "DONE",
		"Should be ENDING or DONE after peer ends first")


# ─────────────────────────────────────────────────────────────────────────────
# Character Freeze
# ─────────────────────────────────────────────────────────────────────────────

func test_characters_frozen_after_end_battle() -> void:
	_battle.start_battle("gyro")
	
	var player = _battle.player
	assert_not_null(player)
	
	# 배틀 중에는 physics_process 활성화
	assert_true(player.is_physics_processing(),
		"Player should process physics during battle")
	
	_battle.end_battle(0)
	
	# 종료 후에는 physics_process 비활성화
	assert_false(player.is_physics_processing(),
		"Player should NOT process physics after battle end")


# ─────────────────────────────────────────────────────────────────────────────
# Diagnostic Info
# ─────────────────────────────────────────────────────────────────────────────

func test_diagnostic_info() -> void:
	_battle.start_battle("gyro")
	
	var info := _battle.get_diagnostic_info()
	
	assert_eq(info["phase"], "PLAYING")
	assert_true(info["is_active"])
	assert_false(info["is_multiplayer"])
	assert_true(info["player_valid"])
	assert_eq(info["enemy_count"], 3)  # ENEMY_SPAWN_POSITIONS.size()


func test_clear_battle_resets_phase() -> void:
	_battle.start_battle("gyro")
	assert_eq(_battle.get_battle_phase_name(), "PLAYING")
	
	_battle._clear_battle()
	assert_eq(_battle.get_battle_phase_name(), "NONE",
		"Phase should reset to NONE after clear")


# ─────────────────────────────────────────────────────────────────────────────
# Force Start Timeout
# ─────────────────────────────────────────────────────────────────────────────

func test_force_start_transitions_from_loading() -> void:
	var enemies: Array[Dictionary] = [
		{"peer_id": 999, "character_id": "shamu"}
	]
	_battle.start_battle("gyro", [], enemies)
	assert_eq(_battle.get_battle_phase_name(), "LOADING")
	
	# 타임아웃 시뮬레이션
	_battle._force_start_if_loading()
	
	assert_eq(_battle.get_battle_phase_name(), "PLAYING",
		"Should force transition to PLAYING on timeout")


func test_force_start_ignored_when_already_playing() -> void:
	_battle.start_battle("gyro")
	assert_eq(_battle.get_battle_phase_name(), "PLAYING")
	
	# PLAYING 상태에서 force start → 아무 일도 안됨
	_battle._force_start_if_loading()
	assert_eq(_battle.get_battle_phase_name(), "PLAYING",
		"force_start should be ignored when already PLAYING")
