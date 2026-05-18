#!/bin/bash
set -e
cd "$(dirname "$0")/.."
flutter pub get
cd ios
pod install
echo "Done. Reopen the Runner.xcworkspace in Xcode if needed."
