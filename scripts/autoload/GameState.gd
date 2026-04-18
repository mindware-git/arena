extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# Game State Management
# Global state for the Arena game
# ═══════════════════════════════════════════════════════════════════════════════

# Online/Offline mode
var online_play := false

# Player data
var current_player_id: String = ""
var current_player_name: String = ""

# Match settings
enum MatchMode {
	OFFLINE = 0,
	ONE_VS_ONE = 1,
	TWO_VS_TWO = 2,
}
var match_mode: int = MatchMode.OFFLINE

# Match state
var is_in_match: bool = false
var is_game_running: bool = false

# Card System State
enum CardType {
	MAIN_WEAPON = 0,
	SUB_WEAPON = 1,
	ARMOR = 2,
	SHOES = 3,
	ULTIMATE = 4
}

var card_type_names = {
	CardType.MAIN_WEAPON: "주무기",
	CardType.SUB_WEAPON: "보조무기",
	CardType.ARMOR: "갑옷",
	CardType.SHOES: "신발",
	CardType.ULTIMATE: "궁극기"
}

var card_db: Dictionary = {
	"card_1": {"name": "파워 스트라이크", "type": CardType.MAIN_WEAPON, "color": Color(0.8, 0.2, 0.2)},
	"card_2": {"name": "단검 던지기", "type": CardType.MAIN_WEAPON, "color": Color(0.9, 0.3, 0.3)},
	"card_3": {"name": "마나의 반지", "type": CardType.SUB_WEAPON, "color": Color(0.2, 0.2, 0.8)},
	"card_4": {"name": "마법서", "type": CardType.SUB_WEAPON, "color": Color(0.3, 0.3, 0.9)},
	"card_5": {"name": "가죽 갑옷", "type": CardType.ARMOR, "color": Color(0.5, 0.5, 0.5)},
	"card_6": {"name": "판금 갑옷", "type": CardType.ARMOR, "color": Color(0.6, 0.6, 0.6)},
	"card_7": {"name": "신속의 장화", "type": CardType.SHOES, "color": Color(0.2, 0.8, 0.2)},
	"card_8": {"name": "강철 부츠", "type": CardType.SHOES, "color": Color(0.3, 0.7, 0.3)},
	
	# --- 스크롤 테스트를 위한 더미 카드들 ---
	"card_9": {"name": "나무 몽둥이", "type": CardType.MAIN_WEAPON, "color": Color(0.6, 0.4, 0.2)},
	"card_10": {"name": "철검", "type": CardType.MAIN_WEAPON, "color": Color(0.7, 0.7, 0.7)},
	"card_11": {"name": "강화된 활", "type": CardType.MAIN_WEAPON, "color": Color(0.5, 0.8, 0.3)},
	"card_12": {"name": "불꽃 지팡이", "type": CardType.MAIN_WEAPON, "color": Color(0.9, 0.4, 0.2)},
	"card_13": {"name": "강철 방패", "type": CardType.SUB_WEAPON, "color": Color(0.6, 0.6, 0.7)},
	"card_14": {"name": "마력의 수정", "type": CardType.SUB_WEAPON, "color": Color(0.4, 0.2, 0.9)},
	"card_15": {"name": "미스릴 갑옷", "type": CardType.ARMOR, "color": Color(0.8, 0.9, 0.9)},
	"card_16": {"name": "여행자의 신발", "type": CardType.SHOES, "color": Color(0.4, 0.8, 0.5)},
	
	# --- 궁극기 카드들 ---
	"card_17": {"name": "드래곤 스트라이크", "type": CardType.ULTIMATE, "color": Color(0.9, 0.8, 0.1)},
	"card_18": {"name": "메테오 소환", "type": CardType.ULTIMATE, "color": Color(0.9, 0.2, 0.8)},
	"card_19": {"name": "시간 정지", "type": CardType.ULTIMATE, "color": Color(0.1, 0.9, 0.8)},
	"card_20": {"name": "신의 심판", "type": CardType.ULTIMATE, "color": Color(1.0, 1.0, 0.8)},
	"card_21": {"name": "광폭화", "type": CardType.ULTIMATE, "color": Color(0.6, 0.0, 0.0)}
}

var owned_cards: Array[String] = [
	"card_1", "card_2", "card_3", "card_4",
	"card_5", "card_6", "card_7", "card_8",
	"card_9", "card_10", "card_11", "card_12", 
	"card_13", "card_14", "card_15", "card_16",
	"card_17", "card_18", "card_19", "card_20", "card_21"
]

# Slot indices: 0(Main), 1(Sub), 2(Armor), 3(Shoes)
var equipped_cards: Dictionary = {
	CardType.MAIN_WEAPON: "",
	CardType.SUB_WEAPON: "",
	CardType.ARMOR: "",
	CardType.SHOES: "",
	CardType.ULTIMATE: ""
}

const SAVE_PATH = "user://game_save.json"

func _ready() -> void:
	load_state()

func save_state() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var save_dict = {
			"equipped_cards": equipped_cards
		}
		file.store_string(JSON.stringify(save_dict))
		file.close()

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return # 최초 실행이라 저장된게 없음
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			if data.has("equipped_cards"):
				# JSON은 Key를 String으로 파싱하므로 Int로 복원 필요
				var saved_equip = data["equipped_cards"]
				# 기존 슬롯 구문을 유지하기 위해 clear하지 않고 덮어쓰기 실시
				for k in saved_equip.keys():
					equipped_cards[int(k)] = saved_equip[k]
		file.close()

# ═══════════════════════════════════════════════════════════════════════════════
# Server Integrity (Mock)
# ═══════════════════════════════════════════════════════════════════════════════

func verify_equipped_cards_with_server_mock() -> void:
	print("[SERVER MOCK] 서버의 소유 카드와 클라이언트 장착 카드를 대조하여 무결성을 검증합니다...")
	var has_cheating = false
	
	# 지금은 서버의 응답을 owned_cards 라고 Mock 가정합니다.
	var server_owned_cards = owned_cards
	
	for slot_index in equipped_cards.keys():
		var card_id = equipped_cards[slot_index]
		if card_id == "":
			continue
			
		if not server_owned_cards.has(card_id):
			print("[SECURITY WARNING] 버그 유저 감지! 비정상적인 카드 장착 기록을 발견했습니다!")
			print(" -> 위반 내역: 슬롯[%s]에 소유하지 않은 카드[%s] 장착 시도" % [str(slot_index), card_id])
			has_cheating = true
			
			# (선택) 여기서 강제 해제 처리를 하거나, 연결을 끊는 로직을 추가할 수 있습니다.
			# equipped_cards[slot_index] = ""
			
	if has_cheating:
		print("[SERVER MOCK] 데이터 변조 의심! (강제 접속 종료 등에 대한 처리 필요)")
		# 세이브파일 강제 복구 (선택사항)
		# save_state() 
	else:
		print("[SERVER MOCK] 카드 검증 완료 (정상 유저)")

