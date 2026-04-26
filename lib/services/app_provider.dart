import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import '../utils/constants.dart';
import 'beacon_service.dart';
import 'firestore_service.dart';
import 'location_service.dart';
import 'route_progress_service.dart';

class AppProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();
  late final BeaconService _beacon = BeaconService(_fs);

  List<LiveBus> _buses = [];
  Position? _userPos;
  bool _locLoading = true;
  bool _busLoading = true;
  String? _error;
  BusStop? _fromStop;
  BusStop? _toStop;

  StreamSubscription<List<LiveBus>>? _sub;
  Timer? _locTimer;
  bool _initialized = false;
  bool _disposed = false;

  List<LiveBus> get buses => _buses;
  Position? get userPos => _userPos;
  bool get locLoading => _locLoading;
  bool get busLoading => _busLoading;
  String? get error => _error;
  BusStop? get fromStop => _fromStop;
  BusStop? get toStop => _toStop;
  BeaconService get beacon => _beacon;
  bool get hasLocation => _userPos != null;

  List<BusStop> get nearbyStops {
    if (_userPos == null) return [];
    return VizagStops.list.where((stop) {
      return LocationService.distanceKm(
            _userPos!.latitude,
            _userPos!.longitude,
            stop.lat,
            stop.lng,
          ) <=
          AppConstants.nearbyRadiusKm;
    }).toList()
      ..sort((a, b) {
        final aDist = LocationService.distanceKm(
          _userPos!.latitude,
          _userPos!.longitude,
          a.lat,
          a.lng,
        );
        final bDist = LocationService.distanceKm(
          _userPos!.latitude,
          _userPos!.longitude,
          b.lat,
          b.lng,
        );
        return aDist.compareTo(bDist);
      });
  }

  List<NearbyBus> get nearbyBuses {
    if (_userPos == null) return [];
    final result = <NearbyBus>[];
    for (final stop in nearbyStops) {
      final dist = LocationService.distanceKm(
        _userPos!.latitude,
        _userPos!.longitude,
        stop.lat,
        stop.lng,
      );
      for (final bus in _buses) {
        final route = bus.routeRef;
        if (route == null || !route.stopIds.contains(stop.id)) continue;
        final busIdx = route.stopIds.indexOf(bus.segmentStartIdResolved);
        final stopIdx = route.stopIds.indexOf(stop.id);
        if (busIdx < 0 || stopIdx < 0 || busIdx > stopIdx) continue;
        final eta = _etaToStopMins(bus, stop.id);
        result.add(
          NearbyBus(
            bus: bus,
            stop: stop,
            distanceKm: dist,
            etaToStopMins: eta,
          ),
        );
      }
    }
    result.sort((a, b) => a.etaToStopMins.compareTo(b.etaToStopMins));
    return result;
  }

  List<RouteResult> searchRoutes(BusStop from, BusStop to) {
    final results = <RouteResult>[];
    for (final route in VizagRoutes.all) {
      final fromIndex = route.stopIds.indexOf(from.id);
      final toIndex = route.stopIds.indexOf(to.id);
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) continue;

      final liveBuses = _buses
          .where((bus) => bus.routeKey == route.routeId)
          .toList()
        ..sort((a, b) {
          final aApproaching = a.isApproachingStop(from.id);
          final bApproaching = b.isApproachingStop(from.id);
          if (aApproaching != bApproaching) {
            return aApproaching ? -1 : 1;
          }

          final etaCompare =
              _etaToStopMins(a, from.id).compareTo(_etaToStopMins(b, from.id));
          if (etaCompare != 0) return etaCompare;

          return b.lastUpdated.compareTo(a.lastUpdated);
        });
      final approachingLiveBuses =
          liveBuses.where((bus) => bus.isApproachingStop(from.id)).toList();

      results.add(
        RouteResult(
          route: route,
          fromStop: from,
          toStop: to,
          fromIndex: fromIndex,
          toIndex: toIndex,
          liveBuses: liveBuses,
          nextBusEtaMins: approachingLiveBuses.isEmpty
              ? route.frequencyMins
              : _etaToStopMins(approachingLiveBuses.first, from.id),
        ),
      );
    }
    results.sort((a, b) => a.nextBusEtaMins.compareTo(b.nextBusEtaMins));
    return results;
  }

  @visibleForTesting
  void debugSetBuses(List<LiveBus> buses) {
    _buses = List<LiveBus>.from(buses);
    _busLoading = false;
  }

  List<NearbyBus> busesAtStop(BusStop stop) {
    final result = <NearbyBus>[];
    for (final bus in _buses) {
      final route = bus.routeRef;
      if (route == null) continue;
      final busIdx = route.stopIds.indexOf(bus.segmentStartIdResolved);
      final stopIdx = route.stopIds.indexOf(stop.id);
      if (busIdx < 0 || stopIdx < 0 || busIdx > stopIdx) continue;
      final eta = _etaToStopMins(bus, stop.id);
      result.add(
        NearbyBus(
          bus: bus,
          stop: stop,
          distanceKm: 0,
          etaToStopMins: eta,
        ),
      );
    }
    result.sort((a, b) => a.etaToStopMins.compareTo(b.etaToStopMins));
    return result;
  }

  int followingBusCountAtStop(NearbyBus target) {
    return busesAtStop(target.stop)
        .where((item) =>
            item.bus.id != target.bus.id &&
            item.bus.routeKey == target.bus.routeKey &&
            item.etaToStopMins > target.etaToStopMins)
        .length;
  }

  void setFromStop(BusStop? stop) {
    _fromStop = stop;
    _safeNotifyListeners();
  }

  void setToStop(BusStop? stop) {
    _toStop = stop;
    _safeNotifyListeners();
  }

  void clearSearch() {
    _fromStop = null;
    _toStop = null;
    _safeNotifyListeners();
  }

  int etaToStopMins(LiveBus bus, String stopId) => _etaToStopMins(bus, stopId);

  int _etaToStopMins(LiveBus bus, String stopId) {
    final route = bus.routeRef;
    final distanceKm = bus.distanceToStopKm(stopId);
    final busIdx = route?.stopIds.indexOf(bus.segmentStartIdResolved) ?? -1;
    final stopIdx = route?.stopIds.indexOf(stopId) ?? -1;
    final effectiveSpeed = bus.effectiveSpeedResolvedKmh ??
        (route == null
            ? null
            : RouteProgressService.defaultRouteSpeedKmh(route));

    if (route != null && distanceKm != null) {
      final distanceEta = RouteProgressService.etaMinutesForDistance(
        distanceKm: distanceKm,
        route: route,
        effectiveSpeedKmh: effectiveSpeed,
      );
      final intermediateStops = busIdx < 0 || stopIdx < 0
          ? 0
          : (stopIdx - busIdx - 1).clamp(0, route.stopIds.length);
      final dwellMins =
          ((intermediateStops * AppConstants.stopDwellTimeSeconds) / 60).ceil();
      return distanceEta + dwellMins;
    }

    if (busIdx < 0 || stopIdx < 0 || busIdx > stopIdx) {
      return bus.etaToNextStopMins;
    }

    final stopsAway = stopIdx - busIdx;
    return bus.etaToNextStopMins + (stopsAway > 1 ? (stopsAway - 1) * 6 : 0);
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
    unawaited(_fs.cleanupStaleBuses());
    _startBusStream();
    _startLocationUpdates();
  }

  void _startBusStream() {
    _sub?.cancel();
    _sub = _fs.liveBusStream().listen((buses) {
      // Only show buses updated recently & within today's service window.
      _buses =
          buses.where((b) => !b.isExpired && !b.isFromPreviousDay).toList();
      _busLoading = false;
      _error = null;
      _safeNotifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _busLoading = false;
      _safeNotifyListeners();
    });
  }

  void _startLocationUpdates() async {
    _locTimer?.cancel();
    final firstPosition = await LocationService.getCurrentPosition();
    if (_disposed) return;
    _userPos = firstPosition;
    _locLoading = false;
    _safeNotifyListeners();
    _locTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final updatedPosition = await LocationService.getCurrentPosition();
      if (_disposed) return;
      _userPos = updatedPosition;
      _locLoading = false;
      _safeNotifyListeners();
    });
  }

  void _safeNotifyListeners() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _locTimer?.cancel();
    super.dispose();
  }
}
