class_name CharacterScreen
extends Node2D

signal transition_requested(next_screen: Node)

var canvas: CanvasLayer
var slot_buttons: Array[Button] = []
var card_buttons: Array[Button] = []

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
	slot_title.position = Vector2(50, 110)
	canvas.add_child(slot_title)
	
	var slot_container := HBoxContainer.new()
	slot_container.position = Vector2(50, 150)
	slot_container.size = Vector2(1180, 140)
	slot_container.add_theme_constant_override("separation", 20)
	canvas.add_child(slot_container)
	
	for i in range(4):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 140)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slot_buttons.append(btn)
		slot_container.add_child(btn)
	
	# 하단: 보유 카드 리스트 레이아웃 (스크롤 기능 추가)
	var owned_title := Label.new()
	owned_title.text = "보유 카드"
	owned_title.add_theme_font_size_override("font_size", 24)
	owned_title.position = Vector2(50, 320)
	canvas.add_child(owned_title)
	
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(50, 360)
	scroll.size = Vector2(1180, 320)
	canvas.add_child(scroll)
	
	var owned_columns := HBoxContainer.new()
	owned_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_columns.add_theme_constant_override("separation", 20)
	scroll.add_child(owned_columns)
	
	var columns: Dictionary = {}
	for i in range(4):
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(280, 0)
		vbox.add_theme_constant_override("separation", 10)
		
		var col_label := Label.new()
		col_label.text = GameState.card_type_names[i]
		col_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(col_label)
		
		owned_columns.add_child(vbox)
		columns[i] = vbox
		
	for i in range(GameState.owned_cards.size()):
		var card_id = GameState.owned_cards[i]
		var card_data = GameState.card_db.get(card_id)
		var c_type = card_data.get("type", 0)
		
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 100)
		btn.pressed.connect(_on_card_pressed.bind(card_id))
		card_buttons.append(btn)
		columns[c_type].add_child(btn)
		
	# UI 초기화 렌더링
	_update_ui()

func _update_ui() -> void:
	# 장착 슬롯 렌더링
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		var type_name = GameState.card_type_names[i]
		var card_id = GameState.equipped_cards.get(i, "")
		
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		
		if card_id == "":
			btn.text = type_name + "\n(빈 슬롯)"
			style.bg_color = Color(0.2, 0.2, 0.2)
		else:
			var card_data = GameState.card_db.get(card_id)
			btn.text = type_name + "\n" + card_data["name"] + "\n(장착 됨)"
			style.bg_color = card_data["color"]
			
		btn.add_theme_stylebox_override("normal", style)
		
		var style_hover = style.duplicate()
		style_hover.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", style_hover)

	# 보유 카드 리스트 렌더링
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		var card_id = GameState.owned_cards[i]
		var card_data = GameState.card_db.get(card_id)
		
		var c_type = card_data.get("type", 0)
		var is_equipped = (GameState.equipped_cards.get(c_type) == card_id)
				
		var label_text = card_data["name"]
		if is_equipped:
			label_text += "\n[장착 중]"
			
		btn.text = label_text
		
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.bg_color = card_data["color"]
		if is_equipped:
			style.bg_color = style.bg_color.darkened(0.5) 
			style.border_width_bottom = 4
			style.border_width_top = 4
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_color = Color(1.0, 0.8, 0.2) # 황금색 테두리로 강조 표시
			
		btn.add_theme_stylebox_override("normal", style)
		
		var style_hover = style.duplicate()
		style_hover.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", style_hover)

func _on_slot_pressed(slot_index: int) -> void:
	GameState.equipped_cards[slot_index] = ""
	GameState.save_state()
	_update_ui()

func _on_card_pressed(card_id: String) -> void:
	var card_data = GameState.card_db.get(card_id)
	if card_data == null:
		return
		
	var c_type = card_data.get("type", 0)
	
	# 이미 장착된 카드라면 해제, 아니면 해당 종류 슬롯에 장착
	if GameState.equipped_cards.get(c_type) == card_id:
		GameState.equipped_cards[c_type] = ""
	else:
		GameState.equipped_cards[c_type] = card_id
			
	GameState.save_state()
	_update_ui()

func _on_back_pressed() -> void:
	var ResourceType = load("res://scripts/ui/lobby_screen.gd")
	var lobby = ResourceType.new()
	transition_requested.emit(lobby)
