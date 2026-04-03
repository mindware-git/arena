extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
# Test Character Scene
# 캐릭터 시스템을 테스트하기 위한 개발용 씬
# ═══════════════════════════════════════════════════════════════════════════════

var _registry: CharacterRegistry
var _current_character: Character
var _character_ids: Array[String] = []
var _current_index: int = 0

# UI
var _debug_label: Label
var _info_panel: VBoxContainer
var _battle_hud: CanvasLayer  # BattleHUD 타입은 런타임에 로드됨

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_registry = CharacterRegistry.new()
	_character_ids = _registry.get_all_ids()
	
	_create_ui()
	_create_battle_hud()
	_spawn_character(_character_ids[_current_index])


func _process(_delta: float) -> void:
	_update_debug_info()

# ═══════════════════════════════════════════════════════════════════════════════
# Input
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	# 숫자키로 캐릭터 전환
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_switch_character(0)
			KEY_2:
				_switch_character(1)
			KEY_R:
				_respawn_character()
			KEY_D:
				_test_damage()
			KEY_H:
				_test_heal()

# ═══════════════════════════════════════════════════════════════════════════════
# Character Management
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_character(id: String) -> void:
	# 기존 캐릭터 제거
	if _current_character:
		_current_character.queue_free()
	
	# 데이터 조회
	var data := _registry.get_character(id)
	if not data:
		push_error("Character not found: " + id)
		return
	
	# 엔티티 생성
	_current_character = Character.new()
	_current_character.init(data)
	_current_character.position = Vector2(400, 300)
	
	# 시그널 연결
	_current_character.hp_changed.connect(_on_hp_changed)
	_current_character.died.connect(_on_character_died)
	
	# 씬에 추가
	add_child(_current_character)
	
	# UI 업데이트
	_update_info_panel()


func _switch_character(index: int) -> void:
	if index >= 0 and index < _character_ids.size():
		_current_index = index
		_spawn_character(_character_ids[index])


func _respawn_character() -> void:
	_spawn_character(_character_ids[_current_index])

# ═══════════════════════════════════════════════════════════════════════════════
# Test Actions
# ═══════════════════════════════════════════════════════════════════════════════

func _test_damage() -> void:
	if _current_character:
		_current_character.take_damage(10)


func _test_heal() -> void:
	if _current_character:
		_current_character.heal(10)

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
	title.text = "=== Character Test Scene ==="
	title.add_theme_font_size_override("font_size", 16)
	main_ui.add_child(title)
	
	# 캐릭터 버튼
	var btn_container := HBoxContainer.new()
	main_ui.add_child(btn_container)
	
	for i in range(_character_ids.size()):
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, _character_ids[i].capitalize()]
		btn.pressed.connect(_switch_character.bind(i))
		btn_container.add_child(btn)
	
	# 리스폰 버튼
	var respawn_btn := Button.new()
	respawn_btn.text = "R. Respawn"
	respawn_btn.pressed.connect(_respawn_character)
	btn_container.add_child(respawn_btn)
	
	# 데미지/힐 버튼
	var action_container := HBoxContainer.new()
	main_ui.add_child(action_container)
	
	var dmg_btn := Button.new()
	dmg_btn.text = "D. Damage -10"
	dmg_btn.pressed.connect(_test_damage)
	action_container.add_child(dmg_btn)
	
	var heal_btn := Button.new()
	heal_btn.text = "H. Heal +10"
	heal_btn.pressed.connect(_test_heal)
	action_container.add_child(heal_btn)
	
	# 정보 패널
	_info_panel = VBoxContainer.new()
	main_ui.add_child(_info_panel)
	
	# 디버그 라벨
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 200)
	_debug_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(_debug_label)


func _update_info_panel() -> void:
	# 기존 자식 제거
	for child in _info_panel.get_children():
		child.queue_free()
	
	if not _current_character or not _current_character.character_data:
		return
	
	var data: CharacterData = _current_character.character_data
	var grades: Dictionary = data.get_all_grades()
	
	# 이름 & 속성
	var name_label := Label.new()
	name_label.text = "Name: %s | Element: %s" % [data.display_name, GameManager.ElementType.keys()[data.element]]
	_info_panel.add_child(name_label)
	
	# 스탯
	var stats_label := Label.new()
	stats_label.text = "HP: %d(%s) MP: %d(%s) BP: %d(%s)" % [
		data.max_hp, grades["hp"],
		data.max_mp, grades["mp"],
		data.max_bp, grades["bp"]
	]
	_info_panel.add_child(stats_label)
	
	# 공격력
	var power_label := Label.new()
	power_label.text = "Melee: %d(%s) Ranged: %d(%s)" % [
		data.melee_power, grades["melee_power"],
		data.ranged_power, grades["ranged_power"]
	]
	_info_panel.add_child(power_label)
	
	# 이동
	var speed_label := Label.new()
	speed_label.text = "Speed: %d(%s) Rotation: %d(%s) Accel: %d(%s)" % [
		int(data.max_speed), grades["max_speed"],
		int(data.rotation_speed), grades["rotation_speed"],
		int(data.acceleration), grades["acceleration"]
	]
	_info_panel.add_child(speed_label)
	
	# 비행 여부
	var fly_label := Label.new()
	fly_label.text = "Flying: %s" % ["Yes" if data.is_flying else "No"]
	_info_panel.add_child(fly_label)


func _update_debug_info() -> void:
	if _current_character:
		_debug_label.text = _current_character.get_debug_info()

# ═══════════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════════

func _on_hp_changed(current: int, max_hp: int) -> void:
	print("HP Changed: %d / %d" % [current, max_hp])


func _on_character_died() -> void:
	print("Character died!")


# ═══════════════════════════════════════════════════════════════════════════════
# Battle HUD
# ═══════════════════════════════════════════════════════════════════════════════

const BATTLE_HUD_SCENE = preload("res://scenes/ui/battle_hud.tscn")

func _create_battle_hud() -> void:
	# 씬 인스턴스화
	_battle_hud = BATTLE_HUD_SCENE.instantiate()
	add_child(_battle_hud)
	
	# TouchScreenButton 설정
	_setup_action_buttons()


func _setup_action_buttons() -> void:
	# HBoxContainer 찾기
	var hbox: HBoxContainer = _battle_hud.get_node("Control/Control/HBoxContainer")
	if not hbox:
		push_error("HBoxContainer not found in BattleHUD")
		return
	
	# 템플릿 버튼 가져오기
	var template_btn: TouchScreenButton = hbox.get_node("TouchScreenButton")
	if not template_btn:
		push_error("TouchScreenButton template not found")
		return
	
	# 버튼 크기
	const BUTTON_SIZE := 80
	const BUTTON_SPACING := 100
	
	# 첫 번째 버튼: 대쉬 (부스터)
	template_btn.action = "booster"
	template_btn.name = "DashButton"
	template_btn.position = Vector2(0, 0)
	_create_button_texture(template_btn, Color(0.2, 0.6, 0.9))
	
	# 두 번째 버튼: 근접 공격 (복제)
	var attack1_btn: TouchScreenButton = template_btn.duplicate()
	attack1_btn.action = "attack_melee"
	attack1_btn.name = "Attack1Button"
	attack1_btn.position = Vector2(BUTTON_SPACING, 0)
	_create_button_texture(attack1_btn, Color(0.9, 0.4, 0.2))
	hbox.add_child(attack1_btn)
	
	# 세 번째 버튼: 원거리 공격 (복제)
	var attack2_btn: TouchScreenButton = template_btn.duplicate()
	attack2_btn.action = "attack_ranged"
	attack2_btn.name = "Attack2Button"
	attack2_btn.position = Vector2(BUTTON_SPACING * 2, 0)
	_create_button_texture(attack2_btn, Color(0.6, 0.2, 0.8))
	hbox.add_child(attack2_btn)


func _create_button_texture(btn: TouchScreenButton, color: Color) -> void:
	# 임시 텍스처 생성 (동적 ImageTexture)
	var image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	# 원형 마스크 적용 (간단히 모서리 둥글게는 생략)
	var texture := ImageTexture.create_from_image(image)
	btn.texture_normal = texture
	
	# 눌렸을 때 밝게
	var pressed_image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	pressed_image.fill(color.lightened(0.3))
	btn.texture_pressed = ImageTexture.create_from_image(pressed_image)
