#!/usr/bin/env bash

set -euo pipefail

sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk

cat <<'EOF'

Linux bootstrap completed for OS-level dependencies.

Next steps:
1. Download the latest stable Flutter SDK archive and extract it to ~/development/flutter.
2. Install Android Studio and the Android SDK components.
3. Export PATH, ANDROID_SDK_ROOT, and JAVA_HOME as described in docs/setup.md.
4. Run: flutter doctor -v
5. Run: flutter pub get

See docs/setup.md for the exact commands.
EOF
