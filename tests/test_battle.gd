extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Battle Screen
# BattleScreen의 기본 기능 테스트
# ═══════════════════════════════════════════════════════════════════════════════

var _battle: BattleScreen

func before_each() -> void:
	_battle = BattleScreen.new()
	add_child(_battle)


func after_each() -> void:
	if _battle and is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null


# ═══════════════════════════════════════════════════════════════════════════════
# Battle Initialization Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_battle_initial_state() -> void:
	# 배틀 초기 상태 확인
	assert_false(_battle.is_battle_active, "Battle should not be active initially")
	assert_eq(_battle.battle_time, 0.0, "Battle time should be 0 initially")
	assert_null(_battle.player, "Player should be null initially")
	assert_eq(_battle.enemies.size(), 0, "Enemies should be empty initially")


func test_battle_start() -> void:
	# 배틀 시작
	_battle.start_battle("gyro")
	
	assert_true(_battle.is_battle_active, "Battle should be active after start")
	assert_not_null(_battle.player, "Player should be spawned")
	assert_true(_battle.enemies.size() > 0, "Enemies should be spawned")


# ═══════════════════════════════════════════════════════════════════════════════
# Player Spawning Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_spawn_player() -> void:
	var player := _battle.spawn_player("gyro")
	
	assert_not_null(player, "Player should be spawned")
	assert_eq(_battle.player, player, "Battle player should match spawned player")
	assert_true(player.is_controllable, "Player should be controllable")
	assert_not_null(player.character_data, "Player should have character data")
	assert_eq(player.character_data.id, "gyro", "Player character ID should be gyro")


func test_spawn_player_invalid_id() -> void:
	# 잘못된 ID로 스폰 시 null 반환
	var player := _battle.spawn_player("invalid_id")
	
	assert_null(player, "Invalid player should not be spawned")


func test_spawn_different_characters() -> void:
	# gyro 스폰
	var gyro := _battle.spawn_player("gyro")
	assert_not_null(gyro, "Gyro should be spawned")
	assert_eq(gyro.character_data.id, "gyro", "Character should be gyro")
	
	# 배틀 클리어 후 shamu 스폰
	_battle._clear_battle()
	
	var shamu := _battle.spawn_player("shamu")
	assert_not_null(shamu, "Shamu should be spawned")
	assert_eq(shamu.character_data.id, "shamu", "Character should be shamu")


# ═══════════════════════════════════════════════════════════════════════════════
# Enemy Spawning Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_spawn_enemy() -> void:
	var enemy := _battle.spawn_enemy("enemy_slime", Vector2(500, 300))
	
	assert_not_null(enemy, "Enemy should be spawned")
	assert_eq(_battle.enemies.size(), 1, "Should have 1 enemy")
	assert_false(enemy.is_controllable, "Enemy should not be controllable")
	assert_eq(enemy.position, Vector2(500, 300), "Enemy position should match")


func test_spawn_multiple_enemies() -> void:
	_battle.spawn_enemy("enemy_slime", Vector2(500, 200))
	_battle.spawn_enemy("enemy_slime", Vector2(600, 300))
	_battle.spawn_enemy("enemy_slime", Vector2(500, 400))
	
	assert_eq(_battle.enemies.size(), 3, "Should have 3 enemies")


func test_spawn_enemy_at_random_position() -> void:
	var enemy := _battle.spawn_enemy_at_random_position("enemy_slime")
	
	assert_not_null(enemy, "Enemy should be spawned at random position")
	assert_true(enemy.position.x > 0, "Enemy X position should be positive")
	assert_true(enemy.position.y > 0, "Enemy Y position should be positive")


# ═══════════════════════════════════════════════════════════════════════════════
# Battle State Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_alive_enemy_count() -> void:
	_battle.spawn_enemy("enemy_slime", Vector2(500, 200))
	_battle.spawn_enemy("enemy_slime", Vector2(600, 300))
	_battle.spawn_enemy("enemy_slime", Vector2(500, 400))
	
	assert_eq(_battle.get_alive_enemy_count(), 3, "Should have 3 alive enemies")


func test_get_battle_info() -> void:
	_battle.start_battle("gyro")
	
	var info := _battle.get_battle_info()
	
	assert_true(info.has("is_active"), "Info should have is_active")
	assert_true(info.has("battle_time"), "Info should have battle_time")
	assert_true(info.has("player_hp"), "Info should have player_hp")
	assert_true(info.has("enemy_count"), "Info should have enemy_count")
	assert_true(info["is_active"], "Battle should be active")


# ═══════════════════════════════════════════════════════════════════════════════
# Signal Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_battle_started_signal() -> void:
	watch_signals(_battle)
	_battle.start_battle("gyro")
	assert_signal_emitted(_battle, "battle_started", "battle_started signal should be emitted")


func test_player_spawned_signal() -> void:
	watch_signals(_battle)
	_battle.spawn_player("gyro")
	assert_signal_emitted(_battle, "player_spawned", "player_spawned signal should be emitted")


func test_enemy_spawned_signal() -> void:
	watch_signals(_battle)
	_battle.spawn_enemy("enemy_slime", Vector2(500, 300))
	assert_signal_emitted(_battle, "enemy_spawned", "enemy_spawned signal should be emitted")


# ═══════════════════════════════════════════════════════════════════════════════
# Battle Reset Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_battle() -> void:
	_battle.start_battle("gyro")
	assert_true(_battle.is_battle_active, "Battle should be active")
	
	_battle.reset_battle()
	
	assert_true(_battle.is_battle_active, "Battle should be active after reset")
	assert_not_null(_battle.player, "Player should be spawned after reset")


func test_clear_battle() -> void:
	_battle.start_battle("gyro")
	_battle._clear_battle()
	
	assert_false(_battle.is_battle_active, "Battle should not be active after clear")
	assert_null(_battle.player, "Player should be null after clear")
	assert_eq(_battle.enemies.size(), 0, "Enemies should be empty after clear")


# ═══════════════════════════════════════════════════════════════════════════════
# Character Stats Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_player_hp_initialization() -> void:
	var player := _battle.spawn_player("gyro")
	
	assert_eq(player.current_hp, player.character_data.max_hp, "Player HP should be max")


func test_player_take_damage() -> void:
	var player := _battle.spawn_player("gyro")
	var initial_hp := player.current_hp
	
	player.take_damage(10)
	
	assert_eq(player.current_hp, initial_hp - 10, "Player HP should decrease by 10")


func test_player_dies_at_zero_hp() -> void:
	var player := _battle.spawn_player("gyro")
	
	# Character의 died 시그널 감시
	watch_signals(player)
	
	player.take_damage(player.character_data.max_hp + 10)
	
	assert_true(player.is_dead, "Player should be dead")
	assert_signal_emitted(player, "died", "died signal should be emitted")