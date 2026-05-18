#!/bin/bash

ZSHRC="$HOME/.zshrc"
BLOCK='
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
'

if [ ! -f "$ZSHRC" ]; then
  touch "$ZSHRC"
fi

if grep -q 'ANDROID_HOME' "$ZSHRC" 2>/dev/null; then
  echo "ANDROID_HOME and related PATH entries already exist in ~/.zshrc. Nothing added."
else
  if echo "$BLOCK" >> "$ZSHRC" 2>/dev/null; then
    echo "Added Android SDK env to ~/.zshrc. Run: source ~/.zshrc"
  else
    echo "Could not write to ~/.zshrc. Run this script from your own terminal (e.g. Terminal.app), not from inside Cursor."
    exit 1
  fi
fi
