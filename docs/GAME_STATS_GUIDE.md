# Master G – Kaunsa game zyada khela ja raha hai + game ratings

Firebase Console → **Firestore Database → Data** → collection **`game_stats`**.
Har game ka ek document hai (Document ID = game id, jaise `block_puzzle`, `game_2048`, `sudoku`).

| Field | Matlab |
|---|---|
| `plays` | game kitni baar khola gaya (sab players milakar) – **sabse bada = sabse zyada khela gaya** |
| `ratings` | kitne players ne is game ko rate kiya |
| `stars` | sabhi stars ka total |
| `r1` … `r5` | kitne logon ne 1★, 2★ … 5★ diya |

**Average rating = `stars` ÷ `ratings`** (jaise stars 46, ratings 10 → 4.6★).

Har player ki apni rating: `game_stats/<game>/ratings/<User ID>` → `stars`.

Players rating kahan se dete hain:
- Profile → **Records** → har game ke neeche 5 stars (kabhi bhi badal sakte hain)
- Jeetne ke baad kabhi-kabhi "Ye game kaisa laga?" popup
(Rating ke liye login zaroori; plays sabke gine jaate hain.)

> Iske liye `firestore.rules` dobara **Publish** karna zaroori hai (naya `game_stats` rule).
