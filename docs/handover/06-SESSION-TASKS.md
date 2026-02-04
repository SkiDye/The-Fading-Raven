# 6세션 작업 분할 지시서

> **목표**: Bad North 레퍼런스 기반 누락 기능 구현
> **기준 문서**: `MISSING-FEATURES-ANALYSIS.md`, `SCENE-BY-SCENE-ANALYSIS.md`
> **플랫폼**: 웹 프로토타입 (Godot 이관 전 완성)

---

## Session 1: 코어 시스템 + GDD 보완

### 목표
Tactical Mode 완성 및 GDD 누락 항목 문서화

### 작업 항목

| # | 작업 | 파일 | 우선순위 |
|---|------|------|----------|
| 1.1 | **GDD UI 섹션 추가** - 녹색 선택 아이콘, 3버튼 명령, 웨이브 화살표 명세 | `game-design-document.md` | P0 |
| 1.2 | **Tactical Mode 자동 진입** - 크루 선택 시 자동 활성화 | `js/pages/battle.js` | P0 |
| 1.3 | **시간 감속 (~0.3배)** - Tactical Mode 진입 시 게임 속도 조절 | `js/core/game-loop.js` | P0 |
| 1.4 | **크루 선택 시 자동 슬로모션** - Bad North 핵심 UX | `js/pages/battle.js` | P0 |

### 완료 조건
- [ ] 크루 클릭 → 자동으로 0.3배 속도
- [ ] 크루 선택 해제 → 정상 속도 복귀
- [ ] GDD에 UI 명세 추가됨

### 참조
- `docs/references/bad-north/09-CONTROLS.md` §슬로우 모션
- `docs/game-design/game-design-document.md` §Tactical Mode

---

## Session 2: Raven 드론 시스템

### 목표
TFR 핵심 차별점인 Raven 드론 4가지 능력 구현

### 작업 항목

| # | 작업 | 파일 | 우선순위 |
|---|------|------|----------|
| 2.1 | **Raven HUD 버튼 4개** - Scout/Flare/Resupply/Orbital Strike | `js/components/hud.js` | P0 |
| 2.2 | **Scout (정찰)** - 다음 웨이브 구성 미리보기 UI | `js/core/wave-system.js` | P0 |
| 2.3 | **Flare (조명탄)** - 폭풍 스테이지 시야 확보 (10초) | `js/core/combat-mechanics.js` | P1 |
| 2.4 | **Resupply (긴급 보급)** - 1팀 즉시 HP 회복 | `js/core/combat-mechanics.js` | P0 |
| 2.5 | **Orbital Strike (궤도 폭격)** - 지정 타일 고데미지 | `js/core/combat-mechanics.js` | P1 |
| 2.6 | **시설 보너스 시스템** - 의료/무기고/통신탑/발전소 효과 | `js/core/station-system.js` | P0 |

### 완료 조건
- [ ] HUD에 Raven 버튼 4개 표시
- [ ] 각 능력 사용 횟수 제한 동작
- [ ] 시설별 보너스 효과 적용

### 참조
- `docs/handover/03-GDD-ENHANCEMENTS.md` §Raven 드론 시스템
- `docs/handover/03-GDD-ENHANCEMENTS.md` §시설 보너스

---

## Session 3: 전투 메카닉 완성

### 목표
Resupply/Emergency Evac 시스템 완전 구현

### 작업 항목

| # | 작업 | 파일 | 우선순위 |
|---|------|------|----------|
| 3.1 | **Resupply 시간 공식** - `2초 × 손실 분대원 수` | `js/core/combat-mechanics.js` | P0 |
| 3.2 | **Resupply 중 명령 불가** - 완전 락 상태 | `js/pages/battle.js` | P0 |
| 3.3 | **Resupply 취소 불가** - 시작하면 끝까지 | `js/core/combat-mechanics.js` | P0 |
| 3.4 | **Resupply 중 시설 파괴 → 영구 손실** | `js/core/combat-mechanics.js` | P1 |
| 3.5 | **Emergency Evac 버튼** - 셔틀 아이콘 HUD | `js/components/hud.js` | P0 |
| 3.6 | **Emergency Evac 연출** - 셔틀 하강/탑승/이륙 | `js/core/combat-mechanics.js` | P1 |
| 3.7 | **지휘관 무적 조건** - 병사 1명+ 생존 시 | `js/core/combat-mechanics.js` | P0 |

### 완료 조건
- [ ] Resupply 시 정확한 시간 계산
- [ ] Resupply 중 다른 명령 차단
- [ ] Emergency Evac 클릭 → 크레딧 0 + 크루 생존

### 참조
- `docs/references/bad-north/01-CORE-MECHANICS.md` §보충 시스템
- `docs/references/bad-north/01-CORE-MECHANICS.md` §도주

---

## Session 4: UI/HUD 구현

### 목표
Bad North 스타일 명령 버튼 및 선택 피드백 구현

### 작업 항목

| # | 작업 | 파일 | 우선순위 |
|---|------|------|----------|
| 4.1 | **녹색 원형 선택 아이콘** - 깃발 위 표시 | `js/components/hud.js` | P0 |
| 4.2 | **Move 버튼 (핀 아이콘)** - 이동 명령 | `js/components/hud.js` | P0 |
| 4.3 | **Skill 버튼 (스킬 아이콘)** - 스킬 사용 | `js/components/hud.js` | P0 |
| 4.4 | **Resupply 버튼 (십자+집 아이콘)** - 회복 명령 | `js/components/hud.js` | P0 |
| 4.5 | **웨이브 방향 화살표** - 화면 가장자리 표시 | `js/components/hud.js` | P0 |
| 4.6 | **"FINAL WAVE" 텍스트** - 마지막 웨이브 알림 | `js/components/hud.js` | P1 |
| 4.7 | **이동 가능 타일 핀 마커** - 흰색 핀 표시 | `js/core/tile-grid.js` | P1 |

### 완료 조건
- [ ] 크루 선택 시 녹색 아이콘 표시
- [ ] 3개 명령 버튼 동작
- [ ] 웨이브 접근 방향 화살표 표시

### 참조
- `docs/references/bad-north/08-UI-UX.md` §명령 버튼
- `docs/references/bad-north/08-UI-UX.md` §선택 피드백
- `docs/implementation/SCENE-BY-SCENE-ANALYSIS.md` §전투 화면

---

## Session 5: 클래스 스킬 + 시각 효과

### 목표
Engineer/Bionic 스킬 및 전투 이펙트 구현

### 작업 항목

| # | 작업 | 파일 | 우선순위 |
|---|------|------|----------|
| 5.1 | **Engineer 터렛 배치** - Deploy Turret 스킬 | `js/core/skill-system.js` | P1 |
| 5.2 | **터렛 자동 공격 AI** - 가장 가까운 적 타겟 | `js/core/turret-system.js` | P1 |
| 5.3 | **Bionic Blink 스킬** - 순간이동 | `js/core/skill-system.js` | P1 |
| 5.4 | **비교전 적 공격 시 2배 데미지** - Bionic 특수 | `js/core/combat-mechanics.js` | P1 |
| 5.5 | **피 스플래터** - 지면 지속 효과 | `js/core/effects.js` | P1 |
| 5.6 | **시체 지속** - 전투 끝까지 유지 | `js/core/effects.js` | P1 |
| 5.7 | **침투선 물결 효과** - 접근 시 wake | `js/core/effects.js` | P2 |

### 완료 조건
- [ ] Engineer 터렛 배치 및 자동 공격
- [ ] Bionic 순간이동 + 암살 보너스
- [ ] 피/시체 전투 중 지속

### 참조
- `docs/handover/03-GDD-ENHANCEMENTS.md` §신규 클래스
- `docs/references/bad-north/10-VISUAL.md` §전투 이펙트

---

## Session 6: 캠페인 + 폴리시

### 목표
월드맵 UI 완성 및 폴리시 작업

### 작업 항목

| # | 작업 | 파일 | 우선순위 |
|---|------|------|----------|
| 6.1 | **Next Turn 버튼** - 월드맵 턴 진행 | `js/pages/sector-map.js` | P0 |
| 6.2 | **점선 (사라질 섬 예고)** - 다음 휴식 시 소멸 노드 | `js/pages/sector-map.js` | P1 |
| 6.3 | **검은 화살 (적 수량 힌트)** - 노드별 난이도 표시 | `js/pages/sector-map.js` | P1 |
| 6.4 | **카메라 회전 버튼 (90도 스냅)** - 전투 화면 | `js/pages/battle.js` | P2 |
| 6.5 | **Q/E 카메라 회전** - 키보드 단축키 | `js/pages/battle.js` | P1 |
| 6.6 | **폭풍 스테이지 Fog of War** - 시야 제한 | `js/core/combat-mechanics.js` | P2 |
| 6.7 | **숫자 키 1-4 분대 선택** - 단축키 | `js/pages/battle.js` | P2 |

### 완료 조건
- [ ] Next Turn 클릭 → 전선 전진 + 섬 소멸
- [ ] 점선/화살표로 노드 정보 표시
- [ ] Q/E로 카메라 회전 동작

### 참조
- `docs/references/bad-north/07-PROGRESSION.md` §턴 시스템
- `docs/references/bad-north/09-CONTROLS.md` §카메라

---

## 세션별 예상 작업량

| 세션 | 작업 수 | 핵심 기능 | 복잡도 |
|------|--------|----------|--------|
| 1 | 4 | Tactical Mode | ⭐⭐ |
| 2 | 6 | Raven 드론 | ⭐⭐⭐ |
| 3 | 7 | Resupply/Evac | ⭐⭐⭐ |
| 4 | 7 | UI/HUD | ⭐⭐ |
| 5 | 7 | 클래스/이펙트 | ⭐⭐⭐ |
| 6 | 7 | 캠페인/폴리시 | ⭐⭐ |

---

## 의존성 그래프

```
Session 1 (Tactical Mode)
    ↓
Session 2 (Raven) ←→ Session 3 (전투 메카닉)
    ↓                    ↓
Session 4 (UI/HUD) ←────┘
    ↓
Session 5 (클래스/이펙트)
    ↓
Session 6 (캠페인/폴리시)
```

**병렬 가능**: Session 2 + Session 3 (서로 독립적)

---

## 공통 참조 문서

| 용도 | 경로 |
|------|------|
| 누락 기능 목록 | `docs/implementation/MISSING-FEATURES-ANALYSIS.md` |
| 화면별 비교 | `docs/implementation/SCENE-BY-SCENE-ANALYSIS.md` |
| Bad North 레퍼런스 | `docs/references/bad-north/*.md` |
| TFR GDD | `docs/game-design/game-design-document.md` |
| TFR 차별점 | `docs/handover/03-GDD-ENHANCEMENTS.md` |

---

## 세션 시작 시 필독

각 세션 시작 전 반드시 읽을 문서:

1. **이 문서** - 해당 세션 작업 항목 확인
2. **MISSING-FEATURES-ANALYSIS.md** - 상세 요구사항
3. **해당 Bad North 레퍼런스** - 구현 기준
4. **관련 소스 파일** - 현재 구현 상태

---

*작성일: 2026-02-05*
