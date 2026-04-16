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

signal battle_started()
signal battle_ended(winning_team: int)
signal player_spawned(player: Character)
signal enemy_spawned(enemy: Character)
signal character_died(character: Character)

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
	_create_battle_ui()


func _process(delta: float) -> void:
	if not _is_battle_active:
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

func start_battle(player_character_id: String, enemy_character_ids: Array[String] = []) -> void:
	_clear_battle()
	_kill_count = 0
	
	# 플레이어 스폰
	spawn_player(player_character_id)
	
	# 적 스폰
	if enemy_character_ids.is_empty():
		# 기본 적 스폰
		for i in range(ENEMY_SPAWN_POSITIONS.size()):
			spawn_enemy("enemy_slime", ENEMY_SPAWN_POSITIONS[i])
	else:
		# 지정된 적 스폰
		for i in range(enemy_character_ids.size()):
			var pos := ENEMY_SPAWN_POSITIONS[i % ENEMY_SPAWN_POSITIONS.size()]
			spawn_enemy(enemy_character_ids[i], pos)
	
	_is_battle_active = true
	_battle_time = 0.0
	battle_started.emit()


func end_battle(winning_team: int) -> void:
	_is_battle_active = false
	battle_ended.emit(winning_team)


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
	
	_is_battle_active = false
	_battle_time = 0.0

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
	_player.position = PLAYER_SPAWN_POSITION
	
	# 시그널 연결
	_player.died.connect(_on_player_died)
	
	add_child(_player)
	player_spawned.emit(_player)
	
	return _player


func spawn_enemy(character_id: String, position: Vector2 = Vector2.ZERO) -> Character:
	var data := _registry.get_character(character_id)
	if not data:
		push_error("Enemy character not found: " + character_id)
		return null
	
	var enemy := Character.new()
	enemy.init(data)
	enemy.position = position if position != Vector2.ZERO else ENEMY_SPAWN_POSITIONS[_enemies.size() % ENEMY_SPAWN_POSITIONS.size()]
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
	# 적 제거 (약간의 딜레이 후)
	call_deferred("_remove_enemy", enemy)


func _remove_enemy(enemy: Character) -> void:
	if _enemies.has(enemy):
		_enemies.erase(enemy)
	if is_instance_valid(enemy):
		enemy.queue_free()

# ═══════════════════════════════════════════════════════════════════════════════
# Network Sync (for multiplayer)
# ═══════════════════════════════════════════════════════════════════════════════

func setup_network_player(peer_id: int, character_id: String, is_local: bool) -> Character:
	var data := _registry.get_character(character_id)
	if not data:
		return null
	
	var character := Character.new()
	character.is_controllable = is_local  # init() 전에 설정
	character.init(data)
	character.position = PLAYER_SPAWN_POSITION
	character.set_network_controlled(not is_local)
	
	add_child(character)
	
	if is_local:
		_player = character
		player_spawned.emit(character)
	
	return character
