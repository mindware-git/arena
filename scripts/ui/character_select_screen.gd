class_name CharacterSelectScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Character Select Screen
# 캐릭터 선택 화면 (자이로, 샤무 등)
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)

# ═══════════════════════════════════════════════════════════════════════════════
# Network Sync
# ═══════════════════════════════════════════════════════════════════════════════

const CHAR_SELECT_OP_CODE := 9004  # 캐릭터 선택 동기화 op_code

var _my_character_id: String = ""
var _my_ready: bool = false
var _opponent_character_id: String = ""
var _opponent_ready: bool = false
var _opponent_peer_id: int = 0

# ═══════════════════════════════════════════════════════════════════════════════
# UI
# ═══════════════════════════════════════════════════════════════════════════════

var _registry: CharacterRegistry
var _character_ids: Array[String] = []
var _selected_index: int = 0
var _selected_character: CharacterData = null

var _name_label: Label
var _element_label: Label
var _stats_label: Label
var _description_label: Label
var _status_label: Label  # 대기 상태 표시
var _confirm_btn: Button

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_registry = CharacterRegistry.new()
	_character_ids = _registry.get_all_ids()
	
	if _character_ids.size() > 0:
		_selected_character = _registry.get_character(_character_ids[0])
		_my_character_id = _character_ids[0]
	
	_create_ui()
	_setup_multiplayer()


func _create_ui() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 타이틀
	var title := Label.new()
	title.text = "캐릭터 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 50)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(title)
	
	# 캐릭터 목록 (좌측)
	_create_character_list()
	
	# 캐릭터 상세 정보 (우측)
	_create_character_info()
	
	# 하단 버튼
	_create_bottom_buttons()


func _create_character_list() -> void:
	var list := VBoxContainer.new()
	list.position = Vector2(50, 100)
	list.size = Vector2(300, 500)
	add_child(list)
	
	for i in range(_character_ids.size()):
		var char_data := _registry.get_character(_character_ids[i])
		var btn := Button.new()
		btn.text = char_data.display_name
		btn.custom_minimum_size = Vector2(280, 80)
		btn.pressed.connect(_on_character_selected.bind(i))
		
		if i == _selected_index:
			btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		
		list.add_child(btn)


func _create_character_info() -> void:
	# 정보 패널
	var info_panel := PanelContainer.new()
	info_panel.position = Vector2(400, 100)
	info_panel.size = Vector2(500, 450)
	add_child(info_panel)
	
	var content := VBoxContainer.new()
	info_panel.add_child(content)
	
	# 캐릭터 이름
	_name_label = Label.new()
	_name_label.text = _selected_character.display_name if _selected_character else "???"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 32)
	content.add_child(_name_label)
	
	# 속성
	_element_label = Label.new()
	_element_label.text = _get_element_text() if _selected_character else ""
	_element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_element_label.add_theme_font_size_override("font_size", 18)
	_element_label.add_theme_color_override("font_color", _get_element_color())
	content.add_child(_element_label)
	
	# 간격
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content.add_child(spacer)
	
	# 스탯
	_stats_label = Label.new()
	_stats_label.text = _get_stats_text() if _selected_character else ""
	_stats_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_stats_label)
	
	# 간격
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	content.add_child(spacer2)
	
	# 설명
	_description_label = Label.new()
	_description_label.text = _selected_character.description if _selected_character else ""
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(_description_label)


func _create_bottom_buttons() -> void:
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(390, 600)
	buttons.size = Vector2(500, 60)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 30)
	add_child(buttons)
	
	# 뒤로가기
	var back_btn := Button.new()
	back_btn.text = "뒤로"
	back_btn.custom_minimum_size = Vector2(150, 50)
	back_btn.pressed.connect(_on_back_pressed)
	buttons.add_child(back_btn)
	
	# 확인
	var confirm_btn := Button.new()
	confirm_btn.text = "확인"
	confirm_btn.custom_minimum_size = Vector2(150, 50)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm_btn)


func _on_character_selected(index: int) -> void:
	_selected_index = index
	_selected_character = _registry.get_character(_character_ids[index])
	
	# UI 업데이트
	_name_label.text = _selected_character.display_name
	_element_label.text = _get_element_text()
	_element_label.add_theme_color_override("font_color", _get_element_color())
	_stats_label.text = _get_stats_text()
	_description_label.text = _selected_character.description


func _get_element_text() -> String:
	if not _selected_character:
		return ""
	
	var element_name: String
	match _selected_character.element:
		GameManager.ElementType.WATER: element_name = "물"
		GameManager.ElementType.FIRE: element_name = "불"
		GameManager.ElementType.WIND: element_name = "바람"
		GameManager.ElementType.EARTH: element_name = "흙"
		_: element_name = "???"
	
	return "속성: %s" % element_name


func _get_element_color() -> Color:
	if not _selected_character:
		return Color.WHITE
	
	match _selected_character.element:
		GameManager.ElementType.WATER: return Color(0.3, 0.6, 1.0)
		GameManager.ElementType.FIRE: return Color(1.0, 0.4, 0.2)
		GameManager.ElementType.WIND: return Color(0.4, 0.8, 0.5)
		GameManager.ElementType.EARTH: return Color(0.7, 0.5, 0.3)
		_: return Color.WHITE


func _get_stats_text() -> String:
	if not _selected_character:
		return ""
	
	var grades := _selected_character.get_all_grades()
	return """HP: %d (%s)   MP: %d (%s)   BP: %d (%s)
근접: %d (%s)   원거리: %d (%s)
속도: %d (%s)   회전: %d (%s)""" % [
		_selected_character.max_hp, grades["hp"],
		_selected_character.max_mp, grades["mp"],
		_selected_character.max_bp, grades["bp"],
		_selected_character.melee_power, grades["melee_power"],
		_selected_character.ranged_power, grades["ranged_power"],
		int(_selected_character.max_speed), grades["max_speed"],
		int(_selected_character.rotation_speed), grades["rotation_speed"]
	]


func _on_back_pressed() -> void:
	# 멀티플레이어에서 나가기
	OnlineMatch.leave()
	var lobby := LobbyScreen.new()
	transition_requested.emit(lobby)


func _on_confirm_pressed() -> void:
	# 캐릭터 선택 저장
	_my_character_id = _character_ids[_selected_index]
	_my_ready = true
	
	# 상대방에게 선택 전송
	_send_character_selection()
	_update_status_ui()
	
	# 양쪽 모두 준비되었는지 확인
	_check_both_ready()


# ═══════════════════════════════════════════════════════════════════════════════
# Multiplayer Methods
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_multiplayer() -> void:
	# 소켓과 match_id가 없으면 잘못된 상태
	assert(OnlineMatch.nakama_socket != null, "CharacterSelectScreen: Nakama socket is null!")
	assert(not OnlineMatch.get_match_id().is_empty(), "CharacterSelectScreen: Match ID is empty!")
	
	print("CharacterSelectScreen: Multiplayer mode enabled")
	
	# 상대방 peer_id 찾기
	var my_peer_id = multiplayer.get_unique_id()
	for peer_id in OnlineMatch.players:
		if peer_id != my_peer_id:
			_opponent_peer_id = peer_id
			print("CharacterSelectScreen: Found opponent peer_id=%d" % peer_id)
			break
	
	# 소켓에 캐릭터 선택 수신 리스너 등록
	if OnlineMatch.nakama_socket:
		OnlineMatch.nakama_socket.received_match_state.connect(_on_received_match_state)
	
	# 상태 UI 추가
	_add_status_ui()


func _add_status_ui() -> void:
	# 상대방 대기 상태 표시
	_status_label = Label.new()
	_status_label.text = "상대 대기 중..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position = Vector2(0, 560)
	_status_label.size = Vector2(1280, 30)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(_status_label)


func _update_status_ui() -> void:
	if not _status_label:
		return
	
	if _my_ready and _opponent_ready:
		_status_label.text = "게임 시작 중..."
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	elif _my_ready:
		_status_label.text = "상대 대기 중... (상대: %s)" % ("준비 완료" if _opponent_ready else "선택 중")
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		_status_label.text = "상대 대기 중..."
		_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _send_character_selection() -> void:
	if not OnlineMatch.nakama_socket:
		print("CharacterSelectScreen: Cannot send - no socket")
		return
	
	if _opponent_peer_id == 0:
		print("CharacterSelectScreen: No opponent found")
		return
	
	# NakamaMultiplayerBridge에서 상대방 presence 가져오기
	var opponent_presence = OnlineMatch.nakama_multiplayer_bridge.get_user_presence_for_peer(_opponent_peer_id)
	if not opponent_presence:
		print("CharacterSelectScreen: Cannot get opponent presence for peer_id=%d" % _opponent_peer_id)
		return
	
	var data := {
		"char_id": _my_character_id,
		"ready": _my_ready
	}
	var select_data := PackedByteArray()
	select_data.append_array(var_to_bytes(data))
	
	var match_id = OnlineMatch.get_match_id()
	OnlineMatch.nakama_socket.send_match_state_raw_async(match_id, CHAR_SELECT_OP_CODE, select_data, [opponent_presence])
	print("CharacterSelectScreen: Sent selection char_id=%s, ready=%s to peer_id=%d" % [_my_character_id, _my_ready, _opponent_peer_id])


func _on_received_match_state(match_state: NakamaRTAPI.MatchData) -> void:
	if match_state.op_code == CHAR_SELECT_OP_CODE:
		var data = bytes_to_var(match_state.binary_data)
		if data is Dictionary:
			_opponent_character_id = data.get("char_id", "")
			_opponent_ready = data.get("ready", false)
			print("CharacterSelectScreen: Received opponent selection char_id=%s, ready=%s" % [_opponent_character_id, _opponent_ready])
			
			_update_status_ui()
			_check_both_ready()


func _check_both_ready() -> void:
	if _my_ready and _opponent_ready:
		print("CharacterSelectScreen: Both players ready, starting game...")
		
		# 짧은 대기 후 게임 시작
		await get_tree().create_timer(0.5).timeout
		
		var battle := BattleScreen.new()
		
		# 아군/적군 정보 구성
		var allies: Array[Dictionary] = []
		var enemies: Array[Dictionary] = []
		
		# 상대방을 적군으로 추가
		if _opponent_peer_id > 0 and not _opponent_character_id.is_empty():
			enemies.append({"peer_id": _opponent_peer_id, "character_id": _opponent_character_id})
		
		# 데이터만 설정 (start_battle은 _ready()에서 호출됨)
		battle.set_battle_data(_my_character_id, allies, enemies)
		transition_requested.emit(battle)
