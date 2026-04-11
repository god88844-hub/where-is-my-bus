// lib/services/mock_service.dart
// Simulates live buses for development. No credentials needed.

import 'dart:async';
import 'dart:math';
import '../models/bus.dart';
import '../data/vizag_data.dart';

class MockService {
  final _ctrl = StreamController<List<LiveBus>>.broadcast();
  Timer? _timer;
  final _rng = Random();

  // Each mock bus: route → current stop index along that route
  final List<Map<String, dynamic>> _state = [
    {'id': 'm1', 'route': '38Y', 'idx': 2, 'dir': 1, 'crowd': 1},
    {'id': 'm2', 'route': '38Y', 'idx': 5, 'dir': 1, 'crowd': 2},
    {'id': 'm3', 'route': '400Y', 'idx': 1, 'dir': 1, 'crowd': 0},
    {'id': 'm4', 'route': '28C', 'idx': 3, 'dir': 1, 'crowd': 1},
    {'id': 'm5', 'route': '900', 'idx': 0, 'dir': 1, 'crowd': 1},
    {'id': 'm6', 'route': '99', 'idx': 4, 'dir': 1, 'crowd': 0},
    {'id': 'm7', 'route': '222', 'idx': 2, 'dir': 1, 'crowd': 2},
    {'id': 'm8', 'route': '5K', 'idx': 1, 'dir': 1, 'crowd': 1},
  ];

  Stream<List<LiveBus>> get stream => _ctrl.stream;

  void start() {
    _emit();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      _advance();
      _emit();
    });
  }

  void stop() {
    _timer?.cancel();
    _ctrl.close();
  }

  void _advance() {
    for (final s in _state) {
      final route = VizagRoutes.byRouteId(s['route'] as String);
      if (route == null) continue;
      int idx = s['idx'] as int;
      int dir = s['dir'] as int;
      idx += dir;
      if (idx >= route.stopIds.length - 1) {
        idx = route.stopIds.length - 2;
        dir = -1;
      }
      if (idx <= 0) {
        idx = 1;
        dir = 1;
      }
      s['idx'] = idx;
      s['dir'] = dir;
    }
  }

  void _emit() {
    final buses = <LiveBus>[];

    for (final s in _state) {
      // Skip if route not found
      final route = VizagRoutes.byRouteId(s['route'] as String);
      if (route == null) continue;

      final idx = s['idx'] as int;
      if (idx < 0 || idx >= route.stopIds.length) continue;

      final stopId = route.stopIds[idx];
      final stop = VizagStops.get(stopId);
      if (stop == null) continue; // skip if stop not in data

      final nextIdx =
          (idx + (s['dir'] as int)).clamp(0, route.stopIds.length - 1);
      final nextId = route.stopIds[nextIdx];
      final nextStop = VizagStops.get(nextId);

      // Interpolate position slightly between stops for realism
      double lat = stop.lat, lng = stop.lng;
      if (nextStop != null) {
        final t = 0.3 + _rng.nextDouble() * 0.4;
        lat += (nextStop.lat - stop.lat) * t;
        lng += (nextStop.lng - stop.lng) * t;
      }

      buses.add(LiveBus(
        id: s['id'] as String,
        routeKey: route.routeId,
        routeNumber: route.number,
        currentStopId: stopId,
        lat: lat,
        lng: lng,
        speedKmh: 18 + _rng.nextDouble() * 20,
        etaToNextStopMins: 2 + _rng.nextInt(12),
        nextStopId: nextId,
        crowd: BusCrowd.values[s['crowd'] as int],
        source: BusDataSource.beacon,
        lastUpdated: DateTime.now(),
      ));
    }

    if (!_ctrl.isClosed) _ctrl.add(buses);
  }
}
