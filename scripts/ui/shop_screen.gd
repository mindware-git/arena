class_name ShopScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Shop Screen
# 상점 화면 (간단 버전)
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_create_ui()


func _create_ui() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 타이틀
	var title := Label.new()
	title.text = "🛒 상점"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.size = Vector2(1280, 60)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	add_child(title)
	
	# 안내 문구
	var notice := Label.new()
	notice.text = "준비 중입니다..."
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.position = Vector2(0, 300)
	notice.size = Vector2(1280, 40)
	notice.add_theme_font_size_override("font_size", 20)
	notice.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(notice)
	
	# 뒤로가기 버튼
	var back_btn := Button.new()
	back_btn.text = "← 뒤로가기"
	back_btn.position = Vector2(540, 500)
	back_btn.size = Vector2(200, 50)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)


func _on_back_pressed() -> void:
	var lobby := LobbyScreen.new()
	transition_requested.emit(lobby)