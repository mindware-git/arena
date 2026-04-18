class_name Projectile
extends Area2D

# ═══════════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════════

signal hit(target: Node2D)
signal out_of_range()

# ═══════════════════════════════════════════════════════════════════════════════
# Data
# ═══════════════════════════════════════════════════════════════════════════════

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 400.0
var _damage: int = 10
var _owner: Character = null
var _distance_traveled: float = 0.0
var _max_range: float = 500.0
var _element: GameManager.ElementType = GameManager.ElementType.EARTH
var _is_special: bool = false  # 필살기 투사체 여부
var _is_visual_only: bool = false  # 원격 클라이언트용 (시각 전용, 데미지 판정 없음)

# ═══════════════════════════════════════════════════════════════════════════════
# Properties
# ═══════════════════════════════════════════════════════════════════════════════

var direction: Vector2:
	get: return _direction

var damage: int:
	get: return _damage

var owner_character: Character:
	get: return _owner

# ═══════════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# 충돌 설정 (레이어 1: 캐릭터 감지)
	collision_mask = 1
	
	# 시각 전용 투사체는 충돌 감지 비활성화 (데미지 판정 안 함)
	if _is_visual_only:
		monitoring = false
	else:
		monitoring = true
		# 충돌 감지 시그널 연결 (owner 클라이언트만)
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
	
	# 시각적 표시
	_setup_visual()
	_setup_collision()


func init(
	p_direction: Vector2,
	p_speed: float,
	p_damage: int,
	p_owner: Character,
	p_max_range: float,
	p_element: GameManager.ElementType = GameManager.ElementType.EARTH,
	p_is_special: bool = false,
	p_visual_only: bool = false
) -> void:
	_direction = p_direction.normalized()
	_speed = p_speed
	_damage = p_damage
	_owner = p_owner
	_max_range = p_max_range
	_element = p_element
	_is_special = p_is_special
	_is_visual_only = p_visual_only


func _setup_visual() -> void:
	# 필살기 투사체는 더 크게 표시
	var size := 24 if _is_special else 12
	var sprite := ColorRect.new()
	sprite.color = _get_element_color() if not _is_special else Color(1.0, 0.8, 0.0)  # 필살기는 금색
	sprite.size = Vector2(size, size)
	sprite.position = Vector2(-size / 2.0, -size / 2.0)
	add_child(sprite)


func _setup_collision() -> void:
	# 충돌 영역 설정 (필살기는 더 큰 충돌 영역)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0 if _is_special else 6.0
	collision.shape = shape
	add_child(collision)


func _get_element_color() -> Color:
	match _element:
		GameManager.ElementType.WATER:
			return Color(0.3, 0.6, 1.0)
		GameManager.ElementType.FIRE:
			return Color(1.0, 0.4, 0.2)
		GameManager.ElementType.WIND:
			return Color(0.5, 0.9, 0.6)
		GameManager.ElementType.EARTH:
			return Color(0.8, 0.6, 0.4)
		_:
			return Color.WHITE

# ═══════════════════════════════════════════════════════════════════════════════
# Movement
# ═══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	# 이동
	var movement := _direction * _speed * delta
	position += movement
	
	# 사거리 체크
	_distance_traveled += movement.length()
	if _distance_traveled >= _max_range:
		out_of_range.emit()
		queue_free()

# ═══════════════════════════════════════════════════════════════════════════════
# Collision
# ═══════════════════════════════════════════════════════════════════════════════

func _on_body_entered(body: Node2D) -> void:
	# 발사한 캐릭터는 무시
	if body == _owner:
		return
	
	# Character에 충돌 시 데미지
	if body is Character:
		var character := body as Character
		# 네트워크 플레이어면 RPC로 데미지 전달
		if character.is_network_controlled():
			character.rpc("take_damage", _damage)
		else:
			character.take_damage(_damage)
		hit.emit(body)
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# 다른 투사체와 충돌 처리 (선택적)
	if area is Projectile and area != self:
		queue_free()
		area.queue_free()

# ═══════════════════════════════════════════════════════════════════════════════
# Debug
# ═══════════════════════════════════════════════════════════════════════════════

func get_debug_info() -> String:
	return "Projectile | DMG: %d | Range: %.0f/%.0f" % [
		_damage, _distance_traveled, _max_range
	]