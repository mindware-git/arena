# Network Principles: Client-Relay Architecture

## Core Principles

### 1. Client-Relay 정책
우리는 권위적 서버(Authoritative Server)를 두지 않는다. 리소스 문제로 Nakama는 **메시지 중계(relay)** 역할만 수행한다. 모든 게임 로직은 각 클라이언트에서 실행된다.

### 2. RPC 100% 신뢰
전용 서버가 없으므로, 다른 클라이언트에서 날아온 RPC는 **100% 신뢰**한다. 검증 없이 그대로 수용한다.

### 3. Owner 책임 원칙
본인(Owner)의 캐릭터, 투사체(Projectile), 이펙트 등은 **모두 본인 클라이언트가 책임**진다. 상대편 클라이언트에서는 해당 오브젝트의 **시각적 표현(visible)만 수정**하는 것이 원칙이다.

### 4. latency (Ping)
만약 우선순위를 결정하기 어려운 순간이 오면 Ping이 높은 쪽의 의견을 따른다.

---

## 상황별 각 클라이언트 동작

> 전제: A, B, C 세 명의 플레이어가 같은 매치에 있다.
> A의 캐릭터/투사체는 A 클라이언트가 Owner이다.

| 상황 | Client A | Client B | Client C |
|---|---|---|---|
| **[이동]** A가 이동함 | 로컬에서 이동 처리. 주기적으로 `sync_remote_position` RPC 브로드캐스트 | RPC 수신 → A 캐릭터의 위치만 갱신 (시각적 이동) | RPC 수신 → A 캐릭터의 위치만 갱신 (시각적 이동) |
| **[투사체]** A가 투사체 발사 | 로컬에서 투사체 생성 (충돌 감지 O, 데미지 판정 O). `_spawn_remote_projectile` RPC 브로드캐스트 | RPC 수신 → 시각전용 투사체 생성 (충돌 시 사라지기만 함, 데미지 판정 X) | RPC 수신 → 시각전용 투사체 생성 (충돌 시 사라지기만 함, 데미지 판정 X) |
| **[투사체]** A의 투사체가 B에게 적중 | A 로컬에서 충돌 감지 → 투사체 제거 → `apply_damage(B, 50)` 로컬 실행 + `take_damage(50)` RPC 브로드캐스트 | 시각전용 투사체가 자기 캐릭터에 닿으면 투사체만 제거. `take_damage` RPC 수신 시 자기 HP 차감 | 시각전용 투사체가 B 캐릭터에 닿으면 투사체만 제거. `take_damage` RPC 수신 시 B의 HP 차감 |
| **[데미지]** A가 B에게 50 데미지를 줌 ( 이 경우 A가 owner인 주체임. ) | `apply_damage`: 로컬에서 B의 HP 차감 + `take_damage(50)` RPC **브로드캐스트** | `take_damage` RPC 수신 → 자기 캐릭터 HP 차감 | `take_damage` RPC 수신 → B 캐릭터의 HP 차감 (HP바 갱신) |
| **[사망]** B의 HP가 0 이하가 됨 | A 로컬에서도 B의 HP ≤ 0 감지 → B 캐릭터 visible 끔 (즉시 반영) | `take_damage` 처리 후 HP ≤ 0 → `_die()` 실행 → `sync_death` RPC 브로드캐스트 | 별도 동작 없음. B의 사망 RPC 수신 대기 |
| **[사망]** B의 사망 RPC 수신 | B 캐릭터를 사망 상태로 전환 + 제거. 킬 카운트 증가 등 처리 | (본인이 발신자) | B 캐릭터를 사망 상태로 전환 + 제거 |
| **[배틀종료]** 상대팀 전원 사망 RPC 수신 완료 | 로컬에서 배틀 종료 판정 → 결과 화면 전환 | 로컬에서 배틀 종료 판정 → 결과 화면 전환 | 로컬에서 배틀 종료 판정 → 결과 화면 전환 |
