class_name SplashScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Splash Screen
# 게임 시작 시 로고 표시 후 Lobby로 이동
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
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 로고/타이틀
	var title := Label.new()
	title.text = "ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-100, -50)
	title.size = Vector2(200, 100)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	add_child(title)
	
	# 부제목
	var subtitle := Label.new()
	subtitle.text = "모바일 서바이벌 대전"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-100, 30)
	subtitle.size = Vector2(200, 30)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(subtitle)
	
	# 시작 버튼
	var start_btn := Button.new()
	start_btn.text = "TOUCH TO START"
	start_btn.set_anchors_preset(Control.PRESET_CENTER)
	start_btn.position = Vector2(-80, 150)
	start_btn.size = Vector2(160, 50)
	start_btn.pressed.connect(_on_start_pressed)
	add_child(start_btn)
	
	# 버전 표시
	var version := Label.new()
	version.text = "v0.1.0"
	version.position = Vector2(10, 690)
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(version)


func _on_start_pressed() -> void:
	# LobbyScreen으로 전환
	var lobby := LobbyScreen.new()
	transition_requested.emit(lobby)