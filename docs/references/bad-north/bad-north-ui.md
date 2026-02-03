# Bad North UI/UX 분석

> 출처: [Interface In Game](https://interfaceingame.com/games/bad-north/), Steam Store

## 개요

Bad North는 미니멀하고 깔끔한 UI 디자인이 특징인 로그라이트 실시간 전술 게임입니다. 귀여운 비주얼과 잔인한 전투의 대비를 UI에서도 그대로 반영하여, 복잡한 요소를 최소화하면서도 필요한 정보를 직관적으로 전달합니다.

---

## 1. 메인 메뉴 (Main Menu)

![Main Menu](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-main-menu.jpg)

### 구성요소
- **타이틀**: "BAD NORTH" 로고 (상단 중앙)
- **메뉴 옵션**: 세로 중앙 정렬
  - Continue (계속하기)
  - New Game (새 게임)
  - Settings (설정)
  - Exit (나가기)
- **배경**: 동적 섬 풍경 (실제 게임플레이 화면)

### 디자인 특징
- 흰색 텍스트, 반투명 배경 없음
- 선택된 항목은 밝은 하이라이트
- 미니멀리스트 접근 - 불필요한 장식 요소 제거
- 폰트: 산세리프, 가독성 높음

**참조**: [Main Menu Screenshot](https://interfaceingame.com/screenshots/bad-north-main-menu/)

---

## 2. 인게임 HUD (In-Game HUD)

### 2.1 기본 HUD 요소

게임 중 화면은 매우 깔끔하며, HUD 요소를 최소화합니다.

![Move](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-move.jpg)

#### 구성요소
- **커맨더 포트레이트**: 화면 하단 또는 측면
  - 원형/사각형 아이콘
  - 유닛 타입 표시 (검/창/활)
  - 체력바 (세로 바 형태)
- **골드 표시**: 우측 상단 (코인 아이콘 + 숫자)
- **일시정지 버튼**: 좌측 상단 모서리

### 2.2 유닛 선택 시 시각적 피드백

![Select Commanders](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-select-commanders.jpg)

#### 선택 피드백
- **원형 하이라이트 링**: 선택된 유닛 아래 원형 표시
- **밝은 색상**: 선택 유닛이 더 밝게 표시
- **이동 가능 영역**: 클릭 시 이동 가능한 타일에 흰색/밝은 표시
- **갓레이(God Ray) 효과**: 없음 - 대신 깔끔한 원형 선택 표시 사용

![Select Your Squads](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-select-your-squads.jpg)

**참조**: 
- [Select Commanders](https://interfaceingame.com/screenshots/bad-north-select-commanders/)
- [Select Your Squads](https://interfaceingame.com/screenshots/bad-north-select-your-squads/)

### 2.3 유닛 이동/배치

![Move](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-move.jpg)

- 이동 명령 시 경로 표시 없음 (직관적 이동)
- 배치 가능 타일에 하이라이트
- 드래그 앤 드롭 방식

**참조**: [Move Screenshot](https://interfaceingame.com/screenshots/bad-north-move/)

---

## 3. 웨이브 알림 UI (Wave Notification)

![Final Wave Incoming](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-final-wave-incoming.jpg)

### 구성요소
- **방향 화살표**: 적 침공 방향을 화면 가장자리에 화살표로 표시
- **보트 아이콘**: 접근하는 바이킹 보트가 직접 보임
- **Final Wave 텍스트**: 마지막 웨이브 시 화면 중앙에 "FINAL WAVE" 텍스트 표시

### 디자인 특징
- 침공 방향이 화면 밖일 경우 화살표 UI로 방향 표시
- 화살표 색상/크기로 위협 수준 암시
- 텍스트 알림은 최소화 - 시각적 요소로 전달

**참조**: [Final Wave Incoming](https://interfaceingame.com/screenshots/bad-north-final-wave-incoming/)

---

## 4. 섹터맵/월드맵 UI (World Map)

![Map](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-map.jpg)

### 구성요소
- **섬 노드**: 각 섬을 점/아이콘으로 표시
  - 클리어한 섬: 어둡거나 체크 표시
  - 선택 가능 섬: 밝게 하이라이트
  - 현재 위치: 특별 표시
- **연결선**: 섬 간 이동 경로를 선으로 연결
- **보상 아이콘**: 각 섬에 획득 가능 보상 미리보기
  - 골드 코인
  - 새 커맨더
  - 아이템
- **난이도 표시**: 적 숫자/아이콘으로 난이도 암시

### 디자인 특징
- 로그라이크 스타일의 노드 기반 맵
- 좌→우 진행 방향
- 분기점에서 전략적 선택 가능
- 배경: 바다/안개 효과

**참조**: [Map Screenshot](https://interfaceingame.com/screenshots/bad-north-map/)

---

## 5. 업그레이드 화면 UI (Upgrade Screen)

![Buy Upgrades](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-buy-upgrades.jpg)

![Commander](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-commander.jpg)

### 구성요소
- **커맨더 정보 패널**:
  - 커맨더 이름
  - 현재 클래스/타입
  - 스탯 표시
- **스킬트리/업그레이드 옵션**:
  - 클래스 업그레이드 (Infantry → Pike → etc.)
  - 아이템 슬롯
  - 스킬 레벨업
- **비용 표시**: 각 업그레이드 옆에 골드 비용
- **보유 골드**: 상단에 현재 골드 표시

### 디자인 특징
- 카드 기반 UI
- 선형적인 업그레이드 경로 (복잡한 트리 없음)
- 직관적인 비교 가능 레이아웃
- 뒤로가기/확인 버튼 명확

**참조**: 
- [Buy Upgrades](https://interfaceingame.com/screenshots/bad-north-buy-upgrades/)
- [Commander](https://interfaceingame.com/screenshots/bad-north-commander/)
- [Upgrades Available](https://interfaceingame.com/screenshots/bad-north-upgrades-available/)

---

## 6. 전투 결과 화면 (Battle Results)

### 구성요소
- **생존 정보**:
  - 살아남은 커맨더 표시
  - 사망한 커맨더 (X 표시 또는 회색)
- **획득 보상**:
  - 골드 획득량
  - 새 아이템
  - 새 커맨더 영입
- **섬 상태**: 집이 파괴되었는지 표시

### 디자인 특징
- 간결한 요약
- 다음 단계로 자연스러운 전환
- 손실에 대한 시각적 강조 (퍼마데스 시스템)

**참조**: [New Item](https://interfaceingame.com/screenshots/bad-north-new-item/)

![New Item](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-new-item.jpg)

---

## 7. 일시정지 메뉴 (Pause Menu)

![Paused](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-paused.jpg)

### 구성요소
- **PAUSED 텍스트**: 화면 중앙 상단
- **메뉴 옵션**:
  - Resume (계속하기)
  - Restart Island (섬 재시작)
  - Settings (설정)
  - Quit to Menu (메뉴로)
- **게임 화면**: 배경에 흐릿하게 유지

### 디자인 특징
- 반투명 오버레이 (어두운 배경)
- 메인 메뉴와 일관된 스타일
- 빠른 접근 가능한 옵션들

**참조**: [Paused Screenshot](https://interfaceingame.com/screenshots/bad-north-paused/)

---

## 8. 설정 화면 (Settings)

![Controls](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-controls.jpg)

### 구성요소
- **컨트롤 설정**: 키 바인딩 표시
- **오디오 설정**: 볼륨 슬라이더
- **그래픽 설정**: 해상도, 품질 옵션

**참조**: [Controls Screenshot](https://interfaceingame.com/screenshots/bad-north-controls/)

---

## 9. 로딩 화면 (Loading)

![Generating New Campaign](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-generating-new-campaign.jpg)

### 구성요소
- **상태 텍스트**: "Generating islands..." 등
- **프로그레스 표시**: 로딩 진행 상태
- **배경**: 게임 아트워크 또는 단색

**참조**: 
- [Generating New Campaign](https://interfaceingame.com/screenshots/bad-north-generating-new-campaign/)
- [Generating Islands](https://interfaceingame.com/screenshots/bad-north-generating-islands/)

---

## 10. 시작 화면 (Start Screen)

![Start](https://interfaceingame.com/wp-content/uploads/bad-north/bad-north-start.jpg)

### 구성요소
- **게임 타이틀/로고**
- **"Press Any Key" 프롬프트**
- **배경 아트**: 게임 분위기를 전달하는 풍경

**참조**: [Start Screenshot](https://interfaceingame.com/screenshots/bad-north-start/)

---

## UI/UX 디자인 원칙 요약

### 1. 미니멀리즘
- 불필요한 UI 요소 제거
- 게임플레이에 집중할 수 있는 깔끔한 화면
- 정보는 필요할 때만 표시

### 2. 직관적 피드백
- 선택 = 하이라이트 (원형 링, 밝기 변화)
- 위협 = 방향 화살표 + 시각적 요소
- 진행 = 간단한 노드 맵

### 3. 일관된 비주얼 언어
- 전체적으로 통일된 색상 팔레트
- 산세리프 폰트
- 반투명 요소 최소화

### 4. 컨텍스트 기반 정보
- HUD는 평소 최소 표시
- 상호작용 시 관련 정보만 표시
- 오버레이는 간결하게

### 5. 로그라이트 특성 반영
- 퍼마데스를 명확히 표시
- 진행 상황을 시각적으로 전달
- 선택의 무게감을 UI로 표현

---

## 스크린샷 참조 링크

| 카테고리 | 스크린샷 수 | 링크 |
|---------|------------|------|
| In game | 11 | [보기](https://interfaceingame.com/screenshots/?elements=in-game&game=bad-north) |
| Menu | 8 | [보기](https://interfaceingame.com/screenshots/?elements=main-menu&game=bad-north) |
| Overlay | 6 | [보기](https://interfaceingame.com/screenshots/?elements=overlay&game=bad-north) |
| Skill tree | 5 | [보기](https://interfaceingame.com/screenshots/?elements=skill-tree&game=bad-north) |
| Progress | 4 | [보기](https://interfaceingame.com/screenshots/?elements=progress&game=bad-north) |
| Map | 2 | [보기](https://interfaceingame.com/screenshots/?elements=map&game=bad-north) |
| Loading | 2 | [보기](https://interfaceingame.com/screenshots/?elements=loading&game=bad-north) |
| Settings | 2 | [보기](https://interfaceingame.com/screenshots/?elements=settings&game=bad-north) |

**전체 스크린샷**: [Interface In Game - Bad North](https://interfaceingame.com/games/bad-north/)

---

## Steam 정보

- **개발사**: Plausible Concept, Oskar Stålberg
- **퍼블리셔**: Raw Fury
- **출시일**: 2018년 11월 16일
- **장르**: Action, Indie, Simulation
- **Steam Deck**: Verified ✓
- **평점**: Very Positive (5,250+ 리뷰)

**Steam 페이지**: https://store.steampowered.com/app/688420/Bad_North_Jotunn_Edition/
