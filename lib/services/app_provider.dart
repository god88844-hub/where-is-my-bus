import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import '../utils/constants.dart';
import 'beacon_service.dart';
import 'firestore_service.dart';
import 'location_service.dart';

class AppProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();
  late final BeaconService _beacon = BeaconService(_fs)
    ..addListener(_onBeaconChanged);

  List<LiveBus> _buses = [];
  Position? _userPos;
  bool _locLoading = true;
  bool _busLoading = true;
  String? _error;
  BusStop? _fromStop;
  BusStop? _toStop;

  StreamSubscription<List<LiveBus>>? _sub;
  Timer? _locTimer;

  List<LiveBus> get buses => _buses;
  Position? get userPos => _userPos;
  bool get locLoading => _locLoading;
  bool get busLoading => _busLoading;
  String? get error => _error;
  BusStop? get fromStop => _fromStop;
  BusStop? get toStop => _toStop;
  BeaconService get beacon => _beacon;
  bool get hasLocation => _userPos != null;

  void _onBeaconChanged() {
    notifyListeners();
  }

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
        final busIdx = route.stopIds.indexOf(bus.currentStopId);
        final stopIdx = route.stopIds.indexOf(stop.id);
        if (busIdx < 0 || stopIdx < 0 || busIdx > stopIdx) continue;
        final stopsAway = stopIdx - busIdx;
        final eta =
            bus.etaToNextStopMins + (stopsAway > 1 ? (stopsAway - 1) * 6 : 0);
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
    if (from.id == to.id) return [];
    final results = <RouteResult>[];
    for (final route in VizagRoutes.all) {
      final fromIndex = route.stopIds.indexOf(from.id);
      final toIndex = route.stopIds.indexOf(to.id);
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) continue;
      final liveBuses =
          _buses.where((bus) => bus.routeKey == route.routeId).toList();
      var minEta = 99;
      for (final bus in liveBuses) {
        final busIndex = route.stopIds.indexOf(bus.currentStopId);
        if (busIndex < 0 || busIndex > fromIndex) continue;
        final stopsAway = fromIndex - busIndex;
        final eta =
            bus.etaToNextStopMins + (stopsAway > 1 ? (stopsAway - 1) * 6 : 0);
        if (eta < minEta) minEta = eta;
      }
      results.add(
        RouteResult(
          route: route,
          fromStop: from,
          toStop: to,
          fromIndex: fromIndex,
          toIndex: toIndex,
          liveBuses: liveBuses,
          nextBusEtaMins: liveBuses.isEmpty ? route.frequencyMins : minEta,
        ),
      );
    }
    results.sort((a, b) => a.nextBusEtaMins.compareTo(b.nextBusEtaMins));
    return results;
  }

  List<NearbyBus> busesAtStop(BusStop stop) {
    final result = <NearbyBus>[];
    for (final bus in _buses) {
      final route = bus.routeRef;
      if (route == null) continue;
      final busIdx = route.stopIds.indexOf(bus.currentStopId);
      final stopIdx = route.stopIds.indexOf(stop.id);
      if (busIdx < 0 || stopIdx < 0 || busIdx > stopIdx) continue;
      final stopsAway = stopIdx - busIdx;
      final eta =
          bus.etaToNextStopMins + (stopsAway > 1 ? (stopsAway - 1) * 6 : 0);
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
    notifyListeners();
  }

  void setToStop(BusStop? stop) {
    _toStop = stop;
    notifyListeners();
  }

  void clearSearch() {
    _fromStop = null;
    _toStop = null;
    notifyListeners();
  }

  void init() {
    _startBusStream();
    _startLocationUpdates();
  }

  void _startBusStream() {
    _sub = _fs.liveBusStream().listen((buses) {
      // Only show buses updated recently & within today's service window.
      _buses =
          buses.where((b) => !b.isExpired && !b.isFromPreviousDay).toList();
      _busLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _busLoading = false;
      notifyListeners();
    });
  }

  void _startLocationUpdates() async {
    _userPos = await LocationService.getCurrentPosition();
    _locLoading = false;
    notifyListeners();
    _locTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      _userPos = await LocationService.getCurrentPosition();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _locTimer?.cancel();
    _beacon.removeListener(_onBeaconChanged);
    super.dispose();
  }
}
