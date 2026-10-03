# puzzle_hub

Memory Puzzle - Brain games collection built with Flutter.

## Release & Play Console Publishing Guide

To ensure your app passes **Internal Testing** and **Closed Testing** in Google Play Console without friction, follow these steps.

---

### 1. How to get SHA-1 and SHA-256 Keys from Google Play Console

Once you upload your first build to Play Console:
1. Open [Google Play Console](https://play.google.com/console).
2. Select your app (**com.memorypuzzle.app**).
3. In the left navigation, go to **Release** > **Setup** > **App integrity** (or **App signing**).
4. Under **App signing key certificate**, you will find:
   - **SHA-1 certificate fingerprint**
   - **SHA-256 certificate fingerprint**
5. Under **Upload key certificate**, you will also find the Upload key's SHA-1 and SHA-256.

> **Important**: If you integrate services like **Firebase**, **Google Sign-In**, **Google Play Games Services**, or **Google Maps**, you must add **both** the **Upload Key SHA-1** AND the **App Signing Key SHA-1** into Firebase Console / Google Cloud Console.

---

### 2. How to Generate Local Keystore SHA-1 / SHA-256 Keys

Run this command from the project root (or `android` folder):

```bash
cd android
./gradlew signingReport
```

On Windows (Command Prompt / PowerShell):
```powershell
cd android
.\gradlew.bat signingReport
```

Alternatively, using JDK `keytool`:
```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
```

---

### 3. Steps for Release Signing Setup

1. Generate your release upload keystore (if not created yet):
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (based on `android/key.properties.example`):
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=app/upload-keystore.jks
   ```

---

### 4. Build Android App Bundle (.aab) for Testing

```bash
flutter build appbundle --release
```
The output file will be generated at:
`build/app/outputs/bundle/release/app-release.aab`

---

### 5. Pre-Checklist to Pass Internal & Closed Testing Directly

- [x] **Unique Package Name / Application ID**: `com.memorypuzzle.app` set in `android/app/build.gradle.kts`.
- [x] **Version Code**: Increment `version` build number in `pubspec.yaml` (e.g. `1.0.0+1` -> `1.0.0+2`) before each upload.
- [x] **Target SDK**: Configured with current Flutter SDK standards (`compileSdk` & `targetSdk`).
- [x] **App Content Declarations**: Complete target audience, privacy policy, and content rating in Google Play Console.
