# Master G 3.0.0 – one app, switched from Firestore

One AAB / one web build replaces the three staged builds (2.5.0 / 2.6.0 / 2.7.0).
What players see is decided by Firestore **`config/app`** – no app update needed.

## 1. Firestore switch (`config/app`)
Firebase Console → Firestore Database → Data → collection **`config`** → document **`app`**.

| Field | Type | Values | What it does |
|---|---|---|---|
| `ads` | string | `unity` / `admob` / `off` | Ad network (AdMob only after 22 Nov 2026) |
| `stage` | number | `1` / `2` / `3` | Whole release look (see table below) |
| `v2From` | string | `2026-11-15` | Becomes stage 2 on this date (India time) by itself |
| `v3From` | string | `2026-12-15` | Becomes stage 3 on this date by itself |
| `games` | map | e.g. `business: "on"` | One game: `on` / `soon` (Coming soon) / `off` (hidden) |

| Stage | Games | Theme (until the player picks one) | Sounds | Extras |
|---|---|---|---|---|
| 1 | Business, Brain Age, Saanp-Seedhi, Mom Memory = Coming soon; Dominoes first | Neon Night | Classic | – |
| 2 | + Business, Brain Age (shown first) | Merry Christmas | Retro arcade | – |
| 3 | Every game; Saanp-Seedhi, Mom Memory first; 2 "New game" cards | Happy New Year (all themes free) | Soft | 6 new home layouts, New Year sale 20 Dec – 5 Jan |

Notes
- Players get a change **the next time they open the app** (read at start, 3 s max).
- Offline: the last value is remembered. Very first start without internet: stage 1.
- Dates only move forward (a date never lowers `stage`). To go back, remove the dates and set `stage`.
- Example first upload: `stage: 1`, `v2From: "2026-11-15"`, `v3From: "2026-12-15"`, `ads: "unity"`.

## 2. Build the AAB (on this PC)
```
cd D:\gita\Games\puzzle_hub
D:\flutter\bin\flutter.bat build appbundle --release --dart-define=STAGE=1 --build-name=3.0.0 --build-number=26
```
File: `D:\gita\Games\puzzle_hub\build\app\outputs\bundle\release\app-release.aab`
(`STAGE=1` is only the fallback for a first start without internet.)

Phone test app (test ads, installs as "Master G Test" next to the Play version):
```
D:\flutter\bin\flutter.bat build apk --release --dart-define=TEST_ADS=true --dart-define=STAGE=1 --build-name=3.0.0 --build-number=26 --android-project-arg=rtest=true
```

## 3. Website (one combined web game)
The same switch works on the website, so `/play/` needs only one build
(the `/play/v1`, `/play/v2`, `/play/v3` folders and `schedule.js` are no longer needed).
```
cd D:\gita\Games\puzzle_hub
D:\flutter\bin\flutter.bat build web --release --base-href /play/ --dart-define=STAGE=1 --no-wasm-dry-run
```
Then replace `D:\gita\Games\website\public\play` with `D:\gita\Games\puzzle_hub\build\web`
(keep `play\icons` and `play\favicon.png` – the home page uses them), and deploy:
```
cd D:\gita\Games\website
firebase deploy --only hosting:masterg-games
```

## 4. Firestore rules
No change needed: `config/app` is readable by everyone and writable only from the console.
Full combined rules (Master G + AYUSH bookings): `D:\gita\Games\firestore_rules.txt`
→ Firebase Console → Firestore Database → Rules → paste everything → Publish.

## 5. Play Store "What's new" (3.0.0)
**English**
- 30+ brain, puzzle and board games in one app – Ludo, Chess, Business, Dominoes, Saanp-Seedhi and more
- New themes: Neon Night, Merry Christmas, Happy New Year
- New home layouts and fresh sound effects
- Now in German, French, Spanish and Italian
- Faster sign-in, cleaner profile and many fixes

**हिन्दी**
- एक ऐप में 30+ दिमागी, पज़ल और बोर्ड गेम – लूडो, शतरंज, बिज़नेस, डोमिनो, साँप-सीढ़ी और बहुत कुछ
- नई थीम: नियॉन नाइट, मेरी क्रिसमस, हैप्पी न्यू ईयर
- नए होम लेआउट और नई आवाज़ें
- अब जर्मन, फ़्रेंच, स्पैनिश और इटैलियन में भी
- आसान साइन-इन, साफ़ प्रोफ़ाइल और कई सुधार

## 6. Data safety
Must include Google AdMob **and** Unity Ads (advertising ID, approximate location,
app interactions, diagnostics shared with ad networks) – see the checklist in chat.
