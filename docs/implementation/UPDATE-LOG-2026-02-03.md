# 2026-02-03 세션별 작업 로그

## Session 2 (세션 6): 2.5D 아이소메트릭 렌더링 시스템

**새 모듈 (demo/js/rendering/):**
| 파일 | 역할 |
|------|------|
| `isometric-renderer.js` | 좌표 변환, 카메라 시스템 |
| `height-system.js` | 타일 높이 매핑 (0-3 레벨) |
| `tile-renderer.js` | 타일/시설/스폰포인트 렌더링 |
| `depth-sorter.js` | 깊이 정렬, 엔티티 선택 |

**전투 시각 개선 (Phase 1-3):**
- Phase 1: 공격 예비동작(windup), 크리티컬 히트, 방향 표시기
- Phase 2: 피격 반응(플래시/넉백), 향상된 사망 애니메이션, 스킬 발동 이펙트
- Phase 3: 투사체 트레일/글로우, 부드러운 체력바, 호흡 애니메이션, 웨이브 전환 효과

**크루 분대원 시각화:**
- 크루 주변에 분대원 사람 형상(머리+몸통) 표시
- 생존/사망 분대원 구분 (색상/투명도)

**이펙트 좌표 시스템 수정:**
- `getEffectPos(entity)`, `addEffectAtEntity()` 헬퍼 함수 추가
- 아이소메트릭 모드에서 타일→화면 좌표 변환 적용

---

## Session 3: Enemy/AI 통합 및 UX 개선

**battle.js Enemy 클래스 통합:**
```javascript
// Enemy class 인스턴스 감지 및 처리
updateEnemy(enemy, dt) {
    if (typeof enemy.update === 'function') {
        enemy.update(dt, context);
        this.updateEntityTilePosition(enemy);  // 아이소메트릭 지원
    }
}
```

**수정된 UX 이슈 (7건):**
| 이슈 | 내용 |
|------|------|
| L-001 | AIManager 클래스 문서화 |
| M-008 | 특수 행동 경고 이벤트 (`specialActionWarning`) |
| M-009 | Shield Generator 보호 범위 시각화 (`getShieldVisuals`) |
| M-010 | 웨이브 미리보기 (`getNextWavePreview`, `getWaveWarnings`) |
| L-008 | 드론 스폰 경고 (`droneSpawnWarning`) |
| L-009 | 보스 페이즈 경고 (`bossPhaseWarning`) |
| L-010 | 처치 통계 (`death` 이벤트 강화) |

**2.5D 렌더링 호환성 검증:**
- Enemy.visual 속성 지원 확인
- DepthSorter 픽셀→타일 좌표 변환 확인
- updateEntityTilePosition() 연동 확인

---

## Session 4: UI/UX 개선 및 전투 시스템 통합

**반응형 레이아웃:**
- 3단계 브레이크포인트 (1024px, 768px, 480px)
- 모바일 터치 타겟 44x44px 보장
- 모달 전체화면 전환

**전투 Phase 1-3 아이소메트릭 통합:**
- `renderCrewIsometric()` Phase 1-3 모두 적용
- `renderEnemyIsometric()` Phase 1-3 모두 적용
- 양쪽 렌더링 경로 동기화

---

## Session 5: 키보드 도움말 및 전투 메카닉

**L-002 해결:**
- `battle.html`: 키보드 도움말 모달 추가
- `battle.js`: `showKeyboardHelp()`, `hideKeyboardHelp()` 구현
- `?` 키로 도움말 토글

**Bad North 전투 메카닉 추가:**
- `combat-mechanics.js`: 등급 시스템, 히트박스, 반응 시간 계산
- `balance.js`: COMBAT_BALANCE 설정 추가
- Landing Knockback, Shield Mechanics, Lance Raise
- Recovery Time, Unit Grade Scaling, Void Knockback Combo
- Wave Progression Patterns

**버그 수정:**
- result.js: `sectorMap` iteration error (map is not iterable)
- result.js: `currentNode.row` → `currentNode.depth`
- result.js: `sectorMap.length` → `sectorMap.totalDepth`

---

## 공통 버그 수정

### Utils.navigateTo() 수정 (세션 3)
```javascript
// 수정 전: '../' (파일 없음 → Chrome crbug/1173575 오류)
// 수정 후: '../index.html' (명시적 파일)
if (page === 'index') {
    targetPath = isInPagesFolder ? '../index.html' : './index.html';
} else {
    targetPath = isInPagesFolder ? `${page}.html` : `pages/${page}.html`;
}
```

### battle.html 스크립트 로드 수정 (세션 3)
- 추가: `enemy.js`, `behavior-tree.js`, `enemy-mechanics.js`
- 제거: 잘못된 `wave-manager.js` 참조

### deploy.js 배치 영역 수정 (세션 3)
- 빈 spawnPoints 배열 처리 (NaN 방지)
- 후보 없을 때 전체 맵 검색 폴백
- 최종 폴백: 고정 위치 배치 영역

---

## 향후 작업 참고사항

### 새 시각 효과 추가 시
- `renderCrew()` + `renderCrewIsometric()` 모두 업데이트
- `renderEnemy()` + `renderEnemyIsometric()` 모두 업데이트

### Enemy 클래스 확장 시
- `battle.js updateEnemy()` 호환성 확인
- `tileX/tileY` 속성 또는 `updateEntityTilePosition()` 호출

### 이펙트 추가 시
- 아이소메트릭 모드: `getEffectPos()` 또는 `addEffectAtEntity()` 사용
- 레거시 모드: entity.x/y 직접 사용 가능
