# Master G – next update wishlist (noted 2026-10-11, decisions updated 2026-10-13)
Do NOT start until the user says so.

1. **In-app update** – the app itself asks to update when a newer Play version exists
   (Play In-App Updates API).
2. **Rate us 5★** – shown on a WIN, **randomly, not every time** (Play In-App Review API).
3. **Home-screen widget / shortcuts** – 1 row × 3 columns of games; tap opens that game
   directly (deep link). App-icon long-press shortcuts use the same links.
4. **Offline play limit**
   - >5 minutes of play without internet → popup asking to turn internet on (again if they
     switch it off right after).
   - Ways to get 5 more offline minutes: **watch 2 ads** (while online) **or pay 100 coins**.
   - When internet comes back after the free period → interstitial first.
   - Ad-free users (pass / approved grant / coupon) are exempt and play offline freely.
5. **Ads placement (decided)**
   - Interstitial after **every game end, win or lose** (already so; keep).
   - **Banner ad at the bottom** of screens (where it doesn't cover gameplay; confirm screens).
   - **Deleting your own records** (reset progress / records) requires watching an ad.
   - No ads for ad-free users.
6. **Rewarded coin ads: no limits** – remove the 15/day cap **and** the 5-minute cooldown.
7. **Undo in every game, ad per step** – back 1 step = 1 ad, 2 steps = 2 ads, **max 3 steps = 3 ads**.
   Also ads for hint and extra life / continue; add an ad option wherever coins are offered.
8. **2048 undo** (part of 7).
9. **BUG – Sudoku: numbers cannot be entered** (reproduce on phone, fix first).
10. **Coupons – admin**
    - Coupons live only in Firestore `coupons/{CODE}` (user created none yet).
    - Assign a coupon to a specific user (uid/email); others get "not valid for this account".
    - Log redemptions (`coupons/{CODE}/redemptions/{uid}`: name, email, date, version) to see who uses it.
    - Revoke: `active: false` or delete the user's redemption → ads return on next start / Shop open.
    - Step-by-step Firebase guide for create / assign / see users / revoke.
11. **How to play** – ❓ button in every game's top bar, step-by-step rules in 9 languages;
    interstitial when they close it and go back (not for ad-free users).
12. **Coins in every game, kept low** – every game (including puzzle/level games) pays a small
    amount of coins; review all reward amounts and keep them low.
13. **Ranking serial numbers** – show the rank number (1, 2, 3 …) on every leaderboard row.
14. **Feedback & Rate in Profile** – Profile tab gets "Rate us" (Play review / store page) and
    "Send feedback" (email to aiforsmart@gmail.com) so anyone can give it any time.

**Started 2026-10-13.**

## Status 2026-10-13 (v1.0.10+14 installed on phone, all 797 tests pass)
Done: 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14.

### Still to do (user will check the app and add improvements first – wait for go)
- **Point 3: home-screen widget 1×3** – not started.
- **Chakra: go back to the earlier version** – user prefers the first chakra (about 12 games
  on the wheel, the rest as cards below it). Revert commit "Chakra fits every game…"
  (game_chakra.dart itemSize/radii/hub changes + test/home/chakra_fit_test.dart).
- Long game titles wrap to two lines in the top bar since the ❓ button was added
  (e.g. "Block Puzzle · Extreme") – shrink/ellipsize the title.
- Undo is not in Block Puzzle, Hexa Sort, Screw Jam, Bus Jam (ask if wanted).
- Build the AAB for 1.0.10 after the next round; user must re-publish firestore.rules
  (coupon redemptions rule).
15. **Rate each game** – players can rate individual games (stars) inside the app.
16. **Which game is played most** – the developer must be able to see play counts per game
    (and the per-game ratings), e.g. Firestore `game_stats/{gameId}` counters or Firebase Analytics.

## Round 2026-10-17 (in progress)
17. **Save & continue every game** – leaving mid-game must resume where you left (only 2048 and
    Sudoku did). Block Puzzle done.
18. **Hint in every game** – "what is the next good move" (missing in Block Puzzle, Ball Sort,
    Sliding Puzzle, Focus Colors, Hexa, Chess, Memory...).
19. **New, nicer logo / app icon.**
20. **Arrow Maze shapes** – boards shaped like a train, bus, plane, mountain, city skyline (city
    in the background) or letters/quotes; arrows slide out of that shape.
21. Production access answers given in chat (closed test ends 2026-10-18).
22. **Online 2-player games (Chess first, then any 2-player game)** – signed-in players only:
    - "Online / available" switch: players can show themselves as ready to play.
    - **Quick match**: play a random available player.
    - **Unique player name**: search a player by name and send a game request; they accept/decline.
    - Live game; moves sync through Firestore (rules so each player only moves in their own game).
23. **Edge-to-edge (Play warning on 1.0.11)** – "Edge-to-edge may not display for all users" (Android 15 /
    SDK 35). Fix later: in `android/app/.../MainActivity.kt` override `onCreate` and call
    `enableEdgeToEdge()` before `super.onCreate` (add `androidx.activity:activity-ktx` to
    `android/app/build.gradle.kts`), then check every screen on the phone that nothing hides under the
    status / navigation bar (SafeArea). User said: not now, do it in a later update.

## Status 2026-10-19 – v2.0.0 (build 17), first production release
Production access approved. Shipped since 1.0.10:
- 1.0.11: save & continue in 14 games; hints (one ad each) in every game.
- 1.0.12: Arrow Maze picture boards (pictures, mini pictures on small boards, big letters every
  3rd level); Bus Jam chibi passengers; ivory / ebony chess pieces; sign-out wipes the phone's
  copy (cloud keeps it) and a different account never inherits the old data.
- 2.0.0:
  - **Online Chess (item 22, first part done):** unique player name (`handles/`), "Available"
    switch + lastSeen heartbeat, Quick match queue, search by name + challenge, incoming
    challenge pop-up anywhere in the app, live game synced through Firestore (`games/`),
    resign, claim win when the opponent is silent 5 min, wins / losses on the profile.
    Entry: Chess menu → "Play online". Code: `lib/core/cloud/online_service.dart`,
    `lib/games/chess/online/`.
  - **Ads:** interstitial after every 2 games, or at the next game end once 1 minute has passed
    since the last one (never in the middle of a game – AdMob policy). One rewarded ad = 3 undo
    steps.
- **User must publish the new `firestore.rules`** (players, handles, challenges, queue, games),
  otherwise online play gets "permission denied". Copy: `D:\gita\Games\firestore_rules.txt`.

Still open:
- 23 edge-to-edge (Android 15) – later, user said not now.
- 22 rest: other 2-player games online (Hexa / 2048 races etc., see list in chat), draw offers,
  online clocks, friends list.
- New app icon (Gemini sign-in needed).

## Status 2026-10-23 – v2.1.0 (build 18) AAB built
Since 2.0.0: Ludo (cpu / pass & play / online rooms, quick match, challenges), Saanp-Seedhi
(same three modes; online uses the ludo_games docs with game = 'snakes'), Brain Age (15+, small
age bands, range result, tips, practice), Mom Memory enabled (last), new default "Arcade" home
(hero cards, game of the day, Top games from game_stats plays, category shelves; chakra still in
Settings), pure white / black chess pieces, Arrow Maze ~2x arrows + black-on-white / white-on-black
styles, Bus Jam bus-stop + park look, ad-free grant / coupon re-checked when the user signs in.
**Publish firestore_rules.txt before releasing** (ludo_* rules, queue 'game' field).

## Noted 2026-10-24 (do later, when the user says)
- **AdMob suspended** (invalid clicks/impressions) Oct 23 – Nov 22, 2026. No ads / payments on hold.
- **Remove "watch ad for coins" completely** (user's decision): Shop `_adCard` / `_watchAd` in
  lib/core/shop/shop_screen.dart, `AdsService.watchAdForCoins`, `rewardedCoins`, `rewardedToday`,
  strings shop.watch_ad_title / shop.ads_unlimited / shop.watch, tests in test/economy/economy_test.dart.
  Keep undo / hint / extra-chance ads and interstitials.
- Phone builds: always `--dart-define=TEST_ADS=true` (added 2026-10-24). The user's own phone is
  already a registered AdMob test device.
- Do NOT build any APK until the user asks. The 2.1.0+18 AAB was built before this note; rebuild it
  after the coin-ad removal.
- **Next build: turn AdMob off temporarily** (user, 2026-10-24). Planned: ad provider switch
  (AdMob / Unity / Off, read from Firestore so it can change without an update), Unity Ads as
  default (user creates Unity account: Game ID + Rewarded/Interstitial/Banner units), test mode on
  own/tester phones, app-ads.txt Unity line, Data safety update. Then In-App Purchase (Play
  Billing): ad-free 1 month ₹49 sub / 1 year ₹399 sub / lifetime ₹499, coins 500 ₹29 / 1500 ₹79 /
  5000 ₹199 (prices to confirm), restore via cloud account. User must create the Play payments
  profile first. Waiting for the user's go and answers (prices, coin packs, banner).
