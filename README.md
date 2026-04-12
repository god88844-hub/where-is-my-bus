# Vizag Bus Live v2

Real-time bus tracking for Visakhapatnam. Dark theme. No maps. Just stops, ETAs, and live buses.

## Local setup

Use [docs/setup.md](/Users/hrishabh/Desktop/Code/where-is-my-bus/docs/setup.md) for the current development setup, version requirements, and bootstrap steps.

Important: the running app is currently wired to Firebase/Firestore on Android. Older mock-mode and Realtime Database notes lower in this README are legacy instructions and should not be used as the source of truth for local setup.

---

## App flow

```
Home (nearby buses)
  ├── Tap stop chip → Stop Detail (all buses arriving)
  │     └── Tap bus → Journey Screen (stop-by-stop timeline)
  ├── Search FROM → TO → Route Results
  │     └── Tap route → Stop Detail
  └── Beacon FAB → Beacon Screen (share your location)
```

---

## Project structure

```
lib/
├── main.dart
├── data/
│   └── vizag_data.dart          ← All stops + routes (edit here to add more)
├── models/
│   └── bus.dart                 ← LiveBus, NearbyBus, RouteResult
├── services/
│   ├── app_provider.dart        ← Central state (Provider)
│   ├── mock_service.dart        ← Dev: 8 simulated buses
│   ├── firebase_service.dart    ← Prod: Firebase Realtime DB
│   ├── beacon_service.dart      ← GPS sharing
│   └── location_service.dart    ← User GPS + distance calc
├── screens/
│   ├── home_screen.dart         ← Nearby buses + FROM/TO search
│   ├── route_results_screen.dart← FROM→TO search results
│   ├── stop_detail_screen.dart  ← All buses at a stop
│   ├── bus_journey_screen.dart  ← Stop-by-stop timeline
│   └── beacon_screen.dart       ← Beacon mode toggle
├── widgets/
│   ├── shared_widgets.dart      ← RouteBadge, CrowdBar, IncomingBusCard…
│   └── stop_search.dart         ← Autocomplete stop search field
└── utils/
    ├── constants.dart           ← ✏️ All credentials here
    └── app_theme.dart           ← Dark theme colours
```

---

## Run immediately (mock mode — no credentials needed)

```bash
cd vizag_bus_v2
flutter pub get
flutter run
```

8 buses on 7 routes simulate live movement across Vizag.

---

## Go live: Step 1 — Firebase

1. Go to console.firebase.google.com → New project
2. Add Android app → package name: `com.example.vizag_bus_live`
3. Download `google-services.json` → put in `android/app/`
4. Enable Realtime Database → Start in test mode
5. In `lib/utils/constants.dart` replace `YOUR_PROJECT_ID`
6. In `lib/main.dart` uncomment the Firebase init lines
7. In `lib/services/app_provider.dart` set `_useMock = false`

### Firebase database rules (replace test mode)
```json
{
  "rules": {
    "bus_locations": {
      ".read": true,
      "$busId": { ".write": "auth != null" }
    },
    "manual_updates": {
      ".read": true,
      ".write": "auth != null"
    },
    "crowd_reports": {
      ".read": true,
      "$busId": { ".write": "auth != null" }
    }
  }
}
```

### Firebase data shape
```json
{
  "bus_locations": {
    "bus_001": {
      "route": "38Y",
      "current_stop": "rtc_complex",
      "lat": 17.7231, "lng": 83.3012,
      "speed": 28.5,
      "eta": 4,
      "next_stop": "maddilapalem",
      "crowd": 1,
      "source": 0,
      "ts": 1712345678000
    }
  }
}
```

crowd: 0=empty, 1=moderate, 2=full
source: 0=beacon, 1=manual, 2=timetable

---

## Go live: Step 2 — Manual fallback updates

Use Firebase console or a simple admin script to push bus positions
when beacon data is unavailable. Write to `manual_updates/{busId}`
with the same shape as above, setting `"source": 1`.

---

## Adding more stops and routes

Open `lib/data/vizag_data.dart`:

```dart
// Add a stop
'new_stop_id': BusStop(
  id: 'new_stop_id',
  name: 'New Stop Name',
  nameTelugu: 'తెలుగు పేరు',
  lat: 17.xxxx, lng: 83.xxxx,
  zone: 'N',
),

// Add a route
BusRoute(
  number: 'XYZ',
  name: 'Origin → Destination',
  nameTelugu: 'తెలుగు పేరు',
  stopIds: ['stop1_id', 'stop2_id', 'stop3_id'],
  frequencyMins: 20,
),
```

Everything else (nearby buses, search, timeline) updates automatically.

---

## Next features to build

- [ ] Push notification: "Bus 38Y arriving in 2 stops"
- [ ] Favourite stops (saved locally)
- [ ] Admin panel for manual bus position updates
- [ ] Crowd report button on bus journey screen
- [ ] Route number search on home screen
- [ ] Telugu full UI localisation
