# 🎮 Arena - Nakama 멀티플레이 아키텍처

fishgame-godot 을 참고하여 설계한 arena 프로젝트의 멀티플레이 아키텍처 문서입니다.

---

## 📊 **시스템 구조**

```
┌─────────────────────────────────────────────────────┐
│                    Main.gd                          │
│          (화면 전환 & 신호 라우팅)                  │
└────────────┬────────────────────────────────────────┘
             │
             ├──→ SplashScreen (1초)
             │     ↓
             ├──→ LoginScreen (Nakama 인증)
             │     → Online.authenticate_device()
             │     ↓
             ├──→ LobbyScreen (모드 선택)
             │     ↓
             ├──→ MatchingScreen (매칭 대기)
             │     → OnlineMatch.start_matchmaking()
             │     ↓
             └──→ BattleScreen (실시간 게임)
                   → GameManager.start_game()
                   → 플레이어 RPC 동기화

┌─────────────────────────────────────────────────────┐
│     Autoload / Global Singletons                    │
├─────────────────────────────────────────────────────┤
│ • Online.gd - Nakama 서버 연결                     │
│ • OnlineMatch.gd - 매칭 로직 & 플레이어 상태       │
│ • GameState.gd - 게임 상태                         │
└─────────────────────────────────────────────────────┘
```

---

## 📁 **프로젝트 레이아웃**

```
scripts/
├── autoload/
│   ├── Online.gd              ← fishgame 기반 복사
│   ├── OnlineMatch.gd         ← fishgame 기반 복사
│   └── GameState.gd           ← 기존 + 수정
│
├── managers/
│   ├── game_manager.gd        ← Game.gd 역할
│   └── screen_manager.gd      ← Main.gd 역할
│
├── ui/
│   ├── splash_screen.gd       (기존 - 1초 후 자동 진행)
│   ├── login_screen.gd        (신규 - Nakama 인증)
│   ├── lobby_screen.gd        (수정 - 모드선택)
│   ├── matching_screen.gd     (수정 - 매칭체크)
│   ├── battle_screen.gd       (수정 - RPC 동기화)
│   └── result_screen.gd       (기존)
│
└── entities/
    └── player.gd             ← 네트워크 플레이어
```

---

## 🔌 **Autoload 설정 (project.godot)**

```gdscript
[autoload]

Online="*res://scripts/autoload/Online.gd"
OnlineMatch="*res://scripts/autoload/OnlineMatch.gd"
GameState="*res://scripts/autoload/GameState.gd"
GameManager="*res://scripts/autoload/GameManager.gd"
```

---

## 🎯 **각 모듈 상세설명**

### 1️⃣ **Online.gd** (Nakama 서버 연결관리)

**책임**: 
- Nakama 클라이언트 생성/관리
- 세션 인증
- 소켓 연결

**API**:
```gdscript
signal session_connected(session: NakamaSession)
signal socket_connected(socket: NakamaSocket)

var nakama_session: NakamaSession
var nakama_socket: NakamaSocket

func authenticate_device() -> void
    # await Online.session_connected
    
func connect_nakama_socket() -> void
    # await Online.socket_connected
```

**사용 예시**:
```gdscript
# LoginScreen에서
func _start_authentication() -> void:
    Online.authenticate_device()
    await Online.session_connected
    _show_loading(false)
    transition_requested.emit(LobbyScreen.new())
```

---

### 2️⃣ **OnlineMatch.gd** (매칭 & 플레이어 상태)

**책임**:
- Nakama 매칭메이커 관리
- NakamaMultiplayerBridge로 RPC 구성
- 플레이어 조인/리브 감지

**상태머신**:
```
LOBBY → MATCHING → CONNECTING → WAITING_FOR_ENOUGH_PLAYERS → READY → PLAYING
```

**API**:
```gdscript
signal match_ready(players: Dictionary)
signal player_joined(player)
signal player_left(player)
signal error(message: String)

var players: Dictionary     # { session_id: Player }
var match_id: String
var match_state: int

func start_matchmaking(_nakama_socket: NakamaSocket) -> void
    # matchmaker 시작, match_ready 신호 대기
    
func leave() -> void
    # 매치 떠나기
```

**사용 예시**:
```gdscript
# MatchingScreen에서
func _on_play_button() -> void:
    OnlineMatch.start_matchmaking(Online.nakama_socket)
    await OnlineMatch.match_ready
    transition_requested.emit(BattleScreen.new())

# BattleScreen에서
func _ready() -> void:
    OnlineMatch.player_joined.connect(_on_player_joined)
    OnlineMatch.player_left.connect(_on_player_left)
```

---

### 3️⃣ **ScreenManager.gd** (화면 전환)

**책임**:
- 화면 전환 오케스트레이션
- 신호 라우팅
- 에러 처리

**API**:
```gdscript
func show_screen(screen: Node) -> void
    # 기존 화면 제거, 새 화면 표시
    
func _on_screen_transition(next_screen: Node) -> void
    # screen의 transition_requested 신호 받기
```

---

### 4️⃣ **GameManager.gd** (게임 루프 & RPC)

**책임**:
- 플레이어 엔티티 생성
- RPC로 네트워크 동기화
- 게임 시작/종료

**API**:
```gdscript
signal game_started()

func start_game(players: Dictionary) -> void
    # 플레이어 생성, 게임 시작
    
@remotesync
func player_moved(peer_id: int, position: Vector2) -> void
    # 플레이어 이동 동기화
```

---

### 5️⃣ **Screens** (화면)

#### **SplashScreen**
- "ARENA" 로고 표시
- 1초 후 자동으로 LoginScreen으로 이동

#### **LoginScreen** (신규)
```gdscript
class_name LoginScreen
extends Control

signal transition_requested(next_screen: Node)

func _ready() -> void:
    _show_loading()
    Online.authenticate_device()
    await Online.session_connected
    _show_loading(false)
    await get_tree().create_timer(0.5).timeout
    transition_requested.emit(LobbyScreen.new())
```

#### **LobbyScreen** (수정)
```gdscript
# 1:1 플레이 버튼만 추가
var play_1v1_btn = Button.new()
play_1v1_btn.pressed.connect(_on_play_1v1)

func _on_play_1v1() -> void:
    GameState.match_mode = GameState.MatchMode.ONE_VS_ONE
    transition_requested.emit(MatchingScreen.new())
```

#### **MatchingScreen** (수정)
```gdscript
func _ready() -> void:
    var socket = await Online.socket_connected
    OnlineMatch.start_matchmaking(socket)
    
func _process(delta) -> void:
    if OnlineMatch.match_state == OnlineMatch.MatchState.READY:
        _on_match_ready()

func _on_match_ready() -> void:
    transition_requested.emit(BattleScreen.new())
```

#### **BattleScreen** (수정)
```gdscript
func _ready() -> void:
    await GameManager.game_started
    OnlineMatch.player_joined.connect(_on_player_joined)
    
func _process(delta) -> void:
    if my_player:
        my_player.position += velocity * delta
        # RPC로 동기화
        rpc(&"_set_player_position", get_tree().get_network_unique_id(), my_player.position)

@remotesync
func _set_player_position(peer_id: int, pos: Vector2) -> void:
    if peer_id in players:
        players[peer_id].position = pos
```

---

## 🔄 **데이터 흐름**

### 1. **인증 흐름**
```
LoginScreen._ready()
  → Online.authenticate_device()
    → Nakama HTTP 인증 (device ID)
    → session 저장
    → signal: session_connected
  → LobbyScreen으로 이동
```

### 2. **매칭 흐름**
```
MatchingScreen._on_play_button()
  → Online.connect_nakama_socket()
    → 웹소켓 연결
    → signal: socket_connected
  → OnlineMatch.start_matchmaking(socket)
    → matchmaker 대기
    → 매칭 완료
    → signal: match_ready
  → BattleScreen으로 이동
```

### 3. **게임 흐름**
```
BattleScreen._ready()
  → GameManager.start_game(players)
    → 플레이어 노드 생성
    → signal: game_started
  → _process()
    → 입력 처리
    → rpc(&"_set_player_position", ...)
    → OnlineMatch 신호로 플레이어 조인/리브 감지
```

---

## 🧪 **테스트 계획**

### 레벨 1: 단위테스트
```
tests/
├── test_online.gd
│   └── test_authenticate_device()
├── test_online_match.gd
│   └── test_start_matchmaking()
└── test_game_manager.gd
    └── test_player_creation()
```

### 레벨 2: 통합테스트
```
tests/
└── test_multiplayer_flow.gd
    ├── authenticate
    ├── matchmaking
    └── game_start
```

---

## 🚀 **구현 순서**

### Phase 1: 기반시설 (Week 1)
- [ ] Online.gd 복사 & 설정
- [ ] OnlineMatch.gd 복사 & 설정
- [ ] GameState.gd 수정
- [ ] autoload 등록
- [ ] test_online.gd 작성

### Phase 2: UI (Week 2)
- [ ] LoginScreen 구현
- [ ] LobbyScreen 수정
- [ ] MatchingScreen 수정
- [ ] test_login_screen.gd 작성

### Phase 3: 게임로직 (Week 3)
- [ ] ScreenManager.gd 구현
- [ ] GameManager.gd 구현
- [ ] BattleScreen 수정
- [ ] test_game_manager.gd 작성

### Phase 4: 통합 (Week 4)
- [ ] Main.gd 수정
- [ ] 전체 흐름 테스트
- [ ] 버그 수정

---

## 📚 **참고 자료**

- fishgame-godot: `../fishgame-godot/`
- Nakama Docs: https://heroiclabs.com/docs/
- GDScript RPC: https://docs.godotengine.org/en/stable/tutorials/networking/using_rpc.html
