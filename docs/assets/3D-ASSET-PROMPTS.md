# The Fading Raven - 3D 모델 에셋 프롬프트

> AI 3D 생성 도구(Meshy, Tripo3D, CSM, Luma AI 등)용 프롬프트 모음

---

## 목차

1. [크루 클래스](#1-크루-클래스-5종)
2. [적 유닛](#2-적-유닛-13종)
3. [보스](#3-보스-2종)
4. [우주 정거장](#4-우주-정거장-환경)
5. [시설 모듈](#5-시설-모듈-7종)
6. [장비 아이템](#6-장비-아이템-10종)
7. [드론 & 터렛](#7-드론--터렛)
8. [함선 & 침투정](#8-함선--침투정)
9. [이펙트 오브젝트](#9-이펙트-오브젝트)

---

## 프롬프트 작성 가이드

### 공통 스타일 키워드
```
Style: sci-fi, stylized low-poly, space opera, cyberpunk military, clean geometry
Rendering: PBR materials, metallic surfaces, emissive glow accents
Color Palette: dark blues, purples, neon accents (cyan, orange, magenta)
Scale Reference: human-sized characters ~1.8m, station modules ~10-20m
```

### AI 도구별 팁
- **Meshy**: 상세한 설명 + "game-ready, low poly" 추가
- **Tripo3D**: 짧고 명확한 프롬프트, 핵심 특징 강조
- **CSM (3D AI)**: 레퍼런스 이미지와 함께 사용
- **Luma AI**: 실사 스타일 선호, "photorealistic render" 추가

---

## 1. 크루 클래스 (5종)

### 1.1 가디언 (Guardian)

**역할**: 올라운더, 대원거리 방어
**색상**: #4a9eff (밝은 파랑)

```
[기본 프롬프트]
Futuristic space marine soldier, sci-fi guardian class, wearing medium armor suit with integrated energy shield emitter on left forearm, holding compact blaster pistol in right hand, blue glowing energy shield projected from arm, sleek helmet with visor, blue accent lights on armor joints, heroic standing pose, game character, stylized low-poly, PBR materials

[상세 프롬프트]
Male/female space soldier in medium-weight powered armor, Guardian class design:
- Helmet: Rounded tactical helmet with blue-tinted visor, small antenna
- Torso: Segmented chest plate with blue glowing core reactor
- Left Arm: Large forearm-mounted circular shield emitter, energy barrier projection
- Right Arm: Compact blaster pistol holster, armored gauntlet
- Legs: Articulated armor plates, magnetic boots
- Colors: Dark gray base, bright blue (#4a9eff) accent lights and trim
- Style: Clean military sci-fi, not bulky, agile appearance
```

**변형**
- `Guardian_Standard`: 기본 버전
- `Guardian_Veteran`: 추가 장갑판, 더 큰 실드
- `Guardian_Elite`: 금색 트림, 화려한 실드 이펙트

---

### 1.2 센티넬 (Sentinel)

**역할**: 병목 방어, 대형 적 카운터
**색상**: #f6ad55 (주황색)

```
[기본 프롬프트]
Futuristic space pikeman, sentinel class soldier, wielding long energy lance weapon with glowing orange tip, heavy stance defensive pose, medium-heavy armor with orange energy lines, helmet with tactical display, sci-fi military design, stylized game character, low-poly optimized

[상세 프롬프트]
Space infantry soldier specialized in polearm combat, Sentinel class:
- Helmet: Angular tactical helmet, orange HUD glow behind visor
- Torso: Reinforced chest armor with energy conduits leading to weapon
- Weapon: 2.5m energy lance, staff body with glowing orange plasma tip
- Arms: Heavy gauntlets for lance grip, energy transfer cables
- Legs: Stable wide stance armor, heavy boots
- Back: Small power pack connected to lance via cable
- Colors: Gunmetal gray armor, orange (#f6ad55) energy effects
- Pose: Defensive stance, lance pointed forward at 45-degree angle
```

**변형**
- `Sentinel_Standard`: 기본 랜스
- `Sentinel_Veteran`: 더 긴 랜스, 강화 장갑
- `Sentinel_Elite`: 이중 블레이드 랜스 팁, 화려한 장식

---

### 1.3 레인저 (Ranger)

**역할**: 원거리 딜러, 침투 저지
**색상**: #68d391 (녹색)

```
[기본 프롬프트]
Futuristic space sniper soldier, ranger class, holding long laser rifle, light armor suit with camouflage pattern, green visor glow, tactical stance aiming pose, sci-fi military marksman, game-ready character model

[상세 프롬프트]
Long-range combat specialist, Ranger class soldier:
- Helmet: Streamlined helmet with advanced targeting visor, green glow
- Torso: Light flexible armor, ammunition pouches, tactical vest
- Weapon: Long-barrel laser rifle, scope with green laser sight
- Arms: Light armored sleeves, stabilizer wrist brace for aiming
- Legs: Light armor for mobility, knee pads
- Back: Ammo pack, small drone companion dock
- Colors: Dark gray with green (#68d391) accent lights and scope glow
- Pose: Aiming stance, one knee raised for stability
```

**변형**
- `Ranger_Standard`: 기본 라이플
- `Ranger_Veteran`: 향상된 스코프, 추가 탄창
- `Ranger_Elite`: 고급 저격 라이플, 길리 슈트 요소

---

### 1.4 엔지니어 (Engineer)

**역할**: 지원, 터렛 설치, 시설 수리
**색상**: #fc8181 (빨간색/핑크)

```
[기본 프롬프트]
Futuristic space engineer soldier, support class, wearing utility armor with many tools, carrying compact turret deployment pack on back, holding pistol and repair tool, red accent lights, tech specialist appearance, game character model

[상세 프롬프트]
Technical support specialist, Engineer class soldier:
- Helmet: Open-face helmet with welding visor (flip-up), headlamp
- Torso: Utility vest with multiple tool pouches, diagnostic screen on chest
- Right Hand: Compact sidearm pistol
- Left Hand: Multi-tool repair device with various attachments
- Back: Folded auto-turret deployment pack, toolbox
- Belt: Spare parts, energy cells, cable coils
- Legs: Reinforced knee pads for kneeling work
- Colors: Orange/red (#fc8181) safety markings, gray utility gear
- Pose: Working stance, one hand on tool belt
```

**변형**
- `Engineer_Standard`: 1개 터렛 팩
- `Engineer_Veteran`: 2개 터렛 팩, 추가 도구
- `Engineer_Elite`: 드론 동반, 고급 장비

---

### 1.5 바이오닉 (Bionic)

**역할**: 고기동, 암살
**색상**: #b794f4 (보라색)

```
[기본 프롬프트]
Futuristic cyborg assassin, bionic class soldier, sleek black armor with purple energy lines, dual energy blades on arms, cybernetic enhancements visible, agile ninja-like pose, sci-fi stealth operative, game character

[상세 프롬프트]
Cybernetically enhanced stealth operative, Bionic class:
- Head: Sleek helmet with purple glowing eyes, no visible face
- Torso: Form-fitting stealth suit, minimal armor, exposed cyber joints
- Arms: Retractable energy blades (forearm-mounted), visible mechanical joints
- Legs: Digitigrade-style cyber legs for speed, shock absorbers
- Back: Blink teleporter device with purple glow
- Enhancements: Visible cybernetic spine, glowing circuit patterns
- Colors: Matte black base, purple (#b794f4) energy lines and eyes
- Pose: Crouched ready-to-strike, blades extended
```

**변형**
- `Bionic_Standard`: 기본 블레이드
- `Bionic_Veteran`: 더 긴 블레이드, 향상된 사이버네틱
- `Bionic_Elite`: 완전 사이보그 외형, 화려한 이펙트

---

## 2. 적 유닛 (13종)

### Tier 1 - 기본 적

#### 2.1 러셔 (Rusher)

**역할**: 기본 근접 적
**색상**: #fc8181 (빨간색)

```
[프롬프트]
Space pirate melee soldier, rusher class enemy, wearing ragged salvaged armor, holding crude energy machete, aggressive charging pose, red glowing eyes, intimidating but expendable appearance, low-poly game enemy

[상세 프롬프트]
Basic pirate infantry, Rusher enemy type:
- Head: Crude helmet or bandana with red goggle lights
- Torso: Salvaged mismatched armor plates, exposed wiring
- Weapon: Crude energy machete or vibro-blade
- Appearance: Lean, aggressive, desperate look
- Colors: Rusty browns, dirty grays, red (#fc8181) eye glow
- Size: Human-sized (1.7m)
- Pose: Running forward, weapon raised
```

---

#### 2.2 건너 (Gunner)

**역할**: 기본 원거리 적
**색상**: #f6ad55 (주황색)

```
[프롬프트]
Space pirate ranged soldier, gunner class enemy, holding salvaged laser rifle, light armor, firing stance pose, orange visor glow, scrappy militant appearance, game enemy character

[상세 프롬프트]
Pirate ranged combatant, Gunner enemy type:
- Head: Open face helmet with orange targeting visor
- Torso: Light salvaged armor vest
- Weapon: Battered but functional laser rifle
- Appearance: Cautious, staying at range
- Colors: Dark clothing, orange (#f6ad55) visor and weapon glow
- Size: Human-sized (1.7m)
- Pose: Aiming stance, taking cover
```

---

#### 2.3 실드 트루퍼 (Shield Trooper)

**역할**: 방어형 근접 적
**색상**: #4a9eff (파란색)

```
[프롬프트]
Space pirate shield bearer, armored trooper with large energy riot shield, defensive stance, blue shield glow, medium armor, one-handed weapon behind shield, game enemy character

[상세 프롬프트]
Armored pirate defender, Shield Trooper enemy type:
- Head: Full helmet with blue visor slit
- Torso: Medium armor plates
- Left Arm: Large rectangular energy riot shield, blue glow
- Right Arm: Short energy sword or club
- Appearance: Bulky, defensive posture
- Colors: Gray armor, blue (#4a9eff) shield energy
- Size: Human-sized (1.8m)
- Pose: Shield forward, advancing slowly
```

---

### Tier 2 - 중급 적

#### 2.4 점퍼 (Jumper)

**역할**: 방어선 우회 적
**색상**: #9f7aea (보라색)

```
[프롬프트]
Space pirate jump trooper, dual wielding energy blades, jet pack on back, acrobatic pose mid-jump, purple thrust glow, light armor for mobility, agile assassin enemy, game character

[상세 프롬프트]
Aerial assault pirate, Jumper enemy type:
- Head: Aerodynamic helmet with purple HUD
- Torso: Light armor, harness for jump pack
- Back: Compact jet pack with purple thrust exhausts
- Arms: Dual short energy blades
- Legs: Light armor, landing shock absorbers
- Appearance: Acrobatic, agile, dangerous
- Colors: Black suit, purple (#9f7aea) thrust and blade glow
- Size: Human-sized (1.7m)
- Pose: Mid-air, diving attack
```

---

#### 2.5 헤비 트루퍼 (Heavy Trooper)

**역할**: 만능형 중장갑 적
**색상**: #718096 (회색)

```
[프롬프트]
Space pirate heavy infantry, heavily armored soldier with shield and grenade launcher, imposing stance, gray heavy armor, tanky bruiser appearance, game enemy character

[상세 프롬프트]
Elite pirate heavy, Heavy Trooper enemy type:
- Head: Heavy full-face helmet, armored visor
- Torso: Thick layered armor plates, ammunition belts
- Left Arm: Heavy ballistic shield
- Right Arm: Grenade launcher attachment
- Legs: Heavy armored boots, slow but unstoppable
- Appearance: Tank-like, intimidating
- Colors: Dark gray (#718096) heavy armor
- Size: Large human (2.0m)
- Pose: Advancing with shield, grenade ready
```

---

#### 2.6 해커 (Hacker)

**역할**: 터렛/시스템 해킹 지원
**색상**: #68d391 (녹색)

```
[프롬프트]
Space pirate tech specialist, hacker class enemy, wearing light tech suit with holographic displays, holding hacking device, green digital effects, sneaky non-combat appearance, game character

[상세 프롬프트]
Technical infiltrator, Hacker enemy type:
- Head: Hood or beanie with AR glasses, green data overlay
- Torso: Light civilian-style tech jacket, no armor
- Hands: Holographic hacking interface, data pad
- Appearance: Non-threatening, tech-focused, evasive
- Effects: Green (#68d391) holographic code displays around hands
- Size: Human-sized (1.6m)
- Pose: Crouched, interfacing with invisible system
```

---

#### 2.7 폭풍 생명체 (Storm Creature)

**역할**: 자폭형 폭풍 스테이지 전용
**색상**: #e53e3e (진한 빨강)

```
[프롬프트]
Alien storm creature, energy-based lifeform, unstable glowing red core, floating ethereal appearance, tentacle-like energy appendages, volatile dangerous creature, sci-fi monster, game enemy

[상세 프롬프트]
Cosmic anomaly entity, Storm Creature enemy type:
- Body: Amorphous energy mass, no solid form
- Core: Bright red (#e53e3e) unstable energy core (glowing)
- Appendages: Wispy energy tentacles, crackling electricity
- Appearance: Alien, unsettling, ready to explode
- Effects: Red energy particles, lightning arcs
- Size: Medium (1.5m diameter)
- Behavior: Floating, pulsating, moving toward targets
```

---

### Tier 3 - 고급 적

#### 2.8 브루트 (Brute)

**역할**: 대형 근접 보스급 적
**색상**: #9f7aea (보라색)

```
[프롬프트]
Massive space pirate brute, giant heavily armored warrior, wielding huge two-handed power hammer, intimidating boss-like enemy, purple energy accents, hulking muscular build, game boss enemy

[상세 프롬프트]
Elite heavy assault pirate, Brute enemy type:
- Head: Small helmet on massive shoulders, glowing eyes
- Torso: Extremely heavy armor, power cables, exposed pistons
- Arms: Massive armored arms, power-assisted
- Weapon: Huge two-handed energy hammer or axe
- Legs: Thick armored legs, ground-shaking footsteps
- Appearance: Terrifying, unstoppable force
- Colors: Dark armor, purple (#9f7aea) power glow
- Size: Very large (2.8-3.2m)
- Pose: Hammer raised, about to strike
```

---

#### 2.9 스나이퍼 (Sniper)

**역할**: 초장거리 저격수
**색상**: #ed64a6 (핑크/마젠타)

```
[프롬프트]
Space pirate elite sniper, long-range assassin with massive anti-materiel rifle, cloaked appearance, pink laser sight, prone or kneeling sniper pose, game enemy character

[상세 프롬프트]
Precision elimination specialist, Sniper enemy type:
- Head: Full face helmet with advanced optics, pink targeting laser
- Torso: Light stealth suit, ghillie-style disruption cloak
- Weapon: Very long anti-materiel laser rifle with large scope
- Appearance: Patient, deadly, hard to spot
- Effects: Pink (#ed64a6) laser sight beam
- Size: Human-sized (1.8m)
- Pose: Prone sniping position, eye on scope
```

---

#### 2.10 드론 캐리어 (Drone Carrier)

**역할**: 드론 소환/지원
**색상**: #4fd1c5 (청록색)

```
[프롬프트]
Space pirate drone controller, bulky armor with drone bays, multiple small attack drones orbiting around, teal glowing drones, support enemy commander, game character

[상세 프롬프트]
Drone warfare specialist, Drone Carrier enemy type:
- Head: Helmet with drone control interface visor
- Torso: Bulky armor with drone storage compartments (open bays)
- Back: Large drone deployment rack
- Drones: 4-6 small attack drones hovering nearby (teal glow)
- Appearance: Command unit, stays back, controls swarm
- Colors: Dark armor, teal (#4fd1c5) drone lights
- Size: Medium-large (2.0m)
- Pose: Standing, directing drones with hand gestures
```

**드론 서브모델**
```
Attack Drone: Small spherical drone, single laser emitter, teal glow, 30cm diameter, hovering, sci-fi combat drone
```

---

#### 2.11 실드 제너레이터 (Shield Generator)

**역할**: 아군 보호막 부여
**색상**: #63b3ed (하늘색)

```
[프롬프트]
Space pirate shield support unit, backpack-mounted shield generator projecting dome, blue energy field around nearby allies, support specialist enemy, game character

[상세 프롬프트]
Defensive support unit, Shield Generator enemy type:
- Head: Tech helmet with shield status displays
- Torso: Light armor, power cables to backpack
- Back: Large shield generator device with antenna array
- Effect: Blue (#63b3ed) dome shield projection (2-tile radius)
- Appearance: Non-combat, priority target, runs with allies
- Size: Human-sized (1.7m)
- Pose: Running, generator humming
```

---

## 3. 보스 (2종)

### 3.1 해적 대장 (Pirate Captain)

**역할**: 섹터 보스
**색상**: #e53e3e (빨간색)

```
[프롬프트]
Space pirate captain boss, imposing commander in ornate heavy armor, cape, wielding power sword and pistol, red glowing eyes, skull motifs, intimidating villain appearance, game boss character

[상세 프롬프트]
Pirate fleet commander, Pirate Captain boss:
- Head: Ornate helmet with skull-like visor, glowing red eyes
- Torso: Heavy ceremonial armor with trophies, medals
- Cape: Tattered but impressive battle cape
- Right Hand: Large power sword with red energy blade
- Left Hand: Heavy ornate pistol
- Appearance: Veteran warrior, scarred, commanding presence
- Colors: Black/gold armor, red (#e53e3e) energy effects
- Size: Large (2.2m)
- Pose: Commanding stance, sword pointed forward
```

---

### 3.2 폭풍 핵 (Storm Core)

**역할**: 환경 보스 (파괴 불가)
**색상**: #ed64a6 (마젠타/핑크)

```
[프롬프트]
Cosmic storm core entity, massive swirling energy vortex, pink and purple energy storm, floating alien anomaly, eldritch horror appearance, environment hazard boss, sci-fi game boss

[상세 프롬프트]
Cosmic anomaly boss, Storm Core:
- Form: Massive swirling energy vortex (5m diameter)
- Core: Bright pink (#ed64a6) pulsating center
- Tendrils: Energy tentacles reaching outward
- Effects: Lightning arcs, particle storms, screen distortion
- Appearance: Alien, incomprehensible, terrifying
- Behavior: Stationary, pulses damage, spawns creatures
- Size: Very large (5m diameter, 8m with tendrils)
```

---

## 4. 우주 정거장 환경

### 4.1 정거장 외관

```
[프롬프트]
Modular space station exterior, cylindrical main structure with multiple attached modules, solar panels, docking ports, communication arrays, sci-fi industrial design, game environment asset

[상세 프롬프트]
Orbital space station exterior:
- Main Body: Central cylindrical hub (50m length)
- Modules: Various attached pods (residential, industrial)
- Solar Panels: Large deployable solar arrays
- Docking: Multiple docking ports for shuttles
- Antenna: Communication dishes and sensor arrays
- Colors: White/gray hull, blue lighting accents
- Style: Functional industrial sci-fi
```

---

### 4.2 정거장 내부 타일셋

#### 바닥 타일 (Floor Tiles)

```
[기본 바닥]
Sci-fi space station floor tile, metal grating with blue light strips, modular game tile, 2x2m, industrial clean design

[복도 바닥]
Space station corridor floor, non-slip metal plating, warning stripes, directional lighting, game environment tile

[시설 바닥]
Space station facility room floor, clean white panels, embedded lighting, medical/lab style, game tile
```

#### 벽 타일 (Wall Tiles)

```
[기본 벽]
Sci-fi space station wall panel, metal with display screens, cable conduits, ventilation grilles, game environment asset

[창문 벽]
Space station wall with viewport window, reinforced frame, space view outside, game environment tile

[에어락 문]
Space station airlock door, heavy reinforced design, warning markings, pressure seals, game prop
```

---

### 4.3 우주 공간 (Void Area)

```
[프롬프트]
Deep space void backdrop, stars and nebula, dark emptiness, purple and blue cosmic dust clouds, game skybox/background

[즉사 영역 표시]
Space station edge with void danger, broken railing, warning lights, view into empty space, danger zone indicator
```

---

## 5. 시설 모듈 (7종)

### 5.1 거주 모듈 (Residential - S/M/L)

```
[소형 - 1 크레딧]
Small residential pod, compact living quarters, single bed visible through window, warm interior lighting, 4x4m footprint, game building asset

[중형 - 2 크레딧]
Medium residential module, multi-room living quarters, bunk beds, common area visible, 6x6m footprint, space station housing

[대형 - 3 크레딧]
Large residential complex, apartment-style housing module, multiple floors, balconies, 8x8m footprint, space station building
```

---

### 5.2 의료 모듈 (Medical)

```
[프롬프트]
Space station medical bay module, white clean design, medical cross symbol, healing tanks visible through windows, blue healing lights, 6x6m game building asset

[상세]
Medical facility module for space station:
- Exterior: White panels, red cross symbol, blue accent lights
- Windows: Healing pods and medical beds visible inside
- Equipment: External decontamination unit
- Effect: Nearby units recover faster (visual healing aura)
```

---

### 5.3 무기고 (Armory)

```
[프롬프트]
Space station armory module, fortified heavy construction, weapon rack symbols, orange hazard markings, ammunition storage warning signs, military facility, game building

[상세]
Military armory module:
- Exterior: Heavy reinforced walls, blast doors
- Symbols: Crossed rifles icon, ammunition warning
- Colors: Gray metal, orange (#f6ad55) hazard stripes
- Effect: Weapons glow emanating from inside
```

---

### 5.4 통신 중계소 (Comm Tower)

```
[프롬프트]
Space station communication tower module, tall antenna array, satellite dishes, blinking signal lights, green status indicators, tech facility, game building

[상세]
Communication relay facility:
- Structure: Tall tower with dish arrays
- Antenna: Multiple parabolic dishes, antenna spires
- Lights: Green (#68d391) blinking status lights
- Effect: Signal waves visualization
```

---

### 5.5 발전소 (Power Plant)

```
[프롬프트]
Space station power plant module, reactor core visible through reinforced glass, yellow hazard warnings, cooling vents, high-energy facility, industrial game building

[상세]
Power generation facility:
- Core: Visible reactor with yellow/orange glow
- Exterior: Heavy shielding, radiation warnings
- Vents: Large cooling exhaust ports
- Colors: Gray industrial, yellow warning markings
- Effect: Power humming, energy particles
```

---

## 6. 장비 아이템 (10종)

### 6.1 커맨드 모듈 (Command Module)

```
[프롬프트]
Sci-fi command module device, holographic tactical display projector, wrist-mounted commander interface, blue hologram glow, military tech equipment, game item

[상세]
Leadership enhancement device:
- Form: Wrist-mounted bracer with projector
- Effect: Blue holographic tactical display
- Style: High-tech military command equipment
```

---

### 6.2 충격파 (Shock Wave)

```
[프롬프트]
Sci-fi shockwave hammer weapon, two-handed energy hammer, ground-pound attack pose, orange shockwave effect rings, heavy melee weapon, game equipment

[상세]
AOE knockback weapon:
- Weapon: Heavy two-handed hammer
- Head: Energy emitter for shockwave
- Effect: Orange (#f6ad55) expanding shockwave rings
```

---

### 6.3 파편 수류탄 (Frag Grenade)

```
[프롬프트]
Sci-fi fragmentation grenade, cylindrical design, red warning lights, primed to explode, explosive device, game item prop

[상세]
Throwable explosive:
- Form: Cylinder with grip rings
- Indicator: Red arming lights
- Effect: Explosion particles, shrapnel
```

---

### 6.4 근접 지뢰 (Proximity Mine)

```
[프롬프트]
Sci-fi proximity mine device, flat disc shape, red sensor light, deployable explosive trap, armed status indicator, game item

[상세]
Triggered explosive:
- Form: Flat disc, deployable
- Sensor: Red proximity detector light
- Effect: Explosion when triggered
```

---

### 6.5 랠리 혼 (Rally Horn)

```
[프롬프트]
Sci-fi rally horn device, trumpet-like energy emitter, golden finish, morale boost effect, healing aura item, game equipment

[상세]
Instant reinforcement device:
- Form: Horn or bugle shape
- Effect: Golden healing particles
- Style: Ceremonial military
```

---

### 6.6 리바이브 키트 (Revive Kit)

```
[프롬프트]
Sci-fi revival kit, medical emergency device, glowing green healing core, life restoration equipment, emergency medical item, game prop

[상세]
Emergency revival device:
- Form: Compact medical case
- Core: Green life-energy container
- Effect: Resurrection particles
```

---

### 6.7 스팀 팩 (Stim Pack)

```
[프롬프트]
Sci-fi stimulant pack, injector device with glowing purple serum, combat enhancement drug, cyberpunk medical item, game equipment

[상세]
Performance enhancer:
- Form: Auto-injector with serum vial
- Serum: Purple (#b794f4) glowing liquid
- Effect: Speed trails, enhanced reflexes visual
```

---

### 6.8 샐비지 코어 (Salvage Core)

```
[프롬프트]
Sci-fi salvage core device, credit extraction tool, golden glow, treasure hunting equipment, economic bonus item, game prop

[상세]
Resource extraction device:
- Form: Handheld scanner with core
- Effect: Golden credit particles
- Style: Prospector/salvager tool
```

---

### 6.9 보호막 생성기 장비 (Shield Generator Equip)

```
[프롬프트]
Portable shield generator device, deployable energy dome projector, blue shield bubble effect, defensive equipment, game item

[상세]
Personal shield device:
- Form: Backpack unit with projector
- Effect: Blue dome shield around user
- Duration visual: Fading shield effect
```

---

### 6.10 해킹 장치 (Hacking Device)

```
[프롬프트]
Sci-fi hacking device, portable terminal with holographic interface, green code display, cyber warfare tool, tech equipment, game item

[상세]
Electronic warfare device:
- Form: Handheld terminal
- Display: Green (#68d391) holographic code
- Effect: Data stream particles to target
```

---

## 7. 드론 & 터렛

### 7.1 Raven 정찰 드론

```
[프롬프트]
Raven scout drone, sleek black reconnaissance UAV, purple engine glow, bird-like silhouette, autonomous scout robot, sci-fi drone, game asset

[상세]
Player's scout drone:
- Form: Bird-like (raven) silhouette
- Size: 50cm wingspan
- Colors: Matte black, purple (#b794f4) engine glow
- Features: Camera eye, scanning beam
```

---

### 7.2 엔지니어 터렛

```
[프롬프트]
Deployable auto-turret, compact folding design, laser barrel, targeting sensor, red (#fc8181) laser sight, automated defense gun, game prop

[상세]
Engineer's deployable turret:
- Form: Tripod base, rotating gun platform
- Weapon: Twin laser barrels
- Sensor: Tracking camera dome
- Size: 1m tall when deployed
- Colors: Gray metal, red targeting laser
```

**업그레이드 변형**
```
Turret_Lv1: Basic single barrel, small
Turret_Lv2: Twin barrels, larger
Turret_Lv3: Heavy barrels, slow effect particles (blue), largest
```

---

### 7.3 적 공격 드론 (Drone Carrier용)

```
[프롬프트]
Enemy attack drone, small spherical combat robot, single laser emitter, teal (#4fd1c5) glow, hostile swarm drone, game enemy prop

[상세]
Carrier's attack drone:
- Form: Spherical, 30cm diameter
- Weapon: Single forward laser
- Propulsion: Anti-gravity hover
- Colors: Dark metal, teal lights
```

---

## 8. 함선 & 침투정

### 8.1 Raven 기함

```
[프롬프트]
Raven mothership, sleek black carrier vessel, bird-like design profile, purple engine trails, command ship, sci-fi capital ship, game asset

[상세]
Player's command ship "Raven":
- Form: Elongated carrier, raven-like prow
- Size: Large (200m length)
- Colors: Matte black, purple trim and engines
- Features: Drone bays, hangar deck, bridge
- Style: Elegant military vessel
```

---

### 8.2 적 침투정 (Boarding Pod)

```
[프롬프트]
Pirate boarding pod, drop ship assault craft, aggressive angular design, red warning lights, troop deployment hatch, enemy transport, game vehicle

[상세]
Enemy troop transport:
- Form: Angular drop pod shape
- Size: 8m length, holds 8-12 troops
- Colors: Rusty metal, red lights
- Features: Breach drill on front, deployment ramp
- Landing: Impact crater effect
```

---

### 8.3 적 모함

```
[프롬프트]
Pirate carrier ship, menacing capital vessel, industrial brutal design, red running lights, boarding pod launchers, enemy mothership, game background asset

[상세]
Enemy fleet carrier:
- Form: Industrial, brutal aesthetic
- Size: Very large (500m+)
- Colors: Dark rust, red lights
- Features: Multiple boarding pod launchers
- Style: Threatening, massive
```

---

## 9. 이펙트 오브젝트

### 9.1 에너지 실드 이펙트

```
[프롬프트]
Energy shield effect, hexagonal force field pattern, blue translucent barrier, sci-fi defensive effect, game VFX asset

색상 변형:
- Guardian Shield: Blue (#4a9eff)
- Enemy Shield: Orange (#f6ad55)
- Generator Dome: Light blue (#63b3ed)
```

---

### 9.2 텔레포트/블링크 이펙트

```
[프롬프트]
Teleportation effect, purple particle burst, blink ability visual, spatial distortion, sci-fi teleport VFX, game effect

[상세]
- Departure: Purple particle implosion
- Trail: Stretched light streak
- Arrival: Purple particle explosion + shockwave
```

---

### 9.3 궤도 폭격 이펙트

```
[프롬프트]
Orbital strike effect, beam from sky, massive explosion, red targeting laser followed by devastating blast, sci-fi artillery strike, game VFX

[상세]
- Targeting: Red (#e53e3e) laser beam from above
- Impact: Massive explosion, screen shake
- Aftermath: Crater, burning debris
```

---

### 9.4 치료/회복 이펙트

```
[프롬프트]
Healing effect particles, green rising sparkles, medical restoration visual, buff effect, sci-fi heal VFX, game effect

[색상]
- Standard Heal: Green (#68d391)
- Rally Horn: Gold
- Medical Bay: Blue cross particles
```

---

### 9.5 폭풍/환경 이펙트

```
[프롬프트]
Cosmic storm effect, purple and pink energy vortex, lightning arcs, space anomaly visual, dangerous environment hazard, game VFX

[상세]
- Colors: Pink (#ed64a6), purple (#9f7aea)
- Elements: Swirling clouds, lightning, particles
- Atmosphere: Oppressive, dangerous
```

---

## 부록: 색상 팔레트 요약

| 대상 | Hex 코드 | 용도 |
|------|----------|------|
| 가디언 | #4a9eff | 파란색 - 실드, 방어 |
| 센티넬 | #f6ad55 | 주황색 - 랜스, 돌격 |
| 레인저 | #68d391 | 녹색 - 저격, 정밀 |
| 엔지니어 | #fc8181 | 빨간색 - 경고, 공학 |
| 바이오닉 | #b794f4 | 보라색 - 순간이동, 사이버 |
| 폭풍 | #ed64a6 | 마젠타 - 위험, 이상현상 |
| 중립 UI | #718096 | 회색 - 인터페이스 |

---

## 사용 방법

1. 원하는 에셋 프롬프트를 복사
2. AI 3D 생성 도구에 붙여넣기
3. 필요시 스타일 키워드 추가/수정
4. 생성된 모델 검토 및 반복 개선
5. 게임 엔진용으로 최적화 (decimation, UV unwrap)

### 추천 워크플로우

```
1. Meshy/Tripo3D로 기본 형태 생성
2. Blender에서 토폴로지 정리
3. 텍스처 베이킹 및 PBR 설정
4. Godot 4.x로 import
5. 머티리얼 및 셰이더 조정
```
