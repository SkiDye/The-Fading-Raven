# The Fading Raven - 인수인계 총정리

> **최종 업데이트**: 2026-02-05
> **현재 상태**: Godot 4.x 3D 구현 Phase 1-4 완료 + 레거시 정리 완료

---

## 프로젝트 개요

**장르**: 실시간 전술 로그라이트 (Bad North 영감)
**테마**: 우주 SF - 정거장 방어
**엔진**: Godot 4.x (3D)

### 핵심 컨셉
> "희미해져 가는 성간 네트워크에서, Raven 드론과 함께 마지막 정거장들을 지켜라"

---

## 현재 진행 상황

### 3D 구현 Phase 진행률

| Phase | 내용 | 상태 |
|-------|------|------|
| **Phase 1** | 3D 전투 엔티티 | ✅ 완료 |
| **Phase 2** | 3D 섹터 맵 | ✅ 완료 |
| **Phase 2.5** | 팀장 관리 & 업그레이드 | ✅ 완료 |
| **Phase 3** | 정거장 미리보기 & 분대 선택 | ✅ 완료 |
| **Phase 4** | 화면 전환 & 이펙트 | ✅ 완료 |

### 구현 완료 항목

#### 3D 엔티티
- `CrewSquad3D.tscn/.gd` - 플레이어 분대 (GLB 모델 연동)
- `EnemyUnit3D.tscn/.gd` - 적 유닛 (GLB 모델 연동)
- `Facility3D.tscn/.gd` - 시설 (GLB 모델 연동)
- `DropPod3D.tscn/.gd` - 적 침투정 (착륙 애니메이션)

#### 3D 씬
- `Battle3D.tscn` - 3D 전투 씬
- `SectorMap3D.tscn` - 3D 섹터 맵 (노드 시각화, Storm Line)
- `Campaign3D.tscn/.gd` - 캠페인 컨트롤러
- `StationPreview3D.tscn/.gd` - 정거장 3D 미리보기 (회전/줌)
- `SquadSelection.tscn/.gd` - 분대 선택 (최대 4팀)

#### Phase 2.5 업그레이드 시스템
- `UpgradeScreen.tscn/.gd` - Bad North 스타일 업그레이드 화면
  - 좌측: 팀장 목록 (원형 초상화, 클래스 아이콘)
  - 우측: 클래스 선택/등급 업그레이드/스킬/장비
  - U 키: 섹터 맵에서 업그레이드 화면 열기
  - 팀장 슬롯 클릭: 해당 팀장 업그레이드

#### Phase 4 신규 구현
- `NewGameSetup.tscn/.gd` - 새 게임 설정 화면
- `BattleResult.tscn/.gd` - 전투 결과 화면
- `Turret3D.tscn/.gd` - Engineer 터렛 엔티티
- `Projectile3D.tscn/.gd` - 투사체 엔티티
- `Explosion3D.tscn/.gd` - 폭발 이펙트
- `HitEffect3D.tscn/.gd` - 피격 이펙트
- `FloatingText3D.tscn/.gd` - 데미지 숫자 표시
- `SceneTransition.gd` - 씬 전환 시스템 (autoload)

#### 렌더링 시스템
- `IsometricCamera.gd` - 아이소메트릭 카메라 (35.264° X, 45° Y)
- `BattleMap3D.gd` - 3D 타일맵 렌더링
- `PlacementPhase.gd` - 전투 전 배치 단계

---

## Godot 프로젝트 구조

```
godot/
├── scenes/
│   ├── Main.tscn               # 게임 매니저
│   ├── battle/
│   │   ├── Battle3D.tscn       ✅ 3D 전투 씬
│   │   └── BattleResult.tscn   ✅ 전투 결과
│   └── campaign/
│       ├── Campaign3D.tscn     ✅ 캠페인 컨트롤러
│       ├── SectorMap3D.tscn    ✅ 3D 섹터 맵
│       ├── StationPreview3D.tscn ✅ 정거장 미리보기
│       ├── SquadSelection.tscn ✅ 분대 선택
│       └── NewGameSetup.tscn   ✅ 새 게임 설정
├── src/
│   ├── autoload/               # EventBus, GameState, Constants 등
│   ├── entities/
│   │   ├── crew/
│   │   │   ├── CrewSquad3D.tscn ✅
│   │   │   └── CrewSquad3D.gd  ✅
│   │   ├── enemy/
│   │   │   ├── EnemyUnit3D.tscn ✅
│   │   │   └── EnemyUnit3D.gd  ✅
│   │   ├── facility/
│   │   │   ├── Facility3D.tscn ✅
│   │   │   └── Facility3D.gd   ✅
│   │   └── vehicle/
│   │       ├── DropPod3D.tscn  ✅
│   │       └── DropPod3D.gd    ✅
│   ├── rendering/
│   │   ├── IsometricCamera.gd  ✅
│   │   ├── BattleMap3D.gd      ✅
│   │   └── IsometricUtils.gd   ✅
│   ├── scenes/
│   │   ├── Battle3DScene.gd    ✅
│   │   ├── SectorMap3DScene.gd ✅
│   │   ├── StationPreview3DScene.gd ✅
│   │   └── SquadSelectionScene.gd ✅
│   ├── systems/
│   │   ├── campaign/           # SectorGenerator, StationGenerator
│   │   ├── combat/             # BattleController, PlacementPhase
│   │   └── wave/               # WaveGenerator, WaveManager
│   └── ui/                     # 2D UI 컴포넌트
└── assets/
    └── models/
        ├── crews/              # guardian.glb + 텍스처
        ├── enemies/            # rusher.glb + 텍스처
        ├── facilities/         # residential_sml.glb + 텍스처
        └── vehicles/           # boarding_pod.glb + 텍스처
```

---

## 게임 플로우

```
[MainMenu] (2D)
    ↓ NEW GAME
[NewGameSetup] (2D)
    - 난이도 선택
    - 시작 팀장 2명 선택
    ↓ START
[SectorMap3D] (3D) ←────────────────────────┐
    │                                        │
    ├── U키 또는 팀장 클릭 ──→ [UpgradeScreen]
    │                              ↓ BACK    │
    ├── 노드 클릭                            │
    │   ↓                                    │
    │   [StationPreview3D] (3D)              │
    │       - A/D 또는 드래그: 회전          │
    │       - R/F 또는 휠: 줌                │
    │   ↓ CONTINUE                           │
    │   [SquadSelection] (2D)                │
    │       - 최대 4팀 선택                  │
    │       - 1-4 키: 슬롯에서 제거          │
    │   ↓ DEPLOY                             │
    │   [Battle3D] (3D)                      │
    │       - 배치 → 웨이브 → 전투          │
    │   ↓ 승리                               │
    │   [BattleResult] (2D)                  │
    │       - 획득 크레딧, 새 팀장/장비      │
    │   ↓ CONTINUE                           │
    └───────────────────────────────────────┘
```

---

## 핵심 시스템 설명

### 1. SectorGenerator
- DAG(방향 비순환 그래프) 기반 섹터 맵 생성
- 노드 타입: START, BATTLE, STORM, BOSS, RESCUE, REST, GATE 등
- Storm Line (적 전선) 전진 시스템

### 2. StationGenerator
- BSP(Binary Space Partitioning) 기반 정거장 레이아웃 생성
- 시설 배치, 진입점(Airlock) 생성
- 타일 타입: FLOOR, WALL, FACILITY, AIRLOCK, ELEVATED 등

### 3. 전투 시스템
- Bad North 스타일 실시간 전술
- 클래스: Guardian(실드), Sentinel(랜스), Ranger(사격), Engineer(터렛), Bionic(암살)
- Tactical Mode: 분대 선택 시 자동 슬로우모션

### 4. Raven 드론 (TFR 고유)
- Scout: 다음 웨이브 미리보기
- Flare: 폭풍 스테이지 시야 확보
- Resupply: 긴급 HP 회복
- Orbital Strike: 지정 타일 폭격

---

## 남은 작업 (폴리시)

### 레거시 정리 ✅ 완료
| 항목 | 설명 | 상태 |
|------|------|------|
| 레거시 2D 씬 정리 | Battle.tscn, sector_map.tscn 등 삭제 | ✅ 완료 |
| 레거시 autoload 정리 | godot/autoload/ 폴더 삭제 | ✅ 완료 |
| 레거시 scripts 정리 | godot/scripts/ 폴더 삭제 | ✅ 완료 |
| 레거시 tests 정리 | godot/tests/ 폴더 삭제 | ✅ 완료 |

### 프로시저럴 3D 메시 ✅ 완료
| 항목 | 설명 | 상태 |
|------|------|------|
| CrewSquad3D | 6개 클래스별 프로시저럴 메시 | ✅ 완료 |
| EnemyUnit3D | 9개 적 타입별 프로시저럴 메시 | ✅ 완료 |
| Facility3D | 5개 시설 타입별 프로시저럴 메시 | ✅ 완료 |
| DropPod3D | 침투정 프로시저럴 메시 | ✅ 완료 |

### 통합 테스트
| 항목 | 설명 |
|------|------|
| 전체 플로우 테스트 | 메뉴 → 섹터맵 → 전투 → 결과 |
| 밸런스 조정 | 데미지/체력/비용 등 |
| 버그 수정 | 발견된 이슈 수정 |

---

## 핵심 문서 위치

| 문서 | 경로 | 설명 |
|------|------|------|
| **3D 구현 계획** | `docs/3D-IMPLEMENTATION-PLAN.md` | Phase별 상세 계획 |
| GDD | `docs/game-design/game-design-document.md` | 게임 디자인 문서 |
| Bad North 레퍼런스 | `docs/references/bad-north/` | 레퍼런스 분석 |
| 공유 상태 정의 | `docs/implementation/SHARED-STATE.md` | 데이터 구조 |
| 3D 에셋 프롬프트 | `docs/assets/3D-ASSET-PROMPTS.md` | AI 모델 생성용 |

---

## Git 정보

- **브랜치**: `main`
- **원격**: `https://github.com/SkiDye/The-Fading-Raven.git`
- **최근 커밋**: `feat: 3D 구현 Phase 1-3 완료`

---

## 용어 정의 (Bad North → TFR)

| Bad North | TFR |
|-----------|-----|
| Commander | **Team Leader (팀장)** |
| Island | **Station (정거장)** |
| House | **Facility (시설)** |
| Gold | **Credits (크레딧)** |
| Vikings | **Pirates/Storm Creatures** |
| Boat | **Drop Pod (침투정)** |
| Slow Motion | **Tactical Mode** |
| Flee | **Emergency Evac (긴급 귀환)** |
| Replenish | **Resupply (재보급)** |
| Campaign Map | **Sector Map (섹터 맵)** |
| Viking Wave | **Storm Line** |

---

## 빠른 시작 가이드

### 1. Godot에서 프로젝트 열기
```
godot/project.godot
```

### 2. 3D 전투 테스트
- `scenes/battle/Battle3D.tscn` 씬 열기
- F5로 실행

### 3. 3D 섹터 맵 테스트
- `scenes/campaign/Campaign3D.tscn` 씬 열기
- F5로 실행

### 4. 메인 게임 실행
- `scenes/Main.tscn` 또는 F5
- 메인 메뉴에서 시작

---

## 주의사항

1. **Bad North 메카닉 유지** - 검증된 시스템을 기반으로 구현
2. **TFR 고유 시스템** - Raven 드론이 핵심 차별점
3. **시드 기반 RNG** - 동일 시드 = 동일 결과 보장
4. **영구 사망** - 로그라이트 긴장감의 핵심
5. **GLB 모델 규격** - 1유닛 = 1타일, 바닥 중앙 원점, -Z 전방

---

*인수인계 문서 v3.0 - Phase 1-4 + 2.5 완료*
