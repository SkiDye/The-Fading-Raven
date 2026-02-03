# Bad North 리서치 vs The Fading Raven 구현 비교

> 리서치 문서와 현재 Godot 구현 상태 비교 분석
> **TFR 컨셉**: 우주 SF 정거장 방어 - Raven 드론과 함께 폭풍 전선에서 탈출

---

## 🚀 TFR 고유 시스템 (Bad North 없음)

### Raven 드론 시스템 ⭐ 핵심 차별점

| 능력 | 효과 | 기본 횟수 | 구현 상태 |
|------|------|----------|----------|
| **Scout (정찰)** | 다음 웨이브 구성 미리보기 | 매 웨이브 | ❌ 미구현 |
| **Flare (조명탄)** | 폭풍 스테이지 시야 확보 | 2회 | ❌ 미구현 |
| **Resupply (긴급 보급)** | 1팀 즉시 회복 | 1회 | ❌ 미구현 |
| **Orbital Strike (궤도 폭격)** | 지정 타일 고데미지 | 1회 | ❌ 미구현 |

### 시설 보너스 시스템

| 시설 | 크레딧 | 특수 보너스 | 구현 상태 |
|------|--------|------------|----------|
| 거주 모듈 | 1-3 | 없음 (기본) | ✅ |
| **의료 모듈** | 2 | 재보급 시간 **-50%** | ❌ 미구현 |
| **무기고** | 2 | 데미지 **+20%** | ❌ 미구현 |
| **통신탑** | 1 | Raven 능력 **+1회** | ❌ 미구현 |
| **발전소** | 3 | 터렛 성능 **+50%** | ❌ 미구현 |

### 폭풍 스테이지 시스템

| 요소 | 효과 | 구현 상태 |
|------|------|----------|
| **시야 제한** | Fog of War 활성화 | ❌ 미구현 |
| **조명탄 필요** | Flare로 시야 확보 | ❌ 미구현 |
| **폭풍 생명체** | Storm Creature 출현 | ✅ 데이터 정의됨 |
| **Storm Core** | 파괴 불가 환경 보스 | ✅ 데이터 정의됨 |

### 엔지니어 고유 메카닉

| 기능 | 상세 | 구현 상태 |
|------|------|----------|
| **터렛 배치** | 자동 포탑 설치 | ❌ 미구현 |
| **시설 수리** | 파괴 시설 복구 (20초) | ❌ 미구현 |
| **해킹 취약** | 적 Hacker가 터렛 해킹 | ❌ 미구현 |

### 바이오닉 고유 메카닉

| 기능 | 상세 | 구현 상태 |
|------|------|----------|
| **Blink** | 순간이동 스킬 | ❌ 미구현 |
| **암살 보너스** | 비교전 적 공격 시 **2배 데미지** | ❌ 미구현 |

---

## 📝 TFR 용어 통일

| Bad North 용어 | TFR 용어 | 적용 상태 |
|---------------|----------|----------|
| Commander | **Team Leader (팀장)** | ⚠️ 혼용 중 |
| House | **Module/Facility (시설)** | ✅ 적용됨 |
| Boat | **Drop Pod/Shuttle (침투정)** | ⚠️ 일부 |
| Island | **Station (정거장)** | ✅ 적용됨 |
| Gold | **Credits (크레딧)** | ✅ 적용됨 |
| Replenish | **Resupply (재보급)** | ⚠️ 혼용 중 |
| Flee | **Emergency Evac (긴급 귀환)** | ❌ 미적용 |
| Viking Wave | **Storm Line (폭풍 전선)** | ⚠️ 일부 |

---

## 🔄 TFR 컨셉 재설계 항목

### 철수 시스템: Flee → Emergency Evac

| 항목 | Bad North | TFR 변경 |
|------|-----------|----------|
| **트리거** | 빈 보트 탑승 | **Raven 기함이 회수** |
| **연출** | 보트로 이동 후 탈출 | 셔틀 하강 → 분대 탑승 → 이륙 |
| **비용** | 해당 섬 코인 0 | 해당 정거장 크레딧 0 |
| **UI** | Flee 버튼 + 배 아이콘 | **Emergency Evac** + 셔틀 아이콘 |

### 크루 영입: Flag Island → Rescue Mission

| 항목 | Bad North | TFR 변경 |
|------|-----------|----------|
| **노드 타입** | 깃발 표시 섬 | **RESCUE** (구조 임무) |
| **연출** | 섬에서 영입 | 탈출자 합류 이벤트 |
| **조건** | 무조건 영입 | 전투 후 생존자 구조 |
| **보상** | 새 Commander | 새 **Team Leader** + 초기 크루 |

### 아이템 획득: Mystery Island → Salvage/Depot

| 항목 | Bad North | TFR 변경 |
|------|-----------|----------|
| **노드 타입** | 물음표(?) 섬 | **SALVAGE** (난파선) 또는 **DEPOT** (보급 정거장) |
| **연출** | 물음표 클릭 → 아이템 | 탐색 이벤트 → 장비 획득 |
| **위험** | 없음 | 선택적 전투 (Salvage) |

### 체크포인트: Save Island → Beacon Activation

| 항목 | Bad North | TFR 변경 |
|------|-----------|----------|
| **개념** | 특정 섬에서 저장 | **비콘 활성화** - 네트워크 노드 복구 |
| **연출** | 체크포인트 도달 | 통신 비콘 수리 → 진행 저장 |
| **의미** | 단순 저장 | Raven과 연결 복구 (세계관 연결) |

### 슬로우 모션: Unit Selection → Tactical Mode

| 항목 | Bad North | TFR 변경 |
|------|-----------|----------|
| **트리거** | 유닛 선택 시 | **Tactical Mode** 진입 |
| **연출** | 단순 시간 감속 | Raven AI 지원 (HUD 오버레이) |
| **UI** | 없음 | "TACTICAL MODE" 표시 + 스캔라인 효과 |

---

## 요약

| 카테고리 | Bad North | TFR 구현 | 상태 |
|----------|-----------|----------|------|
| 유닛 클래스 | 3종 (보병, 창병, 궁수) | 5종 (+엔지니어, 바이오닉) | ✅ 확장 |
| 적 유닛 | ~7종 | 13종 + 보스 2종 | ✅ 확장 |
| 아이템 | 8종 | 10종 | ✅ 확장 |
| 특성 | 13종 | 15종 | ✅ 확장 |
| 핵심 메카닉 | 4개 | 4개 구현 | ✅ 동일 |
| 경제 시스템 | 골드 | 크레딧 | ✅ 동일 |
| 분대 크기 | 9명 | 8명 (5-8 가변) | ⚠️ 차이 |
| 회복 시간 | 2초 × 분대 | 2초 × 분대 | ✅ 동일 |

---

## 1. 유닛/크루 시스템 비교

### 1.1 클래스 매핑

| Bad North | The Fading Raven | 역할 변경 |
|-----------|------------------|----------|
| Infantry (보병) | Guardian (가디언) | 동일 - 올라운더, 실드 |
| Pikemen (창병) | Sentinel (센티넬) | 동일 - 병목 방어, 랜스 |
| Archers (궁수) | Ranger (레인저) | 동일 - 원거리 딜러 |
| - | **Engineer (엔지니어)** | 🆕 신규 - 터렛/수리 |
| - | **Bionic (바이오닉)** | 🆕 신규 - 고기동 암살 |

### 1.2 분대 크기 비교

| 항목 | Bad North | TFR (구현) | 비고 |
|------|-----------|------------|------|
| 기본 분대 | **9명** (8+지휘관) | **8명** (7+팀장) | ⚠️ 1명 차이 |
| Ring/Command Lv1 | 12명 | 11명 | 비례 조정 |
| Ring/Command Lv2 | 16명 | 14명 | 비례 조정 |
| Popular 특성 | +1명 | +1명 | ✅ 동일 |

**구현 위치**: `godot/autoload/data_registry.gd:60-230`

```gdscript
# data_registry.gd - 각 클래스별 base_squad_size
"guardian": 8,  # Bad North: 9
"sentinel": 8,
"ranger": 8,
"engineer": 6,   # 신규 클래스, 작은 분대
"bionic": 5,     # 신규 클래스, 가장 작은 분대
```

### 1.3 핵심 메카닉 구현 상태

| Bad North 메카닉 | TFR 구현 | 파일 | 상태 |
|------------------|----------|------|------|
| **Shield Block (교전 중 비활성)** | `_is_shield_active()` | `combat_mechanics.gd:49-58` | ✅ |
| **Lance Raise (밀착 시 무력화)** | `_is_lance_raised()` | `combat_mechanics.gd:62-72` | ✅ |
| **Landing Knockback (상륙 넉백)** | `apply_landing_knockback()` | `combat_mechanics.gd:85-109` | ✅ |
| **Void Death (물/우주 추락)** | `check_void_death()` | `combat_mechanics.gd:162-169` | ✅ |

**Shield Block 구현 검증**:
```gdscript
# combat_mechanics.gd:49-58
static func _is_shield_active(unit: Node) -> bool:
    if not unit.has_method("get_class_id"):
        return false
    if unit.get_class_id() != "guardian":
        return false
    # Bad North 핵심: 근접 교전 중에는 실드 비활성
    if unit.is_in_melee_combat():
        return false
    return true
```

**Lance Raise 구현 검증**:
```gdscript
# combat_mechanics.gd:62-72
static func _is_lance_raised(unit: Node, enemy: Node) -> bool:
    if not unit.has_method("get_class_id"):
        return false
    if unit.get_class_id() != "sentinel":
        return false
    var distance := unit.global_position.distance_to(enemy.global_position)
    var raise_range: float = Balance.LANCE["raise_range"]
    # Bad North 핵심: 적 밀착 시 랜스 들어올림
    return distance < raise_range
```

---

## 2. 스킬 시스템 비교

### 2.1 스킬 매핑

| Bad North | TFR | 타입 | 차이점 |
|-----------|-----|------|--------|
| Plunge (급강하) | Shield Bash | 방향 지정 | 고지대 필요 없음, 돌진형으로 변경 |
| Pike Charge | Lance Charge | 방향 지정 | ✅ 동일 |
| Volley | Volley Fire | 위치 지정 | ✅ 동일 |
| - | Deploy Turret | 위치 지정 | 🆕 엔지니어 전용 |
| - | Blink | 위치 지정 | 🆕 바이오닉 전용 |

### 2.2 스킬 비용 비교

| 레벨 | Bad North | TFR (구현) | 상태 |
|------|-----------|------------|------|
| Lv1 | 7 골드 | 7 크레딧 | ✅ 동일 |
| Lv2 | 10 골드 | 10 크레딧 | ✅ 동일 |
| Lv3 | 14 골드 | 14 크레딧 | ✅ 동일 |

**구현 위치**: `godot/autoload/balance.gd:42-46`

```gdscript
"skill_upgrade_costs": {
    1: 7,   # Bad North와 동일
    2: 10,
    3: 14,
},
```

### 2.3 스킬 효과 비교 (Lance Charge 예시)

| 레벨 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| Lv1 | 3타일 거리 | 3타일 | ✅ |
| Lv2 | 무제한 거리 | 무제한 (-1) | ✅ |
| Lv3 | 브루트 즉사 | brute_kill: true | ✅ |

**구현 위치**: `godot/autoload/data_registry.gd:117-127`

---

## 3. 적 시스템 비교

### 3.1 적 매핑

| Bad North | TFR | Tier | 비고 |
|-----------|-----|------|------|
| Viking (검) | Rusher | 1 | ✅ 동일 역할 |
| Viking Archer | Gunner | 1 | ✅ 동일 역할 |
| Viking Shield | Shield Trooper | 1 | ✅ 동일 역할 |
| Dual Wielders | Jumper | 2 | ✅ 점프 메카닉 동일 |
| Huscarls | Heavy Trooper | 2 | ✅ 수류탄 + 실드 |
| - | Hacker | 2 | 🆕 터렛 해킹 |
| - | Storm Creature | 2 | 🆕 자폭형 |
| Brutes | Brute | 3 | ✅ 동일 |
| Brute Archers | Sniper | 3 | 유사 - 장거리 고데미지 |
| - | Drone Carrier | 3 | 🆕 드론 소환 |
| - | Shield Generator | 3 | 🆕 아군 보호 |
| - | Pirate Captain | Boss | 🆕 보스 |
| - | Storm Core | Boss | 🆕 환경 보스 |

### 3.2 적 예산(Budget) 시스템

| Bad North | TFR | 상태 |
|-----------|-----|------|
| 보트 크기 기반 | 예산(budget) 기반 | ✅ 확장 |

**구현 위치**: `godot/scripts/generation/wave_generator.gd`

```gdscript
# wave_generator.gd - 예산 기반 적 생성
static func generate_wave(turn: int, difficulty: int, ...) -> Dictionary:
    var budget := _calculate_budget(turn, difficulty, ...)
    # 예산 내에서 적 유형 선택
```

### 3.3 적 상성 구현

| 적 | 카운터 (Bad North) | 카운터 (TFR) | 상태 |
|----|-------------------|--------------|------|
| 러셔 | 모든 클래스 | guardian, sentinel, ranger | ✅ |
| 건너 | Infantry (방패) | guardian | ✅ |
| 실드 트루퍼 | 창병/측면 | sentinel, bionic | ✅ |
| 브루트 | Pikes (필수) | sentinel | ✅ |

**구현 위치**: `godot/autoload/data_registry.gd:321-443`

---

## 4. 재보급(Resupply) 시스템 비교

> TFR 용어: Replenish → **Resupply (재보급)**

### 4.1 재보급 시간 공식

| 항목 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 기본 공식 | 2초 × 분대크기 | 2초 × 분대크기 | ✅ 동일 |
| 기본 (8명) | 16초 | 16초 | ✅ |
| Command Module Lv1 (11명) | 24초 | 22초 | ⚠️ |
| Quick Recovery 특성 | -33% | -33% | ✅ |
| **의료 모듈 보너스** | - | **-50%** | 🆕 TFR 고유 |

**구현 위치**: `godot/autoload/balance.gd:48-51`

```gdscript
"RECOVERY": {
    "base_time_per_unit": 2.0,
    "facility_bonus": 0.5,      # 기본
    "medical_module_bonus": 0.5, # 의료 모듈: 추가 -50%
},
```

### 4.2 재보급 조건

| 조건 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 시설 필요 | 집 점거 | **시설 모듈** 점거 | ✅ |
| 취소 불가 | ✅ | ⚠️ 미구현 | 🔴 필요 |
| 중단 시 손실 | 분대 손실 | 분대 손실 | 🔴 필요 |
| **Raven Resupply** | - | 1회 즉시 회복 (드론 능력) | 🆕 TFR 고유 |

---

## 5. 아이템/장비 시스템 비교

### 5.1 아이템 매핑

| Bad North | TFR | 타입 | 상태 |
|-----------|-----|------|------|
| Ring of Command | Command Module | 패시브 | ✅ |
| Warhammer | Shock Wave | 액티브 (쿨다운) | ✅ |
| Bomb | Frag Grenade | 액티브 (횟수) | ✅ |
| Mines | Proximity Mine | 액티브 (횟수) | ✅ |
| War Horn | Rally Horn | 액티브 (횟수) | ✅ |
| Holy Grail | Revive Kit | 액티브 (1회) | ✅ |
| Jabena | Stim Pack | 패시브 | ✅ |
| Philosopher's Stone | Salvage Core | 패시브 | ✅ |
| - | Shield Generator | 액티브 (쿨다운) | 🆕 |
| - | Hacking Device | 액티브 (횟수) | 🆕 |

### 5.2 아이템 비용 비교

| 아이템 | Bad North Lv2 | TFR Lv2 | 상태 |
|--------|---------------|---------|------|
| Ring/Command | 16 | 16 | ✅ |
| Bomb/Grenade | 8 | 8 | ✅ |
| Mines | 8 | 8 | ✅ |
| War Horn/Rally | 8 | 10 | ⚠️ |
| Phil. Stone/Salvage | 5 | 5 | ✅ |

**구현 위치**: `godot/autoload/data_registry.gd:574-733`

---

## 6. 특성(Traits) 시스템 비교

### 6.1 특성 매핑

| Bad North | TFR | 효과 | 상태 |
|-----------|-----|------|------|
| Sharp Weapons | Sharp Edge | 데미지↑, 넉백↓ | ✅ |
| Heavy Weapons | Heavy Impact | 넉백↑, 스턴↑ | ✅ |
| Mountain | Titan Frame | 지휘관 거대화 | ✅ |
| Ironskin | Reinforced Armor | 데미지 감소 | ✅ |
| Sure Footed | Steady Stance | 넉백/스턴 저항 | ✅ |
| Fearless | Fearless | 도주 불가 | ✅ |
| Energetic | Energetic | 쿨다운 -33% | ✅ |
| Fleet of Foot | Swift Movement | 이동속도 +33% | ✅ |
| Popular | Popular | 분대원 +1 | ✅ |
| Rousing Speeches | Quick Recovery | 회복 -33% | ✅ |
| Skillful | Skillful | 스킬 비용 -50% | ✅ |
| Collector | Collector | 장비 비용 -50% | ✅ |
| Heavy Load | Heavy Load | 횟수 +1 | ✅ |
| - | Tech Savvy | 터렛 +50% | 🆕 |
| - | Salvager | 킬당 크레딧 | 🆕 |

**구현 위치**: `godot/autoload/data_registry.gd:759-781`

---

## 7. 캠페인/섹터맵 비교

### 7.1 맵 구조

| 항목 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 노드 타입 | 섬 (전투) | 노드 (다양) | ✅ 확장 |
| 진행 방향 | 서→동 | 시작→게이트 | ✅ |
| 분기 | 선택적 경로 | DAG 구조 | ✅ |
| 적 전선 | 바이킹 전선 | Storm Line | ✅ |

### 7.2 노드 타입 (TFR 재설계)

| Bad North | TFR 노드 | 설명 | 상태 |
|-----------|----------|------|------|
| 전투 섬 | **STATION** | 기본 전투 | ✅ |
| 깃발 섬 (영입) | **RESCUE** | 구조 임무 → 팀장 합류 | 🔴 필요 |
| 물음표 섬 | **SALVAGE** | 난파선 탐색 → 장비 획득 | 🔄 변경 |
| - | **DEPOT** | 보급 정거장 → 무료 장비 | 🆕 |
| - | SHOP | 상점 | ✅ |
| - | REST | 휴식 + 회복 | ✅ |
| - | ELITE_STATION | 엘리트 전투 | ✅ |
| - | **STORM_STATION** | 폭풍 스테이지 (시야 제한) | 🆕 |
| - | BOSS | 보스 전투 | ✅ |
| - | GATE | 최종 점프 게이트 | ✅ |

**구현 위치**: `godot/scripts/generation/sector_generator.gd`

---

## 8. 경제 시스템 비교

### 8.1 수입/지출

| 항목 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 기본 단위 | Gold (골드) | Credits (크레딧) | ✅ |
| 시설별 수입 | 집 크기별 1-3 | 시설 타입별 1-3 | ✅ |
| 클래스 업그레이드 | 6 → 12 → 20 | 6 → 12 → 20 | ✅ |
| 스킬 업그레이드 | 7 → 10 → 14 | 7 → 10 → 14 | ✅ |

**구현 위치**: `godot/autoload/balance.gd:35-57`

```gdscript
"ECONOMY": {
    "heal_cost": 12,
    "rank_up_costs": {
        "veteran": 12,  # Bad North 동일
        "elite": 20,
    },
    "skill_upgrade_costs": {
        1: 7,  # Bad North 동일
        2: 10,
        3: 14,
    },
},
```

---

## 9. UI/UX 비교

### 9.1 화면 구성

| 화면 | Bad North | TFR (구현) | 상태 |
|------|-----------|------------|------|
| 메인 메뉴 | ✅ | main_menu.tscn | ✅ |
| 섹터맵 | ✅ | sector_map.tscn | ✅ |
| 전투 HUD | ✅ | battle.tscn | ✅ |
| 업그레이드 | ✅ | upgrade.tscn | ✅ |
| 설정 | ✅ | settings.tscn | ✅ |
| 게임오버 | ✅ | game_over.tscn | ✅ |
| 승리 | ✅ | victory.tscn | ✅ |

### 9.2 미구현 UI 요소

| 요소 | Bad North | TFR | 우선순위 |
|------|-----------|-----|----------|
| 웨이브 알림 화살표 | ✅ | ❌ | 높음 |
| 일시정지 메뉴 | ✅ | ❌ | 중간 |
| 전투 결과 화면 | ✅ | ❌ | 높음 |
| 새 아이템 획득 UI | ✅ | ❌ | 중간 |
| 로딩 화면 | ✅ | ❌ | 낮음 |

---

## 10. 미구현 / 차이점 요약

### 10.1 필수 구현 필요 (TFR 컨셉 기준)

**🔴 최우선 - TFR 고유 시스템**
| 항목 | 설명 | 이유 |
|------|------|------|
| **Raven 드론 시스템** | Scout/Resupply/Orbital Strike | ⭐ 핵심 차별점 |
| **시설 보너스** | 의료/무기고/통신탑/발전소 | 전략 깊이 |
| **용어 통일** | Commander→Team Leader 등 | 테마 일관성 |

**🔴 높음 - Bad North 핵심 + TFR 변환**
| 항목 | Bad North | TFR 변환 |
|------|-----------|----------|
| 재보급 취소 불가 | Replenish | Resupply 중 명령 차단 |
| 긴급 귀환 | Flee (보트) | Emergency Evac (Raven 셔틀) |
| 크루 영입 | 깃발 섬 | RESCUE 노드 (구조 임무) |
| 카메라/컨트롤 | Q/E, 휠, 스페이스 | Tactical Mode 연출 추가 |

**🟡 중간 - UI/UX**
| 항목 | 설명 |
|------|------|
| 웨이브 방향 표시 | Storm Line 접근 화살표 |
| 이동 가능 타일 | 타일 마커 |
| Raven 통신 UI | "Raven Scout 보고..." 메시지 |
| 숫자 키 분대 선택 | 1-4 키 바인딩 |

### 10.2 TFR 고유 차별점

| 항목 | Bad North | TFR | 이유 |
|------|-----------|-----|------|
| 분대 크기 | 9명 | 5-8명 (클래스별) | 클래스 특성 반영 |
| 클래스 수 | 3종 | **5종** (+Engineer, Bionic) | 전략 다양성 |
| 적 종류 | ~7종 | **13종 + 보스 2종** | 콘텐츠 확장 |
| **Raven 드론** | ❌ | **4가지 능력** | ⭐ 핵심 차별점 |
| **시설 보너스** | 집 (보상만) | **5종** (특수 효과) | 전략 깊이 |
| **폭풍 스테이지** | ❌ | **시야 제한 + 조명탄** | 긴장감 |
| **해킹 시스템** | ❌ | **Hacker vs 터렛** | 신규 상성 |
| **암살 메카닉** | ❌ | **바이오닉 2배 데미지** | 고위험 고보상 |
| 테마 | 중세 바이킹 | **우주 SF** | 차별화 |

### 10.3 구현 완료 핵심 메카닉

- ✅ Shield Block During Melee (교전 중 실드 비활성)
- ✅ Lance Raise (밀착 시 랜스 들어올림)
- ✅ Landing Knockback (상륙 넉백)
- ✅ Void Death (우주 공간 추락 즉사)
- ✅ Recovery Time (2초 × 분대 크기)
- ✅ 예산 기반 웨이브 생성
- ✅ DAG 기반 섹터맵
- ✅ BSP 기반 정거장 레이아웃

---

## 11. 다음 단계 권장사항 (TFR 컨셉 기반)

### 11.1 Phase 1: 핵심 차별점 (최우선)

1. **🚀 Raven 드론 시스템** ⭐
   - Scout (정찰): 다음 웨이브 미리보기
   - Resupply (긴급 보급): 1팀 즉시 회복
   - Orbital Strike (궤도 폭격): 지정 타일 고데미지
   - Raven HUD 버튼 4개

2. **🏭 시설 보너스 시스템**
   - 의료 모듈: 재보급 -50%
   - 무기고: 데미지 +20%
   - 통신탑: Raven 능력 +1회
   - 발전소: 터렛 +50%

3. **📝 용어 통일**
   - Commander → Team Leader
   - Replenish → Resupply
   - Flee → Emergency Evac

### 11.2 Phase 2: 컨트롤/UI

1. **카메라/컨트롤 시스템**
   - Q/E 키 회전
   - 마우스 휠 줌
   - 스페이스바 → **Tactical Mode** (Raven AI 지원)

2. **긴급 귀환(Emergency Evac) 시스템**
   - Emergency Evac 버튼 (셔틀 아이콘)
   - Raven 셔틀 하강/회수 연출
   - 크레딧 0 처리

3. **구조 임무(RESCUE) 노드**
   - SectorGenerator에 RESCUE 노드 타입
   - 탈출자 합류 이벤트
   - 새 팀장 + 초기 크루 보상

4. **UI 개선**
   - 웨이브 방향 화살표
   - 이동 가능 타일 마커
   - Raven 통신 메시지 ("Raven Scout 보고...")

### 11.3 Phase 3: 고유 시스템

1. **폭풍 스테이지**
   - STORM_STATION 노드
   - Fog of War (시야 제한)
   - Flare (조명탄) 능력

2. **엔지니어 메카닉**
   - 터렛 배치 시스템
   - 시설 수리 (20초)
   - 적 Hacker 해킹 시스템

3. **바이오닉 메카닉**
   - Blink (순간이동)
   - 암살 보너스 (비교전 시 2배 데미지)

### 11.4 Phase 4: 폴리시

1. **난이도 시스템** (Easy/Normal/Hard/Very Hard)
2. **비콘 활성화** (체크포인트 대체)
3. **메타 프로그레션** (영구 언락)
4. **Tactical Mode 연출** (스캔라인, HUD 오버레이)

---

## 12. 조작법/컨트롤 시스템 비교

> **출처**: `bad-north-controls.md`, `bad-north-research.md`

### 12.1 유닛 선택

| 조작 | Bad North | TFR (필요) | 상태 |
|------|-----------|------------|------|
| 마우스 클릭 | 유닛 직접 클릭 | 유닛 직접 클릭 | ✅ |
| 숫자 키 1-4 | 분대 빠른 선택 | ⚠️ 미구현 | 🟡 중간 |
| 키 바인딩 변경 | **불가** (고정) | 설정 가능 권장 | 🔄 개선 |

### 12.2 카메라 컨트롤

| 조작 | Bad North | TFR (필요) | 상태 |
|------|-----------|------------|------|
| 회전 | 마우스 우클릭 드래그 / Q, E | ⚠️ 미구현 | 🔴 필요 |
| 줌 | 마우스 휠 | ⚠️ 미구현 | 🔴 필요 |
| Invert X/Y | 설정에서 토글 | ⚠️ 미구현 | 🟡 |
| 회전 스냅 | 클릭=90도, 홀드=부드럽게 | ⚠️ 미구현 | 🟡 |

**카메라 특성 비교:**

| 특성 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 뷰 타입 | 등각 투영 (Isometric) | 등각 투영 | ✅ |
| 중심 | 섬 고정 회전 | 정거장 고정 | ✅ |
| 틸트 | 고정 | 고정 | ✅ |
| 팬 | 없음 (자동 중앙) | 없음 | ✅ |

### 12.3 게임 속도 컨트롤

| 조작 | Bad North | TFR (필요) | 상태 |
|------|-----------|------------|------|
| 일시정지 | **스페이스바** | ⚠️ 미구현 | 🔴 필요 |
| 유닛 선택 시 | 자동 슬로우 모션 | ⚠️ 미구현 | 🟡 중간 |
| 슬로우 배속 | ~0.3x (추정) | 미정 | 🟡 |

> **전략 가이드 인용**: "Like FTL, you should pause every time you need to think until it feels like turn-based strategy."

### 12.4 명령 UI 버튼

| 버튼 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| Deploy | 유닛 배치 | 유닛 배치 | ✅ |
| Skip Turn | 다음 웨이브 | ⚠️ 미구현 | 🟡 |
| Flee | 섬 탈출 | ⚠️ 미구현 | 🔴 필요 |

**⚠️ UI 크기 문제 (Bad North):**
> "deploy button and skip turn button are taking up about 10% of my screen"
> → TFR: 버튼 크기 최소화 권장

---

## 13. 로그라이트/메타 시스템 비교

> **출처**: `bad-north-progression.md`

### 13.1 캠페인 구조

| 항목 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 맵 타입 | 절차적 생성 섬 | 절차적 생성 노드 | ✅ |
| 진행 방향 | 서→동 (바이킹 전선) | 시작→게이트 | ✅ |
| 다중 경로 | FTL 스타일 분기 | DAG 분기 | ✅ |
| 런 길이 | 3-5시간 (첫 클리어) | 미정 | 🟡 |
| 단일 전투 | **5-15분** | 미정 | 🟡 참고 |

### 13.2 섬/노드 유형 비교

| Bad North | TFR | 설명 | 상태 |
|-----------|-----|------|------|
| 일반 전투 섬 | STATION | 기본 전투 | ✅ |
| 아이템 섬 (?) | EVENT | 랜덤 이벤트 | ✅ |
| 지휘관 섬 (깃발) | **미구현** | 크루 영입 | 🔴 필요 |
| 체크포인트 섬 | **미구현** | 진행 저장 | 🟡 고려 |
| - | SHOP | 상점 | 🆕 확장 |
| - | REST | 휴식 | 🆕 확장 |
| - | ELITE_STATION | 엘리트 전투 | 🆕 확장 |
| - | BOSS | 보스 전투 | 🆕 확장 |

### 13.3 체크포인트 시스템 (Jotunn Edition)

| 항목 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 체크포인트 존재 | ✅ (Jotunn Edition) | ❌ 없음 | 🟡 선택적 |
| 사망 시 복귀 | 마지막 체크포인트 | 런 종료 | 🟡 |
| 원본 (비Jotunn) | 처음부터 시작 | - | - |

**TFR 설계 결정**: 전통적 로그라이트 (체크포인트 없음) vs Jotunn 스타일 선택 필요

### 13.4 메타 프로그레션 (영구 언락)

| 항목 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 영구 언락 | 특성/아이템 일부 | ⚠️ 미정 | 🟡 설계 필요 |
| 시작 보너스 | 해금 아이템 장착 | ⚠️ 미정 | 🟡 |
| 시작 지휘관 | 2명 선택 | 2명 선택 | ✅ |

### 13.5 난이도 시스템

| 난이도 | Bad North | TFR | 상태 |
|--------|-----------|-----|------|
| Easy | ✅ | ⚠️ 미구현 | 🟡 |
| Normal | ✅ (기본) | ⚠️ 미구현 | 🟡 |
| Hard | ✅ | ⚠️ 미구현 | 🟡 |
| Very Hard | Hard 클리어 후 해금 | ⚠️ 미구현 | 🟡 |

**구현 위치**: `godot/autoload/balance.gd` - 난이도별 배율 상수 필요

### 13.6 긴급 귀환(Emergency Evac) 시스템 - TFR 재설계

| 항목 | Bad North | TFR (변경) | 상태 |
|------|-----------|------------|------|
| **명칭** | Flee (도주) | **Emergency Evac** (긴급 귀환) | 🔄 변경 |
| 트리거 | 빈 보트 탑승 | **Raven 기함이 셔틀 파견** | 🔄 변경 |
| 비용 | 해당 섬 코인 0 | 해당 정거장 크레딧 0 | ✅ 동일 |
| 전략적 용도 | 생존을 위한 포기 | 손실 최소화 | ✅ 동일 |
| Fearless 특성 | 철수 불가 (페널티) | **귀환 불가** | ✅ |

**TFR 긴급 귀환 시퀀스:**
1. **Emergency Evac** 버튼 클릭 (셔틀 아이콘)
2. Raven 기함에서 회수 셔틀 하강 (에어락 위치)
3. 각 분대가 셔틀로 이동
4. 모든 분대 탑승 시 이륙 → 정거장 이탈
5. 해당 정거장 크레딧 **0** (시설 방어 실패)

---

## 14. 시각적 분석 비교 (Visual Observation)

> **출처**: `VISUAL-OBSERVATION-ANALYSIS.md` (스크린샷 28장+, 전투 프레임 38장+)

### 12.1 색상 팔레트 비교

| 카테고리 | Bad North | TFR (구현) | 상태 |
|----------|-----------|------------|------|
| **아군 색상** | 파란색 (#4A90D9) | 클래스별 분화 | ✅ 확장 |
| **적 색상** | 검은색/갈색 (#2C2C2C, #5C4033) | 티어별 분화 | ✅ 확장 |
| **선택 하이라이트** | 녹색/노란색 | 녹색 (#68d391) | ✅ |
| **피/데미지** | 선명한 빨강 (#C41E3A) | 빨강 계열 | ✅ |
| **바다/배경** | 청회색 (#7BA3A8) | 우주 검정/보라 | 🔄 테마 변경 |
| **잔디/바닥** | 연녹색 (#90B77D) | 정거장 회색/금속 | 🔄 테마 변경 |

**TFR 클래스별 색상** (`3D-ASSET-PROMPTS.md` 기준):
- Guardian: #4a9eff (파란색)
- Sentinel: #f6ad55 (주황색)
- Ranger: #68d391 (녹색)
- Engineer: #ffd93d (노란색)
- Bionic: #c084fc (보라색)

### 12.2 유닛 시각적 식별 비교

| 요소 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| **깃발 시스템** | 지휘관 등 뒤 깃발 | ⚠️ 미구현 | 🔴 필요 |
| **선택 표시** | 깃발 위 녹색 원형 | 유닛 하단 원형 | ✅ 유사 |
| **이동 가능 표시** | 흰색 핀 마커 | ⚠️ 미구현 | 🟡 필요 |
| **유닛 구분** | 무기 형태 (창/검/활) | 무기 형태 (랜스/실드/라이플) | ✅ |
| **적 분대 크기** | 3-18명 (보트 크기별) | 예산 기반 가변 | ✅ |

### 12.3 전투 시각적 피드백 비교

| 요소 | Bad North | TFR (필요) | 우선순위 |
|------|-----------|------------|----------|
| **화살/발사체** | 밝은 직선 (살구/노란색) | 레이저/플라즈마 이펙트 | 높음 |
| **발사 각도** | 30-45도 포물선 | 직선 (에너지 무기) | 🔄 변경 |
| **피 스플래터** | 지면에 패턴, 전투 종료까지 유지 | ⚠️ 미구현 | 중간 |
| **시체 처리** | 땅에 쓰러진 형태 유지 | ⚠️ 미구현 | 중간 |
| **넉백 효과** | 물에 빠지면 즉사 | Void Death 구현 | ✅ |

### 12.4 보트/침투정 시스템 비교

| 요소 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| **색상** | 갈색/적갈색 (롱쉽) | SF 침투정 (회색/검정) | 🔄 테마 변경 |
| **크기 구분** | 소형(3-5), 중형(5-8), 대형(10+) | 예산 기반 | ✅ |
| **접근 표시** | 흰색 물결(wake) 효과 | ⚠️ 미구현 | 🟡 중간 |
| **정박 위치** | 해안가 타일 | 에어락 타일 | ✅ 동일 |
| **빈 보트** | 적 하선 후 해안 대기 | ⚠️ 미구현 | 낮음 |

### 12.5 UI/HUD 시각적 요소 비교

#### 명령 버튼 (Command Buttons)

| Bad North | TFR | 아이콘 | 상태 |
|-----------|-----|--------|------|
| Flee (도주) | ⚠️ 미구현 | 깃발 + 배 | 🔴 필요 |
| Replenish (회복) | Recovery | 십자가 + 집 | ✅ |
| Move (이동) | Move | 핀 마커 | ✅ |
| **버튼 수** | 3개 | 2-3개 | ⚠️ |

#### 전투 HUD 위치

| 요소 | Bad North 위치 | TFR 권장 | 상태 |
|------|---------------|----------|------|
| 커맨더 포트레이트 | 좌하단 | 좌하단 | ✅ |
| 명령 버튼 | 포트레이트 우측 | 포트레이트 우측 | ✅ |
| 일시정지 | 우상단 (∥ 아이콘) | 우상단 | ✅ |
| 골드/크레딧 | 우측 상단 | 우측 상단 | ✅ |

### 12.6 월드맵/섹터맵 시각 비교

| 요소 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| **노드 색상 (점령)** | 빨간색 | Storm 점령 노드 | ✅ |
| **노드 색상 (선택)** | 노란색 | 하이라이트 | ✅ |
| **노드 색상 (미방문)** | 청록/회색 | 회색 | ✅ |
| **경로 표시** | 점선(미래), 실선(가능) | ⚠️ 미구현 | 🟡 |
| **커맨더 수** | "4/4 Commanders" | 크루 수 표시 | ✅ |
| **턴 버튼** | "Next Turn" | ⚠️ 미구현 | 🟡 |

### 12.7 환경/날씨 효과

| 효과 | Bad North | TFR | 우선순위 |
|------|-----------|-----|----------|
| **비** | 물방울 + 빗줄기 + 물결 | ❌ 없음 | 낮음 |
| **맑음** | 기본 + 안개 | 기본 | ✅ |
| **황혼** | 붉은/보라 톤 | Storm Zone 효과 | ✅ |
| **지형 절벽** | 흰색 수직 면 | 정거장 외벽 | ✅ |
| **나무/덤불** | 녹색 구체 형태 | ❌ (SF 테마) | 🔄 |

### 12.8 승리/결과 화면 비교

| 요소 | Bad North | TFR (필요) | 상태 |
|------|-----------|------------|------|
| **섬/정거장 이름** | 필기체 표시 | 정거장 이름 | ✅ |
| **Victory 텍스트** | 회색 태그 | ⚠️ 미구현 | 🟡 |
| **골드/크레딧 분배** | 커맨더별 +/- 버튼 | ⚠️ 미구현 | 🔴 높음 |
| **활성 커맨더** | 노란색 하이라이트 | 색상 구분 | ✅ |
| **비활성/사망** | 회색 처리 | 회색 처리 | ✅ |
| **Continue 버튼** | Y키 바인딩 | 키 바인딩 필요 | 🟡 |

---

## 15. 시각적 요소 구현 우선순위

### 13.1 높음 (핵심 피드백)

| 항목 | Bad North 관측 | TFR 구현 필요 |
|------|---------------|---------------|
| 선택 표시 | 녹색 원형 아이콘 | ✅ 구현됨 |
| 이동 가능 타일 | 흰색 핀 마커 | 🔴 구현 필요 |
| 웨이브 방향 | 화면 가장자리 화살표 | 🔴 구현 필요 |
| 크레딧 분배 UI | +/- 버튼 | 🔴 구현 필요 |

### 13.2 중간 (전투 몰입)

| 항목 | Bad North 관측 | TFR 구현 필요 |
|------|---------------|---------------|
| 피 스플래터 | 지면 패턴, 지속 | 🟡 파티클 시스템 |
| 시체 유지 | 쓰러진 형태 | 🟡 리지드바디 |
| 침투정 접근 효과 | 물결(wake) | 🟡 트레일 이펙트 |
| 깃발 시스템 | 지휘관 등 뒤 | 🟡 3D 깃발 메쉬 |

### 13.3 낮음 (폴리시)

| 항목 | Bad North 관측 | TFR 구현 필요 |
|------|---------------|---------------|
| 날씨 효과 | 비/안개 | 🔵 파티클 + 포스트 |
| 황혼 톤 | 붉은/보라 | 🔵 조명 프리셋 |
| 빈 침투정 | 해안 대기 | 🔵 선택적 |

---

*문서 작성: 2026-02-04*
*최종 검증: 2026-02-04*

**비교 기준 문서:**
- `bad-north-research.md` - 공식 레퍼런스 (수치, 스크린샷)
- `bad-north-combat-data.md` - 유닛/전투 데이터
- `bad-north-progression.md` - 로그라이트/진행 시스템
- `bad-north-controls.md` - 조작법/컨트롤
- `bad-north-ui.md` - UI/UX 분석
- `VISUAL-OBSERVATION-ANALYSIS.md` - 시각적 관측 데이터
- `interface-in-game/INDEX.md` - 미디어 컬렉션 (영상 6개, 이미지 20개)
