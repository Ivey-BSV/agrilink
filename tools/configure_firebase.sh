#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart pub global activate flutterfire_cli
dart run flutterfire_cli:flutterfire configure \
  --project=ivey-cap \
  --platforms=android,ios \
  --android-package-name=com.agrilink.cap \
  --ios-bundle-id=com.ansel.cap \
  --yes
