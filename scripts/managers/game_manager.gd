extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════════════════════

## 게임 상태
enum GameState {
	NONE,              ## 초기 상태
	LOADING,           ## 리소스 로딩
	MAIN_MENU,         ## 메인 메뉴
	SHOP,              ## 상점
	MATCHING,          ## 매칭 중
	CHARACTER_SELECT,  ## 캐릭터 선택
	PLAYING,           ## 게임 진행 중
	PAUSED,            ## 일시정지
	RESULT             ## 결과 화면
}

## 매치 모드
enum MatchMode {
	ONE_VS_ONE,      ## 1:1
	THREE_VS_THREE,  ## 3:3
	FIVE_VS_FIVE     ## 5:5
}

## 아이템 타입
enum ItemType {
	SKIN,       ## 코스튬/스킨
	EFFECT,     ## 이펙트
	CHARACTER,  ## 캐릭터 언락
	EMOTE       ## 이모티콘
}

## 화폐 타입
enum CurrencyType {
	COIN,  ## 게임 내 화폐
	GEM    ## 유료 화폐
}

## 속성 타입
enum ElementType {
	WATER,  ## 물
	FIRE,   ## 불
	WIND,   ## 바람
	EARTH   ## 흙
}

# ═══════════════════════════════════════════════════════════════════════════════
# Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

## 플레이어 데이터
class PlayerData:
	var id: String = ""
	var name: String = ""
	var character_id: String = ""
	var team_id: int = 0
	var is_ready: bool = false
	
	func _init(p_id: String = "", p_name: String = "") -> void:
		id = p_id
		name = p_name

## 매치 데이터
class MatchData:
	var mode: MatchMode = MatchMode.ONE_VS_ONE
	var map_id: String = ""
	var players: Array[PlayerData] = []
	var time_limit: int = 300  # 초 단위
	
	func get_max_players() -> int:
		match mode:
			MatchMode.ONE_VS_ONE:
				return 2
			MatchMode.THREE_VS_THREE:
				return 6
			MatchMode.FIVE_VS_FIVE:
				return 10
			_:
				return 2

## 매치 결과
class MatchResult:
	var winning_team: int = -1
	var mvp_player_id: String = ""
	var duration: float = 0.0

## 상점 아이템
class ShopItem:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var type: ItemType = ItemType.SKIN
	var price: int = 0
	var currency: CurrencyType = CurrencyType.COIN
	var is_premium: bool = false

## 맵 데이터
class MapData:
	var id: String = ""
	var name: String = ""
	var alias: String = ""
	var element: ElementType = ElementType.EARTH
	var max_players: int = 8
	var has_teleport: bool = false
	var has_hazards: bool = true

# ═══════════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════════

signal state_changed(old_state: GameState, new_state: GameState)
signal match_started(match_data: MatchData)
signal match_ended(result: MatchResult)
signal player_joined(player: PlayerData)
signal player_left(player_id: String)

# ═══════════════════════════════════════════════════════════════════════════════
# State
# ═══════════════════════════════════════════════════════════════════════════════

var current_state: GameState = GameState.NONE
var previous_state: GameState = GameState.NONE
var current_match: MatchData = null
var current_map: MapData = null
var players: Array[PlayerData] = []
var local_player: PlayerData = null

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_initialize()


func _initialize() -> void:
	change_state(GameState.LOADING)
	# 리소스 로드 완료 후
	change_state(GameState.MAIN_MENU)

# ═══════════════════════════════════════════════════════════════════════════════
# State Management
# ═══════════════════════════════════════════════════════════════════════════════

func change_state(new_state: GameState) -> bool:
	if current_state == new_state:
		return false
	
	previous_state = current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)
	return true


func get_current_state() -> GameState:
	return current_state


func get_previous_state() -> GameState:
	return previous_state

# ═══════════════════════════════════════════════════════════════════════════════
# Match Management
# ═══════════════════════════════════════════════════════════════════════════════

func start_match(mode: MatchMode, map_id: String) -> bool:
	if current_state != GameState.CHARACTER_SELECT:
		return false
	
	current_match = MatchData.new()
	current_match.mode = mode
	current_match.map_id = map_id
	
	change_state(GameState.PLAYING)
	match_started.emit(current_match)
	return true


func end_match(result: MatchResult) -> void:
	if current_state != GameState.PLAYING:
		return
	
	change_state(GameState.RESULT)
	match_ended.emit(result)


func cancel_match() -> void:
	current_match = null
	change_state(GameState.MAIN_MENU)

# ═══════════════════════════════════════════════════════════════════════════════
# Player Management
# ═══════════════════════════════════════════════════════════════════════════════

func add_player(player: PlayerData) -> bool:
	for p in players:
		if p.id == player.id:
			return false
	players.append(player)
	player_joined.emit(player)
	return true


func remove_player(player_id: String) -> bool:
	for i in range(players.size()):
		if players[i].id == player_id:
			players.remove_at(i)
			player_left.emit(player_id)
			return true
	return false


func get_player(player_id: String) -> PlayerData:
	for p in players:
		if p.id == player_id:
			return p
	return null


func get_players_by_team(team_id: int) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for p in players:
		if p.team_id == team_id:
			result.append(p)
	return result

# ═══════════════════════════════════════════════════════════════════════════════
# Pause/Resume
# ═══════════════════════════════════════════════════════════════════════════════

func pause_game() -> bool:
	if current_state != GameState.PLAYING:
		return false
	get_tree().paused = true
	change_state(GameState.PAUSED)
	return true


func resume_game() -> bool:
	if current_state != GameState.PAUSED:
		return false
	get_tree().paused = false
	change_state(GameState.PLAYING)
	return true
