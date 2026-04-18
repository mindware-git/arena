class_name CharacterData
extends Resource

# ═══════════════════════════════════════════════════════════════════════════════
# Attack Data (내부 클래스)
# ═══════════════════════════════════════════════════════════════════════════════

class Attack:
	## 공격 스타일
	enum Style {
		MELEE_HITBOX,   # 근접 히트박스
		PROJECTILE,     # 투사체 발사
		AOE_CENTER      # 자신 중심 광역
	}
	
	## 비용 타입
	enum CostType {
		NONE,  # 비용 없음
		MP,    # MP 소모
		BP     # BP 소모
	}
	
	var style: Style = Style.MELEE_HITBOX
	var damage: int = 10
	var cooldown: float = 0.5
	var range: float = 60.0
	var cost_type: CostType = CostType.NONE
	var cost_amount: int = 0
	var projectile_speed: float = 400.0  # 투사체용
	var hitbox_duration: float = 0.2     # 근접 히트박스 지속 시간
	
	func _init(
		p_style: Style = Style.MELEE_HITBOX,
		p_damage: int = 10,
		p_cooldown: float = 0.5,
		p_range: float = 60.0,
		p_cost_type: CostType = CostType.NONE,
		p_cost_amount: int = 0,
		p_projectile_speed: float = 400.0,
		p_hitbox_duration: float = 0.2
	) -> void:
		style = p_style
		damage = p_damage
		cooldown = p_cooldown
		range = p_range
		cost_type = p_cost_type
		cost_amount = p_cost_amount
		projectile_speed = p_projectile_speed
		hitbox_duration = p_hitbox_duration
	
	## 딕셔너리에서 생성
	static func from_dict(data: Dictionary) -> Attack:
		var attack := Attack.new()
		attack.style = data.get("style", Style.MELEE_HITBOX)
		attack.damage = data.get("damage", 10)
		attack.cooldown = data.get("cooldown", 0.5)
		attack.range = data.get("range", 60.0)
		attack.cost_type = data.get("cost_type", CostType.NONE)
		attack.cost_amount = data.get("cost_amount", 0)
		attack.projectile_speed = data.get("projectile_speed", 400.0)
		attack.hitbox_duration = data.get("hitbox_duration", 0.2)
		return attack
	
	## 딕셔너리로 변환 (직렬화용)
	func to_dict() -> Dictionary:
		return {
			"style": style,
			"damage": damage,
			"cooldown": cooldown,
			"range": range,
			"cost_type": cost_type,
			"cost_amount": cost_amount,
			"projectile_speed": projectile_speed,
			"hitbox_duration": hitbox_duration
		}

# ═══════════════════════════════════════════════════════════════════════════════
# 기본 정보
# ═══════════════════════════════════════════════════════════════════════════════

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var element: GameManager.ElementType = GameManager.ElementType.EARTH

# ═══════════════════════════════════════════════════════════════════════════════
# 능력치 (실제 수치)
# ═══════════════════════════════════════════════════════════════════════════════

## 체력
@export var max_hp: int = 100

## 마나
@export var max_mp: int = 50

## 탄환 포인트
@export var max_bp: int = 30

## 근거리 공격력 (기본값, Attack에서 덮어쓸 수 있음)
@export var melee_power: int = 10

## 원거리 공격력 (기본값, Attack에서 덮어쓸 수 있음)
@export var ranged_power: int = 10

## 최대 이동 속도 (픽셀/초)
@export var max_speed: float = 200.0

## 회전 속도 (라디안/초)
@export var rotation_speed: float = 5.0

## 가속도
@export var acceleration: float = 10.0

# ═══════════════════════════════════════════════════════════════════════════════
# 이동 타입
# ═══════════════════════════════════════════════════════════════════════════════

## 비행형 캐릭터 여부 (물웅덩이 페널티 무시)
@export var is_flying: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# 부스터 시스템
# ═══════════════════════════════════════════════════════════════════════════════

## 부스터 속도 배율
@export var booster_speed_multiplier: float = 2.0

## 부스터 초당 MP 소모량
@export var booster_mp_cost_per_sec: float = 15.0

## MP 자연 회복량 (초당)
@export var mp_regen_per_sec: float = 5.0

# ═══════════════════════════════════════════════════════════════════════════════
# 공격 시스템 (일반화)
# ═══════════════════════════════════════════════════════════════════════════════

## 공격 목록: [0]=버튼1, [1]=버튼2, [2]=필살기
## 인스펙터에서 편집할 수 있도록 @export
@export var attacks: Array[Dictionary] = []

## 투사체 사거리 (기본값)
@export var projectile_range: float = 500.0

# ═══════════════════════════════════════════════════════════════════════════════
# Attack 편의 메서드
# ═══════════════════════════════════════════════════════════════════════════════

## 공격 데이터 가져오기 (인덱스별)
func get_attack(index: int) -> Attack:
	if index < 0 or index >= attacks.size():
		return null
	return Attack.from_dict(attacks[index])

## 공격 개수
func get_attack_count() -> int:
	return attacks.size()

## 기본 공격 (버튼1)
func get_attack1() -> Attack:
	return get_attack(0)

## 보조 공격 (버튼2)
func get_attack2() -> Attack:
	return get_attack(1)

## 필살기 (버튼3)
func get_special() -> Attack:
	return get_attack(2)

# ═══════════════════════════════════════════════════════════════════════════════
# 등급 계산 (UI 표시용)
# ═══════════════════════════════════════════════════════════════════════════════

## 등급 기준: A(81-100%), B(61-80%), C(41-60%), D(0-40%)
const GRADE_THRESHOLDS: Array[int] = [81, 61, 41, 0]
const GRADE_LABELS: Array[String] = ["A", "B", "C", "D"]


func get_grade(value: float, max_value: float) -> String:
	var percent := (value / max_value) * 100.0
	for i in range(GRADE_THRESHOLDS.size()):
		if percent >= GRADE_THRESHOLDS[i]:
			return GRADE_LABELS[i]
	return "D"


func get_hp_grade() -> String:
	return get_grade(max_hp, 150.0)


func get_mp_grade() -> String:
	return get_grade(max_mp, 100.0)


func get_bp_grade() -> String:
	return get_grade(max_bp, 50.0)


func get_melee_power_grade() -> String:
	return get_grade(melee_power, 30.0)


func get_ranged_power_grade() -> String:
	return get_grade(ranged_power, 30.0)


func get_max_speed_grade() -> String:
	return get_grade(max_speed, 300.0)


func get_rotation_speed_grade() -> String:
	return get_grade(rotation_speed, 10.0)


func get_acceleration_grade() -> String:
	return get_grade(acceleration, 20.0)


## 모든 등급 정보를 딕셔너리로 반환
func get_all_grades() -> Dictionary:
	return {
		"hp": get_hp_grade(),
		"mp": get_mp_grade(),
		"bp": get_bp_grade(),
		"melee_power": get_melee_power_grade(),
		"ranged_power": get_ranged_power_grade(),
		"max_speed": get_max_speed_grade(),
		"rotation_speed": get_rotation_speed_grade(),
		"acceleration": get_acceleration_grade()
	}