# 기술 스택 및 구조

> **최종 업데이트**: 2026-02-05

## 현재 상태: Godot 4.x 3D

### 기술 스택
| 영역 | 기술 |
|------|------|
| 엔진 | Godot 4.x |
| 렌더링 | Forward+ (3D) |
| 언어 | GDScript |
| 3D 모델 | GLB (GLTF Binary) |
| RNG | Seeded Xorshift128+ |

---

## Godot 프로젝트 구조

```
godot/
├── project.godot           # 프로젝트 설정
├── autoload/               # 레거시 전역 시스템
├── scenes/
│   ├── Main.tscn          # 게임 매니저
│   ├── battle/
│   │   ├── Battle3D.tscn  ✅ 3D 전투
│   │   └── Battle.tscn    # 2D 레거시
│   └── campaign/
│       ├── Campaign3D.tscn ✅ 캠페인 컨트롤러
│       ├── SectorMap3D.tscn ✅ 3D 섹터 맵
│       ├── StationPreview3D.tscn ✅ 정거장 미리보기
│       └── SquadSelection.tscn ✅ 분대 선택
├── src/
│   ├── autoload/          # EventBus, GameState, Constants
│   ├── entities/          # 3D 엔티티
│   │   ├── crew/          # CrewSquad3D
│   │   ├── enemy/         # EnemyUnit3D
│   │   ├── facility/      # Facility3D
│   │   └── vehicle/       # DropPod3D
│   ├── rendering/         # 렌더링 시스템
│   │   ├── IsometricCamera.gd
│   │   ├── BattleMap3D.gd
│   │   └── IsometricUtils.gd
│   ├── scenes/            # 씬 컨트롤러
│   │   ├── Battle3DScene.gd
│   │   ├── SectorMap3DScene.gd
│   │   ├── StationPreview3DScene.gd
│   │   └── SquadSelectionScene.gd
│   ├── systems/           # 게임 시스템
│   │   ├── campaign/      # SectorGenerator, StationGenerator
│   │   ├── combat/        # BattleController, PlacementPhase
│   │   └── wave/          # WaveGenerator, WaveManager
│   └── ui/                # 2D UI 컴포넌트
└── assets/
    └── models/
        ├── crews/         # guardian.glb
        ├── enemies/       # rusher.glb
        ├── facilities/    # residential_sml.glb
        └── vehicles/      # boarding_pod.glb
```

---

## 핵심 3D 씬 구조

### Battle3D.tscn
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

### SectorMap3D.tscn
```
SectorMap3D (Node3D)
├── WorldEnvironment (우주 배경)
├── Camera3D (자유 이동)
├── Nodes (Node3D)
│   └── StationNode × N (각 노드)
├── Connections (Node3D)
│   └── PathMesh (연결선)
├── StormLine (Node3D)
│   └── StormWall (반투명 벽)
└── UI (CanvasLayer)
    ├── TopBar
    ├── BottomPanel (팀 슬롯)
    └── NodeInfoPanel
```

---

## 아이소메트릭 카메라 설정

```gdscript
# IsometricCamera.gd
const ISOMETRIC_ANGLE_X = -35.264  # arctan(1/√2)
const ISOMETRIC_ANGLE_Y = 45.0
projection = PROJECTION_ORTHOGONAL
size = 15.0  # 줌 레벨
```

---

## GLB 모델 규격

| 항목 | 값 |
|------|-----|
| 크기 | 1 유닛 = 1 타일 |
| 원점 | 모델 바닥 중앙 |
| 방향 | -Z가 전방 |
| 애니메이션 | Idle, Walk, Attack, Death |

---

## RNG 스트림 구조

```gdscript
# SeededRNG.gd - 7개 독립 스트림
enum Stream {
  SECTOR_MAP,     # 캠페인 맵 생성
  STATION_LAYOUT, # 정거장 레이아웃
  ENEMY_WAVES,    # 적 스폰
  ITEMS,          # 아이템 드롭
  TRAITS,         # 특성 부여
  COMBAT,         # 전투 RNG
  VISUAL          # 시각 효과
}
```

---

## EventBus 시그널

```gdscript
# EventBus.gd 주요 시그널
signal crew_selected(crew: Node)
signal crew_deselected()
signal crew_moved(crew: Node, position: Vector2i)
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)
signal facility_damaged(facility: Node, damage: int)
signal facility_destroyed(facility: Node)
signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal battle_won()
signal battle_lost()
signal turret_deploy_requested(crew: Node, position: Vector2i)
```

---

## 레거시 웹 프로토타입

### 위치
```
demo/
├── js/core/          # 핵심 시스템 (RNG, GameState)
├── js/pages/         # 페이지 컨트롤러
└── pages/            # HTML 템플릿
```

### 참고용
웹 프로토타입은 레퍼런스 용도로만 유지. 신규 기능은 Godot에서 구현.

---

*최종 업데이트: 2026-02-05*
