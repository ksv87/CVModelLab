#!/usr/bin/env bash
set -euo pipefail

flutter analyze
flutter test
flutter build web

case "$(uname -s)" in
  Linux)
    flutter build linux
    ;;
  Darwin)
    flutter build macos
    ;;
  MINGW*|MSYS*|CYGWIN*)
    flutter build windows
    ;;
  *)
    echo "Unknown desktop target for this host; web build completed."
    ;;
esac
