# Session 3 Issues Report

검토일: 2026-02-03
작성: Session 3
수정 담당: Session 1
**수정 완료: 2026-02-03 (Session 3)**

---

## 높음 (High)

### 1. Conditions 싱글톤 공유 문제 - **[수정 완료]**
- **파일:** `demo/js/ai/behavior-tree.js`
- **위치:** Line 314-346
- **문제:** `Conditions.hasTarget`, `Conditions.canAttack` 등이 싱글톤 인스턴스로 정의됨. 여러 적이 동시에 AI 업데이트될 때 SequenceNode/SelectorNode의 `currentIndex`가 공유되어 상태 충돌 발생
- **해결:** Conditions 객체의 각 항목을 팩토리 함수로 변경 (매번 새 ConditionNode 인스턴스 반환)

---

## 중간 (Medium)

### 2. Math.random() 사용 - **[수정 완료]**
- **파일:** `demo/js/ai/enemy-mechanics.js`
- **위치:** Line 390
- **문제:** `spawnDrones`에서 `Math.random()` 사용 → 리플레이 불일치
- **해결:** `context.rng` 사용, fallback으로 `{ random: () => Math.random() }` 제공

### 3. 터렛 직접 수정 - **[수정 완료]**
- **파일:** `demo/js/ai/enemy-mechanics.js`
- **위치:** Line 117-125
- **문제:** `completeHacking`에서 `turret.isHacked`, `turret.team` 직접 수정. Session 2의 TurretSystem 인터페이스 미사용
- **해결:** 이벤트 기반 방식으로 변경 - `hackingComplete` 이벤트만 발생시키고 TurretSystem이 처리하도록 위임

### 4. 빈 spawnPoints 미처리 - **[수정 완료]**
- **파일:** `demo/js/core/wave-generator.js`
- **위치:** SpawnPatterns 전체 (Line 97-276)
- **문제:** `spawnPoints = []`일 때 `rng.pick([])` → undefined → 크래시
- **해결:** `getSafeSpawnPoints()` 헬퍼 함수 추가, `DEFAULT_SPAWN_POINT = { x: 0, y: 0 }` fallback

### 5. 정면 실드 각도 계산 - **[수정 완료]**
- **파일:** `demo/js/entities/enemy.js`
- **위치:** Line 270
- **문제:** 두 각도 차이 계산 시 0과 2π 경계 처리 미흡
- **해결:** 각도 차이를 -π ~ π 범위로 정규화하는 로직 추가

---

## 낮음 (Low)

### 6. 중복 조건문 - **[수정 완료]**
- **파일:** `demo/js/core/wave-generator.js`
- **위치:** Line 422
- **코드:** `if (!template.stormOnly && isStormStage && !template.stormOnly)`
- **해결:** `if (isStormStage && !template.stormOnly)` 로 수정

### 7. Fallback 트리 미캐싱 - **[수정 완료]**
- **파일:** `demo/js/ai/behavior-tree.js`
- **위치:** Line 1156-1157
- **문제:** 알 수 없는 behaviorId일 때 `melee_basic()` 생성하지만 캐시 안 함
- **해결:** `BehaviorPatterns.melee_basic` 팩토리 참조 반환으로 변경 (호출 시마다 새 인스턴스)

### 8. ES2022 클래스 필드 - **[수정 완료]**
- **파일:** `demo/js/entities/enemy.js`
- **위치:** Line 466
- **코드:** `_events = {}`
- **문제:** 구형 브라우저 미지원
- **해결:** constructor에서 `this._events = {}` 초기화로 이동

### 9. setTimeout 사용 - **[수정 완료]**
- **파일:** `demo/js/entities/enemy.js`
- **위치:** Line 410
- **문제:** 게임 일시정지 시에도 타이머 실행
- **해결:** `deathTimer`를 사용한 게임 루프 기반 타이머로 변경, `update()`에서 처리

---

## 수정 완료 요약

모든 9개 이슈가 Session 3에서 직접 수정 완료됨:

| # | 우선순위 | 이슈 | 상태 |
|---|----------|------|------|
| 1 | 높음 | Conditions 싱글톤 | 완료 |
| 2 | 중간 | Math.random | 완료 |
| 3 | 중간 | 터렛 직접 수정 | 완료 |
| 4 | 중간 | 빈 spawnPoints | 완료 |
| 5 | 중간 | 정면 실드 각도 | 완료 |
| 6 | 낮음 | 중복 조건문 | 완료 |
| 7 | 낮음 | Fallback 미캐싱 | 완료 |
| 8 | 낮음 | ES2022 클래스 필드 | 완료 |
| 9 | 낮음 | setTimeout | 완료 |
