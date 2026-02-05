# 기술 스택 및 구조

> **최종 업데이트**: 2026-02-06

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
    └── models/            # 총 31개 GLB (2000 폴리곤 최적화 완료)
        ├── crews/         # 5종: bionic, engineer, guardian, ranger, sentinel
        ├── enemies/       # 3종: rusher, gunner, shield_trooper
        ├── facilities/    # 6종: residential_sml/med/lrg, medical, armory, comm_tower, power_plant
        ├── drones/        # 3종: raven_drone, turret, attack_drone
        ├── vehicles/      # 3종: boarding_pod, raven_mothership, pirate_carrier
        └── tiles/         # 10종: floor_basic/corridor/facility, wall_basic/window/corner,
                           #       door_airlock/basic, railing, crate
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
var _target_rotation_y = 45.0     # Q/E로 회전 가능
projection = PROJECTION_ORTHOGONAL
size = 10.0  # 기본 줌 레벨 (2026-02-05 조정)
```

### 조작
| 키 | 동작 |
|-----|------|
| Q | 카메라 좌회전 45° |
| E | 카메라 우회전 45° |
| 마우스휠 | 줌 인/아웃 |
| 마우스 가장자리 | 에지 패닝 |

---

## 조작 시스템 (Battle3DScene)

### 입력 처리 흐름
```
BattleMap3D._input()
  ├── 좌클릭 → tile_clicked.emit() → Battle3DScene._on_tile_clicked()
  │                                    └── _find_crew_at_tile() → _select_crew()
  └── 우클릭 → tile_right_clicked.emit() → Battle3DScene._on_tile_right_clicked()
                                           ├── 배치 페이즈 → PlacementPhase.place_crew_at()
                                           └── 전투 페이즈 → _move_crew_to()
```

### 주의사항
- PlacementPhase는 클릭 시그널에 직접 연결하지 않음 (Battle3DScene에서 위임)
- `crew_selected` 시그널 처리 시 재귀 루프 주의

---

## 전투 시스템 아키텍처

### CrewSquad3D 상태 머신
```
_process()
  ├── is_moving → _process_movement()
  ├── is_in_combat → _process_combat()
  │                    └── distance <= attack_range → _perform_attack()
  └── else → _auto_engage_nearby_enemy()
               └── 감지 범위(attack_range×3) 내 적 → command_attack()
```

### EnemyUnit3D 상태 머신
```
_process()
  ├── is_moving → _process_movement()
  │                 └── distance < attack_range → start_attack()
  └── is_attacking → _process_attack()
                      └── _attack_timer <= 0 → _perform_attack()
```

### 데미지 계산
```gdscript
# 아군 (CrewSquad3D)
total_damage = attack_damage * members_alive

# 적 (EnemyUnit3D)
damage = attack_damage
```

---

## GLB 모델 규격

| 항목 | 값 |
|------|-----|
| 크기 | 1 유닛 = 1 타일 |
| 원점 | 모델 바닥 중앙 |
| 방향 | -Z가 전방 |
| 폴리곤 | ~2000 삼각형 (Sharp edge 보존 최적화) |
| 애니메이션 | Idle, Walk, Attack, Death |

### 모델 생성 파이프라인
```
1. SDXL (JuggernautXL) → 1024x1024 이미지 생성
2. Hunyuan3D-2.1 → GLB 변환 (고폴리)
3. Blender → 2000 폴리곤 최적화
   - Sharp edge 마킹 (30°)
   - Decimate COLLAPSE with delimit={'SHARP'}
   - shade_smooth_by_angle()
```

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

*최종 업데이트: 2026-02-06*
