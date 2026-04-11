// lib/utils/constants.dart
// ✏️  Replace TODO values before production build

class AppConstants {
  // ── Google Maps (not used for map tiles, only Distance Matrix ETA) ──
  // TODO: Add key from console.cloud.google.com → Distance Matrix API
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // ── Firebase Realtime Database ──
  // TODO: Replace after creating project at console.firebase.google.com
  static const String firebaseDatabaseUrl =
      'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com';

  // ── Vizag centre coordinates ──
  static const double vizagLat = 17.6868;
  static const double vizagLng  = 83.2185;

  // ── Nearby radius (km) for "buses near me" ──
  static const double nearbyRadiusKm = 2.0;

  // ── Staleness / service hours ──
  /// Buses not updated within this many minutes are hidden from passengers.
  static const int maxBusAgeMins = 30;
  /// Vizag city bus service window (24-hour values).
  static const int serviceStartHour = 5;   // 5 AM
  static const int serviceEndHour   = 23;  // 11 PM

  // ── Beacon ──
  static const int beaconIntervalSec   = 10;
  static const double minSpeedKmh      = 3.0;

  // ── Firebase paths ──
  static const String busLocPath   = 'bus_locations';
  static const String manualPath   = 'manual_updates';
  static const String reportPath   = 'crowd_reports';
}
