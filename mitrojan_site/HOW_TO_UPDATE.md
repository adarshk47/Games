# AYUSH Vaidya website – update kaise karein

Website ki saari files `D:\gita\Games\mitrojan_site` mein hain.
Page seedhe `ayush\` folder mein mat badliye – `ayush_src\` mein badalkar **build** chalaiye, woh `ayush\` ke pages bana deta hai.

---

## 1. Naya article likhna (Dolly ji ya Pooja ji ki taraf se)

1. `ayush_src\articles\_TEMPLATE.md` ko copy kariye.
2. Copy ka naam badaliye: `saal-mahina-din-chhota-naam.md`
   Jaise: `2026-11-05-sardi-mein-chai.md`
   (Naam mein space nahi, sirf chhote angrezi akshar, number aur `-`.)
3. File ko Notepad mein kholiye aur upar ki lines bhariye:

   ```
   title: Article ka title
   author: dolly            ← Dolly ji ke liye "dolly", Pooja ji ke liye "pooja"
   emoji: 🌿                ← koi bhi ek emoji
   date: 2026-11-05         ← saal-mahina-din
   summary: Ek line jo Articles page par dikhegi.
   image: chai.jpg          ← (optional) chhoti photo; khaali chhodenge to emoji dikhega
   ---
   ```

4. `---` ke neeche apna article likhiye:
   - Khaali line chhodne par naya paragraph.
   - `## ` se shuru line = heading.
   - `- ` se shuru line = point.
   - `**shabd**` = bold.
   - `[link ka text](diet.html)` = link.
   - Beech mein photo: `![chhota vivaran](photo.jpg)` (photo `ayush\images\` mein ho).
5. Save kariye. Phir neeche **3. Build** aur **4. Deploy** kariye.

Article apne aap:
- apne page par aa jayega: `ayush.mitrojan.in/article-2026-11-05-sardi-mein-chai.html`
- Articles page par sabse naye **3 articles bade card** mein dikhenge (nayi date pehle),
- baaki saare purane articles neeche **"Purane articles"** ki band list mein, date aur headline ke saath (click karne par khulti hai),
- Google ke sitemap mein jud jayega.

### Photo lagana (optional)
1. Photo ko `D:\gita\Games\mitrojan_site\ayush\images\` folder mein rakhiye (naam mein space nahi, jaise `chai.jpg`).
2. **Photo chhoti rakhiye – 300 KB se kam.** Phone se li photo badi hoti hai: use https://squoosh.app par kholkar "Resize" se chaudai 800 karke save kariye.
   Photo badi hogi ya folder mein nahi milegi to `python build.py` chalate waqt `!` ke saath chetavani aayegi.
3. Article mein:
   - Upar `image: chai.jpg` likhne par photo title ke saath (aur Articles page ke card par) chhoti si dikhegi.
   - Beech mein kahin bhi: `![chai ki photo](chai.jpg)`

Kisi article ko chhupana ho to file ke naam ke aage `_` laga dijiye (jaise `_2026-11-05-sardi.md`), phir build aur deploy.

---

## 2. Khaali jagah (______) bharna

`ayush_src\build.py` kholiye. Upar `CLINIC` aur `DOCTOR_INFO` mein quotes `''` ke beech jaankari likhiye:

```python
'phone': '+91 98765 43210',
'whatsapp': '919876543210',      # sirf number, 91 ke saath, bina + aur space
'fee_consult': '₹300',
```

Doctor ki photo: photo `ayush\` folder mein rakhiye (jaise `dolly.jpg`) aur `'photo': 'dolly.jpg'` likhiye.
Jab tak koi value khaali hai, site par `______` dikhta hai, aur WhatsApp / call / map ke button chhupe rehte hain.

---

## 3. Build (pages banana)

Terminal / PowerShell mein:

```
cd D:\gita\Games\mitrojan_site\ayush_src
python build.py
```

Aakhir mein `built into ... ayush:` aur pages ki list aani chahiye. Koi galti ho (jaise `author` galat) to woh line bata dega.

Deploy se pehle dekhna ho (optional):

```
python -m http.server 8791 --directory D:\gita\Games\mitrojan_site\ayush
```

phir browser mein `http://localhost:8791` kholiye. Band karne ke liye Ctrl+C.

---

## 4. Deploy (live karna)

```
cd D:\gita\Games\mitrojan_site
firebase deploy --only hosting:ayush-mitrojan --project project-8e4ae5be-6ac1-49ce-bc8
```

`Deploy complete!` aane ke baad https://ayush.mitrojan.in par badlav dikh jayenge (browser mein Ctrl+F5).

- mitrojan.in home page badla ho: `--only hosting:mitrojan`
- Bittu Mobile page badla ho: `--only hosting:bittumobile-mitrojan`
- Sab ek saath: `--only hosting`

Pehli baar `firebase login` karna pad sakta hai (aiforsmart@gmail.com se).

---

## 5. Admin calendar login (bookings dekhna)

`https://ayush.mitrojan.in/admin.html` – Google se login.

| Account | Kya dikhta hai |
|---|---|
| aiforsmart@gmail.com | Saari bookings (dono doctors) |
| tripti15d@gmail.com | Sirf Vaidya Dolly Gupta ki bookings |
| pujagupta9813@gmail.com | Sirf Vaidya Pooja Gupta ki bookings |

Yeh roktok **Firestore rules** mein hai. Account badalne / jodne ke liye:
1. `D:\gita\Games\firestore_rules.txt` mein `ayushAdmin()` (owner) ya `ayushDoctorLogins()` (doctor) wali list badaliye.
2. Firebase Console → Firestore Database → **Rules** → poori file paste → **Publish**.

⚠️ Yahi rules Master G games bhi use karte hain. Console mein hamesha woh `firestore_rules.txt` paste kariye jismein **AYUSH Vaidya bookings** wala hissa ho
(woh hissa alag se `mitrojan_site\firestore_rules_ayush.txt` mein bhi rakha hai).
