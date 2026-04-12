#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install it first: https://brew.sh/"
  exit 1
fi

brew bundle --file "$REPO_ROOT/Brewfile"

cat <<'EOF'

macOS bootstrap completed.

Next steps:
1. Add Flutter, Java, and Android SDK paths to your shell profile.
2. Open Android Studio once and install the Android SDK components.
3. Run: flutter doctor -v
4. Run: flutter pub get

See docs/setup.md for the exact commands.
EOF
