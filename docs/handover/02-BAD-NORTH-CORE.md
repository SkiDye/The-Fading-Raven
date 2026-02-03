# Bad North 핵심 메카닉

> **중요**: Bad North가 이 게임의 레퍼런스. 핵심 메카닉은 반드시 유지.
> **참조**: `docs/implementation/REFERENCE-COMPARISON.md` 에서 상세 비교 확인

---

## 필수 유지 메카닉

### 1. 가위바위보 상성
```
가디언(실드) → 적 Gunner/투척병
    ↓ (약함)
브루트 ← 센티넬(랜스)
            ↓ (약함)
         적 Gunner ← 레인저 ─X─ 적 Shield Trooper
```

### 2. 영구 사망
- **팀장(Team Leader)** 사망 시 분대 영구 손실
- 크루가 1명이라도 생존하면 팀장은 무적

### 3. Tactical Mode (기존: 슬로우 모션)
- 크루 선택 시 게임 속도 감소
- 전술 판단 시간 확보
- **TFR 추가**: Raven AI 지원 연출

### 4. 핵심 전투 메카닉
| 메카닉 | Bad North | TFR 용어 |
|--------|-----------|----------|
| **창 들어올림** | 적이 밀착하면 Pikemen 무력화 | 센티넬 Lance Raise |
| **교전 중 실드 무효** | 근접전 중 방패 방어 불가 | 가디언 Shield Block |
| **물 즉사** | 물에 빠지면 즉사 | **Void Death** (우주 공간) |
| **보충 시스템** | 집 점거 → 회복 | **Resupply** (시설 점거) |

### 5. 웨이브 기반 방어
- 침투정(Drop Pod) 도착 → 적 상륙 → 격퇴
- 시설 방어 성공 = 크레딧 획득

### 6. 절차적 생성
- 시드 기반 RNG
- 동일 시드 = 동일 맵

---

## TFR 변환 적용

| Bad North | The Fading Raven | 비고 |
|-----------|------------------|------|
| Commander | **Team Leader (팀장)** | 용어 통일 |
| Replenish | **Resupply (재보급)** | 시설에서 회복 |
| Flee | **Emergency Evac (긴급 귀환)** | Raven 셔틀 회수 |
| Boat | **Drop Pod/Shuttle (침투정)** | 적 수송선 |
| Island | **Station (정거장)** | 스테이지 |
| House | **Module (시설)** | 자원 건물 |
| Gold | **Credits (크레딧)** | 게임 내 화폐 |
| Viking Wave | **Storm Line** | 적 전선 |
| Slow Motion | **Tactical Mode** | Raven AI 지원 |

---

## TFR 추가 메카닉

| 메카닉 | 설명 |
|--------|------|
| **긴급 귀환** | Flee → Raven 기함 셔틀 파견 → 회수 |
| **구조 임무** | 깃발 섬 → RESCUE 노드 (탈출자 보호) |
| **시설 보너스** | 의료/무기고/통신탑/발전소 고유 효과 |
| **Raven 드론** | Scout/Flare/Resupply/Orbital Strike |
| **폭풍 스테이지** | 시야 제한 + 조명탄 필요 |
