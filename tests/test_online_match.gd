extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: OnlineMatch.gd - Matchmaking Logic
# 매칭 로직 및 플레이어 상태 관리 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _original_min_players: int
var _original_max_players: int
var _original_client_version: String

func before_each() -> void:
	_original_min_players = OnlineMatch.min_players
	_original_max_players = OnlineMatch.max_players
	_original_client_version = OnlineMatch.client_version


func after_each() -> void:
	OnlineMatch.min_players = _original_min_players
	OnlineMatch.max_players = _original_max_players
	OnlineMatch.client_version = _original_client_version


func test_initial_state() -> void:
	assert_eq(OnlineMatch.min_players, 2, "Default min_players should be 2")
	assert_eq(OnlineMatch.max_players, 2, "Default max_players should be 2")
	assert_eq(OnlineMatch.client_version, "dev", "Default client_version should be dev")
	assert_eq(OnlineMatch.match_state, OnlineMatch.MatchState.LOBBY, "Initial match_state should be LOBBY")
	assert_eq(OnlineMatch.match_mode, OnlineMatch.MatchMode.NONE, "Initial match_mode should be NONE")


func test_player_class() -> void:
	var player = OnlineMatch.Player.new("session_123", "Player1", 1)
	assert_eq(player.session_id, "session_123", "Session ID should be set")
	assert_eq(player.username, "Player1", "Username should be set")
	assert_eq(player.peer_id, 1, "Peer ID should be set")


func test_player_from_presence() -> void:
	# NakamaRTAPI.UserPresence 모킹
	var mock_presence = {
		"session_id": "session_456",
		"username": "Player2"
	}
	
	var player = OnlineMatch.Player.from_presence(mock_presence, 2)
	assert_eq(player.session_id, "session_456", "Session ID should be extracted")
	assert_eq(player.username, "Player2", "Username should be extracted")
	assert_eq(player.peer_id, 2, "Peer ID should be set")


func test_player_serialization() -> void:
	var player = OnlineMatch.Player.new("session_789", "Player3", 3)
	var dict = player.to_dict()
	
	assert_eq(dict["session_id"], "session_789", "Dict should contain session_id")
	assert_eq(dict["username"], "Player3", "Dict should contain username")
	assert_eq(dict["peer_id"], 3, "Dict should contain peer_id")
	
	var restored = OnlineMatch.Player.from_dict(dict)
	assert_eq(restored.session_id, player.session_id, "Deserialized player should match")
	assert_eq(restored.username, player.username, "Deserialized player should match")
	assert_eq(restored.peer_id, player.peer_id, "Deserialized player should match")


func test_serialize_players() -> void:
	var players = {
		1: OnlineMatch.Player.new("s1", "P1", 1),
		2: OnlineMatch.Player.new("s2", "P2", 2)
	}
	
	var serialized = OnlineMatch.serialize_players(players)
	assert_eq(serialized.size(), 2, "Should serialize all players")
	assert_true(serialized.has(1), "Should contain player 1")
	assert_true(serialized.has(2), "Should contain player 2")


func test_unserialize_players() -> void:
	var data = {
		1: {"session_id": "s1", "username": "P1", "peer_id": 1},
		2: {"session_id": "s2", "username": "P2", "peer_id": 2}
	}
	
	var players = OnlineMatch.unserialize_players(data)
	assert_eq(players.size(), 2, "Should unserialize all players")
	assert_true(players.has(1), "Should contain player 1")
	assert_true(players.has(2), "Should contain player 2")
	assert_eq(players[1].username, "P1", "Player data should be correct")


func test_get_match_state() -> void:
	# 초기 상태
	assert_eq(OnlineMatch.get_match_state(), OnlineMatch.MatchState.LOBBY, "Should return LOBBY initially")
	
	# 상태 변경 (실제로는 내부에서만 변경되지만 테스트용)
	OnlineMatch.match_state = OnlineMatch.MatchState.MATCHING
	assert_eq(OnlineMatch.get_match_state(), OnlineMatch.MatchState.MATCHING, "Should return MATCHING")


func test_get_match_mode() -> void:
	assert_eq(OnlineMatch.get_match_mode(), OnlineMatch.MatchMode.NONE, "Should return NONE initially")
	
	OnlineMatch.match_mode = OnlineMatch.MatchMode.MATCHMAKER
	assert_eq(OnlineMatch.get_match_mode(), OnlineMatch.MatchMode.MATCHMAKER, "Should return MATCHMAKER")


func test_leave() -> void:
	# 상태 설정
	OnlineMatch.match_state = OnlineMatch.MatchState.MATCHING
	OnlineMatch.match_mode = OnlineMatch.MatchMode.MATCHMAKER
	OnlineMatch.players = {1: OnlineMatch.Player.new("s1", "P1", 1)}
	
	# leave 호출
	OnlineMatch.leave()
	
	# 상태 초기화 확인
	assert_eq(OnlineMatch.match_state, OnlineMatch.MatchState.LOBBY, "Should reset to LOBBY")
	assert_eq(OnlineMatch.match_mode, OnlineMatch.MatchMode.NONE, "Should reset to NONE")
	assert_eq(OnlineMatch.players.size(), 0, "Should clear players")
