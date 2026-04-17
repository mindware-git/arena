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
var card_db: Dictionary = {
	"card_1": {"name": "파워 스트라이크", "color": Color(0.8, 0.2, 0.2)},
	"card_2": {"name": "신속의 장화", "color": Color(0.2, 0.8, 0.2)},
	"card_3": {"name": "마나의 반지", "color": Color(0.2, 0.2, 0.8)}
}

var owned_cards: Array[String] = ["card_1", "card_2", "card_3"]

# Slot indices: 0 and 1. Values are card IDs, empty string means unequipped.
var equipped_cards: Dictionary = {
	0: "card_1",
	1: ""
}
