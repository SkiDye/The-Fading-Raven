# 다음 단계

> **최종 업데이트**: 2026-02-05

## Git 규칙
- **푸시는 `main` 브랜치에** (master 아님)
- 원격 저장소: `https://github.com/SkiDye/The-Fading-Raven.git`

---

## 현재 상태

### Godot 4.x 3D 구현 진행률

| Phase | 내용 | 상태 | 완료일 |
|-------|------|------|--------|
| **Phase 1** | 3D 전투 엔티티 | ✅ 완료 | 2026-02-05 |
| **Phase 2** | 3D 섹터 맵 | ✅ 완료 | 2026-02-05 |
| **Phase 2.5** | 팀장 관리 & 업그레이드 | ✅ 완료 | 2026-02-05 |
| **Phase 3** | 정거장 미리보기 & 분대 선택 | ✅ 완료 | 2026-02-05 |
| **Phase 4** | 화면 전환 & 이펙트 | ✅ 완료 | 2026-02-05 |

---

## Phase 4 작업 목록 ✅ 완료

### 4.1 신규 씬 ✅
| 항목 | 설명 | 상태 |
|------|------|------|
| `NewGameSetup.tscn` | 새 게임 설정 (난이도, 시작 팀장 2명) | ✅ 완료 |
| `BattleResult.tscn` | 전투 결과 (획득 크레딧, 새 팀장/장비) | ✅ 완료 |

### 4.2 3D 엔티티 ✅
| 항목 | 설명 | 상태 |
|------|------|------|
| `Turret3D.tscn` | Engineer 터렛 (자동 공격 AI) | ✅ 완료 |
| `Projectile3D.tscn` | 투사체 (Ranger, Turret용) | ✅ 완료 |

### 4.3 3D 이펙트 ✅
| 항목 | 설명 | 상태 |
|------|------|------|
| `Explosion3D.tscn` | GPUParticles3D 폭발 이펙트 | ✅ 완료 |
| `HitEffect3D.tscn` | GPUParticles3D 피격 이펙트 | ✅ 완료 |
| `FloatingText3D.tscn` | Label3D 빌보드 데미지 숫자 | ✅ 완료 |

### 4.4 씬 전환 ✅
| 항목 | 설명 | 상태 |
|------|------|------|
| `SceneTransition.gd` | 씬 전환 시스템 (autoload) | ✅ 완료 |
| 페이드/크로스페이드/줌 | 다양한 전환 효과 지원 | ✅ 완료 |

### 4.5 레거시 정리 ✅ 완료
| 항목 | 설명 | 상태 |
|------|------|------|
| 2D 씬 삭제 | Battle.tscn, sector_map.tscn 등 | ✅ 완료 |
| 레거시 autoload | godot/autoload/ 삭제 | ✅ 완료 |
| 레거시 scripts | godot/scripts/ 삭제 | ✅ 완료 |
| 레거시 tests | godot/tests/ 삭제 | ✅ 완료 |

### 4.6 프로시저럴 3D 메시 ✅ 완료
| 항목 | 설명 | 상태 |
|------|------|------|
| CrewSquad3D | GLB 없을 시 클래스별 프로시저럴 메시 | ✅ 완료 |
| EnemyUnit3D | GLB 없을 시 적 타입별 프로시저럴 메시 | ✅ 완료 |
| Facility3D | GLB 없을 시 시설별 프로시저럴 메시 | ✅ 완료 |
| DropPod3D | GLB 없을 시 침투정 프로시저럴 메시 | ✅ 완료 |

---

## Phase 2.5 (업그레이드 시스템) ✅ 완료

### 구현 완료 항목
| 항목 | 설명 | 상태 |
|------|------|------|
| 팀장 목록 (좌측 패널) | 초상화, 클래스 아이콘, 체력 표시 | ✅ |
| 팀장 상세 (우측 패널) | 대형 초상화, 특성, 통계 | ✅ |
| 클래스 선택 | Militia → 5클래스 선택 (6크레딧) | ✅ |
| 클래스 업그레이드 | Standard → Veteran (12) → Elite (20) | ✅ |
| 스킬 업그레이드 | Lv1(7) → Lv2(10) → Lv3(14) | ✅ |
| 섹터 맵 연동 | U키, 팀장 슬롯 클릭 | ✅ |
| 장비 선택 모달 | 장비 변경 UI | 🔴 TODO |

---

## 전체 게임 플로우 (구현 완료)

```
[MainMenu.tscn] (2D)
    ↓ NEW GAME
[NewGameSetup.tscn] (2D) ✅
    - 난이도 선택
    - 시작 팀장 2명 선택
    ↓ START
[SectorMap3D.tscn] (3D) ←──────────────────────────┐
    │                                              │
    ├── 팀장 클릭 또는 U키 ──→ [UpgradeScreen] ✅ ─┘
    │                               └─ BACK 버튼
    │
    └── 노드 클릭
          ↓
[StationPreview3D.tscn] (3D) ✅
    ↓ CONTINUE
[SquadSelection.tscn] (2D) ✅
    ↓ DEPLOY
[Battle3D.tscn] (3D) ✅
    ↓ 승리/패배
[BattleResult.tscn] (2D) ✅
    ↓ CONTINUE
[SectorMap3D.tscn] (반복)
```

---

## 핵심 참조 문서

| 용도 | 경로 |
|------|------|
| **3D 구현 계획** | `docs/3D-IMPLEMENTATION-PLAN.md` |
| 인수인계 총정리 | `docs/handover/00-SUMMARY.md` |
| 상세 GDD | `docs/game-design/game-design-document.md` |
| 공유 상태 정의 | `docs/implementation/SHARED-STATE.md` |
| Bad North 레퍼런스 | `docs/references/bad-north/` |
| 3D 에셋 프롬프트 | `docs/assets/3D-ASSET-PROMPTS.md` |

---

## 핵심 주의사항

1. **Bad North 메카닉 유지** - 레퍼런스의 검증된 시스템
2. **TFR 고유 시스템 구현** - Raven 드론이 핵심 차별점
3. **용어 통일** - Team Leader, Resupply, Emergency Evac
4. **시드 기반 RNG** - 동일 시드 = 동일 결과 보장
5. **영구 사망** - 로그라이트 긴장감의 핵심
6. **GLB 모델 규격** - 1유닛=1타일, 바닥 중앙 원점, -Z 전방

---

## 즉시 시작 가능한 작업

### 옵션 A: 통합 테스트 (권장)
1. 전체 게임 플로우 테스트 (메뉴 → 섹터맵 → 전투 → 결과)
2. 버그 수정
3. 밸런스 조정

### ~~옵션 B: 레거시 정리~~ ✅ 완료
- ~~2D 씬 삭제~~ ✅
- ~~레거시 autoload/scripts/tests 정리~~ ✅
- ~~프로시저럴 3D 메시 추가~~ ✅

### 옵션 B: 콘텐츠 확장
1. 추가 적 유닛 구현
2. 추가 장비 구현
3. 사운드/음악 통합

### 옵션 C: GLB 3D 모델 추가
1. 크루 클래스 GLB 모델 (guardian, sentinel, ranger, engineer, bionic)
2. 적 유닛 GLB 모델 (rusher, gunner, shield_trooper 등)
3. 시설 GLB 모델 (residential, medical, armory 등)

---

*최종 업데이트: 2026-02-05*
