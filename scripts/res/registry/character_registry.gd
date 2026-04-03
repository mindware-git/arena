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