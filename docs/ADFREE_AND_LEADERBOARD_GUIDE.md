# Master G – Ads-free approval aur Leaderboard setup (step by step)

## A. Pehli baar: Firestore rules publish karo (sirf ek baar, ya jab bhi rules badlein)

1. https://console.firebase.google.com kholo → apna Master G project chuno.
2. Left menu → **Build → Firestore Database** → upar **Rules** tab.
3. PC par file kholo: `D:\gita\Games\puzzle_hub\firestore.rules` (Notepad me) → **Ctrl+A, Ctrl+C**.
4. Firebase ke Rules editor me sab select karke (**Ctrl+A**) paste karo (**Ctrl+V**).
5. **Publish** dabao. "Rules published" aa gaya to ho gaya.

Isse ye chalu hote hain:
- Naye leaderboards (Easy / Medium / Hard / Extreme, 2048 me Classic bhi)
- No-ads coupons
- Ads-free approval (`adfree_grants`)

## B. Naye leaderboard (category-wise) – kaise kaam karta hai

Kuch setup nahi chahiye (rules publish ke baad apne-aap):
1. Player Google/email se login kare (Profile tab).
2. Koi game khele (Block Puzzle, 2048, Chess, Memory Boost, Focus Colors) – jis difficulty me khela, usi ka score save hota hai.
3. Profile → **Leaderboard** → upar game chuno → neeche **Easy / Medium / Hard / Extreme** chip chuno.
4. Top 5 ko Diamond, Gold, Silver, Bronze, Steel badge milta hai; World / Country dono.

Agar leaderboard khali dikhe ya error aaye:
- Rules publish hue hain? (Step A)
- Firestore → **Indexes** tab me dono index "Enabled" hain? (`country` Ascending + `score` Descending, aur `country` Ascending + `score` Ascending, collection group `entries`)

## C. Ads-free request APPROVE karna

1. Player app me **Shop → "Remove ads completely"** → period chunta hai (1 month / 3 months / 6 months / 1 year / 5 years) → **Send request**.
2. Aapke mail **aiforsmart@gmail.com** par mail aata hai. Usme likha hota hai:
   `Requested period`, `Request date & time`, `Name`, **`User ID`**, `Email`, `Country`.
3. Firebase Console → **Firestore Database → Data**.
4. Pehli baar: **+ Start collection** → Collection ID: `adfree_grants` → Next.
   (Baad me: `adfree_grants` collection kholo → **+ Add document**.)
5. **Document ID** = mail wala **User ID** (bilkul same, copy-paste karo).
6. Fields add karo:
   | Field | Type | Value |
   |---|---|---|
   | `until` | **timestamp** | jis din/time tak ads band rakhne hain (jaise aaj + 3 mahine) |
   | `plan` | string | `3 months` (sirf yaad rakhne ke liye) |
   | `revoked` | boolean | `false` |
7. **Save**. Player jab app khole ya Shop khole, ads band ho jaate hain aur Shop me "Ad-free until …" dikhta hai.

Period ka hisaab: 1 month = +30 din, 3 months = +91, 6 months = +182, 1 year = +365, 5 years = +1826 din.

## D. Ads-free REVOKE karna (wapas ads chalu)

Teen me se koi ek tarika:
1. **Sabse aasaan:** `adfree_grants/<User ID>` document kholo → `revoked` ko **true** kar do → Update. (Record bhi bacha rahega.)
2. Ya `until` ki date aaj se pehle ki kar do.
3. Ya pura document **Delete** kar do.

Player ke app khone ya Shop kholne par ads wapas aa jaate hain. (Agar player offline hai to agli baar online hone par.)

Dobara approve karna ho to `revoked` ko **false** karo aur `until` nayi date do.

## E. No-ads COUPON (sabke liye ek code)

Firestore → `coupons` collection → Document ID = code (CAPITAL, jaise `DIWALI2026`) → field `active` (boolean) = true.
Band karna: `active` = false.
