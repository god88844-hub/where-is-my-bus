# Local Development Setup

This repository is a Flutter app with Firebase configured for `Android` only.

For active development, treat `Android` as the supported local target on macOS, Linux, and Windows unless you also regenerate FlutterFire config for other platforms.

## Version requirements

These versions come from the repository, not guesswork:

| Tool | Required version | Why |
| --- | --- | --- |
| Flutter SDK | `>= 3.35.0` | `pubspec.lock` pins `flutter: ">=3.35.0"` |
| Dart SDK | `>= 3.9.0 < 4.0.0` | `pubspec.lock` pins `dart: ">=3.9.0 <4.0.0"` |
| Java | `17` | `android/app/build.gradle.kts` sets `sourceCompatibility` and `targetCompatibility` to `JavaVersion.VERSION_17` |
| Gradle | `8.14` | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | `8.11.1` | `android/settings.gradle.kts` |
| Kotlin | `2.2.20` | `android/settings.gradle.kts` |

Recommended local baseline:

- Flutter stable `3.41.x`
- Java `17`
- Android Studio current stable

Using a newer Flutter stable release is fine as long as it still satisfies the repo minimums above.

## Supported local platforms

- `macOS`: fully documented below
- `Linux`: documented for `Ubuntu 22.04+` and `Debian 11+`
- `Windows`: documented for `Windows 10/11` with `winget`

## One-time machine setup

### macOS

#### 1. Install dependencies

This repo includes a [`Brewfile`](/Users/hrishabh/Desktop/Code/where-is-my-bus/Brewfile) for machine-level dependencies.

```bash
brew bundle
```

That installs:

- Flutter SDK
- OpenJDK 17
- Android Studio
- Android command-line tools
- Android platform tools

You can also use the helper script:

```bash
./scripts/bootstrap-macos.sh
```

#### 2. Export Java and Android paths

Add this to `~/.zshrc` on Apple Silicon Macs when using the Homebrew-installed Android command-line tools:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
export PATH="/opt/homebrew/bin:$JAVA_HOME/bin:/opt/homebrew/share/flutter/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
```

If you are on Intel, replace `/opt/homebrew` with `/usr/local`.

If you prefer Android Studio to manage the SDK in the standard user location instead, use:

```bash
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
```

Reload your shell:

```bash
source ~/.zshrc
```

#### 3. Finish Android SDK installation

Open Android Studio once and complete the first-run SDK setup.

Install these components from `Android Studio > Settings > Languages & Frameworks > Android SDK`:

- Android SDK Platform, API 36
- Android SDK Platform-Tools
- Android SDK Command-line Tools
- Android SDK Build-Tools
- Android Emulator
- One current Android system image if you want an emulator

If you prefer CLI-only setup after Homebrew installs the command-line tools:

```bash
sdkmanager --licenses
sdkmanager "platform-tools" "emulator" "platforms;android-36" "build-tools;36.0.0"
```

#### 4. Verify the toolchain

```bash
flutter doctor -v
```

You want Flutter, Android toolchain, and one device target to be healthy enough for `flutter run`.

### Linux

These instructions assume `Ubuntu 22.04+` or `Debian 11+`, which align with Flutter's current Linux guidance for Android development.

#### 1. Install OS dependencies

```bash
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk
```

You can also use the helper script:

```bash
./scripts/bootstrap-ubuntu.sh
```

#### 2. Install the Flutter SDK

Download the latest stable Linux Flutter SDK archive from the official Flutter install page, then extract it to a stable location such as `~/development/flutter`.

```bash
mkdir -p "$HOME/development"
tar -xf ~/Downloads/flutter_*.tar.xz -C "$HOME/development"
```

#### 3. Export Java, Flutter, and Android paths

Add this to `~/.bashrc` or `~/.zshrc`:

```bash
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export PATH="$HOME/development/flutter/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
```

Set `JAVA_HOME` to your JDK 17 install if your distro does not do it automatically.

Common values:

- x64 Ubuntu/Debian: `/usr/lib/jvm/java-17-openjdk-amd64`
- arm64 Ubuntu/Debian: `/usr/lib/jvm/java-17-openjdk-arm64`

Example:

```bash
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
```

Reload your shell:

```bash
source ~/.bashrc
```

#### 4. Install Android Studio and SDK components

Install the latest stable Android Studio using the official installer or your preferred package manager.

Then open Android Studio and install:

- Android SDK Platform, API 36
- Android SDK Platform-Tools
- Android SDK Command-line Tools
- Android SDK Build-Tools
- Android Emulator

If `sdkmanager` is available after Android Studio setup:

```bash
sdkmanager --licenses
sdkmanager "platform-tools" "emulator" "platforms;android-36" "build-tools;36.0.0"
```

#### 5. Verify the toolchain

```bash
flutter doctor -v
```

### Windows

These instructions assume `Windows 10/11` and `PowerShell` with `winget` available.

#### 1. Install machine dependencies

Use `winget` to install Git, Java 17, and Android Studio:

```powershell
winget install -e --id Git.Git
winget install -e --id Microsoft.OpenJDK.17
winget install -e --id Google.AndroidStudio
```

You can also use the helper script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1
```

#### 2. Install the Flutter SDK

Download the latest stable Windows Flutter SDK archive from the official Flutter install page, then extract it to a stable path such as `C:\src\flutter`.

Avoid installing Flutter inside `C:\Program Files\`.

#### 3. Configure environment variables

Add these values to your user `Path`:

- `C:\src\flutter\bin`
- `%LOCALAPPDATA%\Android\Sdk\platform-tools`
- `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin`

If Java 17 is not automatically available after install, set `JAVA_HOME` to the installed JDK 17 directory and add `%JAVA_HOME%\bin` to `Path`.

#### 4. Finish Android SDK installation

Open Android Studio once and complete the setup wizard.

Install:

- Android SDK Platform, API 36
- Android SDK Platform-Tools
- Android SDK Command-line Tools
- Android SDK Build-Tools
- Android Emulator

Then accept Android licenses:

```powershell
flutter doctor --android-licenses
```

#### 5. Verify the toolchain

```powershell
flutter doctor -v
```

## Project bootstrap

From the repo root:

```bash
flutter pub get
flutter run
```

Useful commands are also exposed through the [`Makefile`](/Users/hrishabh/Desktop/Code/where-is-my-bus/Makefile):

```bash
make doctor
make bootstrap
make analyze
make test
make run-android
```

On Windows, run the `flutter` commands directly from PowerShell or Git Bash. The included `Makefile` is mainly for macOS/Linux shells.

## Debugging

### Android Studio

- Open the repo root as a project
- Wait for Gradle sync and Flutter indexing to finish
- Select an emulator or connected device
- Run or debug the `lib/main.dart` target

### VS Code

- Install the Flutter and Dart extensions
- Open the repo root
- Start an emulator or connect a device
- Run `Flutter: Select Device`
- Press `F5`

## Project-specific notes

- `android/app/google-services.json` is already present in the repo, so Android Firebase bootstrap is available locally.
- `lib/firebase_options.dart` currently supports `Android` only. Web, desktop, and iOS will throw `UnsupportedError` until FlutterFire is regenerated for those targets.
- The current runtime path uses `Cloud Firestore`. Older README sections that mention mock mode or Realtime Database are historical and not the active source of truth.

## Common issues

### `flutter: command not found`

Your Flutter SDK is not on `PATH`. Re-check the `PATH` export above.

### `java: command not found`

Your `JAVA_HOME` is missing or incorrect. Re-check the OpenJDK 17 path above.

### Android build cannot find SDK

Confirm that `ANDROID_SDK_ROOT` points to the SDK you actually installed.

Common macOS values:

- Homebrew command-line tools: `/opt/homebrew/share/android-commandlinetools`
- Android Studio-managed SDK: `$HOME/Library/Android/sdk`

### App fails on non-Android platforms

That is expected with the current repo configuration. This app is only configured for Android Firebase at the moment.

## References

- Flutter install overview: <https://docs.flutter.dev/install>
- Flutter Android setup overview: <https://docs.flutter.dev/platform-integration/android/setup>
- Flutter macOS Android setup: <https://docs.flutter.dev/get-started/install/macos/mobile-android>
- Flutter Linux Android setup: <https://docs.flutter.dev/get-started/install/linux/android>
- Flutter Windows Android setup: <https://docs.flutter.dev/get-started/install/windows/mobile>
- WinGet overview: <https://learn.microsoft.com/en-us/windows/package-manager/winget/>
