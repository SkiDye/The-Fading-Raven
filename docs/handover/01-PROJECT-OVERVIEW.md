# 프로젝트 개요

## The Fading Raven
**장르**: 실시간 전술 로그라이트 (Bad North 영감)
**테마**: 우주 SF - 정거장 방어
**현재 상태**: 웹 프로토타입 완성, Godot 이관 예정

---

## 핵심 컨셉
> "희미해져 가는 성간 네트워크에서, Raven 드론과 함께 마지막 정거장들을 지켜라"

플레이어는 우주 폭풍(Storm Line)과 해적단 침략으로부터 정거장 네트워크를 방어하는 함대 사령관.

---

## TFR 핵심 차별점 (Bad North 대비)

| 시스템 | 설명 |
|--------|------|
| **Raven 드론** | Scout/Flare/Resupply/Orbital Strike 4능력 |
| **시설 보너스** | 의료(-50%), 무기고(+20%), 통신탑, 발전소 |
| **5클래스** | +Engineer (터렛), +Bionic (암살) |
| **폭풍 스테이지** | 시야 제한 + 조명탄 |
| **Tactical Mode** | Raven AI 지원 연출 |

---

## TFR 용어 정의

| Bad North | TFR |
|-----------|-----|
| Commander | **Team Leader (팀장)** |
| Replenish | **Resupply (재보급)** |
| Flee | **Emergency Evac (긴급 귀환)** |
| Slow Motion | **Tactical Mode** |
| Viking Wave | **Storm Line** |

---

## 게임 루프
```
메뉴 → 난이도 선택 → 섹터 맵 → 배치 (Tactical Mode) → 전투 → 결과 → (반복) → 승리/게임오버
```

---

## 프로젝트 구조
```
The-Fading-Raven/
├── demo/                 # 웹 프로토타입
│   ├── js/core/         # 핵심 시스템 (RNG, GameState)
│   ├── js/pages/        # 페이지 컨트롤러
│   └── pages/           # HTML 템플릿
├── godot/               # Godot 4.x 프로젝트
│   ├── autoload/        # 전역 시스템
│   ├── scripts/         # GDScript
│   └── resources/       # .tres 데이터
├── docs/
│   ├── game-design/     # GDD
│   ├── references/      # Bad North 레퍼런스
│   ├── implementation/  # 구현 문서
│   ├── handover/        # 인수인계 문서 (현재)
│   └── assets/          # 에셋 프롬프트
```

---

## 핵심 문서 위치

| 문서 | 경로 |
|------|------|
| 게임 디자인 (GDD) | `docs/game-design/game-design-document.md` |
| **레퍼런스 비교** | `docs/implementation/REFERENCE-COMPARISON.md` |
| Bad North 레퍼런스 | `docs/references/bad-north/` |
| Godot 이관 계획 | `docs/implementation/GODOT-MIGRATION.md` |
| 공유 상태 정의 | `docs/implementation/SHARED-STATE.md` |
| 3D 에셋 프롬프트 | `docs/assets/3D-ASSET-PROMPTS.md` |
