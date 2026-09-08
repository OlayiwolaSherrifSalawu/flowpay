---
name: build-web
description: Compile, verify, and host the FlowPay Web/PWA application pointing to the live backend, ready for instant testing on desktop browsers or mobile devices (iOS Safari / Android Chrome) without heavy SDK downloads.
---

# FlowPay Web / PWA Build & Multi-Device Testing Workflow

Use this workflow to recompile and serve the FlowPay Web and Progressive Web App (PWA) whenever changes are made. This allows instant testing on any desktop browser, iPhone (via Mobile Safari), or Android phone (via Chrome) with zero Xcode or native SDK installation required.

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
   *Expectation: All test suites pass (132+ tests).*

---

## Step 3: Compile Web Application

Execute the Flutter Web compilation targeting the live backend:

```bash
cd mobile
flutter build web --dart-define=FLOWPAY_API_URL=https://flowpay-k2wn.onrender.com
```

Upon completion, verify the generated bundle:
```bash
ls -lh mobile/build/web/index.html mobile/build/web/main.dart.js
```
*Expected: `index.html` and `main.dart.js` (~3.5MB) generated in `mobile/build/web/`.*

---

## Step 4: Host Local Web Server for Multi-Device Access

1. **Identify Your Mac's Local IP Address**:
   ```bash
   ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
   ```
   *(Example: `192.168.8.128`)*

2. **Free Port 8080 (If in Use)**:
   ```bash
   lsof -ti :8080 | xargs kill -9 2>/dev/null || true
   ```

3. **Start the Web Server**:
   ```bash
   python3 -m http.server 8080 --directory mobile/build/web
   ```

---

## Step 5: Test on Devices

### Option A: On iPhone (iOS Safari PWA — Instant Native Look & Feel)
1. Connect your iPhone to the same Wi-Fi network as your Mac.
2. Open **Safari** on your iPhone and navigate to:
   ```text
   http://<YOUR_MAC_IP>:8080
   ```
3. Tap the **Share** button at the bottom of Safari (⎋).
4. Tap **"Add to Home Screen"** and tap **Add**.
5. Tap the new **FlowPay** app icon on your home screen:
   - Launches in full-screen standalone mode without browser chrome.
   - Instant loading with full dark-mode aesthetic and animations.

### Option B: On Android Phone (Chrome PWA)
1. Open **Chrome** on your Android phone and navigate to:
   ```text
   http://<YOUR_MAC_IP>:8080
   ```
2. Tap the three dots menu (⋮) → **Install app** (or **Add to Home screen**).
3. The app installs to your app drawer and home screen.

### Option C: On Mac Desktop (Chrome / Safari DevTools)
1. Open `http://localhost:8080` in your browser.
2. Press `Cmd + Option + I` to open Developer Tools.
3. Toggle the **Device Toolbar** (`Cmd + Shift + M`) and select **iPhone 16 Pro** or **Pixel 8** to preview and test responsive layouts.

---

## Step 6: Verification Checklist on Device

Once the app is running in the browser / PWA:
- [ ] FlowPay splash screen animates cleanly into the dashboard (no blank screen).
- [ ] Wallet balances and currency counters load from `https://flowpay-k2wn.onrender.com`.
- [ ] Role switcher seamlessly toggles between **Personal** and **Business** modes.
- [ ] Money Missions, Send Money review dialogs, and Payroll fan-out interact cleanly.
- [ ] B-Key PIN prompt dialog authorizes transactions as expected.
