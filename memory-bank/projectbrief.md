# Project Brief: Arena

## 개요
Arena는 Godot 4 기반 모바일 2D 멀티플레이어 실시간 대전 게임입니다. Nakama 서버를 활용한 온라인 매칭 및 실시간 전투 시스템을 구축합니다.

## 핵심 요구사항

### 게임 플레이
- 실시간 1:1 / 3:3 / 5:5 배틀
- 다양한 속성(물, 불, 바람, 흙)의 캐릭터
- 근접 공격 및 원거리 투사체 공격
- 부스터 시스템을 통한 빠른 이동

### 온라인 기능
- Nakama 서버 기반 인증 (Device ID)
- 실시간 매칭메이커
- NakamaMultiplayerBridge를 통한 RPC 동기화
- 플레이어 위치, 체력, 공격 동기화

### 개발 방식
- **Spec → Test → Implementation** 주도 개발
- GUT (Godot Unit Test) 프레임워크 사용
- Code-First 데이터 레지스트리

## 프로젝트 범위

### 포함
- 로그인/인증 시스템
- 로비 및 매칭 시스템
- 캐릭터 선택
- 실시간 배틀
- 결과 화면

### 미포함
- 상점 시스템 (아키텍처만 정의)
- 랭킹 시스템
- 친구 시스템

## 기술 스택
- **엔진**: Godot 4.x
- **언어**: GDScript
- **서버**: Nakama (Heroic Labs)
- **테스트**: GUT (Godot Unit Test)
- **버전관리**: Git

## 타겟 플랫폼
- Android (모바일)
- iOS (모바일)