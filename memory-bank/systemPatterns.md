# System Patterns: Arena

## 시스템 아키텍처

### Autoload 싱글톤 계층
```
┌─────────────────────────────────────────────────────────────┐
│                    Main.gd                                  │
│              (화면 전환 & 신호 라우팅)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┼────────────────────────────────────┐
│                        ▼                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Online.gd                                            │   │
│  │ - Nakama 클라이언트/세션/소켓 관리                  │   │
│  │ - 인증 및 연결 상태                                  │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           ▼                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ OnlineMatch.gd                                       │   │
│  │ - 매칭메이커 관리                                    │   │
│  │ - NakamaMultiplayerBridge                            │   │
│  │ - 플레이어 조인/리브                                 │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           ▼                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ GameManager.gd                                       │   │
│  │ - 게임 상태 머신                                     │   │
│  │ - 매치 시작/종료                                     │   │
│  │ - 플레이어 관리                                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 로드 순서 (project.godot)
```ini
[autoload]
Online="*res://scripts/autoload/Online.gd"
OnlineMatch="*res://scripts/autoload/OnlineMatch.gd"
GameState="*res://scripts/autoload/GameState.gd"
GameManager="*res://scripts/autoload/GameManager.gd"
```

## 디렉토리 구조

```
arena/
├── scenes/
│   ├── dev/                    # 개발/테스트 씬
│   │   ├── test_battle.tscn    # 테스트용 배틀 (BattleScreen 인스턴스화)
│   │   └── test_character.tscn # 캐릭터 테스트
│   └── ui/                     # UI 씬
│       ├── battle_hud.tscn     # 배틀 HUD
│       └── ...
│
├── scripts/
│   ├── autoload/               # 싱글톤
│   │   ├── Online.gd
│   │   ├── OnlineMatch.gd
│   │   ├── GameState.gd
│   │   └── GameManager.gd
│   ├── entities/               # 게임 엔티티
│   │   ├── character.gd        # 캐릭터 클래스
│   │   └── projectile.gd       # 투사체 클래스
│   ├── res/                    # 리소스
│   │   ├── character_data.gd   # 캐릭터 데이터
│   │   └── registry/
│   │       └── character_registry.gd
│   └── ui/                     # UI 스크립트
│       ├── login_screen.gd
│       ├── lobby_screen.gd
│       ├── matching_screen.gd
│       ├── battle_screen.gd
│       └── ...
│
├── tests/                      # GUT 테스트
│   ├── test_online.gd
│   ├── test_matchmaking.gd
│   ├── test_battle_sync.gd
│   └── ...
│
└── addons/
    ├── gut/                    # 테스트 프레임워크
    └── com.heroiclabs.nakama/  # Nakama SDK
```

## 핵심 디자인 패턴

### 1. Code-First 데이터 레지스트리
```gdscript
# CharacterRegistry.gd
class_name CharacterRegistry
extends RefCounted

var _characters: Dictionary = {}

func _init() -> void:
    _register_all_characters()

func _register_gyro() -> void:
    var data := CharacterData.new()
    data.id = "gyro"
    data.display_name = "자이로"
    # ... 능력치 설정
    _characters[data.id] = data

func get_character(id: String) -> CharacterData:
    return _characters.get(id)
```

**장점**:
- 버전 관리 용이
- 타입 안전
- 리팩토링 친화적

### 2. 엔티티 초기화 패턴
```gdscript
# Character.gd
class_name Character
extends CharacterBody2D

var _data: CharacterData

func _ready() -> void:
    # 엔티티는 init() 호출 후 동작
    pass

func init(data: CharacterData) -> void:
    _data = data
    _current_hp = data.max_hp
    _setup_collision()
    _setup_visual()
```

**사용법**:
```gdscript
var character := Character.new()
character.init(character_data)
add_child(character)
```

### 3. 시그널 기반 통신
```gdscript
# Character.gd
signal hp_changed(current: int, max_hp: int)
signal died()
signal attacked(is_ranged: bool)

# test_battle.gd
player.hp_changed.connect(_on_player_hp_changed)
player.died.connect(_on_player_died)
```

### 4. 상태 머신 패턴
```gdscript
# GameManager.gd
enum ManagerGameState {
    NONE, LOADING, MAIN_MENU, SHOP, MATCHING,
    CHARACTER_SELECT, PLAYING, PAUSED, RESULT
}

signal state_changed(old_state, new_state)

func change_state(new_state: ManagerGameState) -> bool:
    if current_state == new_state:
        return false
    previous_state = current_state
    current_state = new_state
    state_changed.emit(previous_state, current_state)
    return true
```

### 5. 매치 상태 머신
```gdscript
# OnlineMatch.gd
enum MatchState {
    LOBBY = 0,
    MATCHING = 1,
    CONNECTING = 2,
    WAITING_FOR_ENOUGH_PLAYERS = 3,
    READY = 4,
    PLAYING = 5,
}
```

## 네트워크 동기화 패턴

### NakamaMultiplayerBridge 활용
```gdscript
# 브리지 생성
_bridge = NakamaMultiplayerBridge.new(socket)
_bridge.match_joined.connect(_on_match_joined)

# Godot RPC와 호환
multiplayer.multiplayer_peer = _bridge.multiplayer_peer

# 매치 생성/참가
_bridge.create_match()  # 호스트
_bridge.join_match(match_id)  # 클라이언트
```

### RPC 동기화
```gdscript
# Character.gd
const SYNC_DELAY := 3  # 3프레임마다 동기화

func _sync_position_periodically() -> void:
    if not OnlineMatch.nakama_socket:
        return
    _sync_counter += 1
    if _sync_counter < SYNC_DELAY:
        return
    _sync_counter = 0
    rpc("sync_remote_position", position, velocity, _facing_direction, _current_hp)

@rpc("any_peer", "unreliable")
func sync_remote_position(_pos: Vector2, _vel: Vector2, _facing: Vector2, _hp: int) -> void:
    if _is_network_controlled:
        position = _pos
        velocity = _vel
        _facing_direction = _facing
        _current_hp = _hp
```

### Op Code 규약
| Op Code | 용도 | 방향 |
|---------|------|------|
| 9002 | RPC (데미지 등) | 양방향 |
| 9003 | 위치 동기화 | 양방향 |
| 9004 | 캐릭터 선택 | 양방향 |

## 컴포넌트 관계

### Character ↔ CharacterData
```
CharacterData (Resource)
    ↓ 데이터 제공
Character (CharacterBody2D)
    ↓ 생성
Projectile (Area2D)
```

### OnlineMatch ↔ GameManager
```
OnlineMatch.match_ready
    ↓
GameManager.start_match()
    ↓
GameManager.match_ended
    ↓
OnlineMatch.leave()
```

### Screen 전환
```
SplashScreen
    ↓ transition_requested
LoginScreen
    ↓ transition_requested
LobbyScreen
    ↓ transition_requested
MatchingScreen
    ↓ transition_requested
CharacterSelectScreen
    ↓ transition_requested
BattleScreen
    ↓ transition_requested
ResultScreen
```

## 중요 구현 경로

### 1. 인증 흐름
```
LoginScreen._ready()
  → Online.authenticate_device()
  → await Online.session_connected
  → LobbyScreen으로 전환
```

### 2. 매칭 흐름
```
MatchingScreen._on_play()
  → Online.connect_nakama_socket()
  → OnlineMatch.start_matchmaking(socket)
  → await OnlineMatch.match_ready
  → BattleScreen으로 전환
```

### 3. 배틀 흐름
```
BattleScreen._ready()
  → GameManager.start_match()
  → 캐릭터 스폰
  → _process()에서 입력 처리 및 RPC 동기화
  → 승패 조건 충족
  → GameManager.end_match()