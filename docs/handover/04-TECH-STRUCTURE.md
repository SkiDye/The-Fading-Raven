# 기술 스택 및 구조

## 현재 상태: 웹 프로토타입

### 기술 스택
| 영역 | 기술 |
|------|------|
| 렌더링 | Canvas API |
| 언어 | Vanilla JavaScript (ES6+) |
| 스타일 | CSS3 + 커스텀 변수 |
| 상태 관리 | localStorage |
| RNG | Seeded Xorshift128+ |
| 빌드 시스템 | 없음 (순수 바닐라) |

---

## 핵심 파일

### Core 시스템
```
demo/js/core/
├── utils.js      # 유틸리티 (수학, 애니메이션, 이벤트)
├── rng.js        # 시드 기반 RNG (7개 독립 스트림)
└── game-state.js # 게임 상태 관리 (localStorage)
```

### 페이지 컨트롤러
```
demo/js/pages/
├── menu.js       # 메인 메뉴
├── difficulty.js # 난이도 선택
├── sector.js     # 섹터 맵
├── deploy.js     # 배치 화면
├── battle.js     # 전투 (핵심)
├── result.js     # 결과 화면
└── upgrade.js    # 업그레이드
```

---

## RNG 스트림 구조
```javascript
// 7개 독립 스트림 - 시스템 간 RNG 간섭 방지
{
  sectorMap,    // 캠페인 맵 생성
  stationLayout, // 정거장 레이아웃
  enemyWaves,   // 적 스폰
  items,        // 아이템 드롭
  traits,       // 특성 부여
  combat,       // 전투 RNG
  visual        // 시각 효과
}
```

---

## 컨트롤러 패턴
```javascript
class PageController {
  cacheElements() { /* DOM 참조 캐시 */ }
  bindEvents() { /* 이벤트 리스너 */ }
  init() { /* 초기화 */ }
  render() { /* 화면 렌더링 */ }
}
```

---

## 진입점
- `demo/index.html` → 메인 메뉴
- 스크립트 로딩 순서: core → pages
