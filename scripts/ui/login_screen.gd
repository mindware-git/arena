class_name LoginScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Login Screen
# Nakama 디바이스 인증 화면
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)

var _loading_label: Label
var _status_label: Label
var _is_authenticating: bool = false
var _retry_count: int = 0
var _max_retries: int = 3
var _animation_time: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_create_ui()
	_start_authentication()


func _create_ui() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 타이틀
	var title := Label.new()
	title.name = "Label"
	title.text = "ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-100, -100)
	title.size = Vector2(200, 100)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	add_child(title)
	
	# 로딩 상태 메시지
	_status_label = Label.new()
	_status_label.name = "Label2"
	_status_label.text = "연결 중..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.position = Vector2(-100, 20)
	_status_label.size = Vector2(200, 30)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(_status_label)
	
	# 로딩 스피너 (간단한 점 애니메이션)
	_loading_label = Label.new()
	_loading_label.name = "Label3"
	_loading_label.text = "●"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)
	_loading_label.position = Vector2(-100, 70)
	_loading_label.size = Vector2(200, 50)
	_loading_label.add_theme_font_size_override("font_size", 32)
	_loading_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	add_child(_loading_label)


func _process(delta: float) -> void:
	if _is_authenticating:
		# 간단한 로딩 애니메이션
		_animation_time += delta
		var dots := ["●", "●●", "●●●"]
		var frame := int(_animation_time / 0.5) % 3
		_loading_label.text = dots[frame]


# ═══════════════════════════════════════════════════════════════════════════════
# Authentication
# ═══════════════════════════════════════════════════════════════════════════════

func _start_authentication() -> void:
	print("DEBUG: Starting authentication")
	_is_authenticating = true
	_status_label.text = "Nakama 서버 연결 중..."
	
	# Online 싱글톤으로 인증 시작
	var device_id := OS.get_unique_id()
	print("DEBUG: Device ID: ", device_id)
	var client := Online.get_nakama_client()
	print("DEBUG: Got Nakama client")
	
	# 디바이스 인증 (비동기)
	print("DEBUG: Calling authenticate_device_async")
	var result = await client.authenticate_device_async(device_id)
	print("DEBUG: Authentication result received")
	
	if result.is_exception():
		print("DEBUG: Authentication failed - ", result.get_exception().message)
		_show_error("인증 실패: " + result.get_exception().message)
		return
	
	# 세션 설정
	print("DEBUG: Authentication successful, setting session")
	Online.set_nakama_session(result)
	
	_status_label.text = "인증 완료!"
	print("DEBUG: Transitioning to lobby")
	await get_tree().create_timer(0.5).timeout
	_is_authenticating = false
	
	# LobbyScreen으로 전환
	var lobby := LobbyScreen.new()
	transition_requested.emit(lobby)


func _show_error(message: String) -> void:
	print("DEBUG: Showing error - ", message, " (retry count: ", _retry_count, ")")
	_is_authenticating = false
	_retry_count += 1
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_loading_label.text = "재시도"
	
	# 재시도 횟수 초과 시 메뉴로
	if _retry_count >= _max_retries:
		print("DEBUG: Max retries reached, going back to menu")
		await get_tree().create_timer(2.0).timeout
		_status_label.text = "최대 재시도 횟수 초과"
		_loading_label.text = "메뉴로 돌아갑니다"
		await get_tree().create_timer(2.0).timeout
		var splash := SplashScreen.new()
		transition_requested.emit(splash)
		return
	
	# 2초 후 재시도
	print("DEBUG: Retrying authentication in 2 seconds")
	await get_tree().create_timer(2.0).timeout
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_start_authentication()
