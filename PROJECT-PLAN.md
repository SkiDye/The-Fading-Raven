# The Fading Raven - 프로젝트 마스터 플랜

> 최종 업데이트: 2026-02-03

---

## 프로젝트 개요

**장르:** 로그라이크 전술 게임 (Bad North 스타일)
**엔진:** Godot 4.x (웹 프로토타입에서 이관)
**상태:** 웹 프로토타입 완료 → Godot 이관 준비 중

---

## 완료된 작업 (웹 프로토타입)

### 2026-02-03 대대적 업데이트

5개 병렬 세션으로 전체 시스템 구현 완료.

#### 세션 1: 데이터 & 코어 ✅
| 파일 | 내용 |
|------|------|
| `js/data/crews.js` | 5개 크루 클래스 (Guardian, Sentinel, Ranger, Engineer, Bionic) |
| `js/data/equipment.js` | 10종 장비 + 업그레이드 |
| `js/data/traits.js` | 15종 특성 |
| `js/data/enemies.js` | 15종 적 (Tier 1~3 + Boss) |
| `js/data/facilities.js` | 5종 시설 모듈 |
| `js/data/balance.js` | 밸런싱 상수, 난이도 배율 |
| `js/core/game-state.js` | 런 상태, 세이브/로드, 멀티탭 감지 (L-007) |
| `js/core/utils.js` | 유틸리티, 모듈 검증 API (L-006) |
| `js/core/rng.js` | Xorshift128+ 시드 RNG, SeedUtils |

#### 세션 2: 전투 시스템 ✅
| 파일 | 내용 |
|------|------|
| `js/core/tile-grid.js` | 타일 그리드, A* 경로탐색, 시야선 |
| `js/core/skills.js` | 5개 클래스별 스킬, 쿨다운 |
| `js/core/equipment-effects.js` | 장비 패시브/액티브 효과 |
| `js/core/raven.js` | Raven 드론 4개 능력 |
| `js/entities/turret.js` | 터렛 시스템, 해킹 메카닉 |
| `js/core/combat-mechanics.js` | 데미지 계산, 커버/고지대 보너스 |

#### 세션 3: 적 & AI ✅
| 파일 | 내용 |
|------|------|
| `js/entities/enemy.js` | Enemy 클래스, EnemyFactory |
| `js/ai/behavior-tree.js` | AIManager, 행동 트리 |
| `js/ai/enemy-mechanics.js` | 특수 메카닉 (해킹, 스나이퍼, 드론) |
| `js/ai/crew-ai.js` | 크루 자동 전투 AI (클래스별 프로파일) |
| `js/core/wave-generator.js` | 웨이브 생성, 예산 기반 스케일링 |

#### 세션 4: 캠페인 ✅
| 파일 | 내용 |
|------|------|
| `js/core/sector-generator.js` | DAG 기반 섹터 맵, Storm Front |
| `js/core/station-generator.js` | BSP 기반 스테이션 레이아웃 |
| `js/core/meta-progress.js` | 해금, 업적, 메타 진행 |
| `js/pages/sector.js` | 섹터 맵 UI |

#### 세션 5: UI & 폴리시 ✅
| 파일 | 내용 |
|------|------|
| `js/ui/ui-components.js` | Tooltip, Toast, Modal, ProgressBar, Loading |
| `js/ui/effects.js` | 화면 효과, 파티클, 플로팅 텍스트 |
| `js/ui/hud.js` | 전투 HUD |
| `js/ui/battle-effects-integration.js` | 전투 이펙트 통합 |
| `js/core/combat-mechanics.js` | Bad North 전투 메카닉 |
| `pages/settings.html` | 설정 화면 (접근성 포함) |

#### 세션 6: 2.5D 렌더링 ✅
| 파일 | 내용 |
|------|------|
| `js/rendering/isometric-renderer.js` | 아이소메트릭 좌표 변환, 카메라 |
| `js/rendering/tile-renderer.js` | 타일/시설 렌더링 |
| `js/rendering/height-system.js` | 타일 높이 매핑 |
| `js/rendering/depth-sorter.js` | 깊이 정렬 (back-to-front) |

#### 추가 구현
- **L-006:** 데이터 모듈 로드 검증 (`Utils.validateRequiredModules`)
- **L-007:** 멀티탭 충돌 방지 (`GameState.initMultiTabDetection`)
- **L-002:** 키보드 단축키 도움말 모달

### 테스트 현황
- **통합 테스트:** 202개 통과 (100%)
- **밸런스 검증:** 기본 검증 완료

---

## Godot 이관 계획

### 왜 Godot인가?
| 항목 | 웹 | Godot |
|------|-----|-------|
| AI 협업 정확도 | 낮음 | 높음 (MCP) |
| 실행 검증 | 수동 | 자동 (스크린샷) |
| 배포 | 브라우저 한정 | PC/모바일/콘솔 |
| 성능 | 제한적 | 최적화 가능 |
| 파일 형식 | 분산 (HTML/CSS/JS) | 텍스트 기반 (.tscn, .gd) |

### MCP 설정
```
C:\Claude\godot-mcp\  (Coding-Solo, MIT, 설치 완료)
```

필요시 GDAI MCP ($19)로 업그레이드 - 스크린샷 검증 지원

### 이관 3 Phase

#### Phase 1: 코어 + 데이터
**범위:**
- project.godot 설정
- Resource 기반 데이터 시스템 (CrewClass, EnemyData, etc.)
- GameState 오토로드
- EventBus 시그널 시스템
- 시드 기반 RNG

**웹 → Godot 매핑:**
```
js/data/*.js        → resources/*.tres + src/data/*.gd
js/core/game-state.js → src/autoload/GameState.gd
js/core/utils.js    → src/autoload/Utils.gd
js/core/rng.js      → RandomNumberGenerator (내장)
```

**완료 조건:**
- [ ] 모든 데이터 Resource로 로드 가능
- [ ] GameState 저장/로드 작동
- [ ] 시드 동일 시 동일 결과 재현

---

#### Phase 2: 전투 시스템
**범위:**
- TileMap 또는 커스텀 그리드
- Crew/Enemy 엔티티 (Node2D 기반)
- 전투 컨트롤러 (실시간 + 일시정지)
- 스킬/장비 시스템
- AI 행동 트리
- 웨이브 스폰

**웹 → Godot 매핑:**
```
js/core/tile-grid.js     → TileMap + src/systems/combat/TileGrid.gd
js/pages/battle.js       → src/systems/combat/BattleController.gd
js/core/skills.js        → src/systems/combat/SkillSystem.gd
js/entities/enemy.js     → src/entities/enemy/Enemy.gd + Enemy.tscn
js/ai/behavior-tree.js   → src/entities/enemy/EnemyAI.gd
js/core/wave-generator.js → src/systems/wave/WaveManager.gd
```

**완료 조건:**
- [ ] 크루 선택/이동/공격 가능
- [ ] 적 스폰 및 AI 행동
- [ ] 스킬 사용 및 쿨다운
- [ ] 웨이브 클리어 → 다음 웨이브

---

#### Phase 3: UI + 캠페인
**범위:**
- 배틀 HUD (Control 노드)
- 메뉴/설정 화면
- 섹터 맵 UI
- 업그레이드/상점 화면
- 메타 진행 시스템
- 사운드/파티클 폴리시

**웹 → Godot 매핑:**
```
js/ui/*.js              → src/ui/**/*.gd + .tscn
js/core/sector-generator.js → src/systems/campaign/SectorGenerator.gd
js/core/meta-progress.js → src/autoload/MetaProgress.gd
CSS 스타일              → Godot Theme 리소스
```

**완료 조건:**
- [ ] 전체 게임 루프 플레이 가능 (메뉴 → 전투 → 승리/패배)
- [ ] 섹터 맵 탐색
- [ ] 크루 영입/업그레이드
- [ ] 설정 저장/로드

---

## 프로젝트 구조 (Godot)

```
TheFadingRaven/
├── project.godot
├── assets/
│   ├── sprites/
│   │   ├── crews/
│   │   ├── enemies/
│   │   └── effects/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/
├── src/
│   ├── autoload/
│   │   ├── GameState.gd
│   │   ├── EventBus.gd
│   │   ├── AudioManager.gd
│   │   └── MetaProgress.gd
│   ├── data/
│   │   ├── CrewClass.gd
│   │   ├── SkillData.gd
│   │   ├── EnemyData.gd
│   │   ├── EquipmentData.gd
│   │   └── TraitData.gd
│   ├── entities/
│   │   ├── Entity.gd (base)
│   │   ├── crew/
│   │   │   ├── Crew.gd
│   │   │   └── Crew.tscn
│   │   ├── enemy/
│   │   │   ├── Enemy.gd
│   │   │   ├── Enemy.tscn
│   │   │   └── EnemyAI.gd
│   │   └── projectile/
│   ├── systems/
│   │   ├── combat/
│   │   │   ├── BattleController.gd
│   │   │   ├── TileGrid.gd
│   │   │   ├── SkillSystem.gd
│   │   │   └── DamageSystem.gd
│   │   ├── wave/
│   │   │   ├── WaveGenerator.gd
│   │   │   └── WaveManager.gd
│   │   └── campaign/
│   │       ├── SectorGenerator.gd
│   │       └── StationGenerator.gd
│   └── ui/
│       ├── battle_hud/
│       ├── menus/
│       └── components/
├── scenes/
│   ├── Main.tscn
│   ├── battle/
│   │   └── Battle.tscn
│   ├── campaign/
│   │   ├── SectorMap.tscn
│   │   └── Upgrade.tscn
│   └── ui/
│       ├── MainMenu.tscn
│       └── Settings.tscn
└── resources/
    ├── crews/
    │   ├── guardian.tres
    │   ├── sentinel.tres
    │   └── ...
    ├── enemies/
    ├── equipment/
    └── themes/
```

---

## 일정 (예상)

| 단계 | 내용 | 상태 |
|------|------|------|
| 웹 프로토타입 | GDD 검증용 데모 | ✅ 완료 |
| MCP 설정 | Godot MCP 설치 | ✅ 완료 |
| Phase 1 | 코어 + 데이터 | 🔲 대기 |
| Phase 2 | 전투 시스템 | 🔲 대기 |
| Phase 3 | UI + 캠페인 | 🔲 대기 |
| 알파 | 전체 플레이 가능 | 🔲 대기 |
| 폴리시 | 아트, 사운드, 밸런스 | 🔲 대기 |
| 베타 | 테스트 빌드 | 🔲 대기 |

---

## 핵심 게임 요소 (GDD 기준)

### 크루 클래스 (5종)
| 클래스 | 역할 | 스킬 |
|--------|------|------|
| Guardian | 탱커 | Shield Bash |
| Sentinel | 방어 | Lance Charge |
| Ranger | 원거리 | Volley Fire |
| Engineer | 지원 | Deploy Turret |
| Bionic | 기동 | Blink |

### 적 유형 (15종)
- **Tier 1:** Rusher, Gunner, Shield Trooper
- **Tier 2:** Jumper, Heavy Trooper, Hacker, Storm Creature
- **Tier 3:** Brute, Sniper, Drone Carrier, Shield Generator
- **Boss:** Pirate Captain, Storm Core

### 노드 유형 (8종)
- start, battle, commander, equipment, storm, boss, rest, gate

### Raven 능력 (4종)
- Scout (무제한), Flare (2회), Resupply (1회), Orbital Strike (1회)

---

## 리스크 & 대응

| 리스크 | 대응 |
|--------|------|
| MCP 기능 부족 | GDAI MCP 구매 또는 직접 확장 |
| 밸런스 문제 | 웹 프로토타입으로 사전 검증 |
| 아트 에셋 부재 | 플레이스홀더 → 후반 교체 |
| 스코프 확장 | GDD 기준 엄격 준수 |

---

## 참고 문서

- `docs/game-design/game-design-document.md` - 게임 디자인 문서
- `docs/implementation/SHARED-STATE.md` - 웹 구현 인터페이스
- `docs/implementation/GODOT-MIGRATION.md` - Godot 이관 상세
- `docs/references/bad-north-reference.md` - 레퍼런스 분석
