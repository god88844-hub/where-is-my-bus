# Audit fixes — Vizag Bus Live v2.0.0

What was fixed in code, what must be finished in the Firebase console, and
what is deliberately deferred.

## Fixed in this codebase

### 🔴 #1 Hardcoded staff password (`vizag2026`)
Removed from source. Staff Mode now signs the device in with a **shared
staff Firebase Auth account** (`staff@vizagbus.in`): the entered password
IS the account password, so verification, brute-force lockout and
revocation are all handled by Firebase Auth. Nothing secret ships in the
binary and there is **no per-device approval** — approve the account once,
rotate the password anytime from the console.

One-time setup:
1. Firebase console → Authentication → Sign-in method → enable
   **Email/Password**.
2. Authentication → Users → Add user →
   email `staff@vizagbus.in`, password = your staff password.
3. Firestore → users → open the doc with that account's UID → set
   `role = conductor`. Done — every device with the password is a conductor.

Revoke/rotate: Authentication → Users → staff@vizagbus.in → reset password.

### 🔴 #2 Anyone could spoof the fleet
`live_buses` create/update now requires `users/{uid}.role` to be
`conductor` or `admin` (set manually in the Firebase console). Passenger
self-registration cannot elevate its role (`validUserCreate/validUserUpdate`
lock `role` to `passenger`). Deploy with:

```
firebase deploy --only firestore:rules
```

### 🔴 #3 App Check
`main.dart` activates App Check (Play Integrity on release builds, debug
provider during development). To finish enforcement:
Firebase console → App Check → Firestore → switch **Monitoring → Enforced**
once your release build's Play Integrity attestations show up green.

### 🟡 #6 Config split-brain
`constants.dart` placeholders are gone. The only remaining secret-style
input is the Geocoding key injected at build time:
`flutter build apk --dart-define=GOOGLE_MAPS_GEOCODE_API_KEY=...`.

### 🟡 #7 Silent error swallows
All empty `catch (_) {}` blocks now log via `debugPrint`
(conductor tracking ×2, beacon, location, stop-coordinate resolver ×2,
staff access). Watch `flutter logs` / logcat for them.

### 🟠 #9 Stray artifacts
`-Bot.flutter-plugins-dependencies` deleted; data dumps
(`nominatim_cache.json`, `route_coords_dump.json`, `*.log`) are git-ignored.

### 🟡 #10 Debug package id
`com.example.vizag_bus_live` → **`com.vizagbuslive.app`**
(`android/app/build.gradle.kts`, `MainActivity.kt`,
`google-services.json`). Do this **before** any Play release — it can never
be changed afterwards without losing all users.

### 🟡 #13 No CI
`.github/workflows/flutter-ci.yml` runs `flutter pub get`, `flutter analyze
--fatal-infos` and `flutter test` on every push/PR.

### 🐛 Reverse-route bug ("route id does not match")
Root cause: after tapping the reverse button, Start Tracking validated the
trip against the OLD direction's route id. Fixes in
`conductor_tracking_service.dart`:

- `resolveTripRoute()` is direction-aware: when the route hint points at
  the opposite direction of the picked From→To, its return route is used
  automatically.
- If the hint serves neither direction, resolution falls back to the best
  network corridor instead of hard-failing (the route id is optional;
  From→To defines the trip).
- Start Tracking converges `selectedRoute`/`draftRouteHint` onto the route
  that will actually carry the trip.
- `reverseDirection()` validates the mirrored From→To order on the return
  route and falls back to its full range on bad data.

Regression coverage: `test/reverse_trip_test.dart` (pick 28K → reverse →
resolve `28K-R`; stale-hint self-correction; double-reverse; fallback).

### 🐛 Reverse button vanished after a failed start
- The service no longer clears `selectedRoute` while an unresolvable hint
  is present.
- The screen falls back to the draft route hint when rendering the route
  chip/reverse button (`conductor_screen.dart` → `_activeRoute`).
- The start-failure sheet gained a **"Swap From - To and retry"** action.

## Required console-side steps (cannot be done from code)

| Step | Where |
| --- | --- |
| Register the new package `com.vizagbuslive.app` as an Android app in the Firebase project, then re-run `flutterfire configure` so `google-services.json` / `firebase_options.dart` are regenerated | Firebase console → Project settings |
| Restrict the Web/Android API keys (Android app restriction + package `com.vizagbuslive.app` + SHA-1/SHA-256 of your upload keystore) | Google Cloud console → APIs & Services → Credentials |
| Switch Firestore App Check to **Enforced** after verifying Play Integrity attestation rates | Firebase console → App Check |
| Set `users/{uid}.role = conductor` for each approved conductor device UID (shown in the approval dialog) | Firestore → users collection |
| Create `config/staff_access` with the generated hash | Firestore |

## Deliberately deferred (tracked follow-ups)

- **#5 Data literals in Dart (~20k LOC).** Migrating routes/stops into
  Firestore or build-time-generated assets is a structural project (needs
  offline caching + versioning strategy). The generator tools under `tool/`
  are the right starting point.
- **#8 God classes.** Splitting `conductor_screen.dart` /
  `conductor_tracking_service.dart` should ride on the test suite; do it in
  small extractions (GPS streaming, persistence, geofencing) rather than a
  big-bang refactor.
- **#11 Commit history.** Commit these fixes and commit per-change going
  forward so regressions can be bisected.
- **#12 OneDrive sync.** Move the repo out of OneDrive (e.g.
  `C:\dev\vizag_bus_v2`) — cloud-synced `.gradle`/`.dart_tool`/`build/`
  locks corrupt Gradle builds. OneDrive "Files On-Demand" also strips files
  mid-build.
- **#14 Staleness alerting.** Passengers already see "Last seen Xm ago"
  with an amber border (>90 s stale) before the 10-minute hide cutoff, and
  startup cleanup deactivates buses idle >30 min. A push alert to operators
  when their own stream dies needs a server component (Cloud Function on
  `ts` gap) — recommended next.
