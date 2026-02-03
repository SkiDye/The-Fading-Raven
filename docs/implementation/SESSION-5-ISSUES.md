# Session 5 Issues Report

작성: Session 5
최종 수정: Session 5 (2026-02-03)

---

## 해결된 이슈

### CSS 변수 불일치 문제 ✅

**상태:** 해결됨

Session 5에서 생성한 CSS 파일들이 `common.css`와 다른 변수명을 사용하던 문제 수정.

**수정된 파일:**
- `demo/css/ui-components.css` ✅
- `demo/css/hud.css` ✅
- `demo/css/effects.css` ✅

---

### M-002: BattleController 의존성 처리 ✅

**상태:** 해결됨

**수정 내용:**
- `battle-effects-integration.js`에서 BattleController 미존재 시 조건부 경고
- 전투 페이지에서만 경고 출력, 다른 페이지에서는 무시

---

### M-003: 구매 확인 절차 부재 ✅

**상태:** 해결됨

**수정 내용:**
- `upgrade.js`의 `performUpgrade()` 및 `buyEquipment()`에 `ModalManager.confirm` 추가
- 힐링, 스킬 강화, 승급, 장비 구매 시 확인 대화상자 표시

---

### M-004: 장비 해제 확인 부재 ✅

**상태:** 해결됨

**수정 내용:**
- `upgrade.js`에 `unequipItem()` 함수 추가
- 장착 장비 섹션 UI 추가 (해제 버튼 포함)
- 해제 시 확인 대화상자 표시
- `panel.css`에 관련 스타일 추가

---

### M-005: 업그레이드 효과 미리보기 부족 ✅

**상태:** 해결됨

**수정 내용:**
- `upgrade.js`에 `getSkillPreview()` 함수 추가
- 스킬 강화 확인 시 다음 레벨 효과 미리보기 표시
- 승급 보너스 (최대 병력 +1) 명시

---

### L-002: 키보드 단축키 도움말 부재 ✅

**상태:** 해결됨

**수정 내용:**
- `settings.html`에 CONTROLS 탭 추가
- 전투 조작, Raven 드론, 카메라 조작, 게임 속도, 일반 단축키 목록
- `panel.css`에 키바인드 스타일 추가

---

### L-003: 시드 형식 안내 부재 ✅

**상태:** 해결됨

**수정 내용:**
- `index.html`의 시드 입력 모달에 형식 안내 개선
- placeholder와 hint 텍스트 보강

---

### L-004: 난이도 해금 조건 표시 부재 ✅

**상태:** 해결됨

**수정 내용:**
- `difficulty.js`의 난이도 데이터에 `unlockCondition` 필드 추가
- 잠긴 난이도에 구체적인 해금 조건 표시 (예: "보통 난이도 클리어")

---

### L-005: 런 요약 정보 부족 ✅

**상태:** 해결됨

**수정 내용:**
- `result.js`의 `displayStats()` 확장
- 전투 시간, 스킬 사용 횟수, 가한/받은 피해 표시 지원
- 적 유형별 처치 수 breakdown 표시
- `result.css`에 확장 통계 스타일 추가

---

### 접근성(A11y) 개선 ✅

**상태:** 해결됨

**수정 내용 (`ui-components.js`):**

**Tooltip:**
- `role="tooltip"` 추가
- `aria-hidden` 속성 토글 (show/hide 시)

**Toast:**
- 컨테이너에 `role="region"`, `aria-live="polite"`, `aria-label` 추가
- 에러 토스트에 `role="alert"`, 일반 토스트에 `role="status"` 적용
- 닫기 버튼에 `aria-label="알림 닫기"` 추가
- 아이콘에 `aria-hidden="true"` 추가

**Modal:**
- `role="dialog"`, `aria-modal="true"` 추가
- `aria-labelledby`로 제목 연결
- 닫기 버튼에 `aria-label="닫기"` 추가
- 포커스 트랩 구현 (Tab 키가 모달 내에서만 순환)
- 모달 닫힐 때 이전 포커스 요소로 복원

**ProgressBar:**
- `role="progressbar"` 추가
- `aria-valuemin`, `aria-valuemax`, `aria-valuenow` 속성 지원
- 값 변경 시 aria 속성 자동 업데이트

**Loading:**
- `role="alert"`, `aria-live="assertive"` 추가
- `aria-busy` 속성으로 로딩 상태 표시
- `aria-describedby`로 로딩 텍스트 연결
- 스피너에 `aria-hidden="true"` 추가

---

### battle.html 스크립트 임포트 누락 ✅

**상태:** 해결됨

**문제:**
- `battle.html`에서 `hud.js`가 임포트되지 않아 HUD 시스템이 작동하지 않음

**수정 내용:**
- `demo/pages/battle.html`에 `<script src="../js/ui/hud.js"></script>` 추가

**참고:**
- `WaveManager` 클래스는 `wave-generator.js`에 이미 포함되어 있음 (별도 파일 불필요)
- `enemy.js`, `behavior-tree.js`, `enemy-mechanics.js`는 이미 임포트되어 있었음

---

## Bad North 스타일 전투 메카닉 구현 ✅

**상태:** 구현 완료

Bad North 레퍼런스 문서를 분석하여 전투 밸런스 시스템 구현.

### 고우선순위 기능

**1. Landing Knockback System ✅**
- 적 상륙 시 근처 크루에게 넉백 적용
- 공식: `knockback = baseKnockback × boatSizeMultiplier × enemyCountFactor / unitGradeResistance`
- Steady Stance 특성으로 80% 저항
- 강한 넉백 시 기절 효과

**2. Shield Mechanics (Guardian) ✅**
- 원거리 공격 90% 피해 감소
- 근접전 중에는 실드 비활성화 (핵심 전술 요소)
- 전방 90도 각도 내에서만 차단

**3. Lance Raise (Sentinel) ✅**
- 적이 30px 이내로 접근하면 랜스 들어올림
- 랜스가 올라간 상태에서는 공격 불가
- 탈출 방법: Shock Wave 장비, 후퇴, 아군 지원
- 최적 거리(40-80px)에서 1.5배 데미지

**4. Recovery Time Formula ✅**
- Bad North 공식: 2초 × 분대원 수
- Quick Recovery 특성으로 33% 단축
- 회복 중 시설 파괴 시 난이도별 페널티

### 중간 우선순위 기능

**5. Unit Grade Combat Scaling ✅**
- Standard/Veteran/Elite 등급별 전투력 차등
- 공격력, 방어력, 이동속도, 공격속도 스케일링
- 최대 분대 크기: 8/9/10
- 넉백 저항: 1.0/1.5/2.0
- 사기(Morale) 시스템 추가

**6. Void Knockback Combo ✅**
- 넉백으로 우주(void)로 밀려나면 즉사
- Elite 유닛 30% 확률로 절벽 잡기 가능
- 3초 내 아군 구조 가능
- Binary search로 마지막 유효 위치 계산

**7. Wave Progression Patterns ✅**
- Early/Mid/Late/Boss 웨이브 패턴
- 난이도별 패턴 진행 속도 조절
- 동시 상륙, 순차 상륙, 파상 공격, 급습 타이밍
- 난이도별 동시 스폰 포인트 제한

### 수정된 파일

**demo/js/data/balance.js:**
- `landingKnockback` 섹션 추가
- `shield` 메카닉 섹션 추가
- `lance` 메카닉 섹션 추가
- `melee` 전투 상태 섹션 추가
- `unitGrades` 등급별 스탯 섹션 추가
- `wavePatterns` 웨이브 패턴 섹션 추가
- `environmental` 환경 위험 섹션 추가
- API 메서드 다수 추가

**demo/js/core/combat-mechanics.js (신규):**
- `applyLandingKnockback()` - 상륙 넉백
- `wouldFallIntoVoid()` - 추락 체크
- `calculateShieldedDamage()` - 실드 피해 계산
- `updateLanceState()` - 랜스 상태 업데이트
- `checkLanceEscapeOptions()` - 랜스 탈출 옵션
- `calculateRecoveryTime()` - 회복 시간 계산
- `canStartRecovery()` / `handleRecoveryInterruption()` - 회복 시스템
- `processKnockbackWithVoidCheck()` - 넉백 + 추락 처리
- `findNearestEdge()` / `attemptLedgeRescue()` - 절벽 잡기
- `calculateGradeScaledDamage()` - 등급 스케일링
- `getGradeScaledMoveSpeed()` / `getGradeScaledAttackSpeed()` - 속도 스케일링
- `checkMorale()` - 사기 체크
- `getFullCombatState()` - 전체 전투 상태

**demo/pages/battle.html:**
- `combat-mechanics.js` 스크립트 임포트 추가

---

## 아이소메트릭 시스템 호환성 업데이트 ✅

**상태:** 완료

Session 2의 2.5D 아이소메트릭 렌더링 시스템과 전투 메카닉 연동.

### 추가된 좌표계 유틸리티

**`combat-mechanics.js` 업데이트:**

```javascript
// 좌표계 변환 유틸리티
getUnitTilePosition(unit, tileGrid)     // 픽셀/타일 좌표 → 타일 좌표
getUnitHeight(unit, stationLayout)       // HeightSystem 연동 높이 조회
getKnockbackDirection(attacker, defender) // 카메라 회전 고려한 넉백 방향
knockbackPxToTiles(knockbackPx)          // 픽셀 → 타일 거리 변환
```

### 호환성 수정 사항

| 함수 | 수정 내용 |
|------|----------|
| `wouldFallIntoVoid()` | 타일 좌표 지원, StationLayout 형식 대응 |
| `isHeightBlocked()` | 높이 차이 체크 (신규) |
| `getDistanceBetween()` | 타일/픽셀 좌표 모두 지원 |
| `getTileDistance()` | 타일 거리 계산 (신규) |
| `getAngleBetween()` | 타일/픽셀 좌표 모두 지원 |
| `processKnockbackWithVoidCheck()` | finalTilePosition 반환, IsometricRenderer 연동 |
| `findNearestEdgeTile()` | 타일 기반 엣지 탐색 (신규) |
| `findNearestEdge()` | 레거시 호환 유지 + 타일 기반 변환 |

### 연동되는 Session 2 시스템

- `IsometricRenderer.tileToScreen()` - 타일 → 스크린 좌표 변환
- `IsometricRenderer.screenToTileInt()` - 스크린 → 타일 좌표 변환
- `IsometricRenderer.camera.rotation` - 카메라 회전 상태
- `HeightSystem.getEntityHeight()` - 엔티티 높이 조회
- `HeightSystem.getLayoutTileHeight()` - 타일 높이 조회

---

## 전투 시스템 등급 스케일링 연동 ✅

**상태:** 완료

Unit Grade (standard/veteran/elite) 스케일링을 실제 전투 시스템에 연동.

### battle.js 추가 헬퍼 함수

```javascript
getCrewMoveSpeed(crew)    // 등급 + 특성 적용된 최종 이동속도
getCrewAttackSpeed(crew)  // 등급 적용된 최종 공격속도(쿨다운)
```

### 적용된 위치

| 위치 | 기존 | 변경 |
|------|------|------|
| 경로 이동 | `crew.moveSpeed` | `this.getCrewMoveSpeed(crew)` |
| 직접 이동 | `crew.moveSpeed` | `this.getCrewMoveSpeed(crew)` |
| 추격 이동 | `crew.moveSpeed` | `this.getCrewMoveSpeed(crew)` |
| 공격 쿨다운 | `crew.attackSpeed` | `this.getCrewAttackSpeed(crew)` |

### 등급별 효과

| 등급 | 이동속도 | 공격속도 |
|------|----------|----------|
| Standard | ×1.0 | ×1.0 (기본) |
| Veteran | ×1.05 | ÷1.1 (10% 빠름) |
| Elite | ×1.1 | ÷1.2 (20% 빠름) |

*swiftMovement 특성은 별도로 ×1.33 적용*

---

## 기타 참고사항

- `hud.js`는 battle.html의 기존 HUD와 별개로 설계됨 (사용 안 함)
- `battle-effects-integration.js`로 기존 전투 시스템에 이펙트 연결됨
- JS 파일들은 문법 오류 없음 (node --check 통과)
- Bad North 전투 메카닉은 `CombatMechanics` 글로벌 객체로 접근 가능
