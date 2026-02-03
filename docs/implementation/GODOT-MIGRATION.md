# The Fading Raven - Godot 이관 계획

## 개요
웹 프로토타입을 Godot 4.x로 이관하여 정식 게임으로 개발

---

## 사전 준비

### 1. 환경 확인
- [ ] Godot 버전 확인 (4.2+ 필요)
- [ ] MCP 선택 및 설치
- [ ] Claude Code MCP 연동 테스트

### 2. MCP 옵션

| MCP | 장점 | 단점 |
|-----|------|------|
| **GDAI MCP ($19)** | 스크린샷 검증, 자동 에러 수정 | 유료 |
| **Coding-Solo (무료)** | MIT, 커뮤니티 활발 | 검증 기능 없음 |

**추천:** 정확성 중시 → GDAI MCP

### 3. MCP 설치 (Coding-Solo 기준)
```bash
# 이미 설치됨: C:\Claude\godot-mcp
```

Claude Code 설정 (`~/.claude/mcp.json`):
```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["C:/Claude/godot-mcp/build/index.js"],
      "env": {
        "GODOT_PATH": "C:/YOUR_GODOT_PATH/Godot.exe"
      }
    }
  }
}
```

> 템플릿 파일: `C:\Claude\godot-mcp\mcp-config-template.json`

---

## 프로젝트 구조

```
TheFadingRaven/
├── project.godot
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── src/
│   ├── autoload/           # 싱글톤
│   │   ├── GameState.gd
│   │   ├── EventBus.gd
│   │   └── AudioManager.gd
│   ├── data/               # 데이터 정의
│   │   ├── CrewData.gd
│   │   ├── EnemyData.gd
│   │   ├── EquipmentData.gd
│   │   └── BalanceData.gd
│   ├── entities/           # 게임 엔티티
│   │   ├── crew/
│   │   ├── enemy/
│   │   └── projectile/
│   ├── systems/            # 게임 시스템
│   │   ├── combat/
│   │   ├── wave/
│   │   └── campaign/
│   └── ui/                 # UI 컴포넌트
│       ├── battle_hud/
│       ├── menus/
│       └── components/
├── scenes/
│   ├── main.tscn
│   ├── battle/
│   ├── campaign/
│   └── ui/
└── resources/              # .tres 리소스
    ├── crews/
    ├── enemies/
    └── equipment/
```

---

## 이관 순서 (3 페이즈)

### Phase 1: 코어 + 데이터 (세션 1)
**목표:** 게임 데이터와 기본 시스템 이관

1. **프로젝트 설정**
   - project.godot 설정
   - 입력 매핑
   - 오토로드 등록

2. **데이터 시스템** (Resource 활용)
   ```gdscript
   # CrewClass.gd
   class_name CrewClass extends Resource

   @export var id: String
   @export var name: String
   @export var base_hp: int
   @export var base_damage: int
   @export var skills: Array[SkillData]
   ```

3. **GameState 싱글톤**
   - 런 상태 관리
   - 세이브/로드
   - 시드 기반 RNG

4. **이벤트 버스**
   ```gdscript
   # EventBus.gd
   signal crew_damaged(crew, amount)
   signal enemy_killed(enemy)
   signal wave_started(wave_num)
   ```

**산출물:** 데이터 로드, 상태 관리 작동 확인

---

### Phase 2: 전투 시스템 (세션 2)
**목표:** 핵심 전투 루프 구현

1. **타일 그리드**
   - TileMap 또는 커스텀 그리드
   - A* 경로 탐색 (AStar2D)
   - 시야선 계산

2. **엔티티 시스템**
   ```
   Entity (Node2D)
   ├── Crew extends Entity
   └── Enemy extends Entity
   ```

3. **전투 컨트롤러**
   - 실시간 + 일시정지
   - 크루 선택/명령
   - 타겟팅 시스템

4. **스킬 시스템**
   - 쿨다운 관리
   - 범위/효과 처리
   - 애니메이션 연동

5. **웨이브 시스템**
   - 스폰 관리
   - 난이도 스케일링

**산출물:** 전투 플레이 가능

---

### Phase 3: UI + 캠페인 (세션 3)
**목표:** 게임 완성

1. **UI 시스템**
   - 배틀 HUD
   - 메뉴/설정
   - 업그레이드 화면

2. **섹터 맵**
   - 노드 생성/연결
   - 경로 선택
   - Storm Front

3. **메타 진행**
   - 해금 시스템
   - 통계/업적

4. **폴리시**
   - 사운드
   - 파티클
   - 화면 효과

**산출물:** 완성된 데모

---

## 웹 → Godot 매핑

| 웹 파일 | Godot 대응 |
|---------|-----------|
| `js/data/*.js` | `resources/*.tres` + `src/data/*.gd` |
| `js/core/game-state.js` | `src/autoload/GameState.gd` |
| `js/pages/battle.js` | `src/systems/combat/BattleController.gd` |
| `js/core/tile-grid.js` | `TileMap` 또는 `src/systems/combat/TileGrid.gd` |
| `js/entities/enemy.js` | `src/entities/enemy/Enemy.gd` |
| `js/ai/*.js` | `src/entities/enemy/EnemyAI.gd` |
| `js/ui/*.js` | `src/ui/**/*.gd` + `.tscn` |
| CSS 스타일 | Godot Theme 리소스 |

---

## 데이터 이관 예시

### 웹 (crews.js)
```javascript
const CrewData = {
    classes: {
        guardian: {
            name: "Guardian",
            baseHP: 12,
            baseDamage: 3,
            // ...
        }
    }
};
```

### Godot (crews/guardian.tres)
```gdscript
[gd_resource type="Resource" script_class="CrewClass"]

[resource]
script = ExtResource("res://src/data/CrewClass.gd")
id = "guardian"
name = "Guardian"
base_hp = 12
base_damage = 3
```

---

## 체크리스트

### 이관 전
- [ ] Godot 4.2+ 설치 확인
- [ ] MCP 설치 및 연동 테스트
- [ ] 프로젝트 생성 (`TheFadingRaven`)

### Phase 1 완료 조건
- [ ] 모든 데이터 Resource로 변환
- [ ] GameState 저장/로드 작동
- [ ] 시드 기반 RNG 작동

### Phase 2 완료 조건
- [ ] 크루 이동/공격 가능
- [ ] 적 스폰 및 AI 작동
- [ ] 웨이브 클리어 가능

### Phase 3 완료 조건
- [ ] 섹터 맵 탐색 가능
- [ ] 전체 런 플레이 가능
- [ ] UI 완성

---

## 예상 작업량

| 페이즈 | 예상 규모 | 비고 |
|--------|----------|------|
| Phase 1 | 중간 | 데이터 변환 단순 |
| Phase 2 | 큼 | 핵심 로직 이관 |
| Phase 3 | 중간 | UI 노드 작업 많음 |

**총 예상:** 웹 버전 대비 1.5~2배 토큰
**장점:** 수정 정확도 높음, 실행 검증 가능 (MCP)
