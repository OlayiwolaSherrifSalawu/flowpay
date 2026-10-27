#!/usr/bin/env bash
set -e

echo "===> Checking for Flutter SDK..."
if ! command -v flutter &> /dev/null; then
  # Pinned to the version CI tests with, so a new Flutter release can't silently break the build.
  echo "===> Flutter not found. Installing Flutter 3.47.2 on the Vercel container..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b 3.47.2 "$HOME/flutter"
  export PATH="$PATH:$HOME/flutter/bin"
fi

flutter --version

echo "===> Installing Flutter dependencies..."
if [ -d "mobile" ]; then
  cd mobile
fi
flutter pub get

echo "===> Compiling FlowPay Web for production..."
flutter build web --release --base-href "/" --dart-define=FLOWPAY_API_URL=https://flowpay-k2wn.onrender.com

echo "===> FlowPay Web build finished successfully! Output in mobile/build/web"
