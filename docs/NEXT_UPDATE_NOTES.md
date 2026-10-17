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
