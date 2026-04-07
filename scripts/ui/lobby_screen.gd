class_name LobbyScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Lobby Screen
# 메인 메뉴 - 플레이, 상점, 설정 등
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)

var _player_name_label: Label

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_create_ui()
	_update_player_name()


func _update_player_name() -> void:
	# OnlineMatch에서 현재 플레이어 이름 가져오기
	var my_peer_id = multiplayer.get_unique_id()
	if OnlineMatch.players.has(my_peer_id):
		var player = OnlineMatch.players[my_peer_id]
		if _player_name_label and player.username:
			_player_name_label.text = player.username
			print("LobbyScreen: Player name set to %s" % player.username)


func _create_ui() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 상단 헤더
	_create_header()
	
	# 중앙 메뉴
	_create_menu()
	
	# 하단 탭
	_create_bottom_tabs()


func _create_header() -> void:
	# 헤더 컨테이너
	var header := HBoxContainer.new()
	header.position = Vector2(20, 20)
	header.size = Vector2(1240, 60)
	add_child(header)
	
	# 플레이어 정보
	var player_info := VBoxContainer.new()
	player_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(player_info)
	
	_player_name_label = Label.new()
	_player_name_label.text = "Player_001"
	_player_name_label.add_theme_font_size_override("font_size", 18)
	player_info.add_child(_player_name_label)
	
	var level_label := Label.new()
	level_label.text = "Lv.1 | 0/100 XP"
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	player_info.add_child(level_label)
	
	# 화폐 표시
	var currency := HBoxContainer.new()
	header.add_child(currency)
	
	var coin_icon := Label.new()
	coin_icon.text = "🪙"
	coin_icon.add_theme_font_size_override("font_size", 20)
	currency.add_child(coin_icon)
	
	var coin_label := Label.new()
	coin_label.text = "1,000"
	coin_label.add_theme_font_size_override("font_size", 16)
	currency.add_child(coin_label)
	
	var gem_icon := Label.new()
	gem_icon.text = "💎"
	gem_icon.add_theme_font_size_override("font_size", 20)
	gem_icon.position = Vector2(80, 0)
	currency.add_child(gem_icon)
	
	var gem_label := Label.new()
	gem_label.text = "50"
	gem_label.add_theme_font_size_override("font_size", 16)
	currency.add_child(gem_label)


func _create_menu() -> void:
	# 중앙 버튼들
	var center := VBoxContainer.new()
	center.position = Vector2(440, 250)
	center.size = Vector2(400, 300)
	add_child(center)
	
	# PLAY 버튼 (가장 큼)
	var play_btn := Button.new()
	play_btn.text = "▶ PLAY"
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.custom_minimum_size = Vector2(400, 80)
	play_btn.add_theme_font_size_override("font_size", 24)
	play_btn.pressed.connect(_on_play_pressed)
	center.add_child(play_btn)
	
	# 간격
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer)
	
	# 매치 모드 버튼들
	var modes := HBoxContainer.new()
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(modes)
	
	var mode_1v1 := Button.new()
	mode_1v1.text = "1 vs 1"
	mode_1v1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_1v1.custom_minimum_size = Vector2(120, 50)
	modes.add_child(mode_1v1)
	
	var mode_3v3 := Button.new()
	mode_3v3.text = "3 vs 3"
	mode_3v3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_3v3.custom_minimum_size = Vector2(120, 50)
	modes.add_child(mode_3v3)
	
	var mode_5v5 := Button.new()
	mode_5v5.text = "5 vs 5"
	mode_5v5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_5v5.custom_minimum_size = Vector2(120, 50)
	modes.add_child(mode_5v5)


func _create_bottom_tabs() -> void:
	# 하단 탭바
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(0, 650)
	tabs.size = Vector2(1280, 70)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(tabs)
	
	# 홈
	var home_btn := Button.new()
	home_btn.text = "🏠\n홈"
	home_btn.custom_minimum_size = Vector2(80, 60)
	tabs.add_child(home_btn)
	
	# 상점
	var shop_btn := Button.new()
	shop_btn.text = "🛒\n상점"
	shop_btn.custom_minimum_size = Vector2(80, 60)
	shop_btn.pressed.connect(_on_shop_pressed)
	tabs.add_child(shop_btn)
	
	# 캐릭터
	var char_btn := Button.new()
	char_btn.text = "👤\n캐릭터"
	char_btn.custom_minimum_size = Vector2(80, 60)
	tabs.add_child(char_btn)
	
	# 랭킹
	var rank_btn := Button.new()
	rank_btn.text = "🏆\n랭킹"
	rank_btn.custom_minimum_size = Vector2(80, 60)
	tabs.add_child(rank_btn)
	
	# 설정
	var settings_btn := Button.new()
	settings_btn.text = "⚙️\n설정"
	settings_btn.custom_minimum_size = Vector2(80, 60)
	tabs.add_child(settings_btn)


func _on_play_pressed() -> void:
	# MatchingScreen으로 전환
	var matching := MatchingScreen.new()
	transition_requested.emit(matching)


func _on_shop_pressed() -> void:
	# ShopScreen으로 전환
	var shop := ShopScreen.new()
	transition_requested.emit(shop)
