// lib/utils/constants.dart
// ✏️  Replace TODO values before production build

class AppConstants {
  // ── Vizag centre coordinates ──
  static const double vizagLat = 17.724044586973633;
  static const double vizagLng = 83.30707513638193;

  // ── Nearby radius (km) for "buses near me" ──
  // 2 km so major junctions with several stops nearby (e.g. Pendurthi +
  // Pendurthi Junior College) all appear together.
  static const double nearbyRadiusKm = 2.0;
  // Stop arrival geofencing is adaptive: RouteProgressService scales each
  // stop's arrival radius with the spacing of its neighbouring stops, so no
  // single global radius is configured here.

  // ── Staleness / service hours ──
  /// Buses not updated within this many minutes are hidden from passengers.
  static const int maxBusAgeMins = 10;
  /// Vizag city bus service window (24-hour values).
  static const int serviceStartHour = 5;   // 5 AM
  static const int serviceEndHour   = 23;  // 11 PM
  static const double defaultEtaSpeedKmh = 22;
  static const int stopDwellTimeSeconds = 20;

  // ── Beacon ──
  static const int beaconIntervalSec   = 10;
  static const double minSpeedKmh      = 3.0;

}
