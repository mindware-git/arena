class_name ResultScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Result Screen
# 게임 결과 화면 (승리/패배)
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)

var _is_victory: bool = false
var _game_time: float = 0.0

var _title_label: Label
var _time_label: Label
var _rewards_container: VBoxContainer

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_create_ui()


func set_result(is_victory: bool, game_time: float) -> void:
	_is_victory = is_victory
	_game_time = game_time
	
	if _title_label:
		_update_result_display()


func _create_ui() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 결과 타이틀
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 100)
	_title_label.size = Vector2(1280, 100)
	_title_label.add_theme_font_size_override("font_size", 64)
	add_child(_title_label)
	
	# 게임 시간
	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.position = Vector2(0, 220)
	_time_label.size = Vector2(1280, 40)
	_time_label.add_theme_font_size_override("font_size", 20)
	_time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_time_label)
	
	# 보상 컨테이너
	_rewards_container = VBoxContainer.new()
	_rewards_container.position = Vector2(440, 300)
	_rewards_container.size = Vector2(400, 200)
	add_child(_rewards_container)
	
	_create_rewards()
	_create_buttons()
	
	# 초기 표시 업데이트
	if _is_victory or _game_time > 0:
		_update_result_display()


func _create_rewards() -> void:
	# 보상 타이틀
	var reward_title := Label.new()
	reward_title.text = "보상"
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title.add_theme_font_size_override("font_size", 24)
	_rewards_container.add_child(reward_title)
	
	# 간격
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_rewards_container.add_child(spacer)
	
	# 경험치
	var xp_box := HBoxContainer.new()
	xp_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_rewards_container.add_child(xp_box)
	
	var xp_icon := Label.new()
	xp_icon.text = "⭐"
	xp_icon.add_theme_font_size_override("font_size", 20)
	xp_box.add_child(xp_icon)
	
	var xp_label := Label.new()
	xp_label.text = " +50 XP" if _is_victory else " +10 XP"
	xp_label.add_theme_font_size_override("font_size", 20)
	xp_box.add_child(xp_label)
	
	# 코인
	var coin_box := HBoxContainer.new()
	coin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_rewards_container.add_child(coin_box)
	
	var coin_icon := Label.new()
	coin_icon.text = "🪙"
	coin_icon.add_theme_font_size_override("font_size", 20)
	coin_box.add_child(coin_icon)
	
	var coin_label := Label.new()
	coin_label.text = " +100" if _is_victory else " +20"
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_box.add_child(coin_label)
	
	# 승리 시 추가 보상
	if _is_victory:
		var gem_box := HBoxContainer.new()
		gem_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_rewards_container.add_child(gem_box)
		
		var gem_icon := Label.new()
		gem_icon.text = "💎"
		gem_icon.add_theme_font_size_override("font_size", 20)
		gem_box.add_child(gem_icon)
		
		var gem_label := Label.new()
		gem_label.text = " +5"
		gem_label.add_theme_font_size_override("font_size", 20)
		gem_box.add_child(gem_label)


func _create_buttons() -> void:
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(390, 550)
	buttons.size = Vector2(500, 60)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 30)
	add_child(buttons)
	
	# 다시하기
	var retry_btn := Button.new()
	retry_btn.text = "다시하기"
	retry_btn.custom_minimum_size = Vector2(150, 50)
	retry_btn.pressed.connect(_on_retry_pressed)
	buttons.add_child(retry_btn)
	
	# 로비로
	var lobby_btn := Button.new()
	lobby_btn.text = "로비로"
	lobby_btn.custom_minimum_size = Vector2(150, 50)
	lobby_btn.pressed.connect(_on_lobby_pressed)
	buttons.add_child(lobby_btn)


func _update_result_display() -> void:
	if _is_victory:
		_title_label.text = "승리!"
		_title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		_title_label.text = "패배"
		_title_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	
	# 게임 시간 표시
	@warning_ignore("integer_division")
	var minutes := int(_game_time) / 60
	var seconds := int(_game_time) % 60
	_time_label.text = "게임 시간: %02d:%02d" % [minutes, seconds]


func _on_retry_pressed() -> void:
	# 다시 매칭으로
	var matching := MatchingScreen.new()
	transition_requested.emit(matching)


func _on_lobby_pressed() -> void:
	# 로비로 복귀
	var lobby := LobbyScreen.new()
	transition_requested.emit(lobby)
