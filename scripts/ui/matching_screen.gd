class_name MatchingScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Matching Screen
# 매치메이킹 대기 화면
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)
signal timeout_occurred()

var _elapsed_time: float = 0.0
var _is_matching: bool = false
var _time_label: Label
var _status_label: Label
var _cancel_btn: Button
var _matching_timeout: float = 30.0  # 30초 타임아웃
var _retry_count: int = 0
var _max_retries: int = 3

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_create_ui()
	_start_matching()


func _process(delta: float) -> void:
	if _is_matching:
		_elapsed_time += delta
		_update_time_display()
		
		# 타임아웃 체크 (30초)
		if _elapsed_time >= _matching_timeout:
			_on_matching_timeout()


func _create_ui() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 타이틀
	var title := Label.new()
	title.name = "Label"
	title.text = "매칭 중..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 100)
	title.size = Vector2(1280, 50)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(title)
	
	# 경과 시간
	_time_label = Label.new()
	_time_label.name = "Label2"
	_time_label.text = "00:00"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.position = Vector2(0, 200)
	_time_label.size = Vector2(1280, 80)
	_time_label.add_theme_font_size_override("font_size", 64)
	_time_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
	add_child(_time_label)
	
	# 상태 메시지
	_status_label = Label.new()
	_status_label.name = "Label3"
	_status_label.text = "플레이어 찾는 중..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position = Vector2(0, 320)
	_status_label.size = Vector2(1280, 40)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_status_label)
	
	# 플레이어 슬롯 (2명)
	_create_player_slots()
	
	# 취소 버튼
	_cancel_btn = Button.new()
	_cancel_btn.name = "Button"
	_cancel_btn.text = "취소"
	_cancel_btn.position = Vector2(540, 600)
	_cancel_btn.size = Vector2(200, 50)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	add_child(_cancel_btn)


func _create_player_slots() -> void:
	# 슬롯 컨테이너
	var slots := HBoxContainer.new()
	slots.name = "HBoxContainer"
	slots.position = Vector2(340, 400)
	slots.size = Vector2(600, 120)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 100)
	add_child(slots)
	
	# 플레이어 1 (나)
	var slot1 := _create_slot("Player_001", true)
	slots.add_child(slot1)
	
	# VS
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 28)
	vs.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	slots.add_child(vs)
	
	# 플레이어 2 (상대)
	var slot2 := _create_slot("???", false)
	slots.add_child(slot2)


func _create_slot(player_name: String, is_ready: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(150, 120)
	
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(content)
	
	# 아바타 (임시)
	var avatar := ColorRect.new()
	avatar.color = Color(0.3, 0.3, 0.4)
	avatar.custom_minimum_size = Vector2(60, 60)
	content.add_child(avatar)
	
	# 이름
	var name_lbl := Label.new()
	name_lbl.text = player_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	content.add_child(name_lbl)
	
	# 상태
	var status := Label.new()
	status.text = "준비됨" if is_ready else "대기 중"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if is_ready else Color(0.6, 0.6, 0.6))
	content.add_child(status)
	
	return slot


func _start_matching() -> void:
	_is_matching = true
	_elapsed_time = 0.0
	_status_label.text = "플레이어 찾는 중..."
	_cancel_btn.text = "취소"
	_cancel_btn.disabled = false
	
	# Nakama 소켓 연결
	if not Online.is_nakama_socket_connected():
		Online.connect_nakama_socket()
		var socket = await Online.socket_connected
		if not socket:
			_on_match_error("소켓 연결 실패")
			return
	
	# 매칭메이커 시작
	OnlineMatch.start_matchmaking(Online.nakama_socket)
	
	# 매칭 완료 신호 대기
	OnlineMatch.match_ready.connect(_on_match_ready)
	OnlineMatch.error.connect(_on_match_error)


func _on_match_ready(players: Dictionary) -> void:
	_on_match_found()


func _on_match_error(message: String) -> void:
	_is_matching = false
	_status_label.text = "매칭 실패: " + message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_cancel_btn.text = "재시도"
	_cancel_btn.disabled = false


func _on_match_found() -> void:
	_is_matching = false
	_status_label.text = "매칭 완료!"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_cancel_btn.text = "진행 중..."
	_cancel_btn.disabled = true
	
	# 1초 후 캐릭터 선택으로
	await get_tree().create_timer(1.0).timeout
	var char_select := CharacterSelectScreen.new()
	transition_requested.emit(char_select)


func _on_cancel_pressed() -> void:
	_is_matching = false
	OnlineMatch.leave()
	# Lobby로 복귀
	var lobby := LobbyScreen.new()
	transition_requested.emit(lobby)


func _on_matching_timeout() -> void:
	_is_matching = false
	_status_label.text = "매칭 타임아웃 (30초)"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_cancel_btn.text = "재시도"
	_cancel_btn.disabled = false
	OnlineMatch.leave()
	
	_retry_count += 1
	timeout_occurred.emit()
	
	# 재시도 횟수 초과 시
	if _retry_count >= _max_retries:
		await get_tree().create_timer(2.0).timeout
		_status_label.text = "매칭 실패 - 메뉴로 돌아갑니다"
		_cancel_btn.disabled = true
		await get_tree().create_timer(2.0).timeout
		var lobby := LobbyScreen.new()
		transition_requested.emit(lobby)


func _update_time_display() -> void:
	@warning_ignore("integer_division")
	var minutes := int(_elapsed_time) / 60
	var seconds := int(_elapsed_time) % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]
