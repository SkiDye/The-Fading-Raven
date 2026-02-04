# The Fading Raven - 3D 구현 계획

## 용어 통일 (Bad North → TFR)

| Bad North | TFR | 설명 |
|-----------|-----|------|
| Commander | **Team Leader (팀장)** | 분대 지휘관 |
| Island | **Station (정거장)** | 스테이지 |
| House | **Facility/Module (시설)** | 방어 대상, 크레딧 획득 |
| Gold | **Credits (크레딧)** | 게임 내 화폐 |
| Vikings | **Pirates/Storm Creatures** | 적 세력 |
| Boat | **Drop Pod (침투정)** | 적 수송선 |
| Slow Motion | **Tactical Mode (전술 모드)** | Raven AI 지원 |
| Flee | **Emergency Evac (긴급 귀환)** | Raven 셔틀 회수 |
| Replenish | **Resupply (재보급)** | 시설에서 크루 회복 |
| Campaign Map | **Sector Map (섹터 맵)** | 캠페인 진행 맵 |
| Viking Wave | **Storm Line** | 적 전선 |

---

## 화면 흐름 분석 (Bad North 기준 → TFR 적용)

### 핵심 화면 순서
```
[메인 메뉴]
    ↓
[새 게임 설정] - 난이도, 시작 특성/장비
    ↓
[섹터 맵] - 정거장 노드 선택, Storm Line 전진
    ↓
[정거장 미리보기] - 3D 지형 확인, 카메라 회전
    ↓
[분대 선택] - "SELECT YOUR SQUADS", 최대 4팀
    ↓
[전투] - 실시간 배치, Tactical Mode
    ↓
[전투 결과] - 획득 크레딧, 새 팀장, 장비
    ↓
[업그레이드 화면] - 클래스 선택, 스킬 업그레이드
    ↓
(반복 → 최종 게이트 도달 시 엔딩)
```

### TFR 핵심 특징
1. **실시간 배치**: 전투 시작과 동시에 적 침투정 접근, 배치 시간 제한 없음
2. **Tactical Mode**: 분대 선택 시 자동 발동 (Raven AI 지원), Space 홀드로 수동 발동
3. **정거장 미리보기**: 전투 전 3D 지형을 회전하며 확인 가능
4. **분대 선택 화면**: 별도 UI로 참전 분대 선택 (최대 4팀)

---

## 현재 씬 구조 분석

### 레거시 vs 현재 버전
| 용도 | 레거시 | 현재 버전 | 비고 |
|------|--------|-----------|------|
| 메인 메뉴 | scenes/main_menu.tscn | src/ui/menus/MainMenu.tscn | 현재 버전 사용 |
| 설정 | scenes/settings.tscn | src/ui/menus/SettingsMenu.tscn | 현재 버전 사용 |
| 섹터 맵 | scenes/sector_map.tscn | scenes/campaign/Campaign.tscn | 현재 버전 사용 |
| 업그레이드 | scenes/upgrade.tscn | src/ui/campaign/UpgradeScreen.tscn | 현재 버전 사용 |
| 전투 (2D) | scenes/battle.tscn | scenes/battle/Battle.tscn | 둘 다 2D |
| 전투 (3D) | - | scenes/battle/Battle3D.tscn | 신규 구현 |

### 3D 이관 대상 씬
```
[필수 3D 이관]
├── Battle (전투) ✅ Battle3D.tscn 구현 완료
├── Sector Map (섹터 맵) - 3D 섹터맵으로 전환
├── Station Preview (정거장 미리보기) - 신규, 3D 지형 프리뷰
└── Squad Selection (분대 선택) - 신규, 팀장 선택 UI

[UI 전용 (2D 유지)]
├── MainMenu - 2D Control 유지
├── SettingsMenu - 2D Control 유지
├── PauseMenu - 2D Control 유지
├── UpgradeScreen - 2D Control 유지
├── GameOver - 2D Control 유지
├── Victory - 2D Control 유지
└── BattleHUD - 2D CanvasLayer 유지

[엔티티 (3D 이관)]
├── CrewSquad3D - 신규, GLB 모델 기반
├── EnemyUnit3D - 신규, GLB 모델 기반
├── Facility3D - 신규, GLB 모델 기반
├── Turret3D - 신규, GLB 모델 기반
├── Projectile3D - 신규
└── DropPod3D - 신규 (침투정)

[이펙트 (3D 이관)]
├── Explosion3D - 3D 파티클
├── HitEffect3D - 3D 파티클
└── FloatingText3D - 3D 빌보드 텍스트
```

---

## Phase 1: 3D 전투 씬 완성 (현재 단계)

### 1.1 Battle3D.tscn 구조 확정 ✅
```
Battle3D (Node3D)
├── WorldEnvironment
├── DirectionalLight3D (Main)
├── DirectionalLight3D (Fill)
├── IsometricCamera (Camera3D)
├── BattleMap3D (Node3D)
│   ├── Tiles (타일 메시)
│   ├── Entities (유닛/시설)
│   └── Effects (이펙트)
├── BattleController (Node)
├── PlacementPhase (Node)
└── UI (CanvasLayer)
    └── BattleHUD (Control)
```

### 1.2 3D 엔티티 씬 생성
| 파일 | 상태 | 설명 |
|------|------|------|
| `src/entities/crew/CrewSquad3D.tscn` | ✅ 완료 | GLB 모델 + AnimationPlayer |
| `src/entities/enemy/EnemyUnit3D.tscn` | ✅ 완료 | GLB 모델 + AI |
| `src/entities/facility/Facility3D.tscn` | ✅ 완료 | GLB 모델 + 체력바 |
| `src/entities/turret/Turret3D.tscn` | 🔴 TODO | GLB 모델 + 회전 |
| `src/entities/projectile/Projectile3D.tscn` | 🔴 TODO | 3D 메시 + 트레일 |
| `src/entities/vehicle/DropPod3D.tscn` | ✅ 완료 | GLB 모델 + 애니메이션 |

### 1.3 3D 이펙트 씬 생성
| 파일 | 상태 | 설명 |
|------|------|------|
| `src/effects/Explosion3D.tscn` | 🔴 TODO | GPUParticles3D |
| `src/effects/HitEffect3D.tscn` | 🔴 TODO | GPUParticles3D |
| `src/effects/FloatingText3D.tscn` | 🔴 TODO | Label3D 빌보드 |

---

## Phase 2: 3D 섹터 맵

### 2.1 SectorMap3D.tscn 신규 생성
TFR 스타일의 3D 섹터맵:
- **배경**: 우주/별 배경 (Environment)
- **노드**: 3D 정거장 아이콘 (미니어처)
- **연결선**: 3D 라인 또는 튜브 메시
- **Storm Line**: 반투명 벽 또는 파티클

```
SectorMap3D (Node3D)
├── WorldEnvironment (우주 배경)
├── Camera3D (자유 이동)
├── Nodes (Node3D)
│   ├── StationNode3D (각 노드)
│   │   ├── MeshInstance3D (정거장 미니어처)
│   │   ├── Label3D (노드 이름)
│   │   └── ClickArea (Area3D)
│   └── ...
├── Connections (Node3D)
│   └── PathMesh (각 연결선)
├── StormLine (Node3D)
│   └── StormWall (반투명 메시)
└── UI (CanvasLayer)
    └── SectorMapHUD (Control)
        ├── TopBar
        │   ├── PauseButton (우상단 ||)
        │   └── CreditsDisplay (크레딧 아이콘 + 숫자)
        ├── TeamPanel (하단)
        │   ├── TeamLeaderPortraits (HBox)
        │   │   ├── TeamSlot × 최대 5
        │   │   │   ├── Portrait (원형, 색상 배경)
        │   │   │   ├── ClassIcon (클래스 아이콘)
        │   │   │   ├── FatigueBar (피로도)
        │   │   │   └── TraitIcon (특성 아이콘)
        │   │   └── ...
        │   └── TeamCount ("4/4 Teams Available")
        ├── NextTurnButton ("Next Turn" + Y키)
        └── NodeInfo (선택된 노드 정보)
            ├── StationName
            ├── EnemyIcons (적 유형)
            ├── RewardIcons (보상)
            └── EnterButton
```

### 2.2 섹터 맵 팀장 표시 (레퍼런스 08-UI-UX.md 기준)

| 요소 | 위치 | 설명 |
|------|------|------|
| 팀장 초상화 | 하단 | 원형, 색상 배경 |
| 크루 배경 | 초상화 뒤 | 클래스별 크루 실루엣 |
| 피로도 바 | 초상화 위 | 전투 후 회복 필요 시 |
| 특성 아이콘 | 초상화 옆 | 배너 스타일 |
| 팀 수 | 하단 텍스트 | "4/4 Teams Available" |

### 2.3 노드 상태 표시 (색상)

| 색상 | 의미 |
|------|------|
| 빨간색 | 적 점령 (미방문) |
| 노란색 | 현재 선택됨 |
| 청록색/회색 | 방문 가능 |
| 어두움 | 클리어됨 또는 접근 불가 |

### 2.4 노드 아이콘 표시

| 아이콘 | TFR 노드 타입 | 의미 |
|--------|--------------|------|
| 🏢 정거장 | BATTLE | 일반 전투 (시설 수 = 보상) |
| 🚩 깃발 | RESCUE | 새 팀장 영입 가능 |
| ❓ 물음표 | SALVAGE | 장비 획득 가능 |
| 📦 상자 | DEPOT | 무료 장비 보급 |
| 🌀 폭풍 | STORM | 시야 제한 + 조명탄 필요 |
| 💀 해골 | BOSS | 보스 전투 |
| ⛽ 휴식 | REST | 회복 노드 |
| 🚪 게이트 | GATE | 섹터 종료/탈출 |

### 2.5 노드 타입별 3D 모델
| 노드 타입 | 3D 모델 | 설명 |
|-----------|---------|------|
| BATTLE | 정거장 미니어처 | 기본 전투 노드 |
| RESCUE | 조난선 미니어처 | 구조 미션 |
| SALVAGE | 잔해 미니어처 | 탐색 이벤트 |
| DEPOT | 보급 기지 미니어처 | 무료 장비 |
| STORM | 폭풍 구름 | 특수 스테이지 |
| BOSS | 대형 정거장 | 보스 전투 |
| REST | 휴식처 미니어처 | 회복 노드 |
| GATE | 게이트 미니어처 | 섹터 종료 |

---

## Phase 2.5: 팀장 관리 & 업그레이드 전환

### 2.5.1 섹터 맵 → 업그레이드 화면 전환

**Bad North 방식** (레퍼런스 08-UI-UX.md 기준):
- 캠페인 맵에서 **커맨더 초상화 클릭** → 업그레이드 화면
- 게임패드: **지정 버튼** 프레스로 업그레이드 메뉴
- Switch 휴대모드: **터치**로 접근

**TFR 구현**:
```
[섹터 맵 (SectorMap3D)]
    │
    ├── 팀장 초상화 클릭 → [UpgradeScreen]
    │   └── 해당 팀장 자동 선택
    │
    ├── UPGRADE 버튼 클릭 → [UpgradeScreen]
    │   └── 첫 번째 팀장 선택
    │
    └── 키보드 단축키 (U) → [UpgradeScreen]
```

### 2.5.2 업그레이드 화면 구조 (UpgradeScreen.tscn 개선)

```
UpgradeScreen (Control)
├── Background (반투명 오버레이 또는 별도 배경)
├── LeftPanel (팀장 목록)
│   ├── TeamLeaderList (VBox)
│   │   ├── TeamLeaderCard × N
│   │   │   ├── Portrait (원형)
│   │   │   ├── Name
│   │   │   ├── ClassIcon
│   │   │   ├── StatusText ("Available - Ready for action")
│   │   │   └── SelectionHighlight
│   │   └── ...
│   └── CreditsDisplay
├── RightPanel (선택된 팀장 상세)
│   ├── TeamLeaderInfo
│   │   ├── LargePortrait
│   │   ├── Name + Type ("Team Leader")
│   │   ├── TraitBanner (특성)
│   │   └── Stats (킬 수, 손실 수)
│   ├── ClassSelection (Militia일 때)
│   │   ├── GuardianCard (실드 아이콘, 6크레딧)
│   │   ├── SentinelCard (랜스 아이콘, 6크레딧)
│   │   ├── RangerCard (라이플 아이콘, 6크레딧)
│   │   ├── EngineerCard (렌치 아이콘, 6크레딧)
│   │   └── BionicCard (블레이드 아이콘, 6크레딧)
│   ├── UpgradeSlots (클래스 선택 후)
│   │   ├── ClassUpgrade (Veteran 12, Elite 20크레딧)
│   │   └── SkillUpgrades (Lv1: 7, Lv2: 10, Lv3: 14크레딧)
│   └── EquipmentSlot (장착된 장비 + 업그레이드)
└── BottomBar
    ├── BackButton ("BACK" → 섹터 맵)
    └── ConfirmButton (선택 확정)
```

### 2.5.3 업그레이드 비용 표 (TFR 적용)

| 항목 | 비용 (크레딧) |
|------|--------------|
| 클래스 선택 (Militia → Standard) | **6** |
| Veteran 업그레이드 | **12** |
| Elite 업그레이드 | **20** |
| 스킬 Lv1 | **7** |
| 스킬 Lv2 | **10** |
| 스킬 Lv3 | **14** |
| 장비 Lv2 | **8** |
| 장비 Lv3 | **14-16** |

### 2.5.4 공유 크레딧 시스템 (GDD 기준)

| 설정 | 값 |
|------|-----|
| 크레딧 풀 | **공유** (팀장별 분리 없음) |
| 시설 방어 보상 | 시설 크기별 차등 (1/2/3 크레딧) |
| 완벽 방어 보너스 | +2 크레딧 |

---

## Phase 3: 정거장 미리보기 & 분대 선택

### 3.1 StationPreview3D.tscn (정거장 미리보기)
전투 전 정거장 3D 지형 확인:
```
StationPreview3D (Node3D)
├── WorldEnvironment
├── Camera3D (회전 가능)
├── StationPreview (Node3D)
│   ├── TileMeshes (지형)
│   ├── FacilityPreviews (시설 위치)
│   └── SpawnPointMarkers (침투정 진입로)
├── EnemyInfoPanel (적 정보)
└── UI (CanvasLayer)
    ├── StationInfo (정거장 정보)
    ├── RewardPreview (보상 미리보기)
    └── ConfirmButton (전투 시작)
```

### 3.2 SquadSelection.tscn (분대 선택)
"SELECT YOUR SQUADS" 화면:
```
SquadSelection (Control)
├── Background (우주 배경 또는 3D 뷰포트)
├── Title ("SELECT YOUR SQUADS")
├── SelectedTeams (HBoxContainer)
│   ├── TeamSlotLarge (최대 4개)
│   │   ├── Portrait (팀장 초상화)
│   │   ├── ClassIcon (클래스 아이콘)
│   │   ├── HealthBar (체력)
│   │   └── RemoveButton (X 버튼)
│   └── ...
├── AvailableTeams (선택 가능한 팀장 목록)
├── DeployButton ("DEPLOY")
└── BackButton ("BACK")
```

---

## Phase 4: 화면 전환 흐름

### 4.1 완성된 게임 플로우
```
[MainMenu.tscn] (2D)
    ↓ NEW GAME
[NewGameSetup.tscn] (2D) - 신규
    - 난이도 선택
    - 시작 팀장 선택 (2명)
    - 시작 장비/특성 선택
    ↓ START
[SectorMap3D.tscn] (3D) ←──────────────────────────┐
    │                                              │
    ├── 팀장 초상화 클릭 ────→ [UpgradeScreen] ───┘
    │   (또는 U키 / UPGRADE 버튼)      │
    │                                  └─ BACK 버튼
    │
    ├── Next Turn ────→ Storm Line 전진 + 턴 종료
    │
    └── 노드 클릭
          ↓
[StationPreview3D.tscn] (3D)
    - 3D 지형 회전 확인 (A/D 또는 드래그)
    - 적 유형/보상 미리보기
    - R/F 줌 인/아웃
    ↓ CONTINUE (또는 BACK → 섹터 맵)
[SquadSelection.tscn] (2D/3D 혼합)
    - 최대 4팀 선택 (RESCUE 노드는 3팀 + 현지 팀장)
    - 초상화 위 X 클릭으로 제거
    - 1-4 키로 순서 지정
    ↓ DEPLOY (또는 BACK → 미리보기)
[Battle3D.tscn] (3D)
    - 실시간 배치 + Tactical Mode
    - 분대 선택 시 자동 Tactical Mode
    - Space 홀드로 수동 Tactical Mode
    ↓ 승리/패배
[BattleResult.tscn] (2D) - 신규
    - 정거장 이름 + "Victory" 태그
    - 획득 크레딧 표시
    - 새 팀장/장비 획득 시 표시
    ↓ CONTINUE
[UpgradeScreen.tscn] (2D) ← 전투 후 자동 표시 (선택적)
    ↓ DONE
[SectorMap3D.tscn] (반복)
```

### 4.1.1 섹터 맵 상호작용 요약

| 입력 | 동작 |
|------|------|
| **노드 클릭** | 정거장 미리보기 (StationPreview3D) |
| **팀장 초상화 클릭** | 업그레이드 화면 (해당 팀장 선택) |
| **U 키** | 업그레이드 화면 |
| **Next Turn / Y 키** | 턴 종료 (Storm Line 전진) |
| **ESC / \|\| 버튼** | 일시정지 메뉴 |
| **WASD / 화살표** | 맵 스크롤 |
| **마우스 휠** | 줌 인/아웃 |

### 4.2 씬 전환 트랜지션
| 전환 | 효과 |
|------|------|
| 메뉴 → 섹터 맵 | 페이드 아웃/인 |
| 섹터 맵 → 미리보기 | 카메라 줌인 (3D 트랜지션) |
| 미리보기 → 전투 | 크로스페이드 |
| 전투 → 결과 | 슬로우 페이드 |
| 결과 → 섹터 맵 | 페이드 아웃/인 |

---

## 파일 구조 계획

```
godot/
├── scenes/
│   ├── Main.tscn                    # 게임 매니저 (유지)
│   ├── battle/
│   │   ├── Battle3D.tscn            ✅ 구현됨
│   │   └── BattleResult.tscn        🔴 신규
│   └── campaign/
│       ├── SectorMap3D.tscn         ✅ 구현됨
│       ├── Campaign3D.tscn          ✅ 구현됨
│       ├── StationPreview3D.tscn    ✅ 구현됨
│       ├── SquadSelection.tscn      ✅ 구현됨
│       └── NewGameSetup.tscn        🔴 신규
├── src/
│   ├── rendering/
│   │   ├── IsometricCamera.gd       ✅ 구현됨
│   │   ├── BattleMap3D.gd           ✅ 구현됨
│   │   ├── SectorMap3DRenderer.gd   🔴 신규
│   │   └── StationPreview3D.gd      🔴 신규
│   ├── entities/
│   │   ├── crew/
│   │   │   └── CrewSquad3D.tscn     ✅ 구현됨
│   │   ├── enemy/
│   │   │   └── EnemyUnit3D.tscn     ✅ 구현됨
│   │   ├── facility/
│   │   │   └── Facility3D.tscn      ✅ 구현됨
│   │   ├── turret/
│   │   │   └── Turret3D.tscn        🔴 신규
│   │   ├── projectile/
│   │   │   └── Projectile3D.tscn    🔴 신규
│   │   └── vehicle/
│   │       └── DropPod3D.tscn       ✅ 구현됨
│   ├── effects/
│   │   ├── Explosion3D.tscn         🔴 신규
│   │   ├── HitEffect3D.tscn         🔴 신규
│   │   └── FloatingText3D.tscn      🔴 신규
│   ├── scenes/
│   │   ├── Battle3DScene.gd         ✅ 구현됨
│   │   ├── SectorMap3DScene.gd      ✅ 구현됨
│   │   ├── StationPreview3DScene.gd ✅ 구현됨
│   │   └── SquadSelectionScene.gd   ✅ 구현됨
│   └── systems/
│       └── combat/
│           └── PlacementPhase.gd    ✅ 구현됨
└── assets/
    └── models/
        ├── crews/                   ✅ guardian.glb 존재
        ├── enemies/                 ✅ rusher.glb 존재
        ├── facilities/              ✅ residential_sml.glb 존재
        ├── vehicles/                ✅ boarding_pod.glb → DropPod
        └── environment/             🔴 추가 필요
            ├── station_node.glb
            ├── storm_wall.glb
            └── space_debris.glb
```

---

## 구현 우선순위

### 즉시 (Phase 1) ✅ 완료
1. ✅ Battle3D.tscn 기본 구조
2. ✅ CrewSquad3D.tscn - GLB 모델 연동
3. ✅ EnemyUnit3D.tscn - GLB 모델 연동
4. ✅ Facility3D.tscn - GLB 모델 연동
5. ✅ DropPod3D.tscn - GLB 모델 연동
6. 🟡 전투 테스트 (배치 → 웨이브 → 전투)

### 단기 (Phase 2) ✅ 완료
7. ✅ SectorMap3D.tscn - 3D 섹터 맵
8. ✅ SectorMap3DScene.gd - 렌더링 + 인터랙션
9. ✅ Campaign3D.tscn/gd - 캠페인 컨트롤러
10. ✅ 노드 타입별 3D 메시 (동적 생성)

### 중기 (Phase 3) ✅ 완료
9. ✅ StationPreview3D.tscn - 정거장 미리보기
10. ✅ SquadSelection.tscn - 분대 선택 화면
11. 🔴 NewGameSetup.tscn - 새 게임 설정 (Phase 4로 이동)

### 후기 (Phase 4)
12. 🔴 3D 이펙트 (Explosion3D, HitEffect3D)
13. 🔴 씬 전환 트랜지션 효과
14. 🔴 레거시 2D 씬 정리/삭제

---

## 레거시 씬 정리 계획

### 삭제 예정 (3D 완성 후)
- `scenes/main_menu.tscn` → MainMenu.tscn 사용
- `scenes/settings.tscn` → SettingsMenu.tscn 사용
- `scenes/upgrade.tscn` → UpgradeScreen.tscn 사용
- `scenes/sector_map.tscn` → SectorMap3D.tscn 사용
- `scenes/battle.tscn` → Battle3D.tscn 사용
- `scenes/battle/Battle.tscn` → Battle3D.tscn 사용
- `scenes/battle/TestBattle.tscn` → 삭제
- `scenes/battle/crew_unit.tscn` → CrewSquad3D.tscn 사용
- `scenes/battle/enemy_unit.tscn` → EnemyUnit3D.tscn 사용

### 유지 (2D UI)
- `src/ui/menus/*.tscn` - 메뉴 UI
- `src/ui/battle_hud/*.tscn` - 배틀 HUD
- `src/ui/campaign/*.tscn` - 캠페인 UI (일부)
- `src/ui/components/*.tscn` - UI 컴포넌트
- `src/ui/effects/*.tscn` → 3D 이펙트로 대체 후 삭제

---

## 기술 노트

### 3D 렌더링 설정
- **Renderer**: Forward+ (Godot 4.x 기본)
- **Anti-aliasing**: MSAA 2x
- **그림자**: DirectionalLight3D shadow 활성화
- **환경**: SSAO, Glow 활성화

### 아이소메트릭 카메라 설정
- **투영**: Orthographic
- **X 회전**: -35.264° (arctan(1/√2))
- **Y 회전**: 45°
- **줌 범위**: 5.0 ~ 30.0

### GLB 모델 요구사항
- **크기**: 1 유닛 = 1 타일
- **원점**: 모델 바닥 중앙
- **방향**: -Z가 전방
- **애니메이션**: Idle, Walk, Attack, Death

---

*문서 작성일: 2026-02-05*
*버전: 1.2 - Phase 3 완료 (StationPreview3D, SquadSelection)*
