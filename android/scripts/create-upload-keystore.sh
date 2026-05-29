#!/usr/bin/env bash
# Creates android/upload-keystore.jks and android/key.properties for Play release builds.
# Run from repo root: ./android/scripts/create-upload-keystore.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/android"
JKS="$ANDROID/upload-keystore.jks"
PROPS="$ANDROID/key.properties"

if [[ -f "$JKS" ]]; then
  echo "Already exists: $JKS"
  echo "Delete it first only if you intend to replace the upload key."
  exit 1
fi

KEYTOOL=""
for candidate in \
  "${JAVA_HOME:-}/bin/keytool" \
  "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
  "$(command -v keytool 2>/dev/null || true)"; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    KEYTOOL="$candidate"
    break
  fi
done

if [[ -z "$KEYTOOL" ]]; then
  echo "keytool not found. Install JDK or Android Studio, then rerun."
  exit 1
fi

echo "Using: $KEYTOOL"
echo ""
echo "You will be prompted for:"
echo "  - Keystore password (storePassword)"
echo "  - Key password (keyPassword; Enter = same as keystore)"
echo "  - Name/org (any values are fine for Play)"
echo ""
echo "Save those passwords — you need them in key.properties and for every future release."
echo ""

"$KEYTOOL" -genkey -v \
  -keystore "$JKS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

echo ""
read -r -s -p "Re-enter keystore password for key.properties: " STORE_PASS
echo ""
read -r -s -p "Re-enter key password (Enter if same as keystore): " KEY_PASS
echo ""
if [[ -z "$KEY_PASS" ]]; then
  KEY_PASS="$STORE_PASS"
fi

cat > "$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=upload
storeFile=upload-keystore.jks
EOF

chmod 600 "$PROPS" 2>/dev/null || true

echo ""
echo "Created:"
echo "  $JKS"
echo "  $PROPS"
echo ""
echo "Next:"
echo "  cd $ROOT"
echo "  flutter build appbundle --release"
echo "  Upload: build/app/outputs/bundle/release/app-release.aab"
