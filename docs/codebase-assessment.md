# Vizag Bus Live Codebase Assessment

## Scope

This assessment is based on the current source code in this repository as of April 11, 2026.

Important context:

- The implemented live backend is `Cloud Firestore`, not Realtime Database.
- The repo still contains older mock / Realtime Database artifacts and README instructions that no longer match the running app.
- Build and test execution were not verified in this environment because `flutter` and `dart` are not installed here.

## What The App Does

This is a Flutter-based bus tracking app for Vizag / Visakhapatnam with two primary roles:

- Passenger mode
- Staff / conductor mode

Implemented user-facing features:

- Nearby buses view using device location
- Nearby stops chips within a 2 km radius
- `From` -> `To` stop search for direct route discovery
- Route results with live bus availability and fallback frequency-based ETA
- Stop detail screen showing all live buses approaching that stop
- Bus journey screen with stop-by-stop timeline
- Live bus freshness, current stop, next stop, speed, crowd level, and source badges
- Passenger reporting mode ("Beacon") that sends periodic route/location reports
- Staff access gate before conductor mode
- Conductor tracking mode with:
  - route selection
  - bus plate entry
  - crowd status updates
  - current-stop auto detection from location
  - reverse-direction support for linked route pairs
  - background location tracking on Android
  - persisted tracking session using `SharedPreferences`
- English + Telugu labels for stops and route names

Operationally, the app currently ships with:

- `85` stop definitions
- `108` routens definitio
- about `101` unique public route numbers

## App Flow

### Passenger flow

1. App starts and initializes Firebase.
2. `AppProvider` subscribes to the `live_buses` Firestore collection.
3. The app requests passenger location.
4. Home screen shows:
   - nearby stops
   - nearby incoming buses
   - `From` / `To` stop search
5. Passenger can:
   - tap a nearby stop -> open stop detail
   - search `From` / `To` -> open route results
6. From stop detail, the user can open a bus journey timeline.
7. From the floating action button, the user can enter passenger reporting mode and send periodic location heartbeats / reports for a selected route.

### Staff / conductor flow

1. User opens Staff Mode from the home screen.
2. App asks for a hardcoded access code.
3. App then checks the signed-in Firebase user document and only allows users with `conductor` or `admin` role.
4. Conductor selects route, enters plate number, and starts tracking.
5. App requests high-accuracy location and background permissions on Android.
6. App writes live bus documents into Firestore under `live_buses`.
7. While tracking:
   - position stream runs continuously
   - current stop can auto-advance based on proximity
   - route can be reversed if a linked return route exists
   - session state is persisted locally
8. On stop, the app marks the bus inactive in Firestore and clears persisted session state.

## Is The App Production Ready?

Short answer: `No`, not yet.

It is a solid pilot / MVP codebase, especially for Android-only internal testing or a controlled field rollout. It is not production-ready for a public launch without additional platform, security, operational, and reliability work.

### Why it is not production ready yet

- Android release signing is not configured. Release builds currently use the debug signing config.
- `applicationId` still uses `com.example.vizag_bus_live`.
- Firebase is only configured for Android. `firebase_options.dart` throws `UnsupportedError` for iOS, web, macOS, and Windows.
- iOS permission declarations for location/background usage are not configured in `Info.plist`.
- Tests are minimal. The repo only contains a few unit/widget checks and no service/integration coverage.
- There is no CI/CD, release automation, or environment separation.
- There is no crash reporting, analytics, or production monitoring.
- The README and some constants still describe an older Realtime Database / mock setup, which is operationally dangerous.
- A staff access code is hardcoded in the client.
- Route and stop data are hardcoded in source instead of being managed from a backend or data pipeline.
- ETA logic is heuristic-based, not based on road network, GTFS, traffic, or actual historical travel times.

## Main Limitations

### Product limitations

- Only direct `From` -> `To` routes are supported. No interchange / transfer planning.
- No map view.
- No push notifications.
- No favorites, saved trips, or personalization.
- No public admin console for managing routes, stops, users, or buses.

### Data limitations

- Stops and routes are static code, so operational updates require app changes and redeploys.
- Stop coordinates are approximate and should be field-validated.
- No GTFS or official schedule ingestion.
- Passenger reports are collected, but there is no backend reconciliation engine that turns them into reliable public bus positions.

### Technical limitations

- Every client subscribes to all active `live_buses` and filters locally.
- Search, ETA, route matching, and nearby calculations are all client-side.
- Firestore write frequency can become expensive with many active conductors and passengers.
- `cleanupStaleBuses()` exists but is not invoked, so stale documents can accumulate in Firestore even if the UI hides them.
- Older services like `firebase_service.dart`, `mock_service.dart`, and outdated README instructions increase maintenance risk.
- If anonymous Firebase auth is unavailable, parts of the role/session flows will fail badly because security rules require authenticated access.

## Tech Stack

- Flutter / Dart
- Provider for app state
- Firebase Core
- Firebase Auth with anonymous sign-in
- Cloud Firestore as the live backend
- Geolocator for GPS and background location stream handling
- Permission Handler for Android permission flows
- Shared Preferences for local session persistence
- Material-based custom dark UI

### Scalability

Current verdict: `moderately scalable for a pilot`, `not yet well-shaped for city-scale growth`.

What scales reasonably well:

- Flutter client architecture is simple and maintainable for an MVP.
- Firestore is fine for a limited number of active buses and conductors.
- The app state model is understandable and easy to extend.

What does not scale well yet:

- All live buses are streamed to all clients.
- All ETA derivation happens on-device.
- Static route/stop data in source will become a bottleneck for operations.
- Passenger reports are stored, but not aggregated into a dependable operational model.
- There is no backend service for validation, deduplication, conflict resolution, or analytics.

### Reliability

Current verdict: `acceptable for supervised pilot use`, `not reliable enough for public transit-grade production`.

Positive signals:

- Managed Firebase stack reduces infrastructure burden.
- Firestore rules are more mature than the old README suggests.
- Conductor tracking persists local state and can resume.
- Bus freshness filtering hides outdated data in the passenger UI.

Weak points:

- No production telemetry or crash visibility
- No server-side health checks or stale-session cleanup jobs
- No redundancy or fallback beyond client heuristics
- No conflict resolution if multiple sources disagree
- Hardcoded access code in client
- Platform support is incomplete

## How To Build An APK

### Prerequisites

- Install Flutter SDK and Android SDK
- Ensure `flutter doctor` is clean enough for Android builds
- Add a valid `android/local.properties` pointing to the Flutter SDK
- Keep `android/app/google-services.json` aligned with the Firebase project
- Enable Firebase Anonymous Auth
- Deploy Firestore rules from `firestore.rules`

### Debug APK

```bash
flutter pub get
flutter build apk --debug
```

Expected output path:

- `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK

Before building a real release APK, fix these first:

- set a real Android `applicationId`
- configure release signing / keystore
- stop using debug signing for release

Then build:

```bash
flutter pub get
flutter build apk --release
```

Expected output path:

- `build/app/outputs/flutter-apk/app-release.apk`

### For Play Store readiness

You should prefer:

```bash
flutter build appbundle --release
```

That produces an `.aab`, which is the correct artifact for Play Store distribution.

## High-Priority Items To Pick Next

These are the highest-value items to address before calling the app production-ready.

1. Fix release readiness on Android.
   - Real `applicationId`
   - release signing
   - versioning discipline
   - store-ready branding/package identity

2. Clean up architecture drift.
   - remove or quarantine old mock / Realtime Database paths
   - rewrite README to match Firestore-based reality
   - remove unused constants and stale operational instructions

3. Strengthen security and staff access.
   - remove hardcoded staff access code from client
   - define proper admin/staff onboarding flow
   - review Firestore rules with real operational scenarios

4. Add backend operational logic.
   - scheduled stale-bus cleanup
   - server-side validation of conductor writes
   - aggregation / interpretation of passenger reports
   - audit logs and operational observability

5. Improve test coverage.
   - provider/service unit tests
   - conductor tracking flow tests
   - Firestore rule validation
   - at least one end-to-end smoke path

6. Improve ETA accuracy.
   - replace fixed per-stop assumptions
   - use route segment timing, traffic-aware estimates, or GTFS-style schedule logic

7. Move transit data out of source code.
   - backend-managed routes/stops
   - content versioning
   - field validation for stop coordinates

8. Add production observability.
   - Crashlytics or equivalent
   - analytics for feature usage
   - logs/alerts for failed writes, stale sessions, and permission failures

9. Decide supported platforms explicitly.
   - if Android-only, document it and remove broken platform expectations
   - if iOS is required, finish Firebase config and permission setup

10. Rework client scaling assumptions.
    - avoid streaming all buses to all users
    - introduce filtered queries or region/route partitioning
    - offload more computation from clients to backend services

## Bottom Line

This codebase is a credible Android-first MVP for a live bus pilot. The passenger and conductor flows are coherent, the Firestore rules are better than the docs imply, and the app has enough structure to keep evolving.

The main issue is not lack of features. The main issue is operational maturity: release configuration, data ownership, security hardening, backend processing, and architectural cleanup still need work before this should be treated as a production transit app.
