extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
# Test Battle Scene
# 플레이어와 적 간의 전투를 테스트하는 개발용 씬
# ═══════════════════════════════════════════════════════════════════════════════

var _registry: CharacterRegistry
var _player: Character
var _enemies: Array[Character] = []

# 플레이어 캐릭터 ID
var _player_ids: Array[String] = []
var _current_player_index: int = 0

# UI
var _debug_label: Label
var _info_panel: VBoxContainer
var _battle_log: RichTextLabel
var _battle_hud: CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_registry = CharacterRegistry.new()
	_player_ids = ["gyro", "shamu"]
	
	_create_ui()
	_create_battle_hud()
	_spawn_player(_player_ids[_current_player_index])
	_spawn_enemies()


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
# Player Management
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_player(id: String) -> void:
	# 기존 플레이어 제거
	if _player:
		_player.queue_free()
	
	# 데이터 조회
	var data := _registry.get_character(id)
	if not data:
		push_error("Player character not found: " + id)
		return
	
	# 엔티티 생성
	_player = Character.new()
	_player.init(data)
	_player.position = Vector2(200, 300)
	_player.is_controllable = true  # 플레이어만 입력 제어
	
	# 시그널 연결
	_player.hp_changed.connect(_on_player_hp_changed)
	_player.died.connect(_on_player_died)
	_player.attacked.connect(_on_player_attacked)
	
	# 씬에 추가
	add_child(_player)
	
	_log("플레이어 스폰: %s (HP: %d)" % [data.display_name, data.max_hp])
	_update_info_panel()


func _switch_player(index: int) -> void:
	if index >= 0 and index < _player_ids.size():
		_current_player_index = index
		_spawn_player(_player_ids[index])

# ═══════════════════════════════════════════════════════════════════════════════
# Enemy Management
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_enemies() -> void:
	# 기존 적들 제거
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	
	# 여러 적 스폰
	var spawn_positions := [
		Vector2(500, 200),
		Vector2(600, 300),
		Vector2(500, 400),
	]
	
	for i in range(spawn_positions.size()):
		_spawn_enemy_at(spawn_positions[i])


func _spawn_single_enemy() -> void:
	# 랜덤 위치에 적 스폰
	var random_x := randf_range(400, 700)
	var random_y := randf_range(150, 450)
	_spawn_enemy_at(Vector2(random_x, random_y))


func _spawn_enemy_at(pos: Vector2) -> void:
	var data := _registry.get_character("enemy_slime")
	if not data:
		push_error("Enemy character not found")
		return
	
	var enemy := Character.new()
	enemy.init(data)
	enemy.position = pos
	enemy.is_controllable = false  # 적은 입력 제어 안 함
	
	# 시그널 연결
	enemy.hp_changed.connect(_on_enemy_hp_changed.bind(enemy))
	enemy.died.connect(_on_enemy_died.bind(enemy))
	
	add_child(enemy)
	_enemies.append(enemy)
	
	_log("적 스폰: %s (HP: %d)" % [data.display_name, data.max_hp])


func _remove_enemy(enemy: Character) -> void:
	if _enemies.has(enemy):
		_enemies.erase(enemy)
	if is_instance_valid(enemy):
		enemy.queue_free()

# ═══════════════════════════════════════════════════════════════════════════════
# Battle Control
# ═══════════════════════════════════════════════════════════════════════════════

func _reset_battle() -> void:
	_log("=== 전투 리셋 ===")
	_spawn_player(_player_ids[_current_player_index])
	_spawn_enemies()

# ═══════════════════════════════════════════════════════════════════════════════
# UI
# ═══════════════════════════════════════════════════════════════════════════════

func _create_ui() -> void:
	# CanvasLayer 생성
	var canvas := CanvasLayer.new()
	add_child(canvas)
	
	# 메인 컨테이너
	var main_ui := VBoxContainer.new()
	main_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_ui.position = Vector2(10, 10)
	canvas.add_child(main_ui)
	
	# 제목
	var title := Label.new()
	title.text = "=== Battle Test Scene ==="
	title.add_theme_font_size_override("font_size", 16)
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
	
	# 정보 패널
	_info_panel = VBoxContainer.new()
	main_ui.add_child(_info_panel)
	
	# 전투 로그
	var log_label := Label.new()
	log_label.text = "=== Battle Log ==="
	log_label.add_theme_font_size_override("font_size", 14)
	main_ui.add_child(log_label)
	
	_battle_log = RichTextLabel.new()
	_battle_log.custom_minimum_size = Vector2(400, 150)
	_battle_log.bbcode_enabled = true
	_battle_log.scroll_following = true
	main_ui.add_child(_battle_log)
	
	# 디버그 라벨
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 500)
	_debug_label.add_theme_font_size_override("font_size", 12)
	canvas.add_child(_debug_label)
	
	# 안내 문구
	var help_label := Label.new()
	help_label.text = "방향키: 이동 | Z/마우스좌클릭: 근접공격 | X/마우스우클릭: 원거리공격 | Space: 부스터"
	help_label.position = Vector2(10, 520)
	help_label.add_theme_font_size_override("font_size", 12)
	canvas.add_child(help_label)


func _update_info_panel() -> void:
	# 기존 자식 제거
	for child in _info_panel.get_children():
		child.queue_free()
	
	if not _player or not _player.character_data:
		return
	
	var data: CharacterData = _player.character_data
	
	# 플레이어 정보
	var player_label := Label.new()
	player_label.text = "[Player] %s | HP: %d/%d | MP: %d/%d | BP: %d/%d" % [
		data.display_name,
		_player.current_hp, data.max_hp,
		_player.current_mp, data.max_mp,
		_player.current_bp, data.max_bp
	]
	player_label.add_theme_color_override("font_color", Color.CYAN)
	_info_panel.add_child(player_label)
	
	# 적 정보
	var enemy_label := Label.new()
	enemy_label.text = "[Enemies] Count: %d" % _enemies.size()
	_info_panel.add_child(enemy_label)
	
	var alive_count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			alive_count += 1
	
	var alive_label := Label.new()
	alive_label.text = "  - Alive: %d | Dead: %d" % [alive_count, _enemies.size() - alive_count]
	_info_panel.add_child(alive_label)


func _update_debug_info() -> void:
	if _player:
		_update_info_panel()
		_debug_label.text = _player.get_debug_info()


func _log(message: String) -> void:
	if _battle_log:
		_battle_log.append_text("%s\n" % message)
	print("[Battle] %s" % message)

# ═══════════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════════

func _on_player_hp_changed(current: int, max_hp: int) -> void:
	_log("플레이어 HP: %d / %d" % [current, max_hp])


func _on_player_died() -> void:
	_log("[color=red]플레이어 사망! R을 눌러 리셋[/color]")


func _on_player_attacked(is_ranged: bool) -> void:
	var attack_type := "원거리" if is_ranged else "근접"
	_log("플레이어 %s 공격!" % attack_type)


func _on_enemy_hp_changed(current: int, max_hp: int, enemy: Character) -> void:
	if is_instance_valid(enemy) and enemy.character_data:
		_log("적(%s) HP: %d / %d" % [enemy.character_data.display_name, current, max_hp])


func _on_enemy_died(enemy: Character) -> void:
	if is_instance_valid(enemy) and enemy.character_data:
		_log("[color=green]적(%s) 처치![/color]" % enemy.character_data.display_name)
	
	# 적 제거 (약간의 딜레이 후)
	call_deferred("_remove_enemy", enemy)

# ═══════════════════════════════════════════════════════════════════════════════
# Battle HUD
# ═══════════════════════════════════════════════════════════════════════════════

const BATTLE_HUD_SCENE = preload("res://scenes/ui/battle_hud.tscn")

func _create_battle_hud() -> void:
	_battle_hud = BATTLE_HUD_SCENE.instantiate()
	add_child(_battle_hud)
	_setup_action_buttons()


func _setup_action_buttons() -> void:
	var hbox: HBoxContainer = _battle_hud.get_node("Control/Control/HBoxContainer")
	if not hbox:
		push_error("HBoxContainer not found in BattleHUD")
		return
	
	var template_btn: TouchScreenButton = hbox.get_node("TouchScreenButton")
	if not template_btn:
		push_error("TouchScreenButton template not found")
		return
	
	const BUTTON_SIZE := 80
	const BUTTON_SPACING := 100
	
	# 대쉬 버튼
	template_btn.action = "booster"
	template_btn.name = "DashButton"
	template_btn.position = Vector2(0, 0)
	_create_button_texture(template_btn, Color(0.2, 0.6, 0.9))
	
	# 근접 공격 버튼
	var attack1_btn: TouchScreenButton = template_btn.duplicate()
	attack1_btn.action = "attack_melee"
	attack1_btn.name = "Attack1Button"
	attack1_btn.position = Vector2(BUTTON_SPACING, 0)
	_create_button_texture(attack1_btn, Color(0.9, 0.4, 0.2))
	hbox.add_child(attack1_btn)
	
	# 원거리 공격 버튼
	var attack2_btn: TouchScreenButton = template_btn.duplicate()
	attack2_btn.action = "attack_ranged"
	attack2_btn.name = "Attack2Button"
	attack2_btn.position = Vector2(BUTTON_SPACING * 2, 0)
	_create_button_texture(attack2_btn, Color(0.6, 0.2, 0.8))
	hbox.add_child(attack2_btn)


func _create_button_texture(btn: TouchScreenButton, color: Color) -> void:
	var image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	btn.texture_normal = texture
	
	var pressed_image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	pressed_image.fill(color.lightened(0.3))
	btn.texture_pressed = ImageTexture.create_from_image(pressed_image)
