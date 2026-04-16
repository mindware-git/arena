# Technical Context: Arena

## 기술 스택

### 게임 엔진
- **Godot 4.x**
  - 2D 게임 개발
  - GDScript 스크립팅
  - CharacterBody2D 물리
  - Signal 기반 이벤트 시스템

### 백엔드 서버
- **Nakama (Heroic Labs)**
  - Device ID 인증
  - 실시간 매칭메이커
  - WebSocket 기반 실시간 통신
  - NakamaMultiplayerBridge (Godot RPC 호환)

### 테스트 프레임워크
- **GUT (Godot Unit Test)**
  - BDD 스타일 테스트
  - `extends GutTest`
  - `await` 기반 비동기 테스트
  - `pending()` - 서버 필요 테스트 스킵

## 개발 환경 설정

### 프로젝트 설정 (project.godot)
```ini
[autoload]
Online="*res://scripts/autoload/Online.gd"
OnlineMatch="*res://scripts/autoload/OnlineMatch.gd"
GameState="*res://scripts/autoload/GameState.gd"
GameManager="*res://scripts/autoload/GameManager.gd"

[network]
network/nakama/host="localhost"
network/nakama/port=7350
network/nakama/server_key="defaultkey"
```

### GUT 설정 (.gutconfig.json)
```json
{
  "dirs": ["res://tests"],
  "should_maximize": false,
  "should_exit": true,
  "ignore_pause": true
}
```

### 테스트 실행
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

## 의존성

### Addons
```
addons/
├── gut/                      # Godot Unit Test
│   ├── gut.gd
│   ├── test.gd
│   └── ...
│
└── com.heroiclabs.nakama/    # Nakama SDK
    ├── Nakama.gd
    ├── api/
    ├── client/
    ├── socket/
    └── utils/
```

### 주요 Nakama 클래스
- `NakamaClient` - HTTP 클라이언트
- `NakamaSession` - 인증 세션
- `NakamaSocket` - WebSocket 연결
- `NakamaMultiplayerBridge` - Godot RPC 브리지

## 기술 제약사항

### 네트워크
- Nakama 서버 실행 필요 (Docker 권장)
- WebSocket 연결 필수
- RPC는 `@rpc` 어노테이션 사용
- 위치 동기화는 `unreliable` 모드

### 모바일 최적화
- 터치 컨트롤 필수
- 가상 조이스틱 지원
- 배터리 효율 고려 (동기화 빈도 조절)

### 메모리 관리
- 씬 전환 시 이전 씬 해제
- 오브젝트 풀링 (투사체 등)
- `queue_free()` 명시적 호출

## 도구 사용 패턴

### 디버깅
```gdscript
# Character.gd
func get_debug_info() -> String:
    return "%s | HP: %d/%d | MP: %d/%d" % [
        _data.display_name,
        _current_hp, _data.max_hp,
        _current_mp, _data.max_mp
    ]
```

### 로깅
```gdscript
# 전투 로그
func _log(message: String) -> void:
    if _battle_log:
        _battle_log.append_text("%s\n" % message)
    print("[Battle] %s" % message)
```

### 에러 처리
```gdscript
# Nakama 에러
if result.is_exception():
    pending("Auth failed: %s" % result.get_exception().message)
    return
```

## 코드 스타일 가이드

### 파일 구조
```gdscript
class_name ClassName
extends BaseClass

# ═══════════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════════

signal example_signal(param: int)

# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

const EXAMPLE_CONSTANT := 10

# ═══════════════════════════════════════════════════════════════════════════════
# Variables
# ═══════════════════════════════════════════════════════════════════════════════

var _private_var: int = 0

# ═══════════════════════════════════════════════════════════════════════════════
# Properties
# ═══════════════════════════════════════════════════════════════════════════════

var public_property: int:
    get: return _private_var
    set(value): _private_var = value

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass

# ═══════════════════════════════════════════════════════════════════════════════
# Public Methods
# ═══════════════════════════════════════════════════════════════════════════════

func public_method() -> void:
    pass

# ═══════════════════════════════════════════════════════════════════════════════
# Private Methods
# ═══════════════════════════════════════════════════════════════════════════════

func _private_method() -> void:
    pass
```

### 네이밍 컨벤션
- **클래스**: PascalCase (`Character`, `GameManager`)
- **함수**: snake_case (`_private_method`, `public_method`)
- **변수**: snake_case (`_private_var`, `public_var`)
- **상수**: SCREAMING_SNAKE_CASE (`SYNC_DELAY`)
- **시그널**: snake_case (`hp_changed`, `died`)

### 타입 힌트
```gdscript
# 명시적 타입
var _data: CharacterData
var _current_hp: int = 0
var _position: Vector2 = Vector2.ZERO

# 함수 반환 타입
func get_character(id: String) -> CharacterData:
    return _characters.get(id)

# 배열 타입
var _enemies: Array[Character] = []
```

## 외부 리소스

### 참고 프로젝트
- **fishgame-godot**: Nakama 멀티플레이어 예제
- 경로: `../fishgame-godot/`

### 문서
- Nakama Docs: https://heroiclabs.com/docs/
- Godot RPC: https://docs.godotengine.org/en/stable/tutorials/networking/using_rpc.html
- GUT Wiki: https://github.com/bitwes/Gut/wiki

## 배포

### Docker (Nakama 서버)
```bash
cd nakama
docker-compose up -d
```

### Godot Export
- Android: APK/AAB
- iOS: IPA (Mac 필요)