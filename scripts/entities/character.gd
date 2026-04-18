class_name Character
extends CharacterBody2D

# ═══════════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════════

signal hp_changed(current: int, max_hp: int)
signal mp_changed(current: int, max_mp: int)
signal bp_changed(current: int, max_bp: int)
signal died()
signal booster_changed(is_active: bool)
signal attacked(attack_data: CharacterData.Attack)

# ═══════════════════════════════════════════════════════════════════════════════
# Network Sync Constants
# ═══════════════════════════════════════════════════════════════════════════════

const SYNC_DELAY := 3  # 몇 프레임마다 동기화할지
const POSITION_SYNC_OP_CODE := 9003  # 위치 동기화 op_code

var _sync_counter: int = 0
var _is_network_controlled: bool = false  # 원격 플레이어면 true

# ═══════════════════════════════════════════════════════════════════════════════
# Data
# ═══════════════════════════════════════════════════════════════════════════════

var _data: CharacterData

var _current_hp: int = 0
var _current_mp: int = 0
var _current_bp: int = 0

# Final Stats (Calculated from Data + Equips)
var _final_max_hp: int
var _final_max_mp: int
var _final_max_bp: int
var _final_melee_power: int
var _final_ranged_power: int
var _final_max_speed: float
var _final_rotation_speed: float
var _final_acceleration: float

var _final_critical_chance: float
var _final_critical_multiplier: float
var _final_accl_proc_chance: float

var _is_dead: bool = false
var _is_controllable: bool = false  # 플레이어만 true, 적은 false

# HP 바
var _hp_bar: ProgressBar = null

# 부스터
var _is_boosting: bool = false
var _booster_timer: float = 0.0

# 공격 쿨다운 (attack_index -> timer)
var _cooldowns: Dictionary = {}

# 근거리 히트박스
var _melee_hitbox: Area2D = null
var _melee_hitbox_timer: float = 0.0
var _melee_hitbox_active: bool = false
var _hitbox_damage: int = 0  # 현재 히트박스의 데미지
var _hitbox_duration: float = 0.2  # 현재 히트박스 지속 시간

# 방향
var _facing_direction: Vector2 = Vector2.RIGHT

# Aim 표시
var _aim_line: Line2D = null

# Proc 상태 저장
var _is_accl_proc_active: bool = false
var _accl_proc_timer: float = 0.0

# 카메라
var _camera: Camera2D = null

# ═══════════════════════════════════════════════════════════════════════════════
# Properties
# ═══════════════════════════════════════════════════════════════════════════════

var character_data: CharacterData:
	get: return _data

var current_hp: int:
	get: return _current_hp

var current_mp: int:
	get: return _current_mp

var current_bp: int:
	get: return _current_bp

var is_dead: bool:
	get: return _is_dead

var is_controllable: bool:
	get: return _is_controllable
	set(value): _is_controllable = value

var is_boosting: bool:
	get: return _is_boosting

var facing_direction: Vector2:
	get: return _facing_direction

# ═══════════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# 엔티티는 init() 호출 후 동작
	pass


func init(data: CharacterData) -> void:
	_data = data
	_calculate_final_stats()
	_current_hp = _final_max_hp
	_current_mp = _final_max_mp
	_current_bp = _final_max_bp
	_is_dead = false
	
	# 쿨다운 초기화
	_cooldowns.clear()
	for i in range(data.get_attack_count()):
		_cooldowns[i] = 0.0
	
	# 충돌 레이어 설정 (레이어 1: 캐릭터)
	collision_layer = 1
	
	# 충돌 영역 설정
	_setup_collision()
	
	# 시각적 표시를 위한 임시 설정
	_setup_visual()
	_setup_hp_bar()
	
	# 플레이어만 카메라 활성화
	if _is_controllable:
		_setup_camera()
	
	# Aim 표시 설정
	_setup_aim_indicator()

func _calculate_final_stats() -> void:
	if not _data: return
	
	var base_hp := float(_data.max_hp)
	var base_mp := float(_data.max_mp)
	var base_bp := float(_data.max_bp)
	var base_melee := float(_data.melee_power)
	var base_ranged := float(_data.ranged_power)
	var base_speed := _data.max_speed
	var base_rotation := _data.rotation_speed
	var base_accel := _data.acceleration
	
	var base_crit_chance := 0.0
	var base_crit_mult := 1.5
	var base_accl_proc := 0.0
	
	var add_mods := {
		"max_hp": 0.0, "max_mp": 0.0, "max_bp": 0.0,
		"melee_power": 0.0, "ranged_power": 0.0, "max_speed": 0.0,
		"rotation_speed": 0.0, "acceleration": 0.0,
		"critical_chance": 0.0, "critical_multiplier": 0.0, "accl_proc_chance": 0.0
	}
	var mult_mods := add_mods.duplicate()
	for k in mult_mods.keys(): mult_mods[k] = 1.0
	
	# 로컬 조작 플레이어만 카드 적용. 멀티나 몬스터의 경우 장비/스텟 적용 확장을 위해 수정해야할 수 있음
	if _is_controllable:
		if GameState.get("equipped_cards"):
			for slot in GameState.equipped_cards:
				var card_id = GameState.equipped_cards[slot]
				if card_id == "": continue
				
				var card: CardData = CardRegistry.get_card(card_id)
				if not card: continue
				
				for stat in card.modifiers:
					if add_mods.has(stat):
						add_mods[stat] += card.modifiers[stat].get("add", 0.0)
						mult_mods[stat] *= card.modifiers[stat].get("mult", 1.0)
	
	_final_max_hp = int(max(1, (base_hp + add_mods["max_hp"]) * mult_mods["max_hp"]))
	_final_max_mp = int(max(0, (base_mp + add_mods["max_mp"]) * mult_mods["max_mp"]))
	_final_max_bp = int(max(0, (base_bp + add_mods["max_bp"]) * mult_mods["max_bp"]))
	_final_melee_power = int(max(0, (base_melee + add_mods["melee_power"]) * mult_mods["melee_power"]))
	_final_ranged_power = int(max(0, (base_ranged + add_mods["ranged_power"]) * mult_mods["ranged_power"]))
	
	_final_max_speed = max(0.0, (base_speed + add_mods["max_speed"]) * mult_mods["max_speed"])
	_final_rotation_speed = max(0.0, (base_rotation + add_mods["rotation_speed"]) * mult_mods["rotation_speed"])
	_final_acceleration = max(0.0, (base_accel + add_mods["acceleration"]) * mult_mods["acceleration"])
	
	_final_critical_chance = clamp((base_crit_chance + add_mods["critical_chance"]) * mult_mods["critical_chance"], 0.0, 1.0)
	_final_critical_multiplier = max(1.0, (base_crit_mult + add_mods["critical_multiplier"]) * mult_mods["critical_multiplier"])
	_final_accl_proc_chance = clamp((base_accl_proc + add_mods["accl_proc_chance"]) * mult_mods["accl_proc_chance"], 0.0, 1.0)



func _setup_collision() -> void:
	# 캐릭터 충돌 영역 (캡슐 모양)
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 20.0
	shape.height = 50.0
	collision.shape = shape
	add_child(collision)


func _setup_visual() -> void:
	# 샤무인 경우 AnimatedSprite2D 사용
	if _data.id == "shamu":
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = load("res://asset/sprite/shamu_sprite.tres")
		sprite.play("default")
		add_child(sprite)
	else:
		# 기존: 색상으로 속성 표시
		var sprite := ColorRect.new()
		sprite.color = _get_element_color()
		sprite.size = Vector2(40, 60)
		sprite.position = Vector2(-20, -30)
		add_child(sprite)
	
	# 이름 표시 (공통)
	var label := Label.new()
	label.text = _data.display_name
	label.position = Vector2(-20, -50)
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)


func _get_element_color() -> Color:
	match _data.element:
		GameManager.ElementType.WATER:
			return Color(0.2, 0.5, 0.9)
		GameManager.ElementType.FIRE:
			return Color(0.9, 0.3, 0.2)
		GameManager.ElementType.WIND:
			return Color(0.3, 0.8, 0.4)
		GameManager.ElementType.EARTH:
			return Color(0.7, 0.5, 0.3)
		_:
			return Color.GRAY


func _setup_hp_bar() -> void:
	# HP 바 생성 (캐릭터 상단)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(40, 6)
	_hp_bar.position = Vector2(-20, -60)
	_hp_bar.max_value = _data.max_hp
	_hp_bar.value = _current_hp
	_hp_bar.show_percentage = false
	
	# 스타일 설정
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.2)  # 초록색
	style.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("fill", style)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("background", bg_style)
	
	add_child(_hp_bar)


func _setup_camera() -> void:
	# 플레이어 카메라 생성
	_camera = Camera2D.new()
	_camera.enabled = true
	add_child(_camera)


func _setup_aim_indicator() -> void:
	# Aim 방향 표시용 Line2D 생성
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1.0, 1.0, 0.0, 0.7)  # 노란색, 반투명
	_aim_line.z_index = 5
	add_child(_aim_line)
	_update_aim_line()


func _update_aim_line() -> void:
	if not _aim_line:
		return
	
	# 캐릭터 중심에서 facing_direction 방향으로 선 그리기
	var line_length := 50.0  # 선 길이
	_aim_line.clear_points()
	_aim_line.add_point(Vector2.ZERO)  # 캐릭터 중심
	_aim_line.add_point(_facing_direction * line_length)  # 방향 끝점

# ═══════════════════════════════════════════════════════════════════════════════
# Movement
# ═══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if _is_dead or not _data:
		return
	
	_update_cooldowns(delta)
	_regen_mp(delta)
	_handle_booster(delta)
	_handle_melee_hitbox(delta)
	
	# 네트워크 동기화 처리
	if _is_network_controlled:
		# 원격 플레이어는 동기화된 위치로 이동
		pass
	elif _is_controllable:
		# 로컬 플레이어만 입력 처리
		_move(delta)
		_handle_input()
		move_and_slide()
		
		# 네트워크 동기화 전송
		_sync_position_periodically()


func _move(delta: float) -> void:
	var input_dir := Vector2.ZERO
	
	# Virtual Joystick 찾기
	var joystick = _find_virtual_joystick()
	if joystick:
		input_dir = joystick.output.normalized()
	else:
		# 폴백: 방향키 사용
		if Input.is_action_pressed("ui_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("ui_right"):
			input_dir.x += 1
		if Input.is_action_pressed("ui_up"):
			input_dir.y -= 1
		if Input.is_action_pressed("ui_down"):
			input_dir.y += 1
		input_dir = input_dir.normalized()
	
	# 이동 방향 및 회전 업데이트 (lerp_angle 적용)
	if input_dir != Vector2.ZERO:
		var current_angle = _facing_direction.angle()
		var target_angle = input_dir.angle()
		var new_angle = lerp_angle(current_angle, target_angle, _final_rotation_speed * delta)
		_facing_direction = Vector2.RIGHT.rotated(new_angle).normalized()
		_update_aim_line()
		
		# 정지 상태에서 출발할 때 '가속도 발동' 판정
		if velocity.length() < 10.0 and not _is_accl_proc_active:
			if randf() <= _final_accl_proc_chance:
				_is_accl_proc_active = true
	else:
		_is_accl_proc_active = false
	
	# 속도 계산 (부스터 고려)
	var target_speed := _final_max_speed
	if _is_boosting:
		target_speed = _final_max_speed * _data.booster_speed_multiplier
	
	# 실제 적용 가속도 결정
	var current_accel = _final_acceleration
	if _is_accl_proc_active:
		current_accel *= 5.0 # 발동 시 5배 가속
	
	# 이동 적용
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * target_speed, current_accel * delta * 10)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_accel * delta * 10)


func _handle_input() -> void:
	# 부스터 입력
	if Input.is_action_just_pressed("booster"):
		start_boost()
	elif Input.is_action_just_released("booster"):
		stop_boost()
	
	# 공격 입력 (일반화)
	if Input.is_action_just_pressed("attack_type1"):
		execute_attack_by_index(0)
	if Input.is_action_just_pressed("attack_type2"):
		execute_attack_by_index(1)
	if Input.is_action_just_pressed("attack_special"):
		execute_attack_by_index(2)

# ═══════════════════════════════════════════════════════════════════════════════
# Stats
# ═══════════════════════════════════════════════════════════════════════════════

@rpc("any_peer", "call_remote", "reliable")
func take_damage(amount: int) -> void:
	if _is_dead:
		return
	
	_current_hp = maxi(0, _current_hp - amount)
	hp_changed.emit(_current_hp, _data.max_hp)
	_update_hp_bar()
	
	if _current_hp <= 0:
		if not _is_network_controlled:
			# 내가 Owner인 경우: 사망 판정 후 브로드캐스트
			_die()
			rpc("sync_death")
		else:
			# 내가 Owner가 아닌 경우: 화면에서만 숨기고 공식 사망(sync_death) 대기
			visible = false

@rpc("any_peer", "call_remote", "reliable")
func sync_death() -> void:
	if not _is_dead:
		_die()

## 다른 캐릭터에게 데미지 적용 (Owner 클라이언트가 실행)
func apply_damage_to(target: Character, amount: int) -> void:
	if not target:
		return
	
	# 1. 로컬에 즉시 적용 (내 화면에서 상대 HP 즉시 감소)
	target.take_damage(amount)
	
	# 2. RPC 브로드캐스트 (상대 클라이언트 및 제3자 클라이언트 화면 갱신용)
	if target._is_network_controlled:
		target.rpc("take_damage", amount)


func _update_hp_bar() -> void:
	if _hp_bar:
		_hp_bar.value = _current_hp
		
		# HP 비율에 따른 색상 변경
		var ratio := float(_current_hp) / float(_data.max_hp)
		var style: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill")
		if style:
			if ratio > 0.5:
				style.bg_color = Color(0.2, 0.8, 0.2)  # 초록
			elif ratio > 0.25:
				style.bg_color = Color(0.9, 0.8, 0.2)  # 노랑
			else:
				style.bg_color = Color(0.9, 0.2, 0.2)  # 빨강


func heal(amount: int) -> void:
	if _is_dead:
		return
	
	_current_hp = mini(_data.max_hp, _current_hp + amount)
	hp_changed.emit(_current_hp, _data.max_hp)


func use_mp(amount: int) -> bool:
	if _current_mp < amount:
		return false
	
	_current_mp -= amount
	mp_changed.emit(_current_mp, _data.max_mp)
	return true


func restore_mp(amount: int) -> void:
	_current_mp = mini(_data.max_mp, _current_mp + amount)
	mp_changed.emit(_current_mp, _data.max_mp)


func use_bp(amount: int) -> bool:
	if _current_bp < amount:
		return false
	
	_current_bp -= amount
	bp_changed.emit(_current_bp, _data.max_bp)
	return true


func restore_bp(amount: int) -> void:
	_current_bp = mini(_data.max_bp, _current_bp + amount)
	bp_changed.emit(_current_bp, _data.max_bp)


func _die() -> void:
	_is_dead = true
	_is_boosting = false
	visible = false
	died.emit()

# ═══════════════════════════════════════════════════════════════════════════════
# Cooldowns & Regen
# ═══════════════════════════════════════════════════════════════════════════════

func _update_cooldowns(delta: float) -> void:
	for key in _cooldowns.keys():
		if _cooldowns[key] > 0:
			_cooldowns[key] -= delta


func _regen_mp(delta: float) -> void:
	if _is_boosting or _is_dead:
		return
	
	restore_mp(int(_data.mp_regen_per_sec * delta))

# ═══════════════════════════════════════════════════════════════════════════════
# Booster System
# ═══════════════════════════════════════════════════════════════════════════════

func start_boost() -> bool:
	if _is_dead or _is_boosting:
		return false
	
	if _current_mp <= 0:
		return false
	
	_is_boosting = true
	_booster_timer = 0.0
	booster_changed.emit(true)
	return true


func stop_boost() -> void:
	if not _is_boosting:
		return
	
	_is_boosting = false
	booster_changed.emit(false)


func _handle_booster(delta: float) -> void:
	if not _is_boosting:
		return
	
	# MP 소모
	_booster_timer += delta
	var mp_cost := _data.booster_mp_cost_per_sec * delta
	
	if _current_mp <= mp_cost:
		stop_boost()
		return
	
	use_mp(int(mp_cost))

# ═══════════════════════════════════════════════════════════════════════════════
# Attack System (일반화)
# ═══════════════════════════════════════════════════════════════════════════════

## 인덱스로 공격 실행 (입력 핸들러용)
func execute_attack_by_index(index: int) -> bool:
	var attack := _data.get_attack(index)
	if not attack:
		return false
	return execute_attack(attack, index)


## 공격 실행 (일반화)
func execute_attack(attack: CharacterData.Attack, index: int = -1) -> bool:
	if _is_dead:
		return false
	
	# 쿨다운 체크
	if index >= 0 and _cooldowns.get(index, 0) > 0:
		return false
	
	# 비용 지불
	if not _pay_cost(attack):
		return false
	
	# 스타일별 실행
	match attack.style:
		CharacterData.Attack.Style.MELEE_HITBOX:
			_execute_melee_hitbox(attack)
		CharacterData.Attack.Style.PROJECTILE:
			_execute_projectile(attack)
		CharacterData.Attack.Style.AOE_CENTER:
			_execute_aoe_center(attack)
			
	# 이벤트 트리거 (로컬 캐릭터만)
	if _is_controllable:
		if GameState.get("equipped_cards"):
			for slot in GameState.equipped_cards:
				var c_id = GameState.equipped_cards[slot]
				if c_id == "": continue
				var c: CardData = CardRegistry.get_card(c_id)
				if c and c.on_attack_launched:
					c.on_attack_launched.call(attack, self)
	
	# 쿨다운 설정
	if index >= 0:
		_cooldowns[index] = attack.cooldown
	
	attacked.emit(attack)
	return true


## 비용 지불
func _pay_cost(attack: CharacterData.Attack) -> bool:
	match attack.cost_type:
		CharacterData.Attack.CostType.MP:
			return use_mp(attack.cost_amount)
		CharacterData.Attack.CostType.BP:
			return use_bp(attack.cost_amount)
		_:
			return true  # NONE


## 최종 데미지 산출기
func _get_final_damage(base_dmg: int, is_melee: bool) -> int:
	var pwr = _final_melee_power if is_melee else _final_ranged_power
	var final_dmg = base_dmg + pwr
	
	if _final_critical_chance > 0.0 and randf() <= _final_critical_chance:
		final_dmg = int(final_dmg * _final_critical_multiplier)
		
	return final_dmg

## 근접 히트박스 공격 실행
func _execute_melee_hitbox(attack: CharacterData.Attack) -> void:
	var dmg = _get_final_damage(attack.damage, true)
	_activate_hitbox(attack.range / 2.0, dmg, attack.hitbox_duration)


## 투사체 공격 실행
func _execute_projectile(attack: CharacterData.Attack) -> void:
	var is_special := attack.cost_type == CharacterData.Attack.CostType.MP
	var dmg = _get_final_damage(attack.damage, false)
	
	# 로컬 투사체 생성 (데미지 판정 함)
	var projectile := Projectile.new()
	projectile.init(
		_facing_direction,
		attack.projectile_speed,
		dmg,
		self,
		_data.projectile_range,
		_data.element,
		is_special
	)
	projectile.position = position
	
	var parent := get_parent()
	if parent:
		parent.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)
	
	# 원격 클라이언트에 투사체 생성 동기화 (RPC)
	_sync_projectile_spawn(
		_facing_direction,
		attack.projectile_speed,
		dmg,
		position,
		_data.projectile_range,
		int(_data.element),
		is_special
	)


## AOE 광역 공격 실행
func _execute_aoe_center(attack: CharacterData.Attack) -> void:
	var dmg = _get_final_damage(attack.damage, true)
	_activate_aoe_hitbox(attack.range, dmg)
	_show_special_effect(attack.range)


## 히트박스 활성화
func _activate_hitbox(radius: float, damage: int, duration: float = 0.2) -> void:
	_hitbox_damage = damage
	_hitbox_duration = duration
	
	# 히트박스가 없으면 생성
	if not _melee_hitbox:
		_melee_hitbox = Area2D.new()
		_melee_hitbox.collision_mask = 1  # 레이어 1 (캐릭터) 감지
		
		# 충돌 모양 (원형)
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		collision.shape = shape
		_melee_hitbox.add_child(collision)
		
		# 시각적 표시 (디버그용)
		var visual := ColorRect.new()
		visual.color = Color(1.0, 1.0, 0.0, 0.3)
		_melee_hitbox.add_child(visual)
		
		# 시그널 연결
		_melee_hitbox.body_entered.connect(_on_melee_hitbox_entered)
		add_child(_melee_hitbox)
	
	# 히트박스 크기 및 위치 설정
	var collision_shape: CollisionShape2D = _melee_hitbox.get_child(0)
	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	circle_shape.radius = radius
	
	var visual_rect: ColorRect = _melee_hitbox.get_child(1)
	visual_rect.size = Vector2(radius * 2, radius * 2)
	visual_rect.position = Vector2(-radius, -radius)
	
	_melee_hitbox.position = _facing_direction * (radius + 20.0)
	_melee_hitbox.monitoring = true
	_melee_hitbox.visible = true
	_melee_hitbox_active = true
	_melee_hitbox_timer = _hitbox_duration


func _handle_melee_hitbox(delta: float) -> void:
	if not _melee_hitbox_active:
		return
	
	_melee_hitbox_timer -= delta
	if _melee_hitbox_timer <= 0:
		_deactivate_melee_hitbox()


func _deactivate_melee_hitbox() -> void:
	if _melee_hitbox:
		_melee_hitbox.monitoring = false
		_melee_hitbox.visible = false
	_melee_hitbox_active = false


func _on_melee_hitbox_entered(body: Node2D) -> void:
	if body == self:
		return
	
	if body is Character:
		var character := body as Character
		# 공격 주체가 데미지 적용
		apply_damage_to(character, _hitbox_damage)


## AOE 히트박스 활성화
func _activate_aoe_hitbox(radius: float, damage: int) -> void:
	_hitbox_damage = damage
	
	# AOE용 히트박스 생성 (캐릭터 중심)
	var aoe_hitbox := Area2D.new()
	aoe_hitbox.collision_mask = 1  # 레이어 1 (캐릭터) 감지
	
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	aoe_hitbox.add_child(collision)
	add_child(aoe_hitbox)
	
	# 현재 겹치는 모든 적에게 데미지
	for body in aoe_hitbox.get_overlapping_bodies():
		if body != self and body is Character:
			var character := body as Character
			# 공격 주체가 데미지 적용
			apply_damage_to(character, _hitbox_damage)
	
	# 즉시 제거
	aoe_hitbox.queue_free()


## 특수 효과 표시
func _show_special_effect(radius: float) -> void:
	# 임시 시각 효과: 원형 히트박스 표시
	var effect := ColorRect.new()
	effect.color = Color(1.0, 0.8, 0.0, 0.5)  # 금색 반투명
	effect.size = Vector2(radius * 2, radius * 2)
	effect.position = Vector2(-radius, -radius)
	effect.z_index = 10
	add_child(effect)
	
	# 0.3초 후 제거
	get_tree().create_timer(0.3).timeout.connect(effect.queue_free)


## 공격 가능 여부 확인 (인덱스)
func can_attack(index: int) -> bool:
	if _is_dead:
		return false
	
	var attack := _data.get_attack(index)
	if not attack:
		return false
	
	if _cooldowns.get(index, 0) > 0:
		return false
	
	# 비용 확인
	match attack.cost_type:
		CharacterData.Attack.CostType.MP:
			return _current_mp >= attack.cost_amount
		CharacterData.Attack.CostType.BP:
			return _current_bp >= attack.cost_amount
		_:
			return true

# ═══════════════════════════════════════════════════════════════════════════════
# Network Sync Methods
# ═══════════════════════════════════════════════════════════════════════════════

func set_network_controlled(is_network: bool) -> void:
	_is_network_controlled = is_network
	if is_network:
		# 원격 플레이어는 입력 비활성화
		_is_controllable = false


func is_network_controlled() -> bool:
	return _is_network_controlled


func _sync_position_periodically() -> void:
	# 온라인 플레이가 아니면 동기화하지 않음
	if not OnlineMatch.nakama_socket or OnlineMatch.get_match_id().is_empty():
		return
	
	_sync_counter += 1
	if _sync_counter < SYNC_DELAY:
		return
	_sync_counter = 0
	
	# RPC로 위치 동기화 전송
	rpc("sync_remote_position", position, velocity, _facing_direction, _current_hp)


@rpc("any_peer", "unreliable")
func sync_remote_position(_pos: Vector2, _vel: Vector2, _facing: Vector2, _hp: int) -> void:
	# 원격 플레이어 위치 업데이트
	if _is_network_controlled:
		position = _pos
		velocity = _vel
		_facing_direction = _facing
		_current_hp = _hp
		_update_hp_bar()


func _sync_projectile_spawn(
	dir: Vector2, speed: float, damage: int, pos: Vector2,
	max_range: float, element: int, is_special: bool
) -> void:
	# 온라인 플레이가 아니면 동기화하지 않음
	if not OnlineMatch.nakama_socket or OnlineMatch.get_match_id().is_empty():
		return
	rpc("_spawn_remote_projectile", dir, speed, damage, pos, max_range, element, is_special)


@rpc("any_peer", "reliable")
func _spawn_remote_projectile(
	dir: Vector2, speed: float, damage: int, pos: Vector2,
	max_range: float, element: int, is_special: bool
) -> void:
	# 원격 클라이언트에서 시각 전용 투사체 생성 (데미지 판정 없음)
	var projectile := Projectile.new()
	projectile.init(
		dir, speed, damage, self, max_range,
		element as GameManager.ElementType,
		is_special,
		true  # visual_only = true
	)
	projectile.position = pos
	
	var parent := get_parent()
	if parent:
		parent.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)


# ═══════════════════════════════════════════════════════════════════════════════
# Helper Methods
# ═══════════════════════════════════════════════════════════════════════════════

func _find_virtual_joystick() -> VirtualJoystick:
	# 씬 트리에서 VirtualJoystick 찾기
	var tree := get_tree()
	if not tree:
		return null
	
	# BattleHUD -> Control -> JoystickControl -> Virtual Joystick 경로
	var root := tree.root
	if not root:
		return null
	
	# 모든 노드에서 VirtualJoystick 타입 찾기
	var nodes := root.find_children("*", "VirtualJoystick", true, false)
	if nodes.size() > 0:
		return nodes[0]
	
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Debug
# ═══════════════════════════════════════════════════════════════════════════════

func get_debug_info() -> String:
	if not _data:
		return "No data"
	
	var boost_status := "BOOST" if _is_boosting else ""
	var network_status := "NET" if _is_network_controlled else "LOCAL"
	return "%s | HP: %d/%d | MP: %d/%d | BP: %d/%d | %s | %s" % [
		_data.display_name,
		_current_hp, _data.max_hp,
		_current_mp, _data.max_mp,
		_current_bp, _data.max_bp,
		boost_status,
		network_status
	]
