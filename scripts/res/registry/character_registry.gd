class_name CharacterRegistry
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
# 캐릭터 데이터 레지스트리 (Code-First)
# ═══════════════════════════════════════════════════════════════════════════════

var _characters: Dictionary = {}


func _init() -> void:
	_register_all_characters()


func _register_all_characters() -> void:
	_register_gyro()
	_register_shamu()
	_register_enemy_slime()


# ═══════════════════════════════════════════════════════════════════════════════
# 자이로 (Gyro)
# ═══════════════════════════════════════════════════════════════════════════════

func _register_gyro() -> void:
	var data := CharacterData.new()
	data.id = "gyro"
	data.display_name = "자이로"
	data.description = "균형 잡힌 전사"
	data.element = GameManager.ElementType.EARTH
	
	# 능력치
	data.max_hp = 120
	data.max_mp = 60
	data.max_bp = 40
	data.melee_power = 15
	data.ranged_power = 12
	data.max_speed = 220.0
	data.rotation_speed = 6.0
	data.acceleration = 12.0
	data.is_flying = false
	
	# 공격 목록
	# [0] 버튼1: 근접 공격
	var attack1 := CharacterData.Attack.new(
		CharacterData.Attack.Style.MELEE_HITBOX,
		15,    # damage
		0.5,   # cooldown
		60.0   # range
	)
	data.attacks.append(attack1.to_dict())
	
	# [1] 버튼2: 원거리 공격 (BP 사용)
	var attack2 := CharacterData.Attack.new(
		CharacterData.Attack.Style.PROJECTILE,
		12,    # damage
		0.8,   # cooldown
		500.0, # range
		CharacterData.Attack.CostType.BP,
		5      # cost_amount
	)
	attack2.projectile_speed = 450.0
	data.attacks.append(attack2.to_dict())
	
	# [2] 필살기: 근접 광역 (MP 사용)
	var special := CharacterData.Attack.new(
		CharacterData.Attack.Style.AOE_CENTER,
		50,    # damage
		5.0,   # cooldown
		150.0, # range
		CharacterData.Attack.CostType.MP,
		30     # cost_amount
	)
	data.attacks.append(special.to_dict())
	
	_characters[data.id] = data


# ═══════════════════════════════════════════════════════════════════════════════
# 샤무 (Shamu)
# ═══════════════════════════════════════════════════════════════════════════════

func _register_shamu() -> void:
	var data := CharacterData.new()
	data.id = "shamu"
	data.display_name = "샤무"
	data.description = "민첩한 마법사"
	data.element = GameManager.ElementType.WIND
	
	# 능력치
	data.max_hp = 80
	data.max_mp = 100
	data.max_bp = 50
	data.melee_power = 8
	data.ranged_power = 20
	data.max_speed = 280.0
	data.rotation_speed = 8.0
	data.acceleration = 15.0
	data.is_flying = true
	
	# 공격 목록
	# [0] 버튼1: 원거리 공격
	var attack1 := CharacterData.Attack.new(
		CharacterData.Attack.Style.PROJECTILE,
		15,    # damage
		0.6,   # cooldown
		500.0  # range
	)
	attack1.projectile_speed = 500.0
	data.attacks.append(attack1.to_dict())
	
	# [1] 버튼2: 원거리 공격 (BP 사용)
	var attack2 := CharacterData.Attack.new(
		CharacterData.Attack.Style.PROJECTILE,
		20,    # damage
		1.0,   # cooldown
		600.0, # range
		CharacterData.Attack.CostType.BP,
		8      # cost_amount
	)
	attack2.projectile_speed = 550.0
	data.attacks.append(attack2.to_dict())
	
	# [2] 필살기: 특수 마법 투사체 (MP 사용)
	var special := CharacterData.Attack.new(
		CharacterData.Attack.Style.PROJECTILE,
		40,    # damage
		4.0,   # cooldown
		700.0, # range
		CharacterData.Attack.CostType.MP,
		35     # cost_amount
	)
	special.projectile_speed = 600.0
	data.attacks.append(special.to_dict())
	
	_characters[data.id] = data


# ═══════════════════════════════════════════════════════════════════════════════
# 적 캐릭터 (Enemy Slime)
# ═══════════════════════════════════════════════════════════════════════════════

func _register_enemy_slime() -> void:
	var data := CharacterData.new()
	data.id = "enemy_slime"
	data.display_name = "슬라임"
	data.description = "기본 적"
	data.element = GameManager.ElementType.EARTH
	
	# 능력치 (약한 적)
	data.max_hp = 30
	data.max_mp = 0
	data.max_bp = 0
	data.melee_power = 5
	data.ranged_power = 0
	data.max_speed = 80.0
	data.rotation_speed = 3.0
	data.acceleration = 5.0
	data.is_flying = false
	
	# 공격 목록
	# [0] 버튼1: 근접 공격만
	var attack1 := CharacterData.Attack.new(
		CharacterData.Attack.Style.MELEE_HITBOX,
		5,     # damage
		1.0,   # cooldown
		40.0   # range
	)
	data.attacks.append(attack1.to_dict())
	
	# [1] 버튼2: 없음
	# [2] 필살기: 없음
	
	_characters[data.id] = data


# ═══════════════════════════════════════════════════════════════════════════════
# 조회 메서드
# ═══════════════════════════════════════════════════════════════════════════════

func get_character(id: String) -> CharacterData:
	if _characters.has(id):
		return _characters[id]
	return null


func get_all_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for key in _characters.keys():
		result.append(_characters[key])
	return result


func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _characters.keys():
		result.append(key)
	return result


func has_character(id: String) -> bool:
	return _characters.has(id)
