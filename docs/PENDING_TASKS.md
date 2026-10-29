# Master G: pending tasks (29 Oct 2026)

Test apps on the phone: **Master G V1** (2.5.0), **Master G V2** (2.6.0), **Master G V3** (2.7.0), all updated on 29 Oct.
AABs are ready: `MasterG-2.5.0.aab`, `MasterG-2.6.0.aab`, `MasterG-2.7.0.aab`. They will be rebuilt after your feedback.

---

## A. Code tasks (I'll do these once you say go)

### Before the next AAB build
| # | Task | Notes |
|---|---|---|
| 1 | **Remove the AYUSH link** | Remove from Profile → "Our websites". **mitrojan.in stays.** |
| 2 | **Gita and Ramcharitmanas links** | Will be added once you send the URLs. |
| 3 | **Names of the 2 "New game – Coming soon" cards in V3** | Once you send the names (or pick a new game). |
| 4 | **Remove "Watch ad for coins"** | Shop card + code. Undo, hint and extra-life ads stay. |
| 5 | **Fixes from your V1/V2/V3 feedback** | Waiting for your feedback. |

### Next big update
| # | Task | Notes |
|---|---|---|
| 6 | **New languages** | German, French, Spanish, Italian (please confirm this list) + **Urdu** and **Arabic**. Urdu/Arabic are right-to-left, so every screen needs RTL support. Play Store listing translations too. |
| 7 | **GDPR consent popup** | Needed for the Europe/UK launch (Unity ads), plus the privacy policy update. |
| 8 | **AdMob ⇄ Unity switch** | After 22 Nov (the AdMob suspension ends). Switchable from Firestore `config/app.ads` = unity / admob / off. |
| 9 | **Home-screen widget 1×3** | 3 games on the phone's home screen; tapping one opens that game directly. Not started (only app-icon shortcuts exist). |
| 10 | **Online play for more games** | Online play for other 2-player games (like Chess, Ludo, Saanp-Seedhi, Business), plus draw offers, a clock and a friends list. |
| 11 | **Leaderboard for players who aren't signed in** | Show your own offline score at the end of the list with "Sign in to join". Check it on the phone; it may be partly done. |

---

## B. Your tasks (Play Console / Firebase / Google Ads)

| # | Task | When |
|---|---|---|
| 1 | Firebase → Firestore → Rules: publish everything from `D:\gita\Games\firestore_rules.txt` | Before uploading the AABs |
| 2 | Play Console → App content → **Data safety**: update for Unity Ads and purchases | Before release |
| 3 | Firebase → **App Check**: register the app (don't turn on enforce) | Any time |
| 4 | Upload the AABs **in order**: 2.5.0 → 2.6.0 → 2.7.0 | After feedback |
| 5 | Play Console → set the **New Year sale prices**: ₹19 (1 month), ₹199 (1 year), ₹299 (lifetime), 20 Dec – 5 Jan | Before 20 Dec |
| 6 | Raise **India prices**: ₹49 / ₹399 / ₹499 | After 17 Nov |
| 7 | **AdSense** (same old account) and the AdMob switch | After 22 Nov |
| 8 | **Google Ads:** remove **India** from campaign MasterG-CA-SG-AE-Test1 (all 18 installs, ₹184, came from India) | Now |
| 9 | Google Ads ⇄ Firebase link: add aadarshk627@gmail.com as Admin in Google Ads, then link from Analytics | Any time (not urgent) |

---

## C. Google Ads result (27–29 Oct)
- Installs: **18** · Spend: **₹184.79** · About **₹10 per install**
- Every install came from **India**. Canada, Singapore and UAE got ₹0 of spend.
- Next: once India is removed, check the real cost abroad. The campaign runs until 4 Nov.
