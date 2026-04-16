# Product Context: Arena

## 제품 비전
Arena는 모바일 환경에서 즐길 수 있는 빠르고 직관적인 실시간 대전 게임입니다. 짧은 매치 시간과 간단한 조작으로 누구나 쉽게 즐길 수 있으며, Nakama 서버를 통해 안정적인 온라인 경험을 제공합니다.

## 해결하는 문제
- 모바일 멀티플레이어 게임의 복잡한 조작 문제 → 직관적인 터치 컨트롤
- 긴 매치 시간으로 인한 접근성 문제 → 3~5분 내외의 빠른 매치
- 불안정한 네트워크 동기화 → Nakama 서버를 통한 안정적인 실시간 동기화

## 사용자 경험 목표

### 온보딩
1. 게임 실행 → 자동 로그인 (Device ID)
2. 로비에서 모드 선택
3. 매칭 대기 (최대 30초)
4. 캐릭터 선택
5. 배틀 시작

### 배틀 경험
- **이동**: 가상 조이스틱 또는 방향키
- **공격**: 터치 버튼 (근접/원거리)
- **부스터**: 더블 탭 또는 전용 버튼으로 빠른 이동
- **직관적인 UI**: 체력바, MP/BP 게이지, 킬/데스 카운트

### 게임 흐름
```
Splash (1초) → Login → Lobby → Matching → Character Select → Battle → Result
```

## 핵심 기능

### 1. 인증 시스템
- Device ID 기반 자동 로그인
- 세션 복구 및 재연결 처리

### 2. 매칭 시스템
- 1:1, 3:3, 5:5 모드 지원
- 클라이언트 버전 매칭
- 최소/최대 플레이어 수 확인

### 3. 캐릭터 시스템
- 4가지 속성 (물, 불, 바람, 흙)
- 각 캐릭터별 고유 능력치
  - HP, MP, BP (Bullet Point)
  - 근접/원거리 공격력
  - 이동 속도, 가속도
  - 부스터 효율

### 4. 전투 시스템
- 근접 공격: 히트박스 기반 즉시 데미지
- 원거리 공격: 투사체 발사 (BP 소모)
- 부스터: MP 소모로 이동 속도 2배
- 속성 상성 (추후 구현)

### 5. 네트워크 동기화
- 위치 동기화 (op_code 9003)
- 데미지 동기화 (op_code 9002)
- 캐릭터 선택 동기화 (op_code 9004)
- 주기적 위치 전송 (3프레임마다)

## UI/UX 구조

### 화면 구성
- **SplashScreen**: 로고 표시 (1초)
- **LoginScreen**: 자동 인증, 로딩 표시
- **LobbyScreen**: 모드 선택, 설정
- **MatchingScreen**: 매칭 대기, 플레이어 목록
- **CharacterSelectScreen**: 캐릭터 선택, 준비 상태
- **BattleScreen**: 실제 게임 플레이
- **ResultScreen**: 결과 표시, 보상

### 모바일 최적화
- 터치 버튼 (대쉬, 근접공격, 원거리공격)
- 가상 조이스틱 지원
- 반응형 UI 레이아웃

## 데이터 구조

### 캐릭터 데이터 (CharacterData)
```gdscript
- id: String
- display_name: String
- element: ElementType (WATER, FIRE, WIND, EARTH)
- max_hp, max_mp, max_bp: int
- melee_power, ranged_power: int
- max_speed, acceleration: float
- booster_speed_multiplier: float
```

### 플레이어 데이터 (PlayerData)
```gdscript
- id, name: String
- character_id: String
- team_id: int
- is_ready: bool
```

### 매치 데이터 (MatchData)
```gdscript
- mode: MatchMode
- map_id: String
- players: Array[PlayerData]
- time_limit: int