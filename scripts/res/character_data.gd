class_name CharacterData
extends Resource

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

## 근거리 공격력
@export var melee_power: int = 10

## 원거리 공격력
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
# 공격 시스템
# ═══════════════════════════════════════════════════════════════════════════════

## 근거리 공격 쿨다운 (초)
@export var melee_cooldown: float = 0.5

## 근거리 공격 사거리
@export var melee_range: float = 60.0

## 근거리 히트박스 지속 시간 (초)
@export var melee_hitbox_duration: float = 0.2

## 원거리 공격 쿨다운 (초)
@export var ranged_cooldown: float = 0.3

## 원거리 공격 BP 소모량
@export var ranged_bp_cost: int = 1

## 투사체 속도
@export var projectile_speed: float = 400.0

## 투사체 사거리
@export var projectile_range: float = 500.0

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