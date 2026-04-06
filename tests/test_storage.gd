extends GutTest

# ═══════════════════════════════════════════════════════════════════════════════
# Test: Nakama Storage Engine
# 유저 데이터 저장/읽기 + 권한 + Progression Template 패턴
# ═══════════════════════════════════════════════════════════════════════════════

var SERVER_KEY: String = ProjectSettings.get_setting("network/nakama/server_key", "defaultkey")
var HOST: String = ProjectSettings.get_setting("network/nakama/host", "localhost")
var PORT: int = ProjectSettings.get_setting("network/nakama/port", 7350)
const TIMEOUT := 10.0

# Player A
var _http_adapter_a: NakamaHTTPAdapter
var _client_a: NakamaClient
var _session_a: NakamaSession

# Player B
var _http_adapter_b: NakamaHTTPAdapter
var _client_b: NakamaClient
var _session_b: NakamaSession


func before_each() -> void:
	# Pre-cleanup: ensure clean state before test
	_http_adapter_a = NakamaHTTPAdapter.new()
	add_child(_http_adapter_a)
	_client_a = NakamaClient.new(_http_adapter_a, SERVER_KEY, "http", HOST, PORT, 10)
	
	var result_a = await _client_a.authenticate_device_async("storage_player_a")
	if not result_a.is_exception():
		_session_a = result_a
		# Delete any existing data
		await _client_a.delete_storage_objects_async(_session_a, [
			NakamaStorageObjectId.new("cards", "inventory", _session_a.user_id),
			NakamaStorageObjectId.new("cards", "public_deck", _session_a.user_id),
			NakamaStorageObjectId.new("cards", "private_deck", _session_a.user_id),
			NakamaStorageObjectId.new("progression", "cards", _session_a.user_id),
		])
	
	# Reset
	_http_adapter_a.queue_free()
	_http_adapter_a = null
	_client_a = null
	_session_a = null
	_http_adapter_b = null
	_client_b = null
	_session_b = null


func after_each() -> void:
	# Cleanup storage data
	if _client_a and _session_a:
		await _client_a.delete_storage_objects_async(_session_a, [
			NakamaStorageObjectId.new("cards", "inventory", _session_a.user_id),
			NakamaStorageObjectId.new("cards", "public_deck", _session_a.user_id),
			NakamaStorageObjectId.new("cards", "private_deck", _session_a.user_id),
			NakamaStorageObjectId.new("progression", "cards", _session_a.user_id),
		])
	
	# Cleanup adapters
	if _http_adapter_a and is_instance_valid(_http_adapter_a):
		_http_adapter_a.queue_free()
	if _http_adapter_b and is_instance_valid(_http_adapter_b):
		_http_adapter_b.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Helper: Login Players
# ═══════════════════════════════════════════════════════════════════════════════

func _login_players() -> bool:
	# Player A
	_http_adapter_a = NakamaHTTPAdapter.new()
	add_child(_http_adapter_a)
	_client_a = NakamaClient.new(_http_adapter_a, SERVER_KEY, "http", HOST, PORT, 10)
	
	var result_a = await _client_a.authenticate_device_async("storage_player_a")
	if result_a.is_exception():
		pending("Player A auth failed: %s" % result_a.get_exception().message)
		return false
	_session_a = result_a
	
	# Player B
	_http_adapter_b = NakamaHTTPAdapter.new()
	add_child(_http_adapter_b)
	_client_b = NakamaClient.new(_http_adapter_b, SERVER_KEY, "http", HOST, PORT, 10)
	
	var result_b = await _client_b.authenticate_device_async("storage_player_b")
	if result_b.is_exception():
		pending("Player B auth failed: %s" % result_b.get_exception().message)
		return false
	_session_b = result_b
	
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Test: Basic CRUD
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_collection_crud() -> void:
	if not await _login_players():
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. Create - 카드 컬렉션 저장
	# ═══════════════════════════════════════════════════════════════════════════
	var cards_data := JSON.stringify({
		"cards": ["fireball", "heal", "shield"],
		"count": 3
	})
	
	# version "" = 덮어쓰기 허용
	var write_result = await _client_a.write_storage_objects_async(_session_a, [
		NakamaWriteStorageObject.new("cards", "inventory", 1, 1, cards_data, "")
	])
	
	if write_result.is_exception():
		pending("Write failed: %s" % write_result.get_exception().message)
		return
	
	assert_not_null(write_result.acks, "Write should return acks")
	assert_true(write_result.acks.size() > 0, "Should have at least one ack")
	gut.p("Created card collection with version: %s" % write_result.acks[0].version)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. Read - 카드 컬렉션 읽기
	# ═══════════════════════════════════════════════════════════════════════════
	var read_result = await _client_a.read_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "inventory", _session_a.user_id)
	])
	
	if read_result.is_exception():
		pending("Read failed: %s" % read_result.get_exception().message)
		return
	
	assert_not_null(read_result.objects, "Read should return objects")
	assert_true(read_result.objects.size() > 0, "Should have at least one object")
	
	var stored_data = JSON.parse_string(read_result.objects[0].value)
	assert_eq(stored_data.cards.size(), 3, "Should have 3 cards")
	assert_eq(stored_data.cards[0], "fireball", "First card should be fireball")
	#gut.p("Read cards: %s" % stored_data.cards)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 3. Delete - 카드 컬렉션 삭제
	# ═══════════════════════════════════════════════════════════════════════════
	var delete_result = await _client_a.delete_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "inventory", _session_a.user_id)
	])
	
	if delete_result.is_exception():
		pending("Delete failed: %s" % delete_result.get_exception().message)
		return
	
	# 삭제 확인
	var verify_result = await _client_a.read_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "inventory", _session_a.user_id)
	])
	
	assert_true(verify_result.objects.is_empty() or verify_result.objects.size() == 0, 
		"Object should be deleted")
	gut.p("Card collection deleted successfully")


# ═══════════════════════════════════════════════════════════════════════════════
# Test: Update Cards (Event-driven pattern)
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_collection_update() -> void:
	if not await _login_players():
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. 초기 카드 컬렉션 생성
	# ═══════════════════════════════════════════════════════════════════════════
	var initial_data := JSON.stringify({
		"cards": ["starter_card"],
		"progress": 0
	})
	
	var write_result = await _client_a.write_storage_objects_async(_session_a, [
		NakamaWriteStorageObject.new("cards", "inventory", 1, 1, initial_data, "")
	])
	
	if write_result.is_exception():
		pending("Initial write failed: %s" % write_result.get_exception().message)
		return
	
	var version = write_result.acks[0].version
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. 이벤트: 새 카드 획득 (update with version check)
	# ═══════════════════════════════════════════════════════════════════════════
	var updated_data := JSON.stringify({
		"cards": ["starter_card", "rare_card"],
		"progress": 1
	})
	
	# conditional write: version이 맞을 때만 업데이트
	var update_result = await _client_a.write_storage_objects_async(_session_a, [
		NakamaWriteStorageObject.new("cards", "inventory", 1, 1, updated_data, version)
	])
	
	if update_result.is_exception():
		pending("Update failed: %s" % update_result.get_exception().message)
		return
	
	gut.p("Updated card collection, new version: %s" % update_result.acks[0].version)
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 3. 검증
	# ═══════════════════════════════════════════════════════════════════════════
	var read_result = await _client_a.read_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "inventory", _session_a.user_id)
	])
	
	var stored_data = JSON.parse_string(read_result.objects[0].value)
	assert_eq(stored_data.cards.size(), 2, "Should have 2 cards after update")
	assert_eq(stored_data.cards[1], "rare_card", "Should have new rare_card")
	assert_eq(stored_data.progress, 1, "Progress should be 1")
	
	#gut.p("Cards after update: %s" % stored_data.cards)
	
	# Cleanup
	await _client_a.delete_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "inventory", _session_a.user_id)
	])


# ═══════════════════════════════════════════════════════════════════════════════
# Test: Permission - Public Read
# ═══════════════════════════════════════════════════════════════════════════════

func test_permission_public_read() -> void:
	if not await _login_players():
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. Player A가 Public Read(2)로 카드 저장
	# ═══════════════════════════════════════════════════════════════════════════
	var cards_data := JSON.stringify({
		"cards": ["fireball", "heal"],
		"owner": _session_a.user_id
	})
	
	# Read=2 (Public Read), Write=1 (Owner Write)
	var write_result = await _client_a.write_storage_objects_async(_session_a, [
		NakamaWriteStorageObject.new("cards", "public_deck", 2, 1, cards_data, "")
	])
	
	if write_result.is_exception():
		pending("Write failed: %s" % write_result.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. Player B가 Player A의 카드 읽기 (가능해야 함)
	# ═══════════════════════════════════════════════════════════════════════════
	var read_result = await _client_b.read_storage_objects_async(_session_b, [
		NakamaStorageObjectId.new("cards", "public_deck", _session_a.user_id)
	])
	
	if read_result.is_exception():
		pending("Player B read failed: %s" % read_result.get_exception().message)
		return
	
	assert_not_null(read_result.objects, "Player B should be able to read")
	assert_true(read_result.objects.size() > 0, "Should have objects")
	
	var stored_data = JSON.parse_string(read_result.objects[0].value)
	assert_eq(stored_data.cards.size(), 2, "Player B should see 2 cards")
	#gut.p("Player B successfully read Player A's public deck: %s" % stored_data.cards)
	
	# Cleanup
	await _client_a.delete_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "public_deck", _session_a.user_id)
	])


# ═══════════════════════════════════════════════════════════════════════════════
# Test: Permission - Owner Write Only
# ═══════════════════════════════════════════════════════════════════════════════

func test_permission_owner_write() -> void:
	if not await _login_players():
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. Player A가 카드 저장
	# ═══════════════════════════════════════════════════════════════════════════
	var cards_data := JSON.stringify({"cards": ["fireball"]})
	
	var write_result = await _client_a.write_storage_objects_async(_session_a, [
		NakamaWriteStorageObject.new("cards", "private_deck", 1, 1, cards_data, "")
	])
	
	if write_result.is_exception():
		pending("Write failed: %s" % write_result.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. Player B가 Player A의 카드 수정 시도 (실패해야 함)
	# ═══════════════════════════════════════════════════════════════════════════
	var hack_data := JSON.stringify({"cards": ["hacked_card"]})
	
	var _hack_result = await _client_b.write_storage_objects_async(_session_b, [
		NakamaWriteStorageObject.new("cards", "private_deck", 1, 1, hack_data, "*")
	])
	
	# Player B가 새로운 객체를 생성하게 됨 (권한 없으면 본인 소유로 새 생성)
	# 또는 에러 발생
	
	# Player A의 원본 데이터 확인
	var verify_result = await _client_a.read_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "private_deck", _session_a.user_id)
	])
	
	var original_data = JSON.parse_string(verify_result.objects[0].value)
	assert_eq(original_data.cards[0], "fireball", "Original data should be unchanged")
	gut.p("Player A's data is protected: %s" % original_data.cards)
	
	# Cleanup
	await _client_a.delete_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("cards", "private_deck", _session_a.user_id)
	])


# ═══════════════════════════════════════════════════════════════════════════════
# Test: Progression Template Pattern
# ═══════════════════════════════════════════════════════════════════════════════

func test_progression_template() -> void:
	if not await _login_players():
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 1. 정적 Progression Template 정의
	# ═══════════════════════════════════════════════════════════════════════════
	var template := {
		"title": "card_collection_progression",
		"progress": 0,
		"cards": [],
		"rewards": [
			{"cards": ["starter_pack"]},
			{"cards": ["rare_card"]},
			{"cards": ["legendary_card"]}
		]
	}
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 2. 플레이어에게 Template 복사 (Progression 시작)
	# ═══════════════════════════════════════════════════════════════════════════
	var player_progression := template.duplicate()
	player_progression.cards = ["starter_pack"]  # 첫 번째 보상
	player_progression.progress = 1
	
	var write_result = await _client_a.write_storage_objects_async(_session_a, [
		NakamaWriteStorageObject.new("progression", "cards", 1, 1, 
			JSON.stringify(player_progression), "")
	])
	
	if write_result.is_exception():
		pending("Write failed: %s" % write_result.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 3. 이벤트: 진행도 업데이트 (예: 카드 획득 이벤트)
	# ═══════════════════════════════════════════════════════════════════════════
	var read_result = await _client_a.read_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("progression", "cards", _session_a.user_id)
	])
	
	var current = JSON.parse_string(read_result.objects[0].value)
	var version = read_result.objects[0].version
	
	# 새 보상 획득
	if current.progress < current.rewards.size():
		var new_reward = current.rewards[current.progress]
		current.cards.append_array(new_reward.cards)
		current.progress += 1
	
	var update_result = await _client_a.write_storage_objects_async(_session_a, [
		NakamaWriteStorageObject.new("progression", "cards", 1, 1, 
			JSON.stringify(current), version)
	])
	
	if update_result.is_exception():
		pending("Update failed: %s" % update_result.get_exception().message)
		return
	
	# ═══════════════════════════════════════════════════════════════════════════
	# 4. 검증
	# ═══════════════════════════════════════════════════════════════════════════
	var final_result = await _client_a.read_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("progression", "cards", _session_a.user_id)
	])
	
	var final_data = JSON.parse_string(final_result.objects[0].value)
	assert_eq(final_data.progress, 2, "Progress should be 2")
	assert_eq(final_data.cards.size(), 2, "Should have 2 cards from rewards")
	assert_true(final_data.cards.has("starter_pack"), "Should have starter_pack")
	assert_true(final_data.cards.has("rare_card"), "Should have rare_card")
	
	gut.p("Progression: progress=%d, cards=%s" % [final_data.progress, final_data.cards])
	
	# Cleanup
	await _client_a.delete_storage_objects_async(_session_a, [
		NakamaStorageObjectId.new("progression", "cards", _session_a.user_id)
	])
