# Bad North 리서치 vs The Fading Raven 구현 비교

> 리서치 문서와 현재 Godot 구현 상태 비교 분석

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

## 4. 회복(Replenish) 시스템 비교

### 4.1 회복 시간 공식

| 항목 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 기본 공식 | 2초 × 분대크기 | 2초 × 분대크기 | ✅ 동일 |
| 기본 (8명) | 16초 | 16초 | ✅ |
| Ring Lv1 (12명) | 24초 | 22초 | ⚠️ |
| Rousing Speeches | -33% | -33% (Quick Recovery) | ✅ |

**구현 위치**: `godot/autoload/balance.gd:48-51`

```gdscript
"RECOVERY": {
    "base_time_per_unit": 2.0,  # Bad North 동일
    "facility_bonus": 0.5,
},
```

### 4.2 회복 조건

| 조건 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 시설 필요 | 집 점거 | 시설 점거 | ✅ 동일 |
| 취소 불가 | ✅ | ⚠️ 미구현 | 🔴 필요 |
| 중단 시 손실 | 분대 손실 가능 | ⚠️ 미구현 | 🔴 필요 |

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

### 7.2 노드 타입 (TFR 확장)

| 타입 | Bad North | TFR | 상태 |
|------|-----------|-----|------|
| 전투 | 섬 | STATION | ✅ |
| 지휘관 영입 | 깃발 섬 | (미구현) | 🔴 |
| 아이템 | 물음표 섬 | EVENT | ✅ |
| 상점 | - | SHOP | 🆕 |
| 휴식 | - | REST | 🆕 |
| 엘리트 | - | ELITE_STATION | 🆕 |
| 보스 | - | BOSS | 🆕 |
| 탈출 | - | GATE | 🆕 |

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

### 10.1 필수 구현 필요

| 항목 | 설명 | 우선순위 |
|------|------|----------|
| 회복 취소 불가 | 회복 중 명령 불가 | 🔴 높음 |
| 회복 중단 시 손실 | 시설 파괴 시 분대 손실 | 🔴 높음 |
| 지휘관 영입 노드 | 깃발 섬 대응 | 🔴 높음 |
| 도주 시스템 | 빈 침투정으로 탈출 | 🟡 중간 |
| 웨이브 방향 표시 | 화면 가장자리 화살표 | 🟡 중간 |

### 10.2 의도적 차이점

| 항목 | Bad North | TFR | 이유 |
|------|-----------|-----|------|
| 분대 크기 | 9명 | 8명 | 클래스별 차등화 |
| 클래스 수 | 3종 | 5종 | 전략 다양성 |
| 적 종류 | ~7종 | 13종 | 콘텐츠 확장 |
| Raven 드론 | - | 4가지 능력 | 차별화 요소 |
| 시설 종류 | 집만 | 7종 | 전략 다양성 |

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

## 11. 다음 단계 권장사항

### 11.1 즉시 수정 필요

1. **회복 시스템 완성**
   - 회복 중 명령 차단
   - 회복 중 시설 파괴 시 손실 처리

2. **지휘관 영입 노드 추가**
   - SectorGenerator에 RECRUIT 노드 타입 추가
   - 영입 전투 로직 구현

### 11.2 다음 Phase 고려

1. **도주(Flee) 시스템**
2. **웨이브 방향 표시 UI**
3. **전투 결과 화면**
4. **Raven 드론 능력 구현**

---

## 12. 시각적 분석 비교 (Visual Observation)

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

## 13. 시각적 요소 구현 우선순위

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
*비교 기준: bad-north-reference.md, bad-north-combat-data.md, bad-north-progression.md, VISUAL-OBSERVATION-ANALYSIS.md*
