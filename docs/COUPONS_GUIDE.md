# Master G – No-ads Coupon guide (step by step)

Coupon = ek code (jaise `DIWALI2026`). Jo player Shop me ye code daalega, use **ads nahi dikhenge**.
Coupon lagane ke liye player ka **login (Google / email)** zaroori hai – isi se pata chalta hai kisne lagaya.

> Pehle `firestore.rules` dobara **Publish** karna zaroori hai (naya `redemptions` rule).
> Firebase Console → Firestore Database → Rules → `D:\gita\Games\puzzle_hub\firestore.rules` ka poora text paste → Publish.

---

## 1. Naya coupon banana (sabke liye)
1. Firebase Console → **Firestore Database → Data**.
2. Pehli baar: **+ Start collection** → Collection ID: `coupons` → Next.
   (Baad me: `coupons` kholo → **+ Add document**.)
3. **Document ID** = coupon code, **CAPITAL letters me**, bina space (jaise `DIWALI2026`).
4. Field add karo:

| Field | Type | Value |
|---|---|---|
| `active` | boolean | `true` |
| `expiresAt` *(optional)* | timestamp | is date ke baad coupon band |

5. **Save**. Ab koi bhi logged-in player Shop → "Coupon" me `DIWALI2026` daal kar ads band kar sakta hai.

## 2. Coupon sirf kisi khaas user ko dena
Coupon document me ek ya dono field jodo:

| Field | Type | Value |
|---|---|---|
| `uids` | array | us player ka **User ID** (ads-free request mail me milta hai) – ek se zyada bhi daal sakte ho |
| `emails` | array | us player ka **email** (jaise `friend@gmail.com`) |

Ab sirf in players ke liye coupon chalega. Baaki ko "Ye coupon aapke account ke liye nahi hai" dikhega.

## 3. Kaun-kaun use kar raha hai – kaise dekhein
1. `coupons` → apna coupon (jaise `DIWALI2026`) kholo.
2. Usme **`redemptions`** sub-collection dikhega (pehla use hote hi apne-aap banta hai).
3. Har document = ek player: **Document ID = User ID**, aur fields:
   `name`, `email`, `country`, `version`, `at` (kab lagaya).

## 4. Coupon hatana / ads wapas chalu karna
- **Sabke liye band:** coupon document me `active` ko **false** kar do.
- **Sirf ek player ke liye band:** `coupons/<CODE>/redemptions/<USER ID>` kholo →
  field add karo `revoked` (boolean) = **true**  *(ya pura document delete kar do)*.
- Player jab app khole ya Shop khole, ads wapas aa jaate hain.
- Dobara chalu: `revoked` ko `false` karo (ya `active` ko `true`).

## 5. Dhyan rakhein
- Code me space/`/` nahi; 4–40 characters.
- Coupon ka code jise doge wahi use karega – public jagah mat daalo (ya `uids`/`emails` se limit karo).
- Ads-free approval (mail wala) alag cheez hai – uski guide: `docs/ADFREE_AND_LEADERBOARD_GUIDE.md`.
