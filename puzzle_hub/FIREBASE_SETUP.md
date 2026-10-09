# Firebase setup checklist (login, cloud save, leaderboards, invites)

The app works fully **without** Firebase. Until the setup below is finished,
cloud screens show "Cloud setup pending" and progress stays on the phone.

Do these steps once, in order. Tick each box when done.

## Part A - Firebase project

1. [ ] Open https://console.firebase.google.com -> **Add project** -> name it
   (e.g. `Master G`). Analytics is optional.
   The project starts on the free **Spark** plan. Do not add a card.

2. [ ] Add the two Android apps: **Project settings (gear icon) -> General ->
   Your apps -> Add app -> Android**.
   - App 1 (Play Store): package name `com.memorypuzzle.app`
   - App 2 (test builds from `flutter run`): package name `com.memorypuzzle.app.dev`

   Skip "Download config" and "Add SDK" for now (already done in the code).

## Part B - SHA fingerprints (Google login will NOT work without these)

For each key below, copy **SHA-1** and **SHA-256** and add both in
**Project settings -> Your apps -> (choose the app) -> Add fingerprint**.

`keytool` comes with Android Studio. Run these in **Command Prompt (cmd)**.

3. [ ] **Upload key** -> add to app `com.memorypuzzle.app`:

   ```
   cd D:\gita\Games\puzzle_hub\android\app
   "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore upload-keystore.jks -alias upload
   ```

   It asks for the keystore password (the one in `android\key.properties`).

4. [ ] **Play Console app-signing key** -> add to app `com.memorypuzzle.app`:
   Play Console -> your app -> **Test and release -> App integrity -> App signing**
   -> copy SHA-1 and SHA-256 of the **App signing key certificate**.
   (Without this, Google login fails for people who install from the Play Store.)

5. [ ] **Debug key** -> add to app `com.memorypuzzle.app.dev`:

   ```
   "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```

## Part C - Login methods

6. [ ] **Build -> Authentication -> Get started -> Sign-in method**:
   - **Google** -> Enable -> pick your support email -> Save.
   - **Email/Password** -> Enable (keep "Email link" off) -> Save.

## Part D - Database (Firestore)

7. [ ] **Build -> Firestore Database -> Create database**.
   - Location: **`asia-south1` (Mumbai)** - best for players in India.
     It can never be changed later.
   - Choose **production mode**.

8. [ ] Rules: open the **Rules** tab, delete everything, paste the whole file
   [`firestore.rules`](firestore.rules), click **Publish**.

9. [ ] Indexes (needed for the India / country leaderboards):
   **Firestore Database -> Indexes -> Composite -> Create index**. Make these two:

   | Collection ID | Field 1 | Field 2 | Query scope |
   | --- | --- | --- | --- |
   | `entries` | `country` Ascending | `score` Descending | Collection |
   | `entries` | `country` Ascending | `score` Ascending | Collection |

   Wait until the status shows **Enabled** (a few minutes). The same indexes
   are listed in [`firestore.indexes.json`](firestore.indexes.json).
   Tip: if one is missing, the app log shows an error with a direct
   "create index" link - open it and click **Create**.

## Part E - Config file and build

10. [ ] Download `google-services.json`: **Project settings -> General -> Your apps ->
    (any Android app) -> google-services.json**. One file covers both apps.
    Put it here (replace the old one):

    ```
    D:\gita\Games\puzzle_hub\android\app\google-services.json
    ```

    Download it **again** every time you add an app, a fingerprint, or turn on
    Google login (steps 2-6). Do not upload it to a public GitHub repo.

11. [ ] Rebuild:

    ```
    flutter clean
    flutter pub get
    flutter run
    flutter build appbundle
    ```

12. [ ] Check: Profile -> **Continue with Google** works -> play 2048 ->
    **Leaderboard** shows your name under **India** and **Global**.

## Free plan limits (Spark)

- About **50,000 reads** and **20,000 writes** per day, 1 GB storage - free.
- Each leaderboard open is about 50 reads; each sync or new best score is 1-2 writes.
  This is enough for a few thousand daily players.
- If you reach the limit, cloud features pause until the next day (games keep working).
- Consider the paid **Blaze** plan (pay only for what you use, has a free part too)
  when Firebase **Usage** shows you near the daily limits regularly.
  Set a **budget alert** in Google Cloud billing first.

## If something goes wrong

- **Google login error 10 / DEVELOPER_ERROR**: a SHA fingerprint is missing
  (steps 3-5), or `google-services.json` is old. Fix, download again, rebuild.
- **Still "Cloud setup pending"**: the file is not in `android\app\`, or the
  app you are running is not in it (test builds need `com.memorypuzzle.app.dev`).
- **PERMISSION_DENIED**: rules not published (step 8).
- **Country leaderboard does not load**: indexes not ready (step 9).

## Account deletion (Play Store rule)

- In the app: Profile -> **Account delete karein** removes the cloud save,
  leaderboard entries, invite record and the login.
- Play Console also needs a **web link** for deletion requests
  (**App content -> Data safety -> Data deletion**), e.g. a Google Form asking for
  the account email. Delete such accounts by hand in **Authentication -> Users** and
  Firestore (`users/<uid>`, `leaderboards/*/entries/<uid>`, `referrals/<uid>`).

## What is stored

| Path | Content |
| --- | --- |
| `users/{uid}` | `name`, `country` (e.g. `IN`), `data` (game records, stars, coins, saved games), `meta`, `updatedAt`, `pendingCredits`, `inviteCount` |
| `leaderboards/{board}/entries/{uid}` | `name`, `score`, `country`, `updatedAt`. Boards: `game_2048`, `focus_color`, `memory_boost`, `block_puzzle`, `chess` (wins), `total_stars` |
| `referrals/{inviteeUid}` | `inviter`, `inviterCredited`, `createdAt` |

The PIN and fingerprint lock never leave the phone.
