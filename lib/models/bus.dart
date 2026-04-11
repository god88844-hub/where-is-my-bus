// lib/models/bus.dart

import '../data/vizag_data.dart';
import '../utils/constants.dart';

enum BusDataSource { beacon, manual, timetable }

enum BusCrowd { empty, moderate, full }

class LiveBus {
  final String id;
  final String routeKey;
  final String routeNumber;
  final BusType? busType;
  final String busPlateNumber;
  final String currentStopId; // stop the bus is at / last passed
  final double lat;
  final double lng;
  final double speedKmh;
  final int etaToNextStopMins;
  final String nextStopId;
  final BusCrowd crowd;
  final BusDataSource source;
  final DateTime lastUpdated;

  const LiveBus({
    required this.id,
    String? routeKey,
    required this.routeNumber,
    this.busType,
    this.busPlateNumber = '',
    required this.currentStopId,
    required this.lat,
    required this.lng,
    this.speedKmh = 0,
    this.etaToNextStopMins = 0,
    this.nextStopId = '',
    this.crowd = BusCrowd.moderate,
    this.source = BusDataSource.timetable,
    required this.lastUpdated,
  }) : routeKey = routeKey ?? routeNumber;

  factory LiveBus.fromMap(String id, Map<dynamic, dynamic> m) {
    final rawRoute = m['route'] as String? ?? '?';
    final routeKey = m['route_key'] as String? ?? rawRoute;
    final route =
        VizagRoutes.byRouteId(routeKey) ?? VizagRoutes.byNumber(rawRoute);

    return LiveBus(
      id: id,
      routeKey: routeKey,
      routeNumber: route?.number ?? rawRoute,
      busType: _busTypeFromValue(m['bus_type']),
      busPlateNumber: m['bus_plate'] as String? ?? '',
      currentStopId: m['current_stop'] as String? ?? '',
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      speedKmh: (m['speed'] as num?)?.toDouble() ?? 0,
      etaToNextStopMins: (m['eta'] as num?)?.toInt() ?? 0,
      nextStopId: m['next_stop'] as String? ?? '',
      crowd: _crowdFromValue(m['crowd']),
      source: _sourceFromValue(m['source']),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          (m['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toMap() => {
        'route_key': routeKey,
        'route': routeNumber,
        'bus_type': (busType ?? routeBusType).name,
        'bus_plate': busPlateNumber,
        'current_stop': currentStopId,
        'lat': lat,
        'lng': lng,
        'speed': speedKmh,
        'eta': etaToNextStopMins,
        'next_stop': nextStopId,
        'crowd': crowd.index,
        'source': source.index,
        'ts': lastUpdated.millisecondsSinceEpoch,
      };

  bool get isStale => DateTime.now().difference(lastUpdated).inSeconds > 90;

  /// Hard cutoff — bus data older than [AppConstants.maxBusAgeMins] is hidden.
  bool get isExpired =>
      DateTime.now().difference(lastUpdated).inMinutes >
      AppConstants.maxBusAgeMins;

  /// Data is from before the current service day.
  /// If it's currently before 5 AM, the current service day started at 5 AM yesterday.
  /// If it's after 5 AM, it started at 5 AM today.
  bool get isFromPreviousDay {
    final now = DateTime.now();
    DateTime currentServiceStart;

    if (now.hour < AppConstants.serviceStartHour) {
      // It's past midnight but before 5 AM. The service day started yesterday.
      currentServiceStart = DateTime(
        now.year,
        now.month,
        now.day - 1,
        AppConstants.serviceStartHour,
      );
    } else {
      // It's after 5 AM. The service day started today.
      currentServiceStart = DateTime(
        now.year,
        now.month,
        now.day,
        AppConstants.serviceStartHour,
      );
    }

    return lastUpdated.isBefore(currentServiceStart);
  }

  BusRoute? get routeRef =>
      VizagRoutes.byRouteId(routeKey) ?? VizagRoutes.byNumber(routeNumber);

  BusType get routeBusType =>
      busType ?? routeRef?.busType ?? BusType.redOrdinary;

  String get busTypeLabel => routeBusType.label;
  String get displayBusIdentity =>
      busPlateNumber.isEmpty ? routeNumber : '$routeNumber • $busPlateNumber';

  String get crowdLabel {
    switch (crowd) {
      case BusCrowd.empty:
        return 'Empty';
      case BusCrowd.moderate:
        return 'Moderate';
      case BusCrowd.full:
        return 'Full';
    }
  }

  String get sourceLabel {
    switch (source) {
      case BusDataSource.beacon:
        return 'Live';
      case BusDataSource.manual:
        return 'Updated';
      case BusDataSource.timetable:
        return 'Scheduled';
    }
  }

  static BusType? _busTypeFromValue(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    for (final type in BusType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  static BusCrowd _crowdFromValue(dynamic value) {
    final index = (value as num?)?.toInt() ?? BusCrowd.moderate.index;
    return BusCrowd.values[index.clamp(0, BusCrowd.values.length - 1)];
  }

  static BusDataSource _sourceFromValue(dynamic value) {
    final index = (value as num?)?.toInt() ?? BusDataSource.timetable.index;
    return BusDataSource
        .values[index.clamp(0, BusDataSource.values.length - 1)];
  }
}

// ─────────────────────────────────────────────
//  NearbyBus — a bus arriving at a stop near you
// ─────────────────────────────────────────────
class NearbyBus {
  final LiveBus bus;
  final BusStop stop; // the nearby stop it will arrive at
  final double distanceKm; // user → stop
  final int etaToStopMins; // bus → stop

  const NearbyBus({
    required this.bus,
    required this.stop,
    required this.distanceKm,
    required this.etaToStopMins,
  });
}

// ─────────────────────────────────────────────
//  SearchResult — from → to query result
// ─────────────────────────────────────────────
class RouteResult {
  final BusRoute route;
  final BusStop fromStop;
  final BusStop toStop;
  final int fromIndex;
  final int toIndex;
  final List<LiveBus> liveBuses; // buses currently on this route
  final int nextBusEtaMins;

  const RouteResult({
    required this.route,
    required this.fromStop,
    required this.toStop,
    required this.fromIndex,
    required this.toIndex,
    this.liveBuses = const [],
    this.nextBusEtaMins = 0,
  });

  int get stopCount => (toIndex - fromIndex).abs();
}
