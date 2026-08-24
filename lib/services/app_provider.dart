import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import '../utils/constants.dart';
import 'beacon_service.dart';
import 'firestore_service.dart';
import 'follow_notification_service.dart';
import 'location_service.dart';
import 'route_progress_service.dart';

class AppProvider extends ChangeNotifier {
  static const int _transferBufferMins = 3;
  static const int _defaultConnectionChanges = 1;
  static const int _maxConnectionChanges = 3;

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
        if (!bus.canBoardAtStop(stop.id)) continue;
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

      results.add(_buildRouteResult(
        route: route,
        from: from,
        to: to,
        fromIndex: fromIndex,
        toIndex: toIndex,
      ));
    }
    results.sort((a, b) => a.nextBusEtaMins.compareTo(b.nextBusEtaMins));
    return results;
  }

  List<ConnectingRouteResult> searchConnectingRoutes(
    BusStop from,
    BusStop to, {
    int maxResults = 8,
    int maxChanges = _defaultConnectionChanges,
  }) {
    final cappedChanges = maxChanges < 1
        ? 1
        : maxChanges > _maxConnectionChanges
            ? _maxConnectionChanges
            : maxChanges;
    final maxLegs = cappedChanges + 1;
    final queue = <_ConnectionPath>[
      _ConnectionPath(
        currentStop: from,
        legs: const [],
        visitedStopIds: {from.id},
        usedRouteIds: const {},
        usedRouteNumbers: const {},
      ),
    ];
    final bestByKey = <String, ConnectingRouteResult>{};

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      if (path.legs.length >= maxLegs) continue;

      final candidateLegs = _candidateConnectionLegsFrom(
        path.currentStop,
        destination: to,
      );

      for (final leg in candidateLegs) {
        if (path.usedRouteIds.contains(leg.route.routeId) ||
            path.usedRouteNumbers.contains(leg.route.number)) {
          continue;
        }

        final nextLegs = [...path.legs, leg];
        if (leg.toStop.id == to.id) {
          if (nextLegs.length < 2) continue;

          final candidate = _buildConnectingRouteResult(legs: nextLegs);
          final key = nextLegs
              .map((leg) => '${leg.route.routeId}:${leg.toStop.id}')
              .join('|');
          final existing = bestByKey[key];
          if (existing == null ||
              _connectionSortMins(candidate) < _connectionSortMins(existing)) {
            bestByKey[key] = candidate;
          }
          continue;
        }

        if (nextLegs.length >= maxLegs ||
            path.visitedStopIds.contains(leg.toStop.id)) {
          continue;
        }

        queue.add(
          _ConnectionPath(
            currentStop: leg.toStop,
            legs: nextLegs,
            visitedStopIds: {...path.visitedStopIds, leg.toStop.id},
            usedRouteIds: {...path.usedRouteIds, leg.route.routeId},
            usedRouteNumbers: {...path.usedRouteNumbers, leg.route.number},
          ),
        );
      }
    }

    final results = bestByKey.values.toList()
      ..sort((a, b) {
        final etaCompare =
            _connectionSortMins(a).compareTo(_connectionSortMins(b));
        if (etaCompare != 0) return etaCompare;

        final stopCompare = a.totalStopCount.compareTo(b.totalStopCount);
        if (stopCompare != 0) return stopCompare;

        return a.transferStop.name.compareTo(b.transferStop.name);
      });

    return results.take(maxResults).toList(growable: false);
  }

  List<RouteResult> _candidateConnectionLegsFrom(
    BusStop from, {
    required BusStop destination,
  }) {
    final byKey = <String, RouteResult>{};
    for (final route in VizagRoutes.all) {
      final fromIndex = route.stopIds.indexOf(from.id);
      if (fromIndex < 0 || fromIndex >= route.stopIds.length - 1) continue;

      final visibleStopIds = route.visibleStopIds.toSet();
      final seenStops = <String>{};
      for (var toIndex = fromIndex + 1;
          toIndex < route.stopIds.length;
          toIndex++) {
        final stopId = route.stopIds[toIndex];
        if (!seenStops.add(stopId)) continue;
        if (stopId != destination.id && !visibleStopIds.contains(stopId)) {
          continue;
        }

        final toStop = VizagStops.resolve(stopId);
        final leg = _buildRouteResult(
          route: route,
          from: from,
          to: toStop,
          fromIndex: fromIndex,
          toIndex: toIndex,
        );
        byKey.putIfAbsent('${route.routeId}|$stopId', () => leg);
      }
    }

    final legs = byKey.values.toList()
      ..sort((a, b) {
        final destinationCompare = (a.toStop.id == destination.id ? 0 : 1)
            .compareTo(b.toStop.id == destination.id ? 0 : 1);
        if (destinationCompare != 0) return destinationCompare;

        final liveCompare = b.liveBuses.length.compareTo(a.liveBuses.length);
        if (liveCompare != 0) return liveCompare;

        final etaCompare = a.nextBusEtaMins.compareTo(b.nextBusEtaMins);
        if (etaCompare != 0) return etaCompare;

        return a.stopCount.compareTo(b.stopCount);
      });

    return legs;
  }

  RouteResult _buildRouteResult({
    required BusRoute route,
    required BusStop from,
    required BusStop to,
    required int fromIndex,
    required int toIndex,
  }) {
    final liveBuses = _buses
        .where((bus) =>
            bus.routeKey == route.routeId && bus.canBoardAtStop(from.id))
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

    return RouteResult(
      route: route,
      fromStop: from,
      toStop: to,
      fromIndex: fromIndex,
      toIndex: toIndex,
      liveBuses: liveBuses,
      nextBusEtaMins: approachingLiveBuses.isEmpty
          ? route.frequencyMins
          : _etaToStopMins(approachingLiveBuses.first, from.id),
      rideMins: _rideMins(route, fromIndex, toIndex),
    );
  }

  ConnectingRouteResult _buildConnectingRouteResult({
    required List<RouteResult> legs,
  }) {
    final transferStops = <BusStop>[];
    final transferWaitMinsByLeg = <int>[];
    var totalEtaMins = legs.first.nextBusEtaMins + legs.first.rideMins;

    for (var i = 1; i < legs.length; i++) {
      final previousLeg = legs[i - 1];
      final leg = legs[i];
      transferStops.add(previousLeg.toStop);
      final waitMins = _estimatedTransferWaitMins(totalEtaMins, leg);
      transferWaitMinsByLeg.add(waitMins);
      totalEtaMins += waitMins + leg.rideMins;
    }

    return ConnectingRouteResult(
      legs: List.unmodifiable(legs),
      transferStops: List.unmodifiable(transferStops),
      transferWaitMinsByLeg: List.unmodifiable(transferWaitMinsByLeg),
      totalEtaMins: totalEtaMins,
    );
  }

  int _estimatedTransferWaitMins(
    int firstArrivalMins,
    RouteResult secondLeg,
  ) {
    if (secondLeg.nextBusEtaMins >= firstArrivalMins + _transferBufferMins) {
      return secondLeg.nextBusEtaMins - firstArrivalMins;
    }

    return secondLeg.route.frequencyMins + _transferBufferMins;
  }

  int _connectionSortMins(ConnectingRouteResult result) {
    final extraChangePenalty =
        (result.changeCount <= 1 ? 0 : result.changeCount - 1) * 8;
    return result.totalEtaMins +
        extraChangePenalty +
        result.transferStops.asMap().entries.fold<int>(0, (total, entry) {
          final index = entry.key;
          final transferStopId = entry.value.id;
          return total +
              (_transferVisibilityPenalty(
                    result.legs[index],
                    transferStopId,
                  ) *
                  5) +
              (_transferVisibilityPenalty(
                    result.legs[index + 1],
                    transferStopId,
                  ) *
                  5);
        });
  }

  int _transferVisibilityPenalty(RouteResult leg, String transferStopId) {
    return leg.route.visibleStopIds.contains(transferStopId) ? 0 : 1;
  }

  int _rideMins(BusRoute route, int fromIndex, int toIndex) {
    final stopCount = (toIndex - fromIndex).abs();
    if (stopCount == 0) return 0;

    final fromKm = RouteProgressService.distanceFromRouteStartKm(
      route,
      fromIndex,
    );
    final toKm = RouteProgressService.distanceFromRouteStartKm(
      route,
      toIndex,
    );
    final distanceKm = (toKm - fromKm).abs();
    final travelMins = distanceKm > 0
        ? RouteProgressService.etaMinutesForDistance(
            distanceKm: distanceKm,
            route: route,
          )
        : stopCount * 5;
    final dwellMins = (((stopCount - 1).clamp(0, route.stopIds.length) *
                AppConstants.stopDwellTimeSeconds) /
            60)
        .ceil();

    return travelMins + dwellMins;
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
      if (!bus.canBoardAtStop(stop.id)) continue;
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
      unawaited(FollowBusNotification.instance.reconcile(_buses));
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

class _ConnectionPath {
  final BusStop currentStop;
  final List<RouteResult> legs;
  final Set<String> visitedStopIds;
  final Set<String> usedRouteIds;
  final Set<String> usedRouteNumbers;

  const _ConnectionPath({
    required this.currentStop,
    required this.legs,
    required this.visitedStopIds,
    required this.usedRouteIds,
    required this.usedRouteNumbers,
  });
}
