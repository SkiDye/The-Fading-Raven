# 다음 단계

## Git 규칙
- **푸시는 `main` 브랜치에** (master 아님)
- 원격 저장소: `https://github.com/SkiDye/The-Fading-Raven.git`

---

## 현재 상태
- 웹 프로토타입 완성
- Godot 4.x 이관 진행 중
- TFR 컨셉 재설계 완료

---

## 구현 우선순위 (TFR 컨셉 기반)

### Phase 1: 핵심 차별점 (⭐ 최우선)

1. **Raven 드론 시스템**
   - Scout (정찰): 다음 웨이브 미리보기
   - Flare (조명탄): 폭풍 스테이지 시야
   - Resupply (긴급 보급): 1팀 즉시 회복
   - Orbital Strike (궤도 폭격): 지정 타일 고데미지
   - Raven HUD 버튼 4개

2. **시설 보너스 시스템**
   - 의료 모듈: Resupply -50%
   - 무기고: 데미지 +20%
   - 통신탑: Raven 능력 +1회
   - 발전소: 터렛 +50%

3. **용어 통일**
   - Commander → Team Leader
   - Replenish → Resupply
   - Flee → Emergency Evac

### Phase 2: 컨트롤/UI

1. **카메라/컨트롤**
   - Q/E 키 회전
   - 마우스 휠 줌
   - 스페이스바 일시정지

2. **Tactical Mode**
   - 크루 선택 시 자동 진입
   - ~0.3배 시간 감속
   - Raven AI 연출 (HUD, 스캔라인)

3. **긴급 귀환 (Emergency Evac)**
   - Emergency Evac 버튼 (셔틀 아이콘)
   - Raven 셔틀 하강/회수 연출
   - 크레딧 0 처리

4. **구조 임무 (RESCUE)**
   - SectorGenerator에 RESCUE 노드
   - 탈출자 보호 전투
   - 새 팀장 + 크루 4명 보상

### Phase 3: 고유 시스템

1. **폭풍 스테이지**
   - STORM_STATION 노드
   - Fog of War (시야 제한)
   - Flare (조명탄) 연동

2. **엔지니어 메카닉**
   - 터렛 배치 시스템
   - 시설 수리 (20초)
   - 적 Hacker 해킹

3. **바이오닉 메카닉**
   - Blink (순간이동)
   - 암살 보너스 (비교전 시 2배)

### Phase 4: 폴리시

1. 난이도 시스템 (Easy/Normal/Hard/Very Hard)
2. 비콘 활성화 (BEACON 노드)
3. 메타 프로그레션 (영구 언락)
4. Tactical Mode 연출 완성

---

## Godot 이관 계획

### 3 Phase 구조
| Phase | 목표 | 주요 작업 |
|-------|------|----------|
| **1** | 코어 + 데이터 | GameState, Resource 변환, RNG |
| **2** | 전투 시스템 | TileMap, 크루/적, 웨이브 |
| **3** | UI + 캠페인 | 섹터 맵, 메타 진행, 폴리시 |

### 사전 준비
- [ ] Godot 4.2+ 설치
- [ ] MCP 설치 (godot-mcp 권장)
- [ ] Claude Code MCP 연동

### 웹 → Godot 매핑
```
js/data/*.js       → resources/*.tres
js/core/game-state.js → autoload/game_state.gd
js/pages/battle.js → scripts/combat/battle_controller.gd
```

---

## 주요 참조 문서

| 용도 | 경로 |
|------|------|
| **레퍼런스 비교 (필독)** | `docs/implementation/REFERENCE-COMPARISON.md` |
| 상세 GDD | `docs/game-design/game-design-document.md` |
| Godot 이관 계획 | `docs/implementation/GODOT-MIGRATION.md` |
| 공유 상태 정의 | `docs/implementation/SHARED-STATE.md` |
| 전투 시스템 | `docs/implementation/combat-system.md` |
| 적 AI | `docs/implementation/enemy-ai.md` |
| 3D 에셋 프롬프트 | `docs/assets/3D-ASSET-PROMPTS.md` |

---

## 핵심 주의사항

1. **Bad North 메카닉 유지** - 레퍼런스의 검증된 시스템
2. **TFR 고유 시스템 구현** - Raven 드론이 핵심 차별점
3. **용어 통일** - Team Leader, Resupply, Emergency Evac
4. **시드 기반 RNG** - 동일 시드 = 동일 결과 보장
5. **영구 사망** - 로그라이트 긴장감의 핵심
