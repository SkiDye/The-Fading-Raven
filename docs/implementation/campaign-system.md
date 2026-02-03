# Campaign System Implementation

## Session 4 구현 요약

### 구현된 모듈

#### 1. SectorGenerator (`demo/js/core/sector-generator.js`)

DAG 기반 섹터 맵 생성기.

**주요 기능:**
- 난이도별 맵 깊이 (12-25 레이어)
- 노드 타입 분포 규칙에 따른 자동 배치
- Storm Front 시스템
- 경로 유효성 검증

**노드 타입:**
| 타입 | 설명 | 아이콘 |
|------|------|--------|
| start | 시작점 | 🚀 |
| battle | 일반 전투 | ⚔️ |
| commander | 팀장 영입 | 🚩 |
| equipment | 장비 획득 | ❓ |
| storm | 폭풍 스테이지 | ⚡ |
| boss | 보스 전투 | 💀 |
| rest | 휴식 | 💚 |
| gate | 점프 게이트 (최종) | 🚪 |

**API:**
```javascript
// 맵 생성
const sectorMap = SectorGenerator.generate(rng, 'normal');

// 노드 방문
SectorGenerator.visitNode(sectorMap, nodeId);

// 폭풍 전진
SectorGenerator.advanceStormFront(sectorMap);

// 접근성 업데이트
SectorGenerator.updateAccessibility(sectorMap);

// 게이트 도달 가능 여부
SectorGenerator.hasPathToGate(sectorMap);

// 위험 노드 조회
SectorGenerator.getNodesAtRisk(sectorMap);

// 통계
SectorGenerator.getStats(sectorMap);
```

---

#### 2. StationGenerator (`demo/js/core/station-generator.js`)

BSP 기반 정거장 레이아웃 생성기.

**주요 기능:**
- 난이도 기반 맵 크기 (5x5 ~ 11x11)
- BSP 알고리즘으로 방 생성
- MST 기반 복도 연결
- 시설 배치 (크레딧 가치 포함)
- 스폰 포인트 (에어락) 배치
- 지형 변화 (고지대/저지대)
- A* 경로 탐색

**타일 타입:**
| 코드 | 타입 | 설명 |
|------|------|------|
| 0 | VOID | 우주 (즉사) |
| 1 | FLOOR | 바닥 |
| 2 | WALL | 벽 |
| 3 | FACILITY | 시설 |
| 4 | AIRLOCK | 에어락 |
| 5 | ELEVATED | 고지대 |
| 6 | LOWERED | 저지대 |
| 7 | CORRIDOR | 복도 |

**API:**
```javascript
// 레이아웃 생성
const layout = StationGenerator.generate(rng, difficultyScore);

// 이동 가능 여부
StationGenerator.isWalkable(layout, x, y);

// 경로 탐색
const path = StationGenerator.findPath(layout, x1, y1, x2, y2);

// 디버그 출력
console.log(StationGenerator.toAscii(layout));
```

---

#### 3. MetaProgress (`demo/js/core/meta-progress.js`)

런 간 영구 진행 시스템.

**주요 기능:**
- 클래스/장비/특성 해금
- 난이도 해금
- 도전 과제 시스템
- 통계 추적
- 시드 저장

**해금 조건:**
```javascript
// 클래스
engineer: 첫 클리어
bionic: Hard 클리어

// 난이도
hard: Normal 클리어
veryhard: Hard 클리어
nightmare: Very Hard 클리어
```

**API:**
```javascript
// 해금 확인
MetaProgress.isClassUnlocked('engineer');
MetaProgress.isEquipmentUnlocked('shieldGenerator');

// 런 완료 처리
const result = MetaProgress.processRunCompletion(runData);
// result = { newUnlocks: [...], newAchievements: [...] }

// 통계 조회
MetaProgress.getStats();
```

---

### 개선된 모듈

#### SectorController (`demo/js/pages/sector.js`)

**변경 사항:**
- SectorGenerator 통합
- 새 노드 타입 UI 지원
- 폭풍 전선 시각화 개선
- 난이도 표시 (점)
- 경로 경고 시스템

---

## 의존성

```
Session 1 (Data)
├── CrewData
├── EquipmentData
├── TraitData
└── BalanceData (사용 예정)
    ↓
Session 4 (Campaign)
├── SectorGenerator
├── StationGenerator
├── MetaProgress
└── SectorController
```

## 다른 세션과의 연동

### Session 2 (Combat) 연동 필요:
- `StationGenerator.generate()` 결과를 전투 시스템에 전달
- 타일 타입에 따른 이동/전투 로직

### Session 3 (Enemies/AI) 연동 필요:
- `SectorGenerator` 난이도 점수 → 웨이브 구성
- 노드 타입별 적 구성 (boss, storm 등)

---

## 테스트

### 맵 생성 테스트:
```javascript
const rng = new MultiStreamRNG(12345);
const map = SectorGenerator.generate(rng.get('sectorMap'), 'normal');
console.log(SectorGenerator.getStats(map));
```

### 정거장 생성 테스트:
```javascript
const rng = new MultiStreamRNG(12345);
const layout = StationGenerator.generate(rng.get('stationLayout'), 3.0);
console.log(StationGenerator.toAscii(layout));
```
