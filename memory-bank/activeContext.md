# Active Context: Arena

## 현재 작업 포커스

### 배틀 씬 분리 작업
현재 `scenes/prd/battle.tscn`과 `scenes/dev/test_battle.tscn`을 분리하는 작업을 진행 중입니다.

#### 씬 구조
```
scenes/
├── prd/                    # 프로덕션용 씬
│   ├── battle.tscn         # 실제 배틀 씬 (로직만)
│   └── battle.gd           # 배틀 로직
│
└── dev/                    # 개발/테스트용 씬
    ├── test_battle.tscn    # 테스트용 배틀 씬
    └── test_battle.gd      # 테스트 데이터 설정
```

#### 역할 분담
- **`battle.tscn` (prd)**: 실제 게임에서 사용될 배틀 씬
  - 배틀 로직 처리
  - 캐릭터 스폰/관리
  - 승패 판정
  - 네트워크 동기화

- **`test_battle.tscn` (dev)**: 개발 및 테스트용
  - 테스트할 캐릭터 데이터 설정
  - `battle.tscn`을 인스턴스화하여 실행
  - 디버그 UI (HP, MP, BP 표시)
  - 전투 로그
  - 테스트용 버튼 (캐릭터 전환, 리셋, 적 스폰)

## 최근 변경사항

### 2026-04-15
- `scenes/prd/battle.tscn` 및 `battle.gd` 생성
- 배틀 씬 분리 구조 설계

### 완료된 작업
- [x] Character 엔티티 (이동, 공격, 부스터)
- [x] Projectile 엔티티 (투사체)
- [x] CharacterData 리소스
- [x] CharacterRegistry (Code-First)
- [x] Online.gd (Nakama 연결)
- [x] OnlineMatch.gd (매칭 로직)
- [x] GameManager.gd (게임 상태)
- [x] UI Screen들 (Login, Lobby, Matching, Battle, Result)
- [x] 네트워크 동기화 테스트 (위치, 데미지, 캐릭터 선택)

## 다음 단계

### 1. battle.gd 구현
```gdscript
# 배틀 로직이 들어갈 내용
- 플레이어 스폰
- 적 캐릭터 스폰
- 전투 영역 설정
- 승패 조건 체크
- 네트워크 동기화 처리
```

### 2. test_battle.gd 수정
```gdscript
# 테스트 데이터 설정만 담당
- 플레이어 캐릭터 ID 설정
- 적 캐릭터 ID 설정
- battle.tscn 인스턴스화
- 테스트용 UI 유지
```

### 3. 테스트 작성
- 배틀 시작/종료 테스트
- 캐릭터 스폰 테스트
- 승패 조건 테스트

## 중요한 패턴 및 선호사항

### 코드 스타일
- 섹션 주석: `# ═════════════════════════════════════════════════════════════════════════════════`
- 시그널 먼저, 그 다음 변수, 함수 순
- private 변수는 `_` 접두사 사용

### 씬 분리 원칙
- **prd/**: 실제 게임에서 사용하는 순수 로직
- **dev/**: 테스트 데이터와 디버그 기능

### 네트워크 동기화
- op_code 9002: RPC (데미지 등)
- op_code 9003: 위치 동기화
- op_code 9004: 캐릭터 선택 동기화
- 3프레임마다 위치 전송

## 학습 및 인사이트

### NakamaMultiplayerBridge
- `create_match()`: 호스트가 매치 생성
- `join_match(match_id)`: 클라이언트가 매치 참가
- `multiplayer_peer`: Godot RPC와 호환
- `_id_map`: session_id → peer_id 매핑

### Character 입력 제어
- `is_controllable`: 플레이어만 true
- `_is_network_controlled`: 원격 플레이어는 true
- 로컬 플레이어만 입력 처리

### 테스트 접근
- GUT 프레임워크 사용
- `await` 기반 비동기 테스트
- Nakama 서버 필요한 테스트는 `pending()` 처리