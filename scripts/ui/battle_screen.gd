class_name BattleScreen
extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
# Battle Screen
# 실제 게임 플레이 화면 (Arena)
# - battle.gd의 모든 기능을 통합
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)
signal battle_started()
signal battle_ended(winning_team: int)
signal player_spawned(player: Character)
signal enemy_spawned(enemy: Character)
signal character_died(character: Character)

# ═══════════════════════════════════════════════════════════════════════════════
# Battle Phase (방어적 상태 머신)
# ═══════════════════════════════════════════════════════════════════════════════

enum BattlePhase {
	NONE,       # 아직 시작 안됨
	LOADING,    # 캐릭터 스폰 완료, peer 준비 대기
	PLAYING,    # 양측 준비 완료, 게임 진행 중
	ENDING,     # 승패 결정, 종료 처리 중
	DONE,       # 결과 화면 전환 완료
}

var _battle_phase: int = BattlePhase.NONE

# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

const PLAYER_SPAWN_POSITION := Vector2(200, 300)
const ENEMY_SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(500, 200),
	Vector2(600, 300),
	Vector2(500, 400),
]

const BATTLE_HUD_SCENE = preload("res://scenes/ui/battle_hud.tscn")
const MAP_DRAGON_SCENE = preload("res://scenes/map/dragon.tscn")
# ═══════════════════════════════════════════════════════════════════════════════
# Variables
# ═══════════════════════════════════════════════════════════════════════════════

var _registry: CharacterRegistry
var _player: Character
var _enemies: Array[Character] = []

# 배틀 상태
var _is_battle_active: bool = false
var _battle_time: float = 0.0
var _kill_count: int = 0

# 멀티플레이어
var _is_multiplayer: bool = false
var _remote_players: Dictionary = {}  # peer_id -> Character
var _peers_ready: Dictionary = {}     # peer_id -> bool (배틀 시작 핸드셰이크)
var _peers_ended: Dictionary = {}     # peer_id -> bool (배틀 종료 확인)

# 대기 중인 배틀 데이터 (_ready에서 처리)
var _pending_battle_data: Dictionary = {}

# UI
var _battle_hud: CanvasLayer
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _bp_bar: ProgressBar
var _time_label: Label
var _kill_count_label: Label
var _player_name_label: Label

# ═══════════════════════════════════════════════════════════════════════════════
# Properties
# ═══════════════════════════════════════════════════════════════════════════════

var player: Character:
	get: return _player

var enemies: Array[Character]:
	get: return _enemies

var is_battle_active: bool:
	get: return _is_battle_active

var battle_time: float:
	get: return _battle_time

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_registry = CharacterRegistry.new()
	
	# 드래곤 맵 로드 및 추가
	var map := MAP_DRAGON_SCENE.instantiate()
	add_child(map)
	
	_create_battle_ui()
	
	# 대기 중인 배틀 데이터가 있으면 시작
	if not _pending_battle_data.is_empty():
		start_battle(
			_pending_battle_data.get("my_character_id", ""),
			_pending_battle_data.get("allies", []),
			_pending_battle_data.get("enemies", [])
		)
		_pending_battle_data.clear()


func _process(delta: float) -> void:
	if not _is_battle_active:
		return
	
	# PLAYING 상태에서만 배틀 로직 실행
	if _battle_phase != BattlePhase.PLAYING:
		return
	
	_battle_time += delta
	_check_battle_end_conditions()
	_update_battle_ui()

# ═══════════════════════════════════════════════════════════════════════════════
# UI
# ═══════════════════════════════════════════════════════════════════════════════

func _create_battle_ui() -> void:
	# BattleHUD 인스턴스화
	_battle_hud = BATTLE_HUD_SCENE.instantiate()
	add_child(_battle_hud)
	_setup_action_buttons()
	
	# 추가 UI 컨테이너 (HP/MP/BP 바, 시간, 킬 카운트)
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)
	
	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(control)
	
	# 상단 정보 패널
	var top_panel := HBoxContainer.new()
	top_panel.position = Vector2(10, 10)
	control.add_child(top_panel)
	
	# 플레이어 이름
	_player_name_label = Label.new()
	_player_name_label.add_theme_font_size_override("font_size", 18)
	_player_name_label.add_theme_color_override("font_color", Color.CYAN)
	top_panel.add_child(_player_name_label)
	
	# 스탯 컨테이너
	var stats_panel := VBoxContainer.new()
	stats_panel.position = Vector2(10, 40)
	control.add_child(stats_panel)
	
	# HP 바
	var hp_container := HBoxContainer.new()
	stats_panel.add_child(hp_container)
	
	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.custom_minimum_size = Vector2(30, 20)
	hp_container.add_child(hp_label)
	
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(200, 20)
	_hp_bar.show_percentage = false
	hp_container.add_child(_hp_bar)
	
	# MP 바
	var mp_container := HBoxContainer.new()
	stats_panel.add_child(mp_container)
	
	var mp_label := Label.new()
	mp_label.text = "MP"
	mp_label.custom_minimum_size = Vector2(30, 20)
	mp_container.add_child(mp_label)
	
	_mp_bar = ProgressBar.new()
	_mp_bar.custom_minimum_size = Vector2(200, 20)
	_mp_bar.show_percentage = false
	mp_container.add_child(_mp_bar)
	
	# BP 바
	var bp_container := HBoxContainer.new()
	stats_panel.add_child(bp_container)
	
	var bp_label := Label.new()
	bp_label.text = "BP"
	bp_label.custom_minimum_size = Vector2(30, 20)
	bp_container.add_child(bp_label)
	
	_bp_bar = ProgressBar.new()
	_bp_bar.custom_minimum_size = Vector2(200, 20)
	_bp_bar.show_percentage = false
	bp_container.add_child(_bp_bar)
	
	# 우측 상단: 시간, 킬 카운트
	var right_panel := VBoxContainer.new()
	right_panel.position = Vector2(700, 10)
	right_panel.alignment = BoxContainer.ALIGNMENT_END
	control.add_child(right_panel)
	
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(_time_label)
	
	_kill_count_label = Label.new()
	_kill_count_label.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(_kill_count_label)


func _setup_action_buttons() -> void:
	var hbox: HBoxContainer = _battle_hud.get_node("Control/Control/HBoxContainer")
	if not hbox:
		push_error("HBoxContainer not found in BattleHUD")
		return
	
	# HBoxContainer offset 설정 (화면 하단에서 20px 위로)
	hbox.offset_bottom = -20
	
	var template_btn: TouchScreenButton = hbox.get_node("TouchScreenButton")
	if not template_btn:
		push_error("TouchScreenButton template not found")
		return
	
	# 버튼 크기 및 간격 설정
	const BUTTON_SIZE := 80
	const BUTTON_SPACING := 10
	
	# 대쉬 버튼 (첫 번째)
	template_btn.action = "booster"
	template_btn.name = "DashButton"
	template_btn.position = Vector2(0, 0)
	_create_button_texture(template_btn, Color(0.2, 0.6, 0.9))
	
	# 기본 공격 버튼 (두 번째) - attack_type1
	var attack1_btn: TouchScreenButton = template_btn.duplicate()
	attack1_btn.action = "attack_type1"
	attack1_btn.name = "Attack1Button"
	attack1_btn.position = Vector2(BUTTON_SIZE + BUTTON_SPACING, 0)
	_create_button_texture(attack1_btn, Color(0.9, 0.4, 0.2))
	hbox.add_child(attack1_btn)
	
	# 보조 공격 버튼 (세 번째) - attack_type2
	var attack2_btn: TouchScreenButton = template_btn.duplicate()
	attack2_btn.action = "attack_type2"
	attack2_btn.name = "Attack2Button"
	attack2_btn.position = Vector2((BUTTON_SIZE + BUTTON_SPACING) * 2, 0)
	_create_button_texture(attack2_btn, Color(0.6, 0.2, 0.8))
	hbox.add_child(attack2_btn)
	
	# 필살기 버튼 (네 번째)
	var special_btn: TouchScreenButton = template_btn.duplicate()
	special_btn.action = "attack_special"
	special_btn.name = "SpecialButton"
	special_btn.position = Vector2((BUTTON_SIZE + BUTTON_SPACING) * 3, 0)
	_create_button_texture(special_btn, Color(1.0, 0.8, 0.0))  # 금색
	hbox.add_child(special_btn)


func _create_button_texture(btn: TouchScreenButton, color: Color) -> void:
	var image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	btn.texture_normal = texture
	
	var pressed_image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	pressed_image.fill(color.lightened(0.3))
	btn.texture_pressed = ImageTexture.create_from_image(pressed_image)


func _update_battle_ui() -> void:
	if not _player or not _player.character_data:
		return
	
	# HP/MP/BP 바 업데이트
	_hp_bar.max_value = _player.character_data.max_hp
	_hp_bar.value = _player.current_hp
	
	_mp_bar.max_value = _player.character_data.max_mp
	_mp_bar.value = _player.current_mp
	
	_bp_bar.max_value = _player.character_data.max_bp
	_bp_bar.value = _player.current_bp
	
	# 플레이어 이름
	_player_name_label.text = _player.character_data.display_name
	
	# 시간
	var minutes := int(_battle_time) / 60
	var seconds := int(_battle_time) % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]
	
	# 킬 카운트
	_kill_count_label.text = "Kills: %d" % _kill_count

# ═══════════════════════════════════════════════════════════════════════════════
# Battle Control
# ═══════════════════════════════════════════════════════════════════════════════

func start_battle(
	my_character_id: String,
	allies: Array[Dictionary] = [],   # [{"peer_id": int, "character_id": String}, ...]
	enemies: Array[Dictionary] = []   # [{"peer_id": int, "character_id": String}, ...]
) -> void:
	print("[Battle] start_battle: phase=%s, char=%s" % [BattlePhase.keys()[_battle_phase], my_character_id])
	
	# 방어: 이미 진행 중인 배틀이 있으면 무시
	assert(_battle_phase == BattlePhase.NONE or _battle_phase == BattlePhase.DONE,
		"start_battle called in invalid phase: %s" % BattlePhase.keys()[_battle_phase])
	
	# _ready()보다 먼저 호출될 수 있으므로 null 체크
	if not _registry:
		_registry = CharacterRegistry.new()
	
	_clear_battle()
	_kill_count = 0
	_battle_phase = BattlePhase.LOADING
	
	# 내 플레이어 스폰 (로컬 제어)
	var player_node := spawn_player(my_character_id)
	assert(player_node != null, "Failed to spawn player: %s" % my_character_id)
	
	# 아군 스폰 (네트워크 제어)
	for i in range(allies.size()):
		var ally := allies[i]
		var peer_id: int = ally.get("peer_id", 0)
		var char_id: String = ally.get("character_id", "")
		assert(peer_id > 0, "Ally peer_id must be > 0, got: %d" % peer_id)
		assert(not char_id.is_empty(), "Ally character_id must not be empty")
		if peer_id > 0 and not char_id.is_empty():
			var pos := PLAYER_SPAWN_POSITION + Vector2(100 * (i + 1), 0)
			setup_network_player(peer_id, char_id, false, pos)
	
	# 적군 스폰 (네트워크 제어 또는 기본 AI 적)
	_is_multiplayer = false
	if enemies.is_empty():
		# 기본 AI 적 스폰 (싱글플레이)
		for i in range(ENEMY_SPAWN_POSITIONS.size()):
			spawn_enemy("enemy_slime", ENEMY_SPAWN_POSITIONS[i])
	else:
		_is_multiplayer = true
		# 네트워크 플레이어 적 스폰
		for i in range(enemies.size()):
			var enemy := enemies[i]
			var peer_id: int = enemy.get("peer_id", 0)
			var char_id: String = enemy.get("character_id", "")
			assert(peer_id > 0, "Enemy peer_id must be > 0, got: %d" % peer_id)
			assert(not char_id.is_empty(), "Enemy character_id must not be empty")
			if peer_id > 0 and not char_id.is_empty():
				var pos := ENEMY_SPAWN_POSITIONS[i % ENEMY_SPAWN_POSITIONS.size()]
				setup_network_player(peer_id, char_id, false, pos)
	
	_is_battle_active = true
	_battle_time = 0.0
	
	# ── 핸드셰이크: 멀티플레이어면 준비 신호 교환 ──
	if _is_multiplayer and _remote_players.size() > 0:
		# 초기화: 모든 원격 peer를 미준비 상태로
		_peers_ready.clear()
		for peer_id in _remote_players:
			_peers_ready[peer_id] = false
		
		# 내 캐릭터 노드에 배틀 시작 방어 플래그 설정
		if _player and is_instance_valid(_player):
			_player.set_physics_process(false)  # 준비 완료까지 움직이지 않음
		
		print("[Battle] LOADING: 상대방 준비 대기 중... peers=%s" % str(_peers_ready.keys()))
		
		# 상대방에게 준비 완료 신호 전송
		rpc("_on_peer_battle_ready", _get_my_peer_id())
		
		# 타임아웃 (5초 내 준비 안되면 강제 시작)
		get_tree().create_timer(5.0).timeout.connect(_force_start_if_loading)
	else:
		# 싱글플레이: 즉시 PLAYING
		_battle_phase = BattlePhase.PLAYING
		print("[Battle] PLAYING (singleplayer)")
	
	battle_started.emit()


func end_battle(winning_team: int) -> void:
	# 방어: 이미 종료 중이면 무시 (중복 호출 방지)
	if _battle_phase == BattlePhase.ENDING or _battle_phase == BattlePhase.DONE:
		print("[Battle] end_battle 중복 호출 무시 (phase=%s)" % BattlePhase.keys()[_battle_phase])
		return
	
	print("[Battle] end_battle: winning_team=%d, phase=%s" % [winning_team, BattlePhase.keys()[_battle_phase]])
	
	_battle_phase = BattlePhase.ENDING
	_is_battle_active = false
	battle_ended.emit(winning_team)
	
	# ── 즉시 모든 게임플레이 동작 정지 ──
	_freeze_all_characters()
	_cleanup_projectiles()
	
	# ── 멀티플레이어: 상대에게 배틀 종료 통보 ──
	if _is_multiplayer and _remote_players.size() > 0:
		_peers_ended.clear()
		for peer_id in _remote_players:
			_peers_ended[peer_id] = false
		
		print("[Battle] ENDING: 상대방 종료 확인 대기 중...")
		rpc("_on_peer_battle_ended", _get_my_peer_id(), winning_team)
		
		# 타임아웃 (3초 내 확인 안되면 강제 전환)
		get_tree().create_timer(3.0).timeout.connect(
			func():
				if _battle_phase == BattlePhase.ENDING:
					print("[Battle] WARNING: 종료 확인 타임아웃, 강제 전환")
					_transition_to_result(winning_team)
		)
	else:
		# 싱글플레이: 즉시 결과 전환 예약
		_transition_to_result(winning_team)


## 모든 캐릭터의 물리 업데이트 중지
func _freeze_all_characters() -> void:
	if _player and is_instance_valid(_player):
		_player.set_physics_process(false)
		_player.set_process(false)
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
			enemy.set_process(false)
	for peer_id in _remote_players:
		var character: Character = _remote_players[peer_id]
		if is_instance_valid(character):
			character.set_physics_process(false)
			character.set_process(false)


## 남아있는 투사체 제거
func _cleanup_projectiles() -> void:
	for child in get_children():
		if child is Projectile:
			child.queue_free()


## 결과 화면 전환 (2초 딜레이)
func _transition_to_result(winning_team: int) -> void:
	if _battle_phase == BattlePhase.DONE:
		return
	
	var is_victory := (winning_team == 0)
	_battle_phase = BattlePhase.DONE
	print("[Battle] DONE: 결과 화면 전환 예약 (승리=%s)" % str(is_victory))
	
	# 2초 후 결과 화면으로 전환
	get_tree().create_timer(2.0).timeout.connect(
		func():
			var result := ResultScreen.new()
			result.set_result(is_victory, _battle_time)
			transition_requested.emit(result)
	)


func reset_battle() -> void:
	_clear_battle()
	start_battle("gyro")  # 기본 캐릭터로 리셋


func _clear_battle() -> void:
	# 플레이어 제거
	if _player and is_instance_valid(_player):
		_player.queue_free()
	_player = null
	
	# 적들 제거
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	
	# 네트워크 플레이어 정리
	for peer_id in _remote_players:
		var character: Character = _remote_players[peer_id]
		if is_instance_valid(character):
			character.queue_free()
	_remote_players.clear()
	_peers_ready.clear()
	_peers_ended.clear()
	
	_is_battle_active = false
	_battle_time = 0.0
	_battle_phase = BattlePhase.NONE

# ═══════════════════════════════════════════════════════════════════════════════
# Character Spawning
# ═══════════════════════════════════════════════════════════════════════════════

func spawn_player(character_id: String) -> Character:
	var data := _registry.get_character(character_id)
	if not data:
		push_warning("Player character not found: " + character_id)
		return null
	
	_player = Character.new()
	_player.is_controllable = true  # init() 전에 설정해야 카메라가 활성화됨
	_player.init(data)
	
	var random_offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
	_player.position = PLAYER_SPAWN_POSITION + random_offset
	
	# 노드 이름을 내 peer_id로 설정 (RPC 경로 일치)
	# OnlineMatch.players의 키 중 하나가 내 peer_id
	var my_peer_id := _get_my_peer_id()
	_player.name = "Character_%d" % my_peer_id
	
	# 네트워크 권한 설정 (내 캐릭터는 내가 제어)
	_player.set_multiplayer_authority(my_peer_id)
	
	#print("[DEBUG] Local player name set: %s, peer_id=%s, authority=%s" % [_player.name, my_peer_id, _player.get_multiplayer_authority()])
	
	# 시그널 연결
	_player.died.connect(_on_player_died)
	
	# force_readable_name=true로 RPC 경로 일치 보장
	add_child(_player, true)
	player_spawned.emit(_player)
	
	return _player


func set_battle_data(my_character_id: String, allies: Array[Dictionary] = [], enemies: Array[Dictionary] = []) -> void:
	"""배틀 데이터 설정. _ready()에서 start_battle()이 호출됨."""
	_pending_battle_data = {
		"my_character_id": my_character_id,
		"allies": allies,
		"enemies": enemies
	}


func _get_my_peer_id() -> int:
	# SceneTree의 multiplayer 사용
	var mp = multiplayer
	if mp and mp.has_multiplayer_peer():
		return mp.get_unique_id()
	
	# 최종 Fallback
	#print("[DEBUG] Warning: No multiplayer peer available, returning 1")
	return 1


func spawn_enemy(character_id: String, position: Vector2 = Vector2.ZERO) -> Character:
	var data := _registry.get_character(character_id)
	if not data:
		push_error("Enemy character not found: " + character_id)
		return null
	
	var enemy := Character.new()
	enemy.init(data)
	
	var final_pos := position if position != Vector2.ZERO else ENEMY_SPAWN_POSITIONS[_enemies.size() % ENEMY_SPAWN_POSITIONS.size()]
	var random_offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
	enemy.position = final_pos + random_offset
	
	enemy.is_controllable = false
	
	# 시그널 연결
	enemy.died.connect(_on_enemy_died.bind(enemy))
	
	add_child(enemy)
	_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	
	return enemy


func spawn_enemy_at_random_position(character_id: String) -> Character:
	var random_x := randf_range(400, 700)
	var random_y := randf_range(150, 450)
	return spawn_enemy(character_id, Vector2(random_x, random_y))

# ═══════════════════════════════════════════════════════════════════════════════
# Battle State
# ═══════════════════════════════════════════════════════════════════════════════

func _check_battle_end_conditions() -> void:
	# 방어: PLAYING 상태에서만 판정
	if _battle_phase != BattlePhase.PLAYING:
		return
	
	# 플레이어 사망 체크
	if _player and _player.is_dead:
		end_battle(1)  # 적 팀 승리
		return
	
	# 모든 적 처치 체크
	var all_enemies_dead := true
	for enemy in _enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			all_enemies_dead = false
			break
	
	if all_enemies_dead and _enemies.size() > 0:
		end_battle(0)  # 플레이어 팀 승리


func get_alive_enemy_count() -> int:
	var count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			count += 1
	return count


func get_battle_info() -> Dictionary:
	return {
		"is_active": _is_battle_active,
		"battle_time": _battle_time,
		"player_hp": _player.current_hp if _player else 0,
		"player_max_hp": _player.character_data.max_hp if _player and _player.character_data else 0,
		"enemy_count": _enemies.size(),
		"alive_enemy_count": get_alive_enemy_count(),
		"kill_count": _kill_count,
	}

# ═══════════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════════

func _on_player_died() -> void:
	character_died.emit(_player)


func _on_enemy_died(enemy: Character) -> void:
	character_died.emit(enemy)
	_kill_count += 1

# ═══════════════════════════════════════════════════════════════════════════════
# Network Sync (for multiplayer)
# ═══════════════════════════════════════════════════════════════════════════════

func setup_network_player(peer_id: int, character_id: String, is_local: bool, spawn_pos: Vector2 = Vector2.ZERO) -> Character:
	assert(peer_id > 0, "setup_network_player: peer_id must be > 0, got %d" % peer_id)
	assert(not character_id.is_empty(), "setup_network_player: character_id must not be empty")
	
	var data := _registry.get_character(character_id)
	if not data:
		push_error("Network character not found: " + character_id)
		return null
	
	var character := Character.new()
	character.is_controllable = is_local  # init() 전에 설정
	character.init(data)
	
	var final_pos := spawn_pos if spawn_pos != Vector2.ZERO else PLAYER_SPAWN_POSITION
	var random_offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
	character.position = final_pos + random_offset
	
	character.set_network_controlled(not is_local)
	
	# 노드 이름을 peer_id로 설정 (RPC 경로 일치)
	character.name = "Character_%d" % peer_id
	
	# 네트워크 권한 설정 (Godot 4: set_multiplayer_authority)
	# 해당 peer가 이 노드의 RPC를 제어
	character.set_multiplayer_authority(peer_id)
	
	print("[Battle] Network player: name=%s, peer=%d, local=%s, authority=%d" % [
		character.name, peer_id, is_local, character.get_multiplayer_authority()])
	
	# force_readable_name=true로 RPC 경로 일치 보장
	add_child(character, true)
	
	if is_local:
		_player = character
		character.died.connect(_on_player_died)
		player_spawned.emit(character)
	else:
		_remote_players[peer_id] = character
		_enemies.append(character)
		character.died.connect(_on_enemy_died.bind(character))
		enemy_spawned.emit(character)
	
	return character

# ═══════════════════════════════════════════════════════════════════════════════
# Battle Handshake RPC (배틀 시작/종료 핸드셰이크)
# ═══════════════════════════════════════════════════════════════════════════════

## 상대방이 배틀 준비 완료를 알려옴
@rpc("any_peer", "call_remote", "reliable")
func _on_peer_battle_ready(peer_id: int) -> void:
	print("[Battle] Peer ready received: peer_id=%d, current_phase=%s" % [peer_id, BattlePhase.keys()[_battle_phase]])
	
	# 방어: LOADING 상태가 아니면 무시 (늦게 도착한 패킷)
	if _battle_phase != BattlePhase.LOADING:
		print("[Battle] WARNING: peer_ready 무시 (phase=%s)" % BattlePhase.keys()[_battle_phase])
		return
	
	_peers_ready[peer_id] = true
	_check_all_peers_ready()


## 모든 peer가 준비되었는지 확인
func _check_all_peers_ready() -> void:
	for peer_id in _peers_ready:
		if not _peers_ready[peer_id]:
			return
	
	# 모두 준비 완료 → PLAYING 전환
	print("[Battle] All peers ready! → PLAYING")
	_battle_phase = BattlePhase.PLAYING
	
	# 플레이어 물리 활성화
	if _player and is_instance_valid(_player):
		_player.set_physics_process(true)


## LOADING 상태에서 타임아웃 시 강제 시작
func _force_start_if_loading() -> void:
	if _battle_phase == BattlePhase.LOADING:
		print("[Battle] WARNING: 준비 대기 타임아웃 (5초), 강제 PLAYING 전환")
		for peer_id in _peers_ready:
			if not _peers_ready[peer_id]:
				print("[Battle]   미응답 peer: %d" % peer_id)
		_battle_phase = BattlePhase.PLAYING
		if _player and is_instance_valid(_player):
			_player.set_physics_process(true)


## 상대방이 배틀 종료를 알려옴
@rpc("any_peer", "call_remote", "reliable")
func _on_peer_battle_ended(peer_id: int, winning_team: int) -> void:
	print("[Battle] Peer ended received: peer_id=%d, winning_team=%d, phase=%s" % [
		peer_id, winning_team, BattlePhase.keys()[_battle_phase]])
	
	# 상대가 먼저 종료 통보 → 내 쪽도 종료 처리
	if _battle_phase == BattlePhase.PLAYING:
		print("[Battle] 상대방이 먼저 종료 판정, 동기화하여 종료")
		end_battle(winning_team)
		return
	
	# 내가 먼저 종료 판정한 경우 → 확인 처리
	if _battle_phase == BattlePhase.ENDING:
		_peers_ended[peer_id] = true
		_check_all_peers_ended(winning_team)
		return
	
	print("[Battle] WARNING: peer_ended 무시 (phase=%s)" % BattlePhase.keys()[_battle_phase])


## 모든 peer가 종료를 확인했는지 확인
func _check_all_peers_ended(winning_team: int) -> void:
	for peer_id in _peers_ended:
		if not _peers_ended[peer_id]:
			return
	
	print("[Battle] All peers confirmed end → DONE")
	_transition_to_result(winning_team)


# ═══════════════════════════════════════════════════════════════════════════════
# Debug / Diagnostics
# ═══════════════════════════════════════════════════════════════════════════════

## 현재 배틀 상태 진단 정보
func get_battle_phase_name() -> String:
	return BattlePhase.keys()[_battle_phase]


func get_diagnostic_info() -> Dictionary:
	return {
		"phase": get_battle_phase_name(),
		"is_active": _is_battle_active,
		"is_multiplayer": _is_multiplayer,
		"battle_time": _battle_time,
		"player_valid": _player != null and is_instance_valid(_player),
		"enemy_count": _enemies.size(),
		"remote_player_count": _remote_players.size(),
		"peers_ready": _peers_ready.duplicate(),
		"peers_ended": _peers_ended.duplicate(),
	}
