# P0 에셋 생성 프롬프트

> 기존 Guardian/Rusher 스타일 매칭
> diffusers CLI 파이프라인용 최적화 프롬프트

---

## 공통 스타일 (기존 에셋 기반)

**스타일 키워드:**
```
3D game character render, stylized sci-fi, high quality render, dark gray metallic armor, glowing accent lights, transparent background, isolated character, game asset, unreal engine 5 style
```

**Negative 프롬프트:**
```
realistic photo, blurry, distorted, deformed, bad anatomy, multiple characters, text, watermark, cropped, partial body, complex background, low quality, sketch, painting
```

---

## 1. 크루 클래스 (4종)

### 1.1 Sentinel (센티넬)
**파일명**: `crews/sentinel.glb`
**색상**: 주황색 (#f6ad55)

```
3D game character render, futuristic space soldier with energy lance spear, medium-heavy armor suit, standing defensive pose, orange glowing visor and energy lines, dark gray metallic armor plates, stylized sci-fi military design, transparent background, isolated character, game asset, unreal engine 5 style, high quality render
```

---

### 1.2 Ranger (레인저)
**파일명**: `crews/ranger.glb`
**색상**: 녹색 (#68d391)

```
3D game character render, futuristic space sniper soldier with long rifle and scope, light tactical armor suit, standing alert pose, green glowing visor and accent lights, dark gray armor with green trim, stylized sci-fi military design, transparent background, isolated character, game asset, unreal engine 5 style, high quality render
```

---

### 1.3 Engineer (엔지니어)
**파일명**: `crews/engineer.glb`
**색상**: 빨간색 (#fc8181)

```
3D game character render, futuristic space engineer soldier with tool kit, utility armor with pouches, standing pose holding repair tool, red-orange glowing visor and safety markings, dark gray utility armor, stylized sci-fi tech specialist design, transparent background, isolated character, game asset, unreal engine 5 style, high quality render
```

---

### 1.4 Bionic (바이오닉)
**파일명**: `crews/bionic.glb`
**색상**: 보라색 (#b794f4)

```
3D game character render, futuristic cyborg assassin soldier, sleek black stealth armor with arm blades, standing ready pose, purple glowing eyes and energy lines, matte black armor with purple accents, stylized sci-fi ninja design, transparent background, isolated character, game asset, unreal engine 5 style, high quality render
```

---

## 2. 적 유닛 (2종)

### 2.1 Gunner (건너)
**파일명**: `enemies/gunner.glb`
**색상**: 주황색 (#f6ad55)

```
3D game character render, space pirate soldier with salvaged rifle, scrappy light armor vest, aggressive standing pose, orange glowing visor, worn brown and gray armor, hostile militant appearance, stylized sci-fi enemy design, transparent background, isolated character, game asset, unreal engine 5 style, high quality render
```

---

### 2.2 Shield Trooper (실드 트루퍼)
**파일명**: `enemies/shield_trooper.glb`
**색상**: 파란색 (#4a9eff)

```
3D game character render, space pirate with large energy shield and short sword, medium armor plates, defensive standing pose, blue glowing shield and visor, gray worn armor, stylized sci-fi enemy tank design, transparent background, isolated character, game asset, unreal engine 5 style, high quality render
```

---

## 생성 설정

### diffusers CLI 설정
```python
width=1024
height=1024
num_inference_steps=35
guidance_scale=7.5
```

### 저장 경로
```
godot/assets/models/
├── crews/
│   ├── sentinel.png / .glb
│   ├── ranger.png / .glb
│   ├── engineer.png / .glb
│   └── bionic.png / .glb
└── enemies/
    ├── gunner.png / .glb
    └── shield_trooper.png / .glb
```

---

## 체크리스트

- [ ] Sentinel 이미지 생성
- [ ] Sentinel 3D 변환
- [ ] Ranger 이미지 생성
- [ ] Ranger 3D 변환
- [ ] Engineer 이미지 생성
- [ ] Engineer 3D 변환
- [ ] Bionic 이미지 생성
- [ ] Bionic 3D 변환
- [ ] Gunner 이미지 생성
- [ ] Gunner 3D 변환
- [ ] Shield Trooper 이미지 생성
- [ ] Shield Trooper 3D 변환

---

*수정일: 2026-02-05 (Guardian/Rusher 스타일 매칭)*
