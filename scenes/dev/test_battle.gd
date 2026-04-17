class_name TestBattle
extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
# Test Battle Scene
# 배틀 씬을 테스트하기 위한 개발용 씬
# - 테스트할 캐릭터 데이터 설정
# - BattleScreen 인스턴스화
# - 디버그 UI 제공
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# Test Configuration
# ═══════════════════════════════════════════════════════════════════════════════

## 테스트할 플레이어 캐릭터 ID 목록
var _player_ids: Array[String] = ["gyro", "shamu"]
var _current_player_index: int = 0

## 테스트할 적 캐릭터 ID 목록
var _enemy_ids: Array[String] = ["enemy_slime", "enemy_slime", "enemy_slime"]

# ═══════════════════════════════════════════════════════════════════════════════
# Variables
# ═══════════════════════════════════════════════════════════════════════════════

var _battle: BattleScreen

# 디버그 UI
var _debug_label: Label
var _battle_log: RichTextLabel

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_create_debug_ui()
	_start_test_battle()


func _process(_delta: float) -> void:
	_update_debug_info()

# ═══════════════════════════════════════════════════════════════════════════════
# Input
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_switch_player(0)
			KEY_2:
				_switch_player(1)
			KEY_R:
				_reset_battle()
			KEY_E:
				_spawn_single_enemy()

# ═══════════════════════════════════════════════════════════════════════════════
# Battle Management
# ═══════════════════════════════════════════════════════════════════════════════

func _start_test_battle() -> void:
	# 기존 배틀 제거
	if _battle:
		_battle.queue_free()
	
	# BattleScreen 인스턴스화
	_battle = BattleScreen.new()
	add_child(_battle)
	
	# 시그널 연결
	_battle.battle_started.connect(_on_battle_started)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.player_spawned.connect(_on_player_spawned)
	_battle.enemy_spawned.connect(_on_enemy_spawned)
	_battle.character_died.connect(_on_character_died)
	
	# 배틀 시작 (테스트 데이터로)
	# enemies가 비어있으면 자동으로 enemy_slime 스폰
	_battle.start_battle(_player_ids[_current_player_index])
	
	_log("=== 배틀 시작 ===")


func _switch_player(index: int) -> void:
	if index >= 0 and index < _player_ids.size():
		_current_player_index = index
		_log("플레이어 전환: %s" % _player_ids[index])
		_start_test_battle()


func _reset_battle() -> void:
	_log("=== 배틀 리셋 ===")
	_start_test_battle()


func _spawn_single_enemy() -> void:
	if _battle:
		_battle.spawn_enemy_at_random_position("enemy_slime")
		_log("적 추가 스폰")

# ═══════════════════════════════════════════════════════════════════════════════
# Debug UI
# ═══════════════════════════════════════════════════════════════════════════════

func _create_debug_ui() -> void:
	# CanvasLayer 생성
	var canvas := CanvasLayer.new()
	canvas.layer = 10  # 배틀 UI 위에 표시
	add_child(canvas)
	
	# 메인 컨테이너
	var main_ui := VBoxContainer.new()
	main_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_ui.position = Vector2(10, 80)  # 배틀 UI 아래
	canvas.add_child(main_ui)
	
	# 제목
	var title := Label.new()
	title.text = "=== DEBUG MODE ==="
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.YELLOW)
	main_ui.add_child(title)
	
	# 컨트롤 버튼
	var btn_container := HBoxContainer.new()
	main_ui.add_child(btn_container)
	
	# 플레이어 전환 버튼
	for i in range(_player_ids.size()):
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, _player_ids[i].capitalize()]
		btn.pressed.connect(_switch_player.bind(i))
		btn_container.add_child(btn)
	
	# 리셋 버튼
	var reset_btn := Button.new()
	reset_btn.text = "R. Reset"
	reset_btn.pressed.connect(_reset_battle)
	btn_container.add_child(reset_btn)
	
	# 적 스폰 버튼
	var enemy_btn := Button.new()
	enemy_btn.text = "E. Add Enemy"
	enemy_btn.pressed.connect(_spawn_single_enemy)
	btn_container.add_child(enemy_btn)
	
	# 전투 로그
	var log_label := Label.new()
	log_label.text = "=== Battle Log ==="
	log_label.add_theme_font_size_override("font_size", 12)
	main_ui.add_child(log_label)
	
	_battle_log = RichTextLabel.new()
	_battle_log.custom_minimum_size = Vector2(300, 100)
	_battle_log.bbcode_enabled = true
	_battle_log.scroll_following = true
	main_ui.add_child(_battle_log)
	
	# 디버그 라벨 (하단)
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 500)
	_debug_label.add_theme_font_size_override("font_size", 11)
	_debug_label.add_theme_color_override("font_color", Color.GRAY)
	canvas.add_child(_debug_label)


func _update_debug_info() -> void:
	if _battle and _battle.player:
		_debug_label.text = _battle.player.get_debug_info()


func _log(message: String) -> void:
	if _battle_log:
		_battle_log.append_text("%s\n" % message)
	print("[TestBattle] %s" % message)

# ═══════════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════════

func _on_battle_started() -> void:
	_log("배틀이 시작되었습니다.")


func _on_battle_ended(winning_team: int) -> void:
	var winner := "플레이어" if winning_team == 0 else "적"
	_log("[color=yellow]배틀 종료! %s 승리![/color]" % winner)


func _on_player_spawned(player: Character) -> void:
	if player.character_data:
		_log("플레이어 스폰: %s (HP: %d)" % [player.character_data.display_name, player.character_data.max_hp])
	
	# HP 변경 시그널 연결
	player.hp_changed.connect(_on_player_hp_changed)
	player.attacked.connect(_on_player_attacked)


func _on_enemy_spawned(enemy: Character) -> void:
	if enemy.character_data:
		_log("적 스폰: %s (HP: %d)" % [enemy.character_data.display_name, enemy.character_data.max_hp])
	
	# HP 변경 시그널 연결
	enemy.hp_changed.connect(_on_enemy_hp_changed.bind(enemy))


func _on_character_died(character: Character) -> void:
	if character == _battle.player:
		_log("[color=red]플레이어 사망! R을 눌러 리셋[/color]")
	elif character.character_data:
		_log("[color=green]적(%s) 처치![/color]" % character.character_data.display_name)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	_log("플레이어 HP: %d / %d" % [current, max_hp])


func _on_player_attacked(is_ranged: bool) -> void:
	var attack_type := "원거리" if is_ranged else "근접"
	_log("플레이어 %s 공격!" % attack_type)


func _on_enemy_hp_changed(current: int, max_hp: int, enemy: Character) -> void:
	if is_instance_valid(enemy) and enemy.character_data:
		_log("적(%s) HP: %d / %d" % [enemy.character_data.display_name, current, max_hp])
