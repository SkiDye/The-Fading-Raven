# UI Components Documentation - Session 5

## Overview

Session 5에서 구현한 UI 시스템의 API 문서입니다.

---

## 파일 구조

```
demo/
├── css/
│   ├── ui-components.css    # 공통 UI 컴포넌트 스타일
│   ├── effects.css          # 시각 효과 스타일
│   └── hud.css              # HUD 스타일
└── js/ui/
    ├── ui-components.js     # Tooltip, Toast, Modal, ProgressBar, Loading
    ├── effects.js           # ScreenEffects, Transitions, Particles, FloatingText
    └── hud.js               # HUD, MiniMap
```

---

## 1. UI Components (`ui-components.js`)

### 1.1 Tooltip

마우스 오버 시 정보 표시.

**HTML 사용법:**
```html
<button data-tooltip="툴팁 내용" data-tooltip-title="제목">버튼</button>
```

**프로그래매틱 사용:**
```javascript
Tooltip.showAt(x, y, '제목', '내용');
Tooltip.hide();
```

---

### 1.2 Toast

토스트 알림 메시지.

```javascript
// 기본 사용
Toast.show('메시지', 'info', 3000);  // type: 'info' | 'success' | 'warning' | 'error'

// 편의 메서드
Toast.info('정보 메시지');
Toast.success('성공!');
Toast.warning('경고!');
Toast.error('오류 발생!');
```

**옵션:**
- `message`: 표시할 메시지
- `type`: 'info' | 'success' | 'warning' | 'error'
- `duration`: 표시 시간 (ms), 0이면 자동으로 사라지지 않음

---

### 1.3 ModalManager

모달 대화상자 관리.

```javascript
// 커스텀 모달
ModalManager.open({
    id: 'my-modal',
    title: '제목',
    content: '<p>HTML 내용</p>',
    size: 'medium',  // 'small' | 'medium' | 'large'
    buttons: [
        { label: '취소', class: 'btn-secondary', onClick: (mgr, id) => mgr.close(id) },
        { label: '확인', class: 'btn-primary', onClick: (mgr, id) => { /* ... */ } }
    ],
    closeOnEsc: true,
    closeOnOverlay: true,
    onClose: () => console.log('닫힘')
});

// 확인 대화상자
ModalManager.confirm('정말 삭제하시겠습니까?',
    () => { /* 확인 */ },
    () => { /* 취소 */ }
);

// 알림 대화상자
ModalManager.alert('작업이 완료되었습니다.', () => { /* 확인 */ });

// 모달 닫기
ModalManager.close('my-modal');
ModalManager.closeAll();
```

---

### 1.4 ProgressBar

진행 표시줄 생성.

```javascript
// 생성
const progress = ProgressBar.create({
    value: 50,
    max: 100,
    showLabel: true,
    labelFormat: 'percent',  // 'percent' | 'value' | 'custom'
    customLabel: (value, max) => `${value}/${max}`,
    color: 'success',  // 'accent' | 'success' | 'warning' | 'danger' | '#hexcolor'
    size: 'medium',    // 'small' | 'medium' | 'large'
    animated: true,
    striped: true
});

container.appendChild(progress);

// 업데이트
ProgressBar.update(progress, 75, 100);

// 색상 변경
ProgressBar.setColor(progress, 'danger');
```

---

### 1.5 Loading

전체 화면 로딩 표시.

```javascript
// 표시/숨김
Loading.show('로딩 중...');
Loading.hide();

// 비동기 작업 래핑
const result = await Loading.wrap(fetchData(), '데이터 로딩 중...');
```

---

## 2. Effects System (`effects.js`)

### 2.1 ScreenEffects

화면 효과.

```javascript
// 화면 쉐이크
ScreenEffects.shake({
    intensity: 10,      // 강도 (픽셀)
    duration: 300,      // 지속시간 (ms)
    type: 'both',       // 'horizontal' | 'vertical' | 'both'
    frequency: 50       // 진동 빈도 (ms)
});

// 화면 플래시
ScreenEffects.flash({
    color: 'white',
    duration: 200,
    intensity: 0.5
});

// 프리셋
ScreenEffects.damage('medium');  // 'light' | 'medium' | 'heavy'
ScreenEffects.heal();
ScreenEffects.criticalHit();
ScreenEffects.explosion();
```

---

### 2.2 TransitionEffects

화면 전환 효과.

```javascript
// 페이드 전환
await TransitionEffects.fade(async () => {
    // 화면이 어두워진 동안 실행될 코드
    loadNewScene();
}, { color: '#000', duration: 300 });

// 슬라이드 전환
await TransitionEffects.slide(callback, 'left', 400);  // 'left' | 'right' | 'up' | 'down'
```

---

### 2.3 ElementAnimations

요소 애니메이션.

```javascript
// 펄스
ElementAnimations.pulse(element, { scale: 1.1, duration: 300, repeat: 2 });

// 흔들기
ElementAnimations.wiggle(element, { intensity: 5, duration: 500 });

// 바운스
ElementAnimations.bounce(element, { height: 10, duration: 400 });

// 페이드
await ElementAnimations.fadeIn(element, 300);
await ElementAnimations.fadeOut(element, 300);

// 슬라이드
await ElementAnimations.slideIn(element, 'left', 300);

// 타이핑 효과
await ElementAnimations.typeText(element, '타이핑 텍스트', { speed: 50, cursor: true });

// 숫자 카운트업
ElementAnimations.countUp(element, 0, 1000, {
    duration: 1000,
    format: (v) => `${Math.floor(v)} 원`
});
```

---

### 2.4 ParticleSystem

파티클 효과.

```javascript
// 커스텀 파티클
ParticleSystem.emit(x, y, {
    count: 10,
    colors: ['#4a9eff', '#48bb78'],
    size: { min: 4, max: 8 },
    speed: { min: 50, max: 150 },
    lifetime: { min: 500, max: 1000 },
    gravity: 100,
    spread: 360  // 방출 각도 (도)
});

// 프리셋
ParticleSystem.explosion(x, y, '#ff6b00');
ParticleSystem.sparkle(x, y);
ParticleSystem.credits(x, y);
ParticleSystem.damage(x, y);
```

---

### 2.5 FloatingText

플로팅 텍스트.

```javascript
// 커스텀
FloatingText.show(x, y, '텍스트', {
    color: '#ffffff',
    fontSize: '1rem',
    duration: 1000,
    rise: 50,
    type: 'default'  // 'default' | 'damage' | 'heal' | 'critical' | 'miss'
});

// 프리셋
FloatingText.damage(x, y, 25);
FloatingText.heal(x, y, 10);
FloatingText.critical(x, y, 50);
FloatingText.miss(x, y);
FloatingText.credits(x, y, 100);
```

---

## 3. HUD System (`hud.js`)

전투 중 표시되는 정보 UI.

### 3.1 초기화

```javascript
HUD.init('#battle-hud');  // 또는 기본 컨테이너 자동 생성
```

### 3.2 상태 업데이트

```javascript
// 웨이브 정보
HUD.updateWave(currentWave, totalWaves);

// 적 수
HUD.updateEnemyCount(count);

// 시설 상태
HUD.updateFacilities([
    { id: 'f1', name: '발전소', health: 80, maxHealth: 100, isDestroyed: false },
    // ...
]);

// 크레딧
HUD.updateCredits(amount, animate);

// 크루 목록
HUD.updateCrews([
    { id: 'c1', name: '알렉스', classId: 'guardian', className: '가디언',
      health: 6, maxHealth: 8, skill: { name: 'Shield Bash', isReady: true } },
    // ...
]);

// 크루 선택
HUD.selectCrew('c1');
HUD.selectCrewByIndex(0);  // 1번 키
```

### 3.3 알림

```javascript
// 웨이브 알림
HUD.announceWave(3, '대규모 공격!');

// 일반 알림
HUD.alert('메시지', 'info', 3000);

// 프리셋
HUD.alertFacilityDamage('발전소');
HUD.alertFacilityDestroyed('발전소');
HUD.alertCrewDown('알렉스');
HUD.alertWaveComplete();
```

### 3.4 콜백 설정

```javascript
HUD.onCrewSelect = (crew) => { /* 크루 선택 시 */ };
HUD.onSkillUse = (crew) => { /* 스킬 사용 */ };
HUD.onEquipmentUse = (crew) => { /* 장비 사용 */ };
HUD.onPauseToggle = (isPaused) => { /* 일시정지 토글 */ };
HUD.onSpeedChange = (speed) => { /* 속도 변경 */ };
```

### 3.5 표시/숨김

```javascript
HUD.show();
HUD.hide();
```

---

## 4. CSS 클래스

### 애니메이션 유틸리티

```html
<div class="fade-in">페이드 인</div>
<div class="slide-in-left">슬라이드 인</div>
<div class="scale-in">스케일 인</div>
<div class="pop-in">팝 인</div>
<div class="shake">흔들기</div>
<div class="attention">주목</div>
<div class="glow">글로우</div>
<div class="float">플로트</div>
```

### 전투 관련

```html
<div class="wave-warning">웨이브 경고</div>
<div class="low-health">낮은 체력</div>
<div class="skill-ready">스킬 준비</div>
<div class="hit-flash">피격</div>
<div class="death-animation">사망</div>
```

---

## 5. 초기화 순서

모든 UI 시스템은 DOMContentLoaded 시 자동 초기화됩니다.

```html
<!-- 권장 로드 순서 -->
<link rel="stylesheet" href="css/common.css">
<link rel="stylesheet" href="css/ui-components.css">
<link rel="stylesheet" href="css/effects.css">
<link rel="stylesheet" href="css/hud.css">

<script src="js/ui/ui-components.js"></script>
<script src="js/ui/effects.js"></script>
<script src="js/ui/hud.js"></script>
```

수동 초기화:
```javascript
UIComponents.init();  // Tooltip, Toast, Modal, Loading
Effects.init();       // ScreenEffects, Transitions, Particles, FloatingText
HUD.init();           // HUD 시스템
```

---

## 6. 접근성 지원

Settings에서 설정 가능:
- Screen Shake 끄기
- Screen Flash 끄기
- 색맹 모드 (Protanopia, Deuteranopia, Tritanopia)
- 텍스트 크기 조절 (80% ~ 120%)
- 고대비 모드
- 애니메이션 최소화
- 난독증 친화 폰트
