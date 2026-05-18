#!/bin/bash

PREFERRED_DEVICE_ID="2F1F794D-21DE-4710-A592-E916E93E2BE9"
PREFERRED_DEVICE_NAME="iPhone 17 Pro"

echo "🔍 Checking for iOS simulator..."

if xcrun simctl list devices | grep -q "$PREFERRED_DEVICE_ID.*Booted"; then
    echo "✅ $PREFERRED_DEVICE_NAME is already running"
else
    echo "🚀 Starting $PREFERRED_DEVICE_NAME..."
    
    if xcrun simctl boot "$PREFERRED_DEVICE_ID" 2>/dev/null; then
        echo "✅ Booted $PREFERRED_DEVICE_NAME successfully"
        open -a Simulator
        sleep 2
    else
        echo "⚠️ Direct boot failed, searching for $PREFERRED_DEVICE_NAME..."
        DEVICE_ID=$(xcrun simctl list devices | grep "$PREFERRED_DEVICE_NAME" | grep -oE '[A-F0-9-]{36}' | head -1)
        
        if [ -n "$DEVICE_ID" ]; then
            echo "📱 Found $PREFERRED_DEVICE_NAME: $DEVICE_ID"
            xcrun simctl boot "$DEVICE_ID" 2>/dev/null
            open -a Simulator
            sleep 2
        else
            echo "⚠️ $PREFERRED_DEVICE_NAME not found, using Flutter's device selection..."
        fi
    fi
fi

echo "🎯 Running Flutter app on iOS..."
if [ -n "$PREFERRED_DEVICE_ID" ]; then
    flutter run -d "$PREFERRED_DEVICE_ID"
else
    flutter run -d ios
fi
