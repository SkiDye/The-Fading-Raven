# 3D Model Assets Manifest

> Godot 4.x 연동용 3D 에셋 목록

---

## 연동 완료

| 파일명 | 원본 | 카테고리 | 용도 |
|--------|------|----------|------|
| `crews/guardian.glb` | 가디언 (Guardian) | 크루 | Guardian 클래스 분대원 |
| `enemies/rusher.glb` | 러셔 | 적 | Tier 1 근접 적 |
| `facilities/residential_sml.glb` | Residential - SML | 시설 | 소형 거주 모듈 |
| `vehicles/boarding_pod.glb` | Boarding Pod | 차량 | 적 침투선 |

---

## 누락 에셋 (우선순위별)

### P0 - 핵심 게임플레이

| 에셋 | 카테고리 | 프롬프트 위치 |
|------|----------|---------------|
| sentinel.glb | crews | §1.2 센티넬 |
| ranger.glb | crews | §1.3 레인저 |
| engineer.glb | crews | §1.4 엔지니어 |
| bionic.glb | crews | §1.5 바이오닉 |
| gunner.glb | enemies | §2.2 건너 |
| shield_trooper.glb | enemies | §2.3 실드 트루퍼 |

### P1 - 중요

| 에셋 | 카테고리 | 프롬프트 위치 |
|------|----------|---------------|
| jumper.glb | enemies | §2.4 점퍼 |
| heavy_trooper.glb | enemies | §2.5 헤비 트루퍼 |
| hacker.glb | enemies | §2.6 해커 |
| turret.glb | props | §7.2 엔지니어 터렛 |
| medical.glb | facilities | §5.2 의료 모듈 |
| armory.glb | facilities | §5.3 무기고 |

### P2 - 폴리시

| 에셋 | 카테고리 | 프롬프트 위치 |
|------|----------|---------------|
| brute.glb | enemies | §2.8 브루트 |
| sniper.glb | enemies | §2.9 스나이퍼 |
| drone_carrier.glb | enemies | §2.10 드론 캐리어 |
| pirate_captain.glb | enemies | §3.1 해적 대장 |
| raven_drone.glb | props | §7.1 Raven 드론 |
| comm_tower.glb | facilities | §5.4 통신 중계소 |
| power_plant.glb | facilities | §5.5 발전소 |

---

## 폴더 구조

```
godot/assets/models/
├── crews/          # 플레이어 크루 클래스
│   └── guardian.glb
├── enemies/        # 적 유닛
│   └── rusher.glb
├── facilities/     # 정거장 시설
│   └── residential_sml.glb
├── vehicles/       # 함선, 침투선
│   └── boarding_pod.glb
├── props/          # 터렛, 드론, 소품
└── effects/        # 이펙트 메시
```

---

## 프롬프트 참조

전체 에셋 생성 프롬프트: `docs/assets/3D-ASSET-PROMPTS.md`

---

*업데이트: 2026-02-05*
