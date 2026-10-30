# Master G website – how to change dates and deploy

Site: **games.mitrojan.in** (Firebase Hosting site `masterg-games`, project PuzzleGame).

## What is where
| Path | What it is |
|---|---|
| `public/index.html` | Home page (Play / Download buttons) |
| `public/schedule.js` | **The only file you edit for releases** – V2 and V3 dates |
| `public/play/index.html` | Switch page: sends visitors to the live version |
| `public/play/v1/` | Web game 2.5.0 (Neon Night) |
| `public/play/v2/` | Web game 2.6.0 (Business + Brain Age, Merry Christmas) |
| `public/play/v3/` | Web game 2.7.0 (all games, Happy New Year) |

## 1. Change the dates
Open `public/schedule.js` in Notepad and change only these two lines:
```js
  v2: '2026-11-15',
  v3: '2026-12-15',
```
Keep the format `'YYYY-MM-DD'` with the quotes and the comma. The switch happens
at 00:00 India time on that date – nothing else to do on the day.

## 2. Check before deploying (optional)
After deploying you can open any version early in your own browser:
- `https://games.mitrojan.in/play/?preview=2` → V2
- `https://games.mitrojan.in/play/?preview=3` → V3
- `https://games.mitrojan.in/play/?preview=1` → V1

The preview stays only in that browser tab. Normal visitors always get the
version for today's date. (Opening `/play/v3/` directly before its date sends
the visitor back to the live version.)

## 3. Deploy
Open a terminal (PowerShell or Git Bash) and run:
```
cd D:\gita\Games\website
firebase deploy --only hosting:masterg-games
```
If it asks to log in: `firebase login` with **aiforsmart@gmail.com**, then run
the deploy again. It prints `Deploy complete!` and the site is live in about a
minute.

## 4. Undo a deploy
Firebase Console → **Hosting** → site `masterg-games` → **Release history** →
on an older release, **⋮ → Rollback**.
