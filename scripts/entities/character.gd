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
signal attacked(is_ranged: bool)

# ═══════════════════════════════════════════════════════════════════════════════
# Data
# ═══════════════════════════════════════════════════════════════════════════════

var _data: CharacterData

var _current_hp: int = 0
var _current_mp: int = 0
var _current_bp: int = 0

var _is_dead: bool = false

# 부스터
var _is_boosting: bool = false
var _booster_timer: float = 0.0

# 공격
var _melee_cooldown_timer: float = 0.0
var _ranged_cooldown_timer: float = 0.0

# 근거리 히트박스
var _melee_hitbox: Area2D = null
var _melee_hitbox_timer: float = 0.0
var _melee_hitbox_active: bool = false

# 방향
var _facing_direction: Vector2 = Vector2.RIGHT

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
	_current_hp = data.max_hp
	_current_mp = data.max_mp
	_current_bp = data.max_bp
	_is_dead = false
	
	# 시각적 표시를 위한 임시 설정
	_setup_visual()


func _setup_visual() -> void:
	# 임시: 색상으로 속성 표시
	var sprite := ColorRect.new()
	sprite.color = _get_element_color()
	sprite.size = Vector2(40, 60)
	sprite.position = Vector2(-20, -30)
	add_child(sprite)
	
	# 이름 표시
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
	_move(delta)
	_handle_input()
	move_and_slide()


func _move(delta: float) -> void:
	var input_dir := Vector2.ZERO
	
	# 방향키만 사용 (WASD 제거)
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	if Input.is_action_pressed("ui_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.y += 1
	
	input_dir = input_dir.normalized()
	
	# 이동 방향 업데이트
	if input_dir != Vector2.ZERO:
		_facing_direction = input_dir
	
	# 속도 계산 (부스터 고려)
	var target_speed := _data.max_speed
	if _is_boosting:
		target_speed = _data.max_speed * _data.booster_speed_multiplier
	
	# 가속도 적용
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * target_speed, _data.acceleration * delta * 10)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, _data.acceleration * delta * 10)


func _handle_input() -> void:
	# 부스터 입력
	if Input.is_action_just_pressed("booster"):
		start_boost()
	elif Input.is_action_just_released("booster"):
		stop_boost()
	
	# 공격 입력
	if Input.is_action_just_pressed("attack_melee"):
		attack_melee()
	if Input.is_action_just_pressed("attack_ranged"):
		attack_ranged()

# ═══════════════════════════════════════════════════════════════════════════════
# Stats
# ═══════════════════════════════════════════════════════════════════════════════

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	
	_current_hp = maxi(0, _current_hp - amount)
	hp_changed.emit(_current_hp, _data.max_hp)
	
	if _current_hp <= 0:
		_die()


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
	died.emit()

# ═══════════════════════════════════════════════════════════════════════════════
# Cooldowns & Regen
# ═══════════════════════════════════════════════════════════════════════════════

func _update_cooldowns(delta: float) -> void:
	if _melee_cooldown_timer > 0:
		_melee_cooldown_timer -= delta
	if _ranged_cooldown_timer > 0:
		_ranged_cooldown_timer -= delta


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
# Attack System
# ═══════════════════════════════════════════════════════════════════════════════

func attack_melee() -> bool:
	if _is_dead:
		return false
	
	if _melee_cooldown_timer > 0:
		return false
	
	_melee_cooldown_timer = _data.melee_cooldown
	_activate_melee_hitbox()
	attacked.emit(false)
	return true


func _activate_melee_hitbox() -> void:
	# 히트박스가 없으면 생성
	if not _melee_hitbox:
		_melee_hitbox = Area2D.new()
		
		# 충돌 모양 (캐릭터 앞쪽 원형)
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = _data.melee_range / 2.0
		collision.shape = shape
		_melee_hitbox.add_child(collision)
		
		# 시각적 표시 (디버그용)
		var visual := ColorRect.new()
		visual.color = Color(1.0, 1.0, 0.0, 0.3)
		visual.size = Vector2(_data.melee_range, _data.melee_range)
		visual.position = Vector2(-_data.melee_range / 2.0, -_data.melee_range / 2.0)
		_melee_hitbox.add_child(visual)
		
		# 시그널 연결
		_melee_hitbox.body_entered.connect(_on_melee_hitbox_entered)
		add_child(_melee_hitbox)
	
	# 히트박스 위치 설정 (캐릭터 앞쪽)
	_melee_hitbox.position = _facing_direction * (_data.melee_range / 2.0 + 20.0)
	_melee_hitbox.monitoring = true
	_melee_hitbox.visible = true
	_melee_hitbox_active = true
	_melee_hitbox_timer = _data.melee_hitbox_duration


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
		character.take_damage(_data.melee_power)


func attack_ranged() -> bool:
	if _is_dead:
		return false
	
	if _ranged_cooldown_timer > 0:
		return false
	
	if not use_bp(_data.ranged_bp_cost):
		return false
	
	_ranged_cooldown_timer = _data.ranged_cooldown
	_spawn_projectile()
	attacked.emit(true)
	return true


func _spawn_projectile() -> void:
	var projectile := Projectile.new()
	projectile.init(
		_facing_direction,
		_data.projectile_speed,
		_data.ranged_power,
		self,
		_data.projectile_range,
		_data.element
	)
	projectile.position = position
	
	# 씬에 추가 (부모 씬 또는 최상위 노드)
	var parent := get_parent()
	if parent:
		parent.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)


func can_attack_melee() -> bool:
	return not _is_dead and _melee_cooldown_timer <= 0


func can_attack_ranged() -> bool:
	return not _is_dead and _ranged_cooldown_timer <= 0 and _current_bp >= _data.ranged_bp_cost

# ═══════════════════════════════════════════════════════════════════════════════
# Debug
# ═══════════════════════════════════════════════════════════════════════════════

func get_debug_info() -> String:
	if not _data:
		return "No data"
	
	var boost_status := "BOOST" if _is_boosting else ""
	return "%s | HP: %d/%d | MP: %d/%d | BP: %d/%d | %s" % [
		_data.display_name,
		_current_hp, _data.max_hp,
		_current_mp, _data.max_mp,
		_current_bp, _data.max_bp,
		boost_status
	]
