class_name CharacterScreen
extends Node2D

signal transition_requested(next_screen: Node)

var canvas: CanvasLayer
var slot_buttons: Array[Button] = []
var card_buttons: Array[Button] = []

var _selected_slot: int = 0  # 기본으로 0번 슬롯 선택

func _ready() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)
	_create_ui()

func _create_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	# Header
	var header := Control.new()
	header.custom_minimum_size = Vector2(1280, 80)
	header.position = Vector2(0, 0)
	canvas.add_child(header)
	
	var back_btn := Button.new()
	back_btn.text = "◀ 뒤로가기"
	back_btn.position = Vector2(20, 20)
	back_btn.custom_minimum_size = Vector2(120, 50)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.2, 0.2)
	sb.set_corner_radius_all(5)
	back_btn.add_theme_stylebox_override("normal", sb)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)
	
	var title := Label.new()
	title.text = "장비 세팅"
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(580, 25)
	header.add_child(title)
	
	# 중단: 장착 슬롯 레이아웃
	var slot_title := Label.new()
	slot_title.text = "장착 중인 카드"
	slot_title.add_theme_font_size_override("font_size", 24)
	slot_title.position = Vector2(50, 120)
	canvas.add_child(slot_title)
	
	var slot_container := HBoxContainer.new()
	slot_container.position = Vector2(50, 160)
	slot_container.size = Vector2(1180, 150)
	slot_container.add_theme_constant_override("separation", 20)
	canvas.add_child(slot_container)
	
	for i in range(2):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(250, 150)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slot_buttons.append(btn)
		slot_container.add_child(btn)
	
	# 하단: 보유 카드 리스트 레이아웃
	var owned_title := Label.new()
	owned_title.text = "보유 카드"
	owned_title.add_theme_font_size_override("font_size", 24)
	owned_title.position = Vector2(50, 360)
	canvas.add_child(owned_title)
	
	var owned_container := HBoxContainer.new()
	owned_container.position = Vector2(50, 400)
	owned_container.size = Vector2(1180, 250)
	owned_container.add_theme_constant_override("separation", 20)
	canvas.add_child(owned_container)
	
	for i in range(GameState.owned_cards.size()):
		var card_id = GameState.owned_cards[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 250)
		btn.pressed.connect(_on_card_pressed.bind(card_id))
		card_buttons.append(btn)
		owned_container.add_child(btn)
		
	# UI 초기화 렌더링
	_update_ui()

func _update_ui() -> void:
	# 장착 슬롯 렌더링
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		var card_id = GameState.equipped_cards.get(i, "")
		
		# 선택 하이라이트 스타일
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		
		if i == _selected_slot:
			style.border_width_bottom = 6
			style.border_width_top = 6
			style.border_width_left = 6
			style.border_width_right = 6
			style.border_color = Color(1.0, 0.8, 0.2) # 황금색 박스 라인
		
		if card_id == "":
			btn.text = "빈 슬롯\n(선택 가능)"
			style.bg_color = Color(0.2, 0.2, 0.2)
		else:
			var card_data = GameState.card_db.get(card_id)
			btn.text = card_data["name"] + "\n(장착 됨)"
			style.bg_color = card_data["color"]
			
		btn.add_theme_stylebox_override("normal", style)
		
		# hover 
		var style_hover = style.duplicate()
		style_hover.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", style_hover)

	# 보유 카드 리스트 렌더링
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		var card_id = GameState.owned_cards[i]
		var card_data = GameState.card_db.get(card_id)
		
		# 이 카드가 어느 슬롯에 장착되어있는가?
		var eq_slot = -1
		for k in GameState.equipped_cards.keys():
			if GameState.equipped_cards[k] == card_id:
				eq_slot = k
				
		var label_text = card_data["name"]
		if eq_slot != -1:
			label_text += "\n[장착 중]"
			
		btn.text = label_text
		
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.bg_color = card_data["color"]
		if eq_slot != -1:
			style.bg_color = style.bg_color.darkened(0.5) # 연하게/어둡게 표시해 장착됨 표시
			
		btn.add_theme_stylebox_override("normal", style)
		
		var style_hover = style.duplicate()
		style_hover.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", style_hover)

func _on_slot_pressed(slot_index: int) -> void:
	if _selected_slot == slot_index:
		# 같은 슬롯을 또 눌렀으면 장착 해제
		GameState.equipped_cards[slot_index] = ""
		GameState.save_state()
	else:
		_selected_slot = slot_index
	_update_ui()

func _on_card_pressed(card_id: String) -> void:
	if _selected_slot < 0 or _selected_slot >= slot_buttons.size():
		return
		
	# 다른 슬롯에 같은 카드가 있는지 확인하여 해제 (한 카드를 여러 슬롯에 못 끼게)
	for k in GameState.equipped_cards.keys():
		if GameState.equipped_cards[k] == card_id:
			GameState.equipped_cards[k] = ""
			
	GameState.equipped_cards[_selected_slot] = card_id
	GameState.save_state()
	_update_ui()

func _on_back_pressed() -> void:
	var ResourceType = load("res://scripts/ui/lobby_screen.gd")
	var lobby = ResourceType.new()
	transition_requested.emit(lobby)
