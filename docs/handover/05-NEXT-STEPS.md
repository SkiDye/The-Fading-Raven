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
| **Phase 2.5** | 팀장 관리 & 업그레이드 | 🔴 대기 | - |
| **Phase 3** | 정거장 미리보기 & 분대 선택 | ✅ 완료 | 2026-02-05 |
| **Phase 4** | 화면 전환 & 이펙트 | 🔴 대기 | - |

---

## Phase 4 작업 목록

### 4.1 신규 씬
| 항목 | 설명 | 우선순위 |
|------|------|----------|
| `NewGameSetup.tscn` | 새 게임 설정 (난이도, 시작 팀장 2명, 시작 장비) | P0 |
| `BattleResult.tscn` | 전투 결과 (획득 크레딧, 새 팀장/장비) | P0 |

### 4.2 미구현 3D 엔티티
| 항목 | 설명 | 우선순위 |
|------|------|----------|
| `Turret3D.tscn` | Engineer 터렛 (자동 공격 AI) | P1 |
| `Projectile3D.tscn` | 투사체 (Ranger, Turret용) | P1 |

### 4.3 3D 이펙트
| 항목 | 설명 | 우선순위 |
|------|------|----------|
| `Explosion3D.tscn` | GPUParticles3D 폭발 이펙트 | P2 |
| `HitEffect3D.tscn` | GPUParticles3D 피격 이펙트 | P2 |
| `FloatingText3D.tscn` | Label3D 빌보드 데미지 숫자 | P2 |

### 4.4 씬 전환
| 전환 | 효과 | 우선순위 |
|------|------|----------|
| 메뉴 → 섹터 맵 | 페이드 아웃/인 | P2 |
| 섹터 맵 → 미리보기 | 카메라 줌인 (3D 트랜지션) | P2 |
| 미리보기 → 전투 | 크로스페이드 | P2 |
| 전투 → 결과 | 슬로우 페이드 | P2 |

### 4.5 레거시 정리
| 항목 | 설명 | 우선순위 |
|------|------|----------|
| 2D 씬 삭제 | Battle.tscn, sector_map.tscn 등 | P3 |
| 레거시 autoload | godot/autoload/ 정리 | P3 |

---

## Phase 2.5 (업그레이드 시스템)

### 목표
UpgradeScreen.tscn 개선 - Bad North 스타일 업그레이드

### 작업 항목
| 항목 | 설명 |
|------|------|
| 팀장 목록 (좌측 패널) | 초상화, 클래스 아이콘, 상태 텍스트 |
| 팀장 상세 (우측 패널) | 대형 초상화, 특성, 통계 |
| 클래스 선택 | Militia → 5클래스 선택 (6크레딧) |
| 클래스 업그레이드 | Standard → Veteran (12) → Elite (20) |
| 스킬 업그레이드 | Lv1(7) → Lv2(10) → Lv3(14) |
| 장비 업그레이드 | Lv2(8), Lv3(14-16) |

---

## 전체 게임 플로우 목표

```
[MainMenu.tscn] (2D)
    ↓ NEW GAME
[NewGameSetup.tscn] (2D) 🔴 신규
    - 난이도 선택
    - 시작 팀장 2명 선택
    - 시작 장비/특성 선택
    ↓ START
[SectorMap3D.tscn] (3D) ←──────────────────────────┐
    │                                              │
    ├── 팀장 초상화 클릭 ────→ [UpgradeScreen] ───┘
    │   (또는 U키)                  │
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
[BattleResult.tscn] (2D) 🔴 신규
    ↓ CONTINUE
[UpgradeScreen.tscn] (2D) ← 전투 후 자동 (선택적)
    ↓ DONE
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

### 옵션 A: Phase 4 진행
1. `NewGameSetup.tscn` 구현
2. `BattleResult.tscn` 구현
3. `Turret3D.tscn` 구현
4. 씬 전환 트랜지션

### 옵션 B: Phase 2.5 진행
1. `UpgradeScreen.tscn` 개선
2. 클래스/스킬 업그레이드 UI
3. 섹터 맵과 연동

### 옵션 C: 통합 테스트
1. 전체 게임 플로우 테스트
2. 버그 수정
3. 밸런스 조정

---

*최종 업데이트: 2026-02-05*
