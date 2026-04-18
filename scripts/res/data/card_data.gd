class_name CardData
extends RefCounted

var id: String
var name: String
var type: int  # 참고: GameState.CardType의 값
var color: Color

# 스텟 모디파이어 딕셔너리
# 구조: { "stat_name": {"add": 0.0, "mult": 1.0} }
var modifiers: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════════
# 이벤트 라이프사이클 훅 (Proc / 트리거용)
# ═══════════════════════════════════════════════════════════════════════════════

# 공격 발사 시 (투사체, 히트박스 등이 생성될 때)
# signature: func(attack_data: CharacterData.Attack, character: Character) -> void
var on_attack_launched: Callable

# 멈춰 있다가 이동을 시작할 때
# signature: func(character: Character) -> void
var on_move_started: Callable

# 데미지를 받을 때
# signature: func(damage: int, attacker: Character, target: Character) -> int (최종 데미지 반환)
var on_damage_taken: Callable


func _init(p_id: String, p_name: String, p_type: int, p_color: Color) -> void:
	id = p_id
	name = p_name
	type = p_type
	color = p_color

# ═══════════════════════════════════════════════════════════════════════════════
# Builder Pattern 편의 메서드 (카드 정의 단계에서 사용)
# ═══════════════════════════════════════════════════════════════════════════════

## 스텟 모디파이어 추가 (체인 호출 가능)
func add_modifier(stat_name: String, add_val: float = 0.0, mult_val: float = 1.0) -> CardData:
	modifiers[stat_name] = {"add": add_val, "mult": mult_val}
	return self

## 이동 시작 이벤트 셋 생성
func set_on_move(callback: Callable) -> CardData:
	on_move_started = callback
	return self

## 공격 발사 이벤트 연결
func set_on_attack(callback: Callable) -> CardData:
	on_attack_launched = callback
	return self

## 피격 시 이벤트 연결
func set_on_damage(callback: Callable) -> CardData:
	on_damage_taken = callback
	return self
