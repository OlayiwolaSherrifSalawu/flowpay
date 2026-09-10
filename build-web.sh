#!/usr/bin/env bash
set -e

echo "===> Checking for Flutter SDK..."
if ! command -v flutter &> /dev/null; then
  echo "===> Flutter not found. Installing Flutter stable on Vercel container..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  export PATH="$PATH:$HOME/flutter/bin"
fi

flutter --version

echo "===> Installing Flutter dependencies..."
cd mobile
flutter pub get

echo "===> Compiling FlowPay Web for production..."
flutter build web --release --dart-define=FLOWPAY_API_URL=https://flowpay-k2wn.onrender.com

echo "===> FlowPay Web build finished successfully! Output in mobile/build/web"
