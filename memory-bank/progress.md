# Progress: Arena

## 현재 상태

### 완료된 기능
- [x] 프로젝트 구조 설정
- [x] Autoload 싱글톤 구성
- [x] Nakama SDK 통합
- [x] GUT 테스트 프레임워크 설정

### 온라인 시스템
- [x] Online.gd - Nakama 연결 관리
- [x] OnlineMatch.gd - 매칭 로직
- [x] GameManager.gd - 게임 상태 머신
- [x] GameState.gd - 게임 상태

### 엔티티 시스템
- [x] Character 엔티티
  - [x] 이동 (방향키)
  - [x] 근접 공격 (히트박스)
  - [x] 원거리 공격 (투사체)
  - [x] 부스터 시스템
  - [x] HP/MP/BP 관리
  - [x] 네트워크 동기화
- [x] Projectile 엔티티
  - [x] 이동 및 충돌
  - [x] 데미지 처리
  - [x] 사거리 제한

### 데이터 시스템
- [x] CharacterData 리소스
- [x] CharacterRegistry (Code-First)
- [x] 등록된 캐릭터: gyro, shamu, enemy_slime

### UI 시스템
- [x] SplashScreen
- [x] LoginScreen
- [x] LobbyScreen
- [x] MatchingScreen
- [x] CharacterSelectScreen
- [x] BattleScreen
- [x] ResultScreen
- [x] BattleHUD (터치 버튼)

### 테스트
- [x] test_online.gd - 인증 테스트
- [x] test_matchmaking.gd - 매칭 테스트
- [x] test_battle_sync.gd - 동기화 테스트
  - [x] 데미지 동기화
  - [x] 위치 동기화
  - [x] 캐릭터 선택 동기화
- [x] test_multiplayer_flow.gd - 통합 테스트

## 진행 중인 작업

### 배틀 씬 분리 ✅ 완료
- [x] `scripts/ui/battle_screen.gd` 구조 확립
- [x] 배틀 로직 구현
  - [x] 플레이어 스폰 함수
  - [x] 적 캐릭터 스폰 함수
  - [x] 배틀 시작/종료 제어
  - [x] 승패 조건 체크
  - [x] 네트워크 플레이어 설정
- [x] `scenes/dev/test_battle.gd` 리팩토링
  - [x] `BattleScreen` 분리 인스턴스화
  - [x] 테스트 데이터 설정 분리
  - [x] 디버그 UI 유지
- [x] `tests/test_battle.gd` 작성
  - [x] 배틀 초기화 테스트
  - [x] 플레이어/적 스폰 테스트
  - [x] 시그널 테스트
  - [x] 캐릭터 스탯 테스트

## 남은 작업

### Phase 1: 배틀 로직 ✅ 완료
- [x] battle.gd 구현
- [x] test_battle.gd 리팩토링
- [x] 배틀 테스트 작성

### Phase 2: 맵 시스템 (다음)
- [ ] MapData 정의
- [ ] 맵 충돌 영역
- [ ] 환경 위험 요소
- [ ] 텔레포트 지점

### Phase 3: 게임플레이
- [ ] 속성 상성 시스템
- [ ] 아이템 드롭
- [ ] 스킬 시스템
- [ ] AI 적

### Phase 4: UI/UX
- [ ] 설정 화면
- [ ] 튜토리얼
- [ ] 업적 시스템

## 알려진 이슈

### 네트워크
- 위치 동기화가 간헐적으로 끊김 (3프레임마다 전송)
- 원격 플레이어 위치 보간 필요

### 캐릭터
- 근접 공격 히트박스가 시각적으로 보임 (디버그용)
- 투사체가 다른 투사체와 충돌 시 즉시 삭제

### UI
- 모바일 터치 컨트롤 최적화 필요
- 화면 회전 대응 필요

## 결정사항 변화

### 2026-04-15 ~ 17
- 배틀 씬 구조 및 분리 결정 수정
  - `scripts/ui/battle_screen.gd`: 실제 게임용 코어 배틀 씬
  - `scenes/dev/test_battle.tscn`: 개발/테스트용 랩퍼(wrapper) 씬으로 활용해 의존성 분리
- Code-First 레지스트리 방식 채택
- NakamaMultiplayerBridge 기반 RPC 방식 채택

### 이전 결정사항
- Device ID 인증 방식 채택
- GUT 테스트 프레임워크 선택
- Godot 4.x 사용

## 다음 마일스톤

### v0.1.0 - 기본 배틀 ✅ 완료
- [x] battle.gd 완성
- [x] 1:1 배틀 가능
- [x] 기본 승패 조건

### v0.2.0 - 네트워크 배틀 (다음)
- [ ] 온라인 매칭
- [ ] 실시간 동기화
- [ ] 재연결 처리

### v0.3.0 - 콘텐츠
- [ ] 다양한 캐릭터
- [ ] 맵 추가
- [ ] 속성 상성