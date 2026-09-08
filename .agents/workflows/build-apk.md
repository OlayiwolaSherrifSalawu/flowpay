---
name: build-apk
description: Compile, verify, and package the FlowPay Android release APK pointing to the live backend, ready for testing on a physical phone.
---

# FlowPay Android APK Build & Device Testing Workflow

Use this workflow to recompile the FlowPay Android APK whenever changes are made, ensuring all tests pass, the API points to the live backend, and the APK is deployed to your physical phone for testing.

---

## Step 1: Pre-flight Verification & API Configuration

1. **Verify Backend Target**:
   Ensure [api_config.dart](file:///Users/macbookpro/flowpay/mobile/lib/core/config/api_config.dart) points to the live backend:
   ```dart
   static const String liveBackendUrl = 'https://flowpay-k2wn.onrender.com';
   ```
   Confirm `ApiConfig.baseUrl` defaults to `liveBackendUrl`.

2. **Check Live Backend Health**:
   Run a curl check against the live backend endpoint:
   ```bash
   curl -s -i https://flowpay-k2wn.onrender.com/api/health
   ```
   Confirm `HTTP/2 200` with status `"ok"` and active BMONI origin.

---

## Step 2: Code Quality & Regression Checks

Navigate to `mobile/` and run the static analyzer and test suite:

1. **Static Analysis**:
   ```bash
   cd mobile
   flutter analyze
   ```
   *Expectation: "No issues found!" (0 lints, 0 errors).*

2. **Unit & Widget Tests**:
   ```bash
   cd mobile
   flutter test
   ```
   *Expectation: All test suites pass (116+ tests).*

---

## Step 3: Compile Android Release APK

Execute the Flutter release compilation with the live backend URL defined:

```bash
cd mobile
flutter build apk --release \
  --android-skip-build-dependency-validation \
  --dart-define=FLOWPAY_API_URL=https://flowpay-k2wn.onrender.com
```

Upon completion, verify the generated binary:
```bash
ls -lh mobile/build/app/outputs/flutter-apk/app-release.apk
```
*Expected binary: `mobile/build/app/outputs/flutter-apk/app-release.apk` (~55MB).*

---

## Step 4: Deploy & Test on Physical Phone

### Option A: Direct USB ADB Install (Fastest)
1. Ensure your Android phone has **Developer Options** and **USB Debugging** enabled.
2. Connect your phone via USB cable and verify device detection:
   ```bash
   /Users/macbookpro/Library/Android/sdk/platform-tools/adb devices
   ```
3. Install the APK directly:
   ```bash
   /Users/macbookpro/Library/Android/sdk/platform-tools/adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk
   ```

### Option B: Download via Local Wi-Fi (No Cable)
If your phone and Mac are connected to the same Wi-Fi network:
1. Identify your Mac's local IP address:
   ```bash
   ipconfig getifaddr en0 || ipconfig getifaddr en1
   ```
2. Start a local HTTP file server in the APK directory:
   ```bash
   python3 -m http.server 8080 --directory mobile/build/app/outputs/flutter-apk
   ```
3. Open your mobile browser (Chrome/Firefox) on your phone and navigate to:
   ```
   http://<YOUR_MAC_IP>:8080/app-release.apk
   ```
4. Tap **Download** and install.

---

## Step 5: Verification Checklist on Device

Once the app is running on the physical phone:
- [ ] App launches with FlowPay splash and unlocks directly into the dashboard.
- [ ] BMONI on-device hardware signer initializes without errors.
- [ ] Balances load from live backend (`https://flowpay-k2wn.onrender.com`).
- [ ] Mode switching between Personal and Business functions seamlessly.
- [ ] Biometrics and 6-digit B-Key PIN prompt authorize transactions.
