# Firebase setup (cloud save, login, leaderboards, invites)

The app runs fully offline without Firebase. Until `android/app/google-services.json`
exists, `CloudService.available` is `false` and every cloud screen shows
"Cloud setup pending". Follow these steps once to switch the online features on.

## 1. Create the project

1. Open https://console.firebase.google.com and click **Add project**.
2. Name it (e.g. `Master G`). Google Analytics is optional.

## 2. Add the Android apps

In **Project settings -> General -> Your apps -> Add app -> Android**:

| App | Package name | Used for |
| --- | --- | --- |
| Release | `com.memorypuzzle.app` | Play Store builds |
| Debug | `com.memorypuzzle.app.dev` | `flutter run` debug builds (`applicationIdSuffix ".dev"`) |

Skip the "download config" and "add SDK" steps for now (the Gradle plugin is already wired up).

## 3. Add the SHA fingerprints (needed for Google Sign-In)

Add **both SHA-1 and SHA-256** for every key that signs the app
(**Project settings -> Your apps -> select the app -> Add fingerprint**).

**a) Upload key** (release app `com.memorypuzzle.app`), from the `puzzle_hub` folder:

```
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
```

**b) Play App Signing key** (release app): Play Console -> your app ->
**Test and release -> Setup -> App signing** (older UI: *Release -> Setup -> App integrity*)
-> copy the SHA-1 and SHA-256 of the **App signing key certificate**.
Without this, Google Sign-In fails for users who install from the Play Store.

**c) Debug key** (debug app `com.memorypuzzle.app.dev`):

```
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

(or run `gradlew signingReport` inside `android/`).

## 4. Enable sign-in methods

**Build -> Authentication -> Get started -> Sign-in method**:

1. **Google** -> Enable -> choose a support email -> Save.
   (This creates the *Web client* OAuth ID that Google Sign-In needs; it is
   included in `google-services.json` automatically, so download the file
   **after** this step.)
2. **Email/Password** -> Enable (leave "Email link" off) -> Save.
3. Optional: **Authentication -> Templates** to customise the verification and
   password-reset emails.

## 5. Create Firestore

1. **Build -> Firestore Database -> Create database**.
2. Choose a location close to your players (e.g. `asia-south1` for India). It cannot be changed later.
3. Start in **production mode**.
4. Open the **Rules** tab, replace everything with the contents of
   [`firestore.rules`](firestore.rules) and click **Publish**.

No indexes are needed (leaderboards use a single-field `score` order).

## 6. Download `google-services.json`

**Project settings -> General -> Your apps -> (either Android app) -> google-services.json**.
One file contains both apps. Save it as:

```
puzzle_hub/android/app/google-services.json
```

Re-download it whenever you add a fingerprint or app. Do not commit it to a public repository.

## 7. Rebuild

```
flutter clean
flutter pub get
flutter run            # debug (.dev)
flutter build appbundle  # release
```

The Gradle build applies the `google-services` plugin automatically once the
file exists. On start the app calls `Firebase.initializeApp()`; if that fails it
quietly stays offline.

## 8. Check it works

1. Profile -> **Continue with Google** (or Email) -> the cloud card shows your
   account and "Last synced: just now".
2. Firestore console shows `users/<uid>` with a `data` map.
3. Play a score game, open **Leaderboard** -> your entry is there.
4. Profile -> **Invite friends** shares
   `https://play.google.com/store/apps/details?id=com.memorypuzzle.app&referrer=ref_<uid>`.
   The referral only triggers for installs from the Play Store (the Install
   Referrer API); the invitee gets 50 coins after their first level while signed in, the
   inviter gets 100 coins on their next sync (max 20 invites).

## Account deletion (Google Play policy)

- In-app: Profile -> **Account delete karein** deletes the Firestore user
  document, the player's leaderboard entries and referral record, the Firebase
  Auth user, and all local data on the phone. Firebase may ask the player to
  sign in again first.
- Play Console also requires a **web link** where users can request deletion
  without the app (**App content -> Data safety -> Data deletion**). Placeholder:

  `https://YOUR-DOMAIN.example/master-g/delete-account`

  Create a simple page (Google Form / Sites page / email link) that asks for
  the account email and explains that the account, cloud save and leaderboard
  entries are deleted within 30 days. Delete such accounts manually in
  **Authentication -> Users** and **Firestore -> users/<uid>**,
  **leaderboards/*/entries/<uid>** and **referrals/<uid>**.
- Update the Data safety form: Email address + User IDs (account management),
  App activity / in-game progress (app functionality); data is encrypted in transit
  and users can request deletion.

## What is stored

| Path | Content |
| --- | --- |
| `users/{uid}` | `name`, `data` (the player's local game keys: records, stars, coins ledger, saved games), `meta` (per-key `updatedAt` for saved games), `updatedAt`, `pendingCredits`, `inviteCount` |
| `leaderboards/{board}/entries/{uid}` | `name`, `score`, `updatedAt` (boards: `game_2048`, `focus_color`, `memory_boost`, `block_puzzle`, `total_stars`) |
| `referrals/{inviteeUid}` | `inviter`, `inviterCredited`, `createdAt` |

The local PIN and fingerprint lock never leave the phone.

## Troubleshooting

- **Google sign-in fails / error 10 (DEVELOPER_ERROR)**: a SHA fingerprint is
  missing for the key that signed this build (debug, upload or Play signing),
  or `google-services.json` was downloaded before Google sign-in was enabled.
  Add the fingerprint, re-download the file, rebuild.
- **"Cloud setup pending" still shows**: the file is not at
  `android/app/google-services.json`, or its `package_name` does not match the
  build (`.dev` for debug builds). Run `flutter clean` and rebuild.
- **PERMISSION_DENIED in logs**: the rules from `firestore.rules` were not published.
