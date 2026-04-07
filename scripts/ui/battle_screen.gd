class_name BattleScreen
extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Battle Screen
# 실제 게임 플레이 화면 (Arena)
# ═══════════════════════════════════════════════════════════════════════════════

signal transition_requested(next_screen: Node)

var _player: Character
var _enemy: Character
var _registry: CharacterRegistry
var _game_time: float = 0.0
var _is_game_over: bool = false
var _is_multiplayer: bool = false  # 멀티플레이어 여부
var _remote_players: Dictionary = {}  # peer_id -> Character

var _time_label: Label
var _player_hp_bar: ProgressBar
var _player_mp_bar: ProgressBar
var _player_bp_bar: ProgressBar
var _enemy_hp_bar: ProgressBar
var _player_name_label: Label
var _enemy_name_label: Label

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_registry = CharacterRegistry.new()
	_create_ui()
	_spawn_characters()


func _process(delta: float) -> void:
	if _is_game_over:
		return
	
	_game_time += delta
	_update_time_display()
	_check_game_over()


func _create_ui() -> void:
	# 게임 화면 (배경)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 상단 HUD
	_create_hud()
	
	# 일시정지 버튼
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.position = Vector2(10, 10)
	pause_btn.size = Vector2(40, 40)
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)


func _create_hud() -> void:
	# 플레이어 상태 (좌측 하단)
	var player_hud := VBoxContainer.new()
	player_hud.position = Vector2(20, 580)
	player_hud.size = Vector2(200, 130)
	add_child(player_hud)
	
	_player_name_label = Label.new()
	_player_name_label.text = "Player_001"
	_player_name_label.add_theme_font_size_override("font_size", 14)
	player_hud.add_child(_player_name_label)
	
	# HP
	var hp_box := HBoxContainer.new()
	player_hud.add_child(hp_box)
	
	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.custom_minimum_size = Vector2(30, 20)
	hp_box.add_child(hp_label)
	
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.custom_minimum_size = Vector2(170, 20)
	_player_hp_bar.value = 100
	_player_hp_bar.show_percentage = false
	hp_box.add_child(_player_hp_bar)
	
	# MP
	var mp_box := HBoxContainer.new()
	player_hud.add_child(mp_box)
	
	var mp_label := Label.new()
	mp_label.text = "MP"
	mp_label.custom_minimum_size = Vector2(30, 20)
	mp_box.add_child(mp_label)
	
	_player_mp_bar = ProgressBar.new()
	_player_mp_bar.custom_minimum_size = Vector2(170, 20)
	_player_mp_bar.value = 100
	_player_mp_bar.show_percentage = false
	_player_mp_bar.modulate = Color(0.3, 0.5, 0.9)
	mp_box.add_child(_player_mp_bar)
	
	# BP
	var bp_box := HBoxContainer.new()
	player_hud.add_child(bp_box)
	
	var bp_label := Label.new()
	bp_label.text = "BP"
	bp_label.custom_minimum_size = Vector2(30, 20)
	bp_box.add_child(bp_label)
	
	_player_bp_bar = ProgressBar.new()
	_player_bp_bar.custom_minimum_size = Vector2(170, 20)
	_player_bp_bar.value = 100
	_player_bp_bar.show_percentage = false
	_player_bp_bar.modulate = Color(0.9, 0.6, 0.2)
	bp_box.add_child(_player_bp_bar)
	
	# 적 상태 (우측 하단)
	var enemy_hud := VBoxContainer.new()
	enemy_hud.position = Vector2(1060, 580)
	enemy_hud.size = Vector2(200, 80)
	add_child(enemy_hud)
	
	_enemy_name_label = Label.new()
	_enemy_name_label.text = "Enemy_Bot"
	_enemy_name_label.add_theme_font_size_override("font_size", 14)
	enemy_hud.add_child(_enemy_name_label)
	
	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.custom_minimum_size = Vector2(200, 25)
	_enemy_hp_bar.value = 100
	_enemy_hp_bar.show_percentage = false
	enemy_hud.add_child(_enemy_hp_bar)
	
	# 게임 시간 (상단 중앙)
	_time_label = Label.new()
	_time_label.text = "05:00"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.position = Vector2(0, 10)
	_time_label.size = Vector2(1280, 40)
	_time_label.add_theme_font_size_override("font_size", 28)
	_time_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(_time_label)


func _spawn_characters() -> void:
	# 멀티플레이어 모드 확인
	_is_multiplayer = OnlineMatch.nakama_socket != null and not OnlineMatch.get_match_id().is_empty()
	
	if _is_multiplayer:
		_spawn_multiplayer_characters()
	else:
		_spawn_singleplayer_characters()


func _spawn_singleplayer_characters() -> void:
	# 플레이어 캐릭터
	var player_data := _registry.get_character("gyro")
	_player = Character.new()
	_player.init(player_data)
	_player.position = Vector2(300, 360)
	_player.is_controllable = true  # 로컬 플레이어
	_player.died.connect(_on_player_died)
	_player.hp_changed.connect(_on_player_hp_changed)
	_player.mp_changed.connect(_on_player_mp_changed)
	_player.bp_changed.connect(_on_player_bp_changed)
	add_child(_player)
	
	# 적 캐릭터 (간단한 AI)
	var enemy_data := _registry.get_character("shamu")
	_enemy = Character.new()
	_enemy.init(enemy_data)
	_enemy.position = Vector2(980, 360)
	_enemy.died.connect(_on_enemy_died)
	_enemy.hp_changed.connect(_on_enemy_hp_changed)
	# 적은 플레이어 입력 비활성화
	_enemy.set_physics_process(false)
	add_child(_enemy)
	
	# 간단한 적 AI 시작
	_setup_enemy_ai()


func _spawn_multiplayer_characters() -> void:
	# OnlineMatch.players에서 플레이어 정보 가져오기
	var players = OnlineMatch.players
	var my_peer_id = multiplayer.get_unique_id()
	
	print("Spawning multiplayer characters. My peer_id: %d, players: %s" % [my_peer_id, players.keys()])
	
	# 플레이어 스폰 위치
	var spawn_positions = [
		Vector2(300, 360),   # Player 1 (왼쪽)
		Vector2(980, 360)    # Player 2 (오른쪽)
	]
	
	var spawn_index = 0
	for peer_id in players:
		var player_info = players[peer_id]
		var player_data: CharacterData
		
		# TODO: 캐릭터 선택 동기화 필요. 일단 기본 캐릭터 사용
		if peer_id == my_peer_id:
			player_data = _registry.get_character("gyro")
		else:
			player_data = _registry.get_character("shamu")
		
		var character := Character.new()
		character.init(player_data)
		character.position = spawn_positions[spawn_index]
		character.name = "Player_%d" % peer_id
		
		# 멀티플레이어 권한 설정
		character.set_multiplayer_authority(peer_id)
		
		if peer_id == my_peer_id:
			# 로컬 플레이어
			_player = character
			character.is_controllable = true
			character.died.connect(_on_player_died)
			character.hp_changed.connect(_on_player_hp_changed)
			character.mp_changed.connect(_on_player_mp_changed)
			character.bp_changed.connect(_on_player_bp_changed)
			# 이름 업데이트
			if _player_name_label and player_info.username:
				_player_name_label.text = player_info.username
		else:
			# 원격 플레이어
			_remote_players[peer_id] = character
			character.set_network_controlled(true)
			_enemy = character  # 호환성을 위해 _enemy에도 할당
			character.hp_changed.connect(_on_enemy_hp_changed)
			# 이름 업데이트
			if _enemy_name_label and player_info.username:
				_enemy_name_label.text = player_info.username
		
		add_child(character)
		spawn_index += 1
	
	print("Multiplayer characters spawned. Local: %s, Remote: %d" % [_player.name, _remote_players.size()])


func _setup_enemy_ai() -> void:
	# 간단한 AI: 랜덤하게 이동하고 공격
	while not _is_game_over and is_instance_valid(_enemy) and not _enemy.is_dead:
		await get_tree().create_timer(0.5).timeout
		
		if _is_game_over or not is_instance_valid(_enemy) or _enemy.is_dead:
			break
		
		# 플레이어 방향으로 이동
		if is_instance_valid(_player):
			var direction := (_player.position - _enemy.position).normalized()
			_enemy._facing_direction = direction
			
			# 이동 (velocity 직접 설정)
			_enemy.velocity = direction * _enemy.character_data.max_speed * 0.5
			_enemy.move_and_slide()
			
			# 가끔 공격
			if randf() > 0.6:
				if _enemy.position.distance_to(_player.position) < 100:
					_enemy.attack_melee()
				else:
					_enemy.attack_ranged()


func _update_time_display() -> void:
	var remaining: int = maxi(0, 300 - int(_game_time))
	@warning_ignore("integer_division")
	var minutes: int = remaining / 60
	var seconds: int = remaining % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]
	
	if remaining <= 0:
		_on_time_up()


func _check_game_over() -> void:
	# HP 바 업데이트
	if is_instance_valid(_player):
		_player_hp_bar.value = (float(_player.current_hp) / _player.character_data.max_hp) * 100
		_player_mp_bar.value = (float(_player.current_mp) / _player.character_data.max_mp) * 100
		_player_bp_bar.value = (float(_player.current_bp) / _player.character_data.max_bp) * 100


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	_player_hp_bar.value = (float(current) / max_hp) * 100


func _on_player_mp_changed(current: int, max_mp: int) -> void:
	_player_mp_bar.value = (float(current) / max_mp) * 100


func _on_player_bp_changed(current: int, max_bp: int) -> void:
	_player_bp_bar.value = (float(current) / max_bp) * 100


func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	if is_instance_valid(_enemy_hp_bar):
		_enemy_hp_bar.value = (float(current) / max_hp) * 100


func _on_player_died() -> void:
	_is_game_over = true
	await get_tree().create_timer(1.0).timeout
	_show_result(false)


func _on_enemy_died() -> void:
	_is_game_over = true
	await get_tree().create_timer(1.0).timeout
	_show_result(true)


func _on_time_up() -> void:
	_is_game_over = true
	# HP가 더 높은 쪽이 승리
	var player_wins := _player.current_hp > _enemy.current_hp
	_show_result(player_wins)


func _show_result(player_wins: bool) -> void:
	var result := ResultScreen.new()
	result.set_result(player_wins, _game_time)
	transition_requested.emit(result)


func _on_pause_pressed() -> void:
	# 간단한 일시정지 (게임 시간 정지)
	_is_game_over = true
	get_tree().paused = true
	
	# 재개 버튼 표시
	var resume_btn := Button.new()
	resume_btn.text = "계속하기"
	resume_btn.position = Vector2(540, 300)
	resume_btn.size = Vector2(200, 50)
	resume_btn.pressed.connect(func():
		get_tree().paused = false
		_is_game_over = false
		resume_btn.queue_free()
	)
	add_child(resume_btn)
