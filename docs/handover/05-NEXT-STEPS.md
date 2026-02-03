# 다음 단계

## Git 규칙
- **푸시는 `main` 브랜치에** (master 아님)
- 원격 저장소: `https://github.com/SkiDye/The-Fading-Raven.git`

---

## 현재 상태
- 웹 프로토타입 완성 (5-session 병렬 개발)
- Godot 4.x 이관 예정

---

## Godot 이관 계획

### 3 Phase 구조
| Phase | 목표 | 주요 작업 |
|-------|------|----------|
| **1** | 코어 + 데이터 | GameState, Resource 변환, RNG |
| **2** | 전투 시스템 | TileMap, 크루/적, 웨이브 |
| **3** | UI + 캠페인 | 섹터 맵, 메타 진행, 폴리시 |

### 사전 준비
- [ ] Godot 4.2+ 설치
- [ ] MCP 설치 (GDAI MCP 권장 또는 Coding-Solo)
- [ ] Claude Code MCP 연동

### 웹 → Godot 매핑
```
js/data/*.js       → resources/*.tres
js/core/game-state.js → src/autoload/GameState.gd
js/pages/battle.js → src/systems/combat/BattleController.gd
```

---

## 주요 참조 문서

| 용도 | 경로 |
|------|------|
| 상세 이관 계획 | `docs/implementation/GODOT-MIGRATION.md` |
| 공유 상태 정의 | `docs/implementation/SHARED-STATE.md` |
| 전투 시스템 | `docs/implementation/combat-system.md` |
| 적 AI | `docs/implementation/enemy-ai.md` |
| 테스트 계획 | `docs/implementation/INTEGRATION-TEST-PLAN.md` |

---

## 핵심 주의사항

1. **Bad North 메카닉 유지** - 레퍼런스의 검증된 시스템
2. **GDD 개선사항 반영** - 차별화 요소
3. **시드 기반 RNG** - 동일 시드 = 동일 결과 보장
4. **영구 사망** - 로그라이트 긴장감의 핵심
