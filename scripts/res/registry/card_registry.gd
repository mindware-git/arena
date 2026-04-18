class_name CardRegistry
extends RefCounted

static var _cards: Dictionary = {}
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_init_cards()

static func get_card(id: String) -> CardData:
	_ensure_init()
	if _cards.has(id):
		return _cards[id]
	return null

static func get_all_cards() -> Dictionary:
	_ensure_init()
	return _cards

static func _register(card_id: String, c_name: String, c_type: int, c_color: Color) -> CardData:
	var new_card = CardData.new(card_id, c_name, c_type, c_color)
	_cards[card_id] = new_card
	return new_card

static func _init_cards() -> void:
	# MAIN
	_register("card_1", "파워 스트라이크", 0, Color(0.8, 0.2, 0.2)).add_modifier("melee_power", 10.0, 1.0).add_modifier("critical_chance", 0.0, 1.2)
	_register("card_2", "단검 던지기", 0, Color(0.9, 0.3, 0.3)).add_modifier("ranged_power", 5.0, 1.0)
	_register("card_9", "나무 몽둥이", 0, Color(0.6, 0.4, 0.2)).add_modifier("melee_power", 2.0, 1.0)
	_register("card_10", "철검", 0, Color(0.7, 0.7, 0.7)).add_modifier("melee_power", 8.0, 1.0)
	_register("card_11", "강화된 활", 0, Color(0.5, 0.8, 0.3)).add_modifier("ranged_power", 12.0, 1.0)
	_register("card_12", "불꽃 지팡이", 0, Color(0.9, 0.4, 0.2)).add_modifier("ranged_power", 15.0, 1.0)

	# SUB
	_register("card_3", "마나의 반지", 1, Color(0.2, 0.2, 0.8)).add_modifier("max_mp", 20.0, 1.0)
	_register("card_4", "마법서", 1, Color(0.3, 0.3, 0.9)).add_modifier("max_mp", 40.0, 1.0).add_modifier("mp_regen_per_sec", 2.0, 1.0)
	_register("card_13", "강철 방패", 1, Color(0.6, 0.6, 0.7)).add_modifier("max_hp", 30.0, 1.0)
	_register("card_14", "마력의 수정", 1, Color(0.4, 0.2, 0.9)).add_modifier("max_mp", 50.0, 1.0)

	# ARMOR
	_register("card_5", "가죽 갑옷", 2, Color(0.5, 0.5, 0.5)).add_modifier("max_hp", 50.0, 1.0)
	_register("card_6", "판금 갑옷", 2, Color(0.6, 0.6, 0.6)).add_modifier("max_hp", 150.0, 1.0).add_modifier("max_speed", -30.0, 1.0).add_modifier("acceleration", -2.0, 1.0)
	_register("card_15", "미스릴 갑옷", 2, Color(0.8, 0.9, 0.9)).add_modifier("max_hp", 100.0, 1.0).add_modifier("max_speed", 10.0, 1.0)

	# SHOES
	_register("card_7", "신속의 장화", 3, Color(0.2, 0.8, 0.2)).add_modifier("max_speed", 50.0, 1.0).add_modifier("acceleration", 5.0, 1.0)
	_register("card_8", "강철 부츠", 3, Color(0.3, 0.7, 0.3)).add_modifier("max_speed", 10.0, 1.0).add_modifier("max_hp", 20.0, 1.0)
	_register("card_16", "여행자의 신발", 3, Color(0.4, 0.8, 0.5)).add_modifier("max_speed", 30.0, 1.0).add_modifier("max_bp", 15.0, 1.0)

	# ULTIMATE
	_register("card_17", "드래곤 스트라이크", 4, Color(0.9, 0.8, 0.1))
	_register("card_18", "메테오 소환", 4, Color(0.9, 0.2, 0.8))
	_register("card_19", "시간 정지", 4, Color(0.1, 0.9, 0.8))
	_register("card_20", "신의 심판", 4, Color(1.0, 1.0, 0.8))
	_register("card_21", "광폭화", 4, Color(0.6, 0.0, 0.0)).add_modifier("melee_power", 0.0, 1.2)

