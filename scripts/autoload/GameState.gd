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
