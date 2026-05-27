# 📱 Universal Wallet — Complete Developer Guide

> **Project:** my_wallet (Flutter)  
> **Version:** 1.0.0+1  
> **Platform:** Android • iOS • macOS • Web • Windows • Linux  
> **Tech Stack:** Flutter · Firebase Auth · Cloud Firestore · SQLite (sqflite) · fl_chart · PDF

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Project Setup](#2-project-setup)
3. [Firebase Configuration](#3-firebase-configuration)
4. [Running the App Locally](#4-running-the-app-locally)
5. [Running on Real Device](#5-running-on-real-device)
6. [Building for Release](#6-building-for-release)
7. [Deploying to Android (Play Store)](#7-deploying-to-android-play-store)
8. [Deploying to iOS (App Store)](#8-deploying-to-ios-app-store)
9. [Architecture & File Structure](#9-architecture--file-structure)
10. [Database Schema](#10-database-schema)
11. [Features Overview](#11-features-overview)
12. [Troubleshooting](#12-troubleshooting)
13. [Bug Fixes Applied](#13-bug-fixes-applied)

---

## 1. Prerequisites

Before you start, make sure the following are installed on your machine:

### Required Software

| Tool           | Version  | Check Command         | Install                                                       |
| -------------- | -------- | --------------------- | ------------------------------------------------------------- |
| Flutter SDK    | ≥ 3.11.0 | `flutter --version`   | [flutter.dev](https://flutter.dev/docs/get-started/install)   |
| Dart SDK       | ≥ 3.11.0 | `dart --version`      | Bundled with Flutter                                          |
| Android Studio | Latest   | —                     | [developer.android.com](https://developer.android.com/studio) |
| Xcode          | ≥ 15     | `xcodebuild -version` | Mac App Store                                                 |
| CocoaPods      | Latest   | `pod --version`       | `sudo gem install cocoapods`                                  |
| Java JDK       | ≥ 17     | `java -version`       | [adoptium.net](https://adoptium.net)                          |
| Git            | Any      | `git --version`       | [git-scm.com](https://git-scm.com)                            |

### Verify Flutter Installation

```bash
flutter doctor
```

All items should show ✅. Fix any ❌ items before continuing.

---

## 2. Project Setup

### Step 1 — Clone / Open the Project

```bash
# Navigate to the project folder
cd /Users/uvinduadeeshadeshapriya/Documents/Wallet/my_wallet

# OR if starting fresh from git
git clone <your-repo-url>
cd my_wallet
```

### Step 2 — Install Dependencies

```bash
flutter pub get
```

Expected output:

```
Got dependencies!
```

### Step 3 — Verify Code Quality

```bash
flutter analyze
```

Expected output:

```
No issues found!
```

---

## 3. Firebase Configuration

This app uses **Firebase Authentication** (Phone OTP + Google Sign-In) and **Cloud Firestore**.

### Step 1 — Firebase Project Setup

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add Project** → name it `my_wallet`
3. Enable **Google Analytics** (optional but recommended)

### Step 2 — Enable Authentication

1. In Firebase Console → **Authentication** → **Sign-in method**
2. Enable **Phone** authentication
3. Enable **Google** authentication
4. Under Google, set your **Support email**

### Step 3 — Add Android App

1. Firebase Console → **Project settings** → **Add app** → Android
2. Package name: `com.example.my_wallet` _(check `android/app/build.gradle` for actual package name)_
3. Download `google-services.json`
4. Place it at: `android/app/google-services.json`

### Step 4 — Add iOS App

1. Firebase Console → **Add app** → iOS
2. Bundle ID: check `ios/Runner.xcodeproj/project.pbxproj` for your bundle ID
3. Download `GoogleService-Info.plist`
4. Place it at: `ios/Runner/GoogleService-Info.plist`
5. In Xcode: drag `GoogleService-Info.plist` into the `Runner` target (check **Copy if needed**)

### Step 5 — Update firebase_options.dart

The file `lib/firebase_options.dart` was auto-generated. If you create a new Firebase project, regenerate it:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (run from project root)
flutterfire configure
```

This will update `lib/firebase_options.dart` automatically.

### Step 6 — Firestore Rules (if using Firestore)

In Firebase Console → **Firestore Database** → **Rules**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 4. Running the App Locally

### Run on iOS Simulator

```bash
# List available simulators
flutter emulators

# Launch a simulator first (example: iPhone 15)
open -a Simulator

# Run the app
flutter run -d "iPhone 11"
```

### Run on macOS Desktop

```bash
flutter run -d macos
```

### Run on Chrome (Web)

```bash
flutter run -d chrome
```

### Run on Android Emulator

```bash
# Create an AVD from Android Studio first, then:
flutter emulators --launch <emulator_id>
flutter run -d emulator-5554
```

### Hot Reload & Hot Restart

While the app is running:

| Key | Action                                    |
| --- | ----------------------------------------- |
| `r` | Hot Reload — refresh UI changes instantly |
| `R` | Hot Restart — full restart (resets state) |
| `q` | Quit                                      |
| `d` | Detach (keep app running)                 |
| `p` | Show performance overlay                  |

---

## 5. Running on Real Device

### Android (Physical Phone)

1. Enable **Developer Options** on your phone:
   - Settings → About Phone → Tap **Build Number** 7 times
2. Enable **USB Debugging** in Developer Options
3. Connect phone via USB
4. Accept the "Allow USB Debugging" prompt on phone
5. Verify device is detected:
   ```bash
   flutter devices
   ```
6. Run:
   ```bash
   flutter run
   ```

### iOS (Physical iPhone)

1. Connect iPhone via USB
2. Open `ios/Runner.xcworkspace` in Xcode
3. Set your **Team** (Apple Developer account) under Signing & Capabilities
4. Trust the developer on iPhone: Settings → General → VPN & Device Management
5. Run from terminal:

   ```bash
   flutter run -d "UVINDU ADEESHA DESHAPRIYA's iPhone"
   ```

   Or use the device ID from `flutter devices`:

   ```bash
   flutter run -d 00008030-001C49D826A0802E
   ```

> **Note for Phone Auth on real device:** Firebase Phone authentication requires SHA-1 fingerprints to be added in Firebase Console for Android. See [Firebase Phone Auth docs](https://firebase.google.com/docs/auth/android/phone-auth).

---

## 6. Building for Release

### Android APK (for sideloading / testing)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS Archive (for App Store / TestFlight)

```bash
flutter build ios --release
```

Then open Xcode → Product → Archive → Distribute App.

### macOS App

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/my_wallet.app`

### Web

```bash
flutter build web --release
```

Output: `build/web/` — deploy this folder to any web host.

---

## 7. Deploying to Android (Play Store)

### Step 1 — Generate Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Keep this file **safe and backed up**. If you lose it, you cannot update your app.

### Step 2 — Configure key.properties

Create file `android/key.properties`:

```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=upload
storeFile=<PATH_TO_KEYSTORE>/upload-keystore.jks
```

> ⚠️ **Never commit `key.properties` to git!** Add it to `.gitignore`.

### Step 3 — Update build.gradle

In `android/app/build.gradle`, add before `android {}`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

And inside `android { buildTypes { release { ... } } }`:

```gradle
signingConfig signingConfigs.release
```

Add `signingConfigs` block:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

### Step 4 — Build and Upload

```bash
flutter build appbundle --release
```

Upload `app-release.aab` to [Google Play Console](https://play.google.com/console).

### Step 5 — Play Store Listing

- App name: **Universal Wallet**
- Category: Finance
- Screenshots: at least 2 per device type
- Privacy Policy URL: required for apps with login

---

## 8. Deploying to iOS (App Store)

### Prerequisites

- Mac with Xcode installed
- Apple Developer account ($99/year)
- App ID registered at [developer.apple.com](https://developer.apple.com)

### Step 1 — Configure Bundle ID

In `ios/Runner.xcworkspace`:

- Runner target → Signing & Capabilities
- Set Team and Bundle Identifier (e.g., `com.yourname.mywallet`)

### Step 2 — Update Info.plist

Add required privacy descriptions in `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Access to photo library for profile pictures</string>
<key>NSCameraUsageDescription</key>
<string>Access to camera for taking photos</string>
```

### Step 3 — Build Archive

```bash
flutter build ios --release
```

Open Xcode → Product → **Archive** → Distribute App → App Store Connect.

### Step 4 — TestFlight (Recommended before App Store)

1. In App Store Connect → your app → TestFlight
2. Add internal testers (your Apple ID)
3. Install TestFlight app on device → test thoroughly

### Step 5 — Submit for Review

App Store Connect → Submit for Review. Average review time: 24–48 hours.

---

## 9. Architecture & File Structure

```
my_wallet/
├── lib/
│   ├── main.dart                    # App entry point, Firebase init, theme setup
│   ├── firebase_options.dart        # Auto-generated Firebase config
│   ├── database_helper.dart         # SQLite DB singleton (sqflite)
│   │
│   ├── login_screen.dart            # Phone OTP + Google Sign-In
│   ├── dashboard_screen.dart        # Main dashboard with chart + accounts
│   │
│   ├── add_transaction_screen.dart  # Add Income / Expense / Transfer
│   ├── add_account_screen.dart      # Add new bank/cash account
│   ├── add_debt_screen.dart         # Add debt (Give / Take)
│   │
│   ├── account_details_screen.dart  # Transaction history per account
│   ├── debt_list_screen.dart        # Pending debts list + settle
│   ├── net_worth_details_screen.dart # Full statement + swipe-to-delete
│   └── reports_screen.dart          # Search + PDF report generator
│
├── android/                         # Android-specific config
├── ios/                             # iOS-specific config (Xcode)
├── macos/                           # macOS desktop config
├── web/                             # Web config
├── pubspec.yaml                     # Dependencies
├── analysis_options.yaml            # Linting rules
└── firebase.json                    # Firebase hosting config
```

### Data Flow

```
Firebase Auth (Cloud)
      │
      ▼
main.dart ──► StreamBuilder<User?>
      │            │
      ├── null ──► LoginScreen
      └── user ──► DashboardScreen
                       │
           ┌───────────┼───────────────┐
           ▼           ▼               ▼
  SQLite (local)   fl_chart       Navigation
  DatabaseHelper   LineChart      screens...
```

---

## 10. Database Schema

The app uses **SQLite** (via sqflite) stored locally on device. The DB file is `wallet.db`.

### Table: `accounts`

| Column    | Type                     | Description                             |
| --------- | ------------------------ | --------------------------------------- |
| `id`      | INTEGER PK AUTOINCREMENT | Unique account ID                       |
| `name`    | TEXT                     | Account display name (e.g., "BOC Bank") |
| `type`    | TEXT                     | `Cash`, `Bank`, or `Card`               |
| `balance` | REAL                     | Current balance in Rs.                  |

**Default accounts seeded on first launch:**

- Purse (Cash, Rs. 0.00)
- BOC (Bank, Rs. 0.00)

### Table: `transactions`

| Column        | Type                     | Description                        |
| ------------- | ------------------------ | ---------------------------------- |
| `id`          | INTEGER PK AUTOINCREMENT | Unique transaction ID              |
| `amount`      | REAL                     | Transaction amount                 |
| `type`        | TEXT                     | `Income`, `Expense`, or `Transfer` |
| `category`    | TEXT                     | e.g., Food, Salary, Transfer       |
| `date`        | TEXT                     | `YYYY-MM-DD` format                |
| `description` | TEXT                     | Optional note                      |
| `account_id`  | INTEGER                  | Foreign key → accounts.id          |

### Table: `debts`

| Column        | Type                     | Description                                        |
| ------------- | ------------------------ | -------------------------------------------------- |
| `id`          | INTEGER PK AUTOINCREMENT | Unique debt ID                                     |
| `amount`      | REAL                     | Remaining debt amount                              |
| `type`        | TEXT                     | `Give` (money lent out) or `Take` (money borrowed) |
| `person_name` | TEXT                     | Name of the other person                           |
| `reason`      | TEXT                     | Optional reason/note                               |
| `date`        | TEXT                     | `YYYY-MM-DD` format                                |
| `status`      | TEXT                     | `Pending` or `Settled`                             |
| `account_id`  | INTEGER                  | Which account was used                             |

---

## 11. Features Overview

| Feature                | Screen                          | Description                                                |
| ---------------------- | ------------------------------- | ---------------------------------------------------------- |
| 🔐 Phone OTP Login     | `login_screen.dart`             | Firebase phone verification with 6-digit OTP               |
| 🔐 Google Sign-In      | `login_screen.dart`             | One-tap Google authentication                              |
| 📊 Dashboard           | `dashboard_screen.dart`         | Net worth, debt summary, account grid, line chart          |
| 📈 Line Chart          | `dashboard_screen.dart`         | Expense/Income/Net Worth over Daily/Weekly/Monthly/Yearly  |
| ➕ Add Transaction     | `add_transaction_screen.dart`   | Income, Expense, Transfer between accounts                 |
| 🏦 Add Account         | `add_account_screen.dart`       | Create Bank/Cash/Card accounts with initial balance        |
| 🤝 Add Debt            | `add_debt_screen.dart`          | Record money lent (Give) or borrowed (Take)                |
| 💳 Account Details     | `account_details_screen.dart`   | Full transaction history per account                       |
| 📋 Debt List           | `debt_list_screen.dart`         | Pending debts, full/partial settlement                     |
| 🌐 Net Worth Analytics | `net_worth_details_screen.dart` | All-time statements, swipe-to-delete with balance reversal |
| 🔍 Reports & Search    | `reports_screen.dart`           | Search by name/reason, generate PDF report                 |
| 🌙 Dark / Light Theme  | `main.dart`                     | Toggle between dark and light mode                         |

---

## 12. Troubleshooting

### ❌ `flutter pub get` fails

```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### ❌ Firebase initialization error

- Verify `google-services.json` is at `android/app/google-services.json`
- Verify `GoogleService-Info.plist` is at `ios/Runner/GoogleService-Info.plist`
- Run `flutterfire configure` to regenerate `firebase_options.dart`

### ❌ Phone Authentication not working

For Android:

1. Get SHA-1 fingerprint:
   ```bash
   cd android && ./gradlew signingReport
   ```
2. Add SHA-1 to Firebase Console → Project Settings → Your Android App → SHA certificate fingerprints

For iOS: ensure phone auth is enabled in Firebase Console.

### ❌ Google Sign-In fails on Android

Add your SHA-1 to Firebase Console. Google Sign-In on Android requires SHA-1.

### ❌ Build fails with `Gradle` errors

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### ❌ iOS build fails — CocoaPods error

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

### ❌ `sqflite` database not found / migration issues

If you've changed the DB schema and get errors on existing installs, increment the DB version in `database_helper.dart`:

```dart
return await openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
```

And add an `_onUpgrade` function.

### ❌ App shows blank screen after login

This is usually a `FirebaseApp` init issue. Check that `Firebase.initializeApp()` runs **before** `runApp()` in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

### ❌ `flutter analyze` shows warnings

Run:

```bash
flutter analyze --no-fatal-infos
```

All critical issues in this project have been fixed. See [Bug Fixes Applied](#13-bug-fixes-applied).

---

## 13. Bug Fixes Applied

The following issues were identified and fixed (2026-05-27):

| #    | Severity    | File                                                     | Fix                                                                                              |
| ---- | ----------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 1    | 🔴 Critical | `debt_list_screen.dart`                                  | Settle debt now updates correct `account_id` from debt record, not hardcoded ID=1                |
| 2    | 🔴 Critical | `net_worth_details_screen.dart`                          | Delete now reverses account balance before removing DB row                                       |
| 3    | 🔴 Critical | `dashboard_screen.dart`                                  | Daily chart now filters to current week only, drops Sat/Sun correctly                            |
| 4    | 🔴 Critical | `pubspec.yaml`                                           | Pinned `sqflite: ^2.4.1` and `path: ^1.9.1` (was `any`)                                          |
| 5–7  | 🟠 Warning  | `account_details_screen.dart`, `add_account_screen.dart` | Fixed BuildContext used across async gaps using `context.mounted` and captured Navigator pattern |
| 8–21 | 🟡 Info     | All files                                                | Replaced all `.withOpacity()` with `.withValues(alpha:)`                                         |
| 22   | 🔵 UX       | `login_screen.dart`                                      | Google Sign-In button now disabled while loading (`_isLoading ? null : _signInWithGoogle`)       |
| 23   | 🔵 UX       | `add_transaction_screen.dart`                            | Added validation: amount must be > 0                                                             |
| 24   | 🔵 UX       | `add_account_screen.dart`                                | Added `dispose()` for `_nameController` and `_balanceController`                                 |
| 25   | 🔵 UX       | `reports_screen.dart`                                    | Replaced Sinhala "ගත්තා"/"දුන්නා" with English "Borrowed"/"Lent"                                 |

**Result:** `flutter analyze` → **No issues found!** ✅

---

## 🚀 Quick Start Commands Reference

```bash
# Install dependencies
flutter pub get

# Check code quality
flutter analyze

# Run on iOS simulator
flutter run -d "iPhone 11"

# Run on macOS desktop
flutter run -d macos

# Run on Chrome
flutter run -d chrome

# Run on physical iPhone
flutter run -d 00008030-001C49D826A0802E

# Build Android APK
flutter build apk --release

# Build Android App Bundle (Play Store)
flutter build appbundle --release

# Build iOS release
flutter build ios --release

# Build macOS app
flutter build macos --release

# Build Web
flutter build web --release

# Clean build cache
flutter clean && flutter pub get

# Check outdated packages
flutter pub outdated

# Upgrade packages
flutter pub upgrade
```

---

_Generated by Antigravity AI • Universal Wallet v1.0.0+1_
