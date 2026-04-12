Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packages = @(
  "Git.Git",
  "Microsoft.OpenJDK.17",
  "Google.AndroidStudio"
)

foreach ($package in $packages) {
  winget install -e --id $package
}

Write-Host ""
Write-Host "Windows bootstrap completed for machine dependencies."
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Download the latest stable Flutter SDK archive and extract it to C:\src\flutter."
Write-Host "2. Add Flutter, Java, and Android SDK paths to your user Path."
Write-Host "3. Open Android Studio once and install the Android SDK components."
Write-Host "4. Run: flutter doctor -v"
Write-Host "5. Run: flutter pub get"
Write-Host ""
Write-Host "See docs/setup.md for the exact commands."
