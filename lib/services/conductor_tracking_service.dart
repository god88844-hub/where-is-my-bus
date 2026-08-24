import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';

import '../dev/mock_coordinate_scenarios.dart';
import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../utils/app_language.dart';
import 'location_service.dart';
import 'firestore_service.dart';
import 'route_progress_service.dart';

class ConductorTrackingService extends ChangeNotifier {
  ConductorTrackingService._();

  static final ConductorTrackingService instance = ConductorTrackingService._();

  static const prefsKeyTracking = 'conductor_tracking';
  static const prefsKeyRoute = 'conductor_route';
  static const prefsKeyStopId = 'conductor_stop_id';
  static const prefsKeyBusType = 'conductor_bus_type';
  static const prefsKeyCrowd = 'conductor_crowd';
  static const prefsKeyBusId = 'conductor_bus_id';
  static const prefsKeyStatus = 'conductor_status';
  static const prefsKeyLat = 'conductor_last_lat';
  static const prefsKeyLng = 'conductor_last_lng';
  static const prefsKeySpeed = 'conductor_last_speed';
  static const prefsKeyUpdateMs = 'conductor_last_update_ms';
  static const prefsKeyAutoStop = 'conductor_auto_stop';
  static const prefsKeyTripFrom = 'conductor_trip_from';
  static const prefsKeyTripTo = 'conductor_trip_to';
  static const prefsKeyRouteHint = 'conductor_route_hint';

  final FirestoreService _fs = FirestoreService();

  StreamSubscription<Position>? _positionSub;
  Timer? _simulationTimer;
  MockCoordinateScenario? _mockScenario;
  int _mockScenarioIndex = 0;
  bool _initialized = false;
  bool _starting = false;
  bool _debugSimulationActive = false;
  double _simulationSpeedKmh = 24;

  bool tracking = false;
  bool autoStopEnabled = true;
  String? selectedRoute;
  String? selectedStopId;
  BusType? selectedBusType;
  BusCrowd crowd = BusCrowd.moderate;
  String? busId;
  String? statusMessage;
  double? lastLat;
  double? lastLng;
  double? lastSpeed;
  DateTime? lastUpdate;
  String? tripFromStopId;
  String? tripToStopId;
  String? draftRouteHint;
  String? _segmentStartStopId;
  String? _segmentEndStopId;
  double? _segmentProgress;
  double? _distanceToNextStopKm;
  double? _remainingRouteKm;
  double? _snappedLat;
  double? _snappedLng;
  double? _effectiveSpeedKmh;
  bool _lastCloudSyncSucceeded = true;
  String? _lastCloudSyncError;

  String _t(String english, String telugu) =>
      AppLanguage.instance.t(english, telugu);

  BusRoute? get activeRoute {
    if (selectedRoute == null) return null;
    return VizagRoutes.byRouteId(selectedRoute!);
  }

  int get currentStopIndex {
    final route = activeRoute;
    if (route == null || selectedStopId == null) return -1;
    return route.stopIds.indexOf(selectedStopId!);
  }

  String? get nextStopId {
    if (_segmentEndStopId != null) return _segmentEndStopId;
    final route = activeRoute;
    final index = currentStopIndex;
    if (route == null || index < 0 || index >= route.stopIds.length - 1) {
      return null;
    }
    return route.stopIds[index + 1];
  }

  double? get segmentProgress => _segmentProgress;
  double? get distanceToNextStopKm => _distanceToNextStopKm;
  double? get remainingRouteKm => _remainingRouteKm;
  double? get snappedLat => _snappedLat;
  double? get snappedLng => _snappedLng;
  double? get effectiveSpeedKmh => _effectiveSpeedKmh;
  bool get debugSimulationActive => _debugSimulationActive;
  bool get lastCloudSyncSucceeded => _lastCloudSyncSucceeded;
  String? get lastCloudSyncError => _lastCloudSyncError;

  BusType get resolvedBusType {
    return selectedBusType ?? activeRoute?.busType ?? BusType.redOrdinary;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _restoreSession();
    if (tracking) {
      await _startPositionStream();
      unawaited(syncNow());
    }
  }

  /// Resolves the route that will carry this trip.
  ///
  /// An explicit route hint (typed route id) wins — it must serve the
  /// From -> To range in order. Without a hint, the route with the MOST stops
  /// between From and To across the whole network is chosen (the corridor
  /// that serves both stops most directly).
  BusRoute? resolveTripRoute() {
    final from = tripFromStopId;
    final to = tripToStopId;
    if (from == null || to == null) return null;

    final hint = draftRouteHint?.trim();
    if (hint != null && hint.isNotEmpty) {
      final hinted =
          VizagRoutes.byRouteId(hint) ?? VizagRoutes.byNumber(hint);
      if (hinted == null) return null;
      final fi = hinted.stopIds.indexOf(from);
      final ti = hinted.stopIds.indexOf(to);
      if (fi < 0 || ti <= fi) return null;
      return hinted;
    }

    BusRoute? best;
    var bestSpan = -1;
    for (final r in VizagRoutes.all) {
      final fi = r.stopIds.indexOf(from);
      final ti = r.stopIds.indexOf(to);
      if (fi < 0 || ti <= fi) continue;
      final span = ti - fi;
      if (span > bestSpan) {
        best = r;
        bestSpan = span;
      }
    }
    return best;
  }

  /// Optional route id/number typed by the conductor. When empty, the route
  /// is derived from the From -> To stops alone.
  Future<void> setDraftRouteHint(String? hint) async {
    if (tracking) {
      throw StateError('Stop tracking before changing the route');
    }
    final trimmed = hint?.trim() ?? '';
    draftRouteHint = trimmed.isEmpty ? null : trimmed;
    _reresolveSelectedRoute();
    statusMessage = draftRouteHint == null
        ? 'Route id cleared — route will be found from From -> To'
        : 'Route id saved';
    await _persistSession();
    notifyListeners();
  }

  void _reresolveSelectedRoute() {
    final route = resolveTripRoute();
    selectedRoute = route?.routeId;
    if (route == null) {
      _clearProgressState();
    }
  }

  /// Selecting a route from the picker pins the hint and defaults the trip
  /// range to the full route.
  Future<void> setDraftRoute(BusRoute route) async {
    if (tracking) {
      throw StateError('Stop tracking before changing the route');
    }
    draftRouteHint = route.routeId;
    selectedRoute = route.routeId;
    if (selectedStopId != null && !route.stopIds.contains(selectedStopId)) {
      selectedStopId = null;
    }
    // A new route resets the trip range to the full route; the conductor can
    // then customise From / To in the stops section.
    tripFromStopId = route.stopIds.isEmpty ? null : route.stopIds.first;
    tripToStopId = route.stopIds.length < 2 ? null : route.stopIds.last;
    statusMessage ??= _t('Trip details saved', 'ట్రిప్ వివరాలు సేవ్ అయ్యాయి');
    await _persistSession();
    notifyListeners();
  }

  /// Customise the trip range. From and To are REQUIRED; the route is derived
  /// from them (optionally narrowed by the route id hint). The From stop must
  /// come before the To stop on the resolved route.
  Future<bool> setDraftTripStops({
    required String fromStopId,
    required String toStopId,
  }) async {
    if (tracking) {
      throw StateError('Stop tracking before changing the trip stops');
    }
    if (fromStopId == toStopId) return false;

    tripFromStopId = fromStopId;
    tripToStopId = toStopId;
    _reresolveSelectedRoute();

    final route = activeRoute;
    if (route != null && selectedStopId != null) {
      final fromIndex = route.stopIds.indexOf(fromStopId);
      final toIndex = route.stopIds.indexOf(toStopId);
      final currentIndex = route.stopIds.indexOf(selectedStopId!);
      if (fromIndex >= 0 &&
          toIndex > fromIndex &&
          (currentIndex < fromIndex || currentIndex > toIndex)) {
        selectedStopId = fromStopId;
        _resetManualProgressForSelectedStop();
      }
    }
    statusMessage =
        '${_t('Trip', 'ట్రిప్')}: '
        '${VizagStops.get(fromStopId)?.name ?? fromStopId} '
        '${_t('to', 'నుండి')} '
        '${VizagStops.get(toStopId)?.name ?? toStopId}';
    await _persistSession();
    notifyListeners();
    return true;
  }

  Future<void> clearDraftRoute() async {
    if (tracking) return;
    selectedRoute = null;
    selectedStopId = null;
    draftRouteHint = null;
    _clearProgressState();
    statusMessage = _t(
        'Route selection cleared',
        'రూట్ ఎంపిక తీసివేయబడింది');
    await _persistSession();
    notifyListeners();
  }

  Future<void> setDraftBusType(BusType value) async {
    selectedBusType = value;
    await _persistSession();
    notifyListeners();
  }

  Future<void> setDraftStop(String? stopId) async {
    selectedStopId = stopId;
    await _persistSession();
    notifyListeners();
  }

  Future<void> setDraftCrowd(BusCrowd value) async {
    crowd = value;
    await _persistSession();
    notifyListeners();
  }

  Future<void> setAutoStopEnabled(bool value) async {
    autoStopEnabled = value;
    statusMessage = value
        ? _t('Auto stop detection is on',
            'గ్పస్ స్టాప్ గుర్తింపు పని చేస్తోంది')
        : _t('Auto stop detection is off',
            'గ్పస్ స్టాప్ గుర్తింపు ఆపివేయబడింది');
    if (!value) {
      _ensureManualStopSelected();
    } else if (lastLat != null && lastLng != null) {
      _advanceStopFromLocation(lat: lastLat!, lng: lastLng!);
    }
    await _persistSession();
    notifyListeners();
  }

  /// Starts live tracking with GPS validation.
  ///
  /// The conductor's real position is snapped to the resolved route: starting
  /// mid-route continues the trip to the To stop; a position that does not
  /// match the route at all returns a structured failure (with the detected
  /// nearest stop) so the UI can explain the wrong From - To.
  Future<StartTrackingResult> startTracking() async {
    if (_starting) {
      return const StartTrackingResult.failure(
        title: 'Please wait',
        message: 'Starting is already in progress.',
      );
    }
    _starting = true;
    try {
      final fromId = tripFromStopId;
      final toId = tripToStopId;
      if (fromId == null || toId == null) {
        statusMessage = 'Pick the From and To stops first';
        await _persistSession();
        notifyListeners();
        return const StartTrackingResult.failure(
          title: 'From - To required',
          message: 'Pick the From and To stops before starting. The route id '
              'is optional.',
        );
      }

      var route = resolveTripRoute();
      if (route == null) {
        final hint = draftRouteHint?.trim();
        if (hint != null && hint.isNotEmpty) {
          final hinted =
              VizagRoutes.byRouteId(hint) ?? VizagRoutes.byNumber(hint);
          statusMessage = hinted == null
              ? 'Route $hint not found'
              : 'Route $hint does not run between the picked From and To stops';
          await _persistSession();
          notifyListeners();
          return StartTrackingResult.failure(
            title: 'Route id does not match',
            message: hinted == null
                ? 'Route "$hint" was not found. Clear it or correct it.'
                : 'Route "$hint" does not run between '
                    '${VizagStops.get(fromId)?.name ?? fromId} and '
                    '${VizagStops.get(toId)?.name ?? toId}. '
                    'Check the From - To stops or clear the route id.',
            route: hinted,
          );
        }
        statusMessage = 'No route found between the picked stops';
        await _persistSession();
        notifyListeners();
        return StartTrackingResult.failure(
          title: 'No route path found',
          message: 'No bus route in the network runs from '
              '${VizagStops.get(fromId)?.name ?? fromId} to '
              '${VizagStops.get(toId)?.name ?? toId} in that direction. '
              'Check the From - To stops.',
        );
      }

      final permission = await _ensurePermission();
      if (!permission) {
        tracking = false;
        statusMessage = 'Location permission is required for live tracking';
        await _persistSession();
        notifyListeners();
        return const StartTrackingResult.failure(
          title: 'Location permission needed',
          message: 'Allow location access so passengers can see the bus.',
        );
      }

      selectedBusType ??= route.busType;
      busId ??= _buildBusId(route.routeId);
      statusMessage = 'Detecting your location...';
      notifyListeners();

      // ── GPS validation: the conductor's real position must lie on (or very
      // near) the chosen route corridor. Starting mid-route is fine — the
      // detection continues the trip to the To stop.
      Position? fix;
      try {
        final sampleTime = DateTime.now();
        fix = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 20),
        );
        lastLat = fix.latitude;
        lastLng = fix.longitude;
        lastSpeed = _normalizedSpeedKmh(
          rawSpeedKmh: fix.speed * 3.6,
          lat: fix.latitude,
          lng: fix.longitude,
          sampleTime: sampleTime,
        );
        lastUpdate = sampleTime;
      } catch (e) {
        debugPrint('ConductorTrackingService: start GPS fix failed: $e');
      }

      if (fix == null) {
        tracking = false;
        statusMessage = 'Could not get a GPS fix. Go outside and retry.';
        await _persistSession();
        notifyListeners();
        return StartTrackingResult.failure(
          title: 'No GPS signal',
          message: 'Could not get your location. Move to an open area and '
              'try Start Tracking again.',
          route: route,
        );
      }

      var snapshot = RouteProgressService.snapToRoute(
        route: route,
        lat: fix.latitude,
        lng: fix.longitude,
      );

      // ── Auto-detect the trip start ──
      // "Wrong" is shown ONLY when the conductor's live location is not near
      // ANY stop in the entered route's stop list. Otherwise the trip
      // continues from the detected place, with every earlier stop marked
      // completed.
      //
      // Match order:
      //   1. On the route corridor between stops (mid-segment start) -> exact.
      //   2. Within 1 km of any stop in the route's stop list -> that stop.
      //   3. Otherwise -> wrong From-To (with the nearest real stop shown).
      var currentIndex = -1;
      var onDetectedPosition = false;

      // nearest stop in THIS route's stop list
      ({int index, double distanceKm})? nearestOnRoute;
      for (var i = 0; i < route.stopIds.length; i++) {
        final s = VizagStops.get(route.stopIds[i]);
        if (s == null || !s.hasCoordinates) continue;
        final d = LocationService.distanceKm(
            fix.latitude, fix.longitude, s.lat, s.lng);
        if (nearestOnRoute == null || d < nearestOnRoute.distanceKm) {
          nearestOnRoute = (index: i, distanceKm: d);
        }
      }

      if (snapshot != null && snapshot.distanceFromRouteKm <= 1.0) {
        currentIndex = snapshot.currentStopIndex;
        onDetectedPosition = true;
      } else if (nearestOnRoute != null &&
          nearestOnRoute.distanceKm <= 1.0) {
        currentIndex = nearestOnRoute.index;
        snapshot = null;
      } else {
        final detected = _nearestStopTo(fix.latitude, fix.longitude);
        tracking = false;
        statusMessage = _t(
          'Your location is not on this route',
          '\u0c2e\u0c40 \u0c38\u0c4d\u0c25\u0c3e\u0c28\u0c02 \u0c08 \u0c30\u0c42\u0c1f\u0c4d \u0c38\u0c4d\u0c1f\u0c3e\u0c2a\u0c4d\u0c32 \u0c1c\u0c3e\u0c2c\u0c3f\u0c24\u0c3e\u0c32\u0c4b \u0c32\u0c47\u0c26\u0c41',
        );
        await _persistSession();
        notifyListeners();
        return StartTrackingResult.failure(
          title: _t('Location does not match this route',
              '\u0c2e\u0c40 \u0c38\u0c4d\u0c25\u0c3e\u0c28\u0c02 \u0c08 \u0c30\u0c42\u0c1f\u0c4d \u0c15\u0c3f \u0c38\u0c30\u0c3f\u0c17\u0c3e \u0c32\u0c47\u0c26\u0c41'),
          message: _t(
            'Your GPS location is near '
                '${detected?.name ?? 'an unknown stop'}'
                '${detected != null ? ' (${detected.distanceKm.toStringAsFixed(1)} km away)' : ''}'
                ', which is not in the stop list of '
                '${route.number}: ${route.from} -> ${route.to}. '
                'Pick the From - To that matches where the bus actually is.',
            '\u0c2e\u0c40 GPS \u0c38\u0c4d\u0c25\u0c3e\u0c28\u0c02 '
                '${detected?.name ?? '\u0c24\u0c46\u0c32\u0c3f\u0c2f\u0c28\u0c3f \u0c38\u0c4d\u0c1f\u0c3e\u0c2a\u0c4d'}'
                '${detected != null ? ' (${detected.distanceKm.toStringAsFixed(1)} \u0c15\u0c3f.\u0c2e\u0c40 \u0c26\u0c42\u0c30\u0c02\u0c32\u0c4b)' : ''}'
                ' \u0c26\u0c17\u0c4d\u0c17\u0c30 \u0c09\u0c02\u0c26\u0c3f, \u0c07\u0c26\u0c3f '
                '${route.number}: ${route.from} -> ${route.to} '
                '\u0c38\u0c4d\u0c1f\u0c3e\u0c2a\u0c4d \u0c1c\u0c3e\u0c2c\u0c3f\u0c24\u0c3e\u0c32\u0c4b \u0c32\u0c47\u0c26\u0c41. '
                '\u0c2c\u0c38\u0c4d\u0c38\u0c41 \u0c28\u0c3f\u0c1c\u0c02\u0c17\u0c3e \u0c09\u0c28\u0c4d\u0c28 \u0c2a\u0c4d\u0c30\u0c15\u0c3e\u0c30\u0c2e\u0c41 From - To \u0c0e\u0c02\u0c1a\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f.',
          ),
          route: route,
          detectedStopName: detected?.name,
          detectedDistanceKm: detected?.distanceKm,
        );
      }

      final toIndex = route.stopIds.indexOf(toId);
      if (currentIndex > toIndex) {
        tracking = false;
        statusMessage = _t('You are already past the To stop',
            '\u0c2e\u0c40\u0c30\u0c41 \u0c07\u0c2a\u0c4d\u0c2a\u0c1f\u0c3f\u0c15\u0c47 To \u0c38\u0c4d\u0c1f\u0c3e\u0c2a\u0c4d \u0c26\u0c3e\u0c1f\u0c3f\u0c2a\u0c4b\u0c2f\u0c3e\u0c30\u0c41');
        await _persistSession();
        notifyListeners();
        return StartTrackingResult.failure(
          title: _t('Beyond the destination', '\u0c17\u0c2e\u0c4d\u0c2f\u0c02 \u0c26\u0c3e\u0c1f\u0c3f\u0c2a\u0c4b\u0c2f\u0c3f\u0c02\u0c26\u0c3f'),
          message: _t(
              'You are past ${VizagStops.get(toId)?.name ?? toId} already. '
              'Reverse the direction or pick a different From - To.',
              '${VizagStops.get(toId)?.name ?? toId} '
              '\u0c15\u0c3f \u0c2e\u0c40\u0c30\u0c41 \u0c07\u0c2a\u0c4d\u0c2a\u0c1f\u0c3f\u0c15\u0c47 \u0c26\u0c3e\u0c1f\u0c3f\u0c2a\u0c4b\u0c2f\u0c3e\u0c30\u0c41. '
              '\u0c26\u0c3f\u0c36 \u0c2e\u0c3e\u0c30\u0c4d\u0c1a\u0c02\u0c21\u0c3f \u0c32\u0c47\u0c26\u0c3e From - To \u0c2e\u0c3e\u0c30\u0c4d\u0c1a\u0c02\u0c21\u0c3f.'),
          route: route,
        );
      }

      selectedRoute = route.routeId;
      // The trip now really starts from the detected position — every stop
      // before it counts as completed.
      tripFromStopId = route.stopIds[currentIndex];
      tripToStopId = toId;
      tracking = true;
      _lastCloudSyncSucceeded = true;
      _lastCloudSyncError = null;

      selectedStopId = route.stopIds[currentIndex];
      if (onDetectedPosition && snapshot != null) {
        // snapped mid-segment: keep the exact progress
        _applyProgressSnapshot(snapshot);
      } else {
        // started at a stop: progress begins at 0, previous stops completed
        _resetManualProgressForSelectedStop();
      }
      final startName =
          VizagStops.get(selectedStopId!)?.name ?? selectedStopId!;
      statusMessage =
          '${_t('Tracking from', 'ట్రాకింగ్ ప్రారంభము')} $startName';
      await _persistSession();
      notifyListeners();

      await _startPositionStream();
      await syncNow();
      return const StartTrackingResult.ok();
    } finally {
      _starting = false;
    }
  }

  /// Nearest coordinate-bearing stop to a raw GPS fix — used to tell the
  /// conductor where they actually are when the From-To doesn't match.
  ({String name, double distanceKm})? _nearestStopTo(double lat, double lng) {
    ({String name, double distanceKm})? best;
    for (final stop in VizagStops.list) {
      if (!stop.hasCoordinates) continue;
      final d = LocationService.distanceKm(lat, lng, stop.lat, stop.lng);
      if (best == null || d < best.distanceKm) {
        best = (name: stop.name, distanceKm: d);
      }
    }
    return best;
  }

  Future<void> syncNow() async {
    if (!tracking || activeRoute == null || busId == null) {
      return;
    }

    if (_debugSimulationActive) {
      await _emitSimulatedTick();
      return;
    }

    if (selectedStopId == null) {
      await _resolveCurrentStopFromLocation();
    }

    final fallbackStop =
        selectedStopId == null ? null : VizagStops.get(selectedStopId!);
    double lat = fallbackStop?.lat ?? 0;
    double lng = fallbackStop?.lng ?? 0;
    double speed = 0;

    try {
      final sampleTime = DateTime.now();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lat = pos.latitude;
      lng = pos.longitude;
      speed = _normalizedSpeedKmh(
        rawSpeedKmh: pos.speed * 3.6,
        lat: lat,
        lng: lng,
        sampleTime: sampleTime,
      );
      _advanceStopFromLocation(lat: lat, lng: lng);
    } catch (_) {
      // Keep fallback stop coordinates when the live fix fails.
    }

    _ensureManualStopSelected();
    await _pushUpdate(lat: lat, lng: lng, speed: speed);
  }

  Future<void> changeRoute(BusRoute route) async {
    if (tracking) {
      throw StateError('Stop tracking before changing the route');
    }
    await setDraftRoute(route);
  }

  bool get canReverseDirection =>
      activeRoute?.returnRouteNumber != null &&
      VizagRoutes.byRouteId(activeRoute!.returnRouteNumber!) != null;

  Future<void> reverseDirection() async {
    final route = activeRoute;
    final returnRouteId = route?.returnRouteNumber;
    if (route == null || returnRouteId == null) return;

    final returnRoute = VizagRoutes.byRouteId(returnRouteId);
    if (returnRoute == null) return;

    await stopDebugSimulation(resumeGps: false);
    final currentStop = selectedStopId;
    selectedRoute = returnRoute.routeId;
    _clearProgressState();
    selectedStopId = currentStop != null &&
            returnRoute.stopIds.contains(currentStop)
        ? currentStop
        : (returnRoute.stopIds.isNotEmpty ? returnRoute.stopIds.first : null);

    // Mirror the custom trip range onto the return direction: the old To
    // becomes the new From (and vice versa) when both stops exist on the
    // return route, otherwise fall back to the return route's full range.
    final mirroredFrom = tripToStopId != null &&
            returnRoute.stopIds.contains(tripToStopId!)
        ? tripToStopId!
        : (returnRoute.stopIds.isNotEmpty ? returnRoute.stopIds.first : null);
    final mirroredTo = tripFromStopId != null &&
            returnRoute.stopIds.contains(tripFromStopId!)
        ? tripFromStopId!
        : (returnRoute.stopIds.length >= 2
            ? returnRoute.stopIds.last
            : null);
    tripFromStopId = mirroredFrom;
    tripToStopId = mirroredTo;
    if (selectedStopId == null && mirroredFrom != null) {
      selectedStopId = mirroredFrom;
    }

    if (lastLat != null && lastLng != null) {
      final snapshot = RouteProgressService.snapToRoute(
        route: returnRoute,
        lat: lastLat!,
        lng: lastLng!,
        hintCurrentStopId: selectedStopId,
      );
      if (snapshot != null) {
        if (autoStopEnabled) {
          _applyProgressSnapshot(snapshot);
        } else {
          _applyManualProgressSnapshot(snapshot);
        }
      } else if (selectedStopId != null) {
        _resetManualProgressForSelectedStop();
      }
    } else if (selectedStopId != null) {
      _resetManualProgressForSelectedStop();
    }

    statusMessage =
        'Direction changed: ${returnRoute.from} to ${returnRoute.to}';

    await _persistSession();
    notifyListeners();

    if (tracking) {
      await syncNow();
    }
  }

  bool get canMoveToPreviousStop => currentStopIndex > 0;

  bool get canAdvanceToNextStop {
    final route = activeRoute;
    return route != null &&
        currentStopIndex >= 0 &&
        currentStopIndex < route.stopIds.length - 1;
  }

  Future<void> moveToPreviousStop() async {
    final route = activeRoute;
    if (route == null) return;

    if (selectedStopId == null) {
      selectedStopId = route.stopIds.first;
    } else {
      final index = route.stopIds.indexOf(selectedStopId!);
      if (index > 0) {
        selectedStopId = route.stopIds[index - 1];
      }
    }

    _resetManualProgressForSelectedStop();
    statusMessage =
        'Manual stop set to ${VizagStops.get(selectedStopId!)?.name ?? selectedStopId!}';
    await _persistSession();
    notifyListeners();

    if (tracking) {
      await syncNow();
    }
  }

  Future<void> advanceToNextStop() async {
    final route = activeRoute;
    if (route == null) return;

    if (selectedStopId == null) {
      selectedStopId = route.stopIds.first;
    } else {
      final index = route.stopIds.indexOf(selectedStopId!);
      if (index >= 0 && index < route.stopIds.length - 1) {
        selectedStopId = route.stopIds[index + 1];
      }
    }

    _resetManualProgressForSelectedStop();
    statusMessage =
        'Manual stop set to ${VizagStops.get(selectedStopId!)?.name ?? selectedStopId!}';
    await _persistSession();
    notifyListeners();

    if (tracking) {
      await syncNow();
    }
  }

  Future<void> stopTracking() async {
    await stopDebugSimulation(resumeGps: false);
    await _positionSub?.cancel();
    _positionSub = null;
    var cloudDeactivateFailed = false;
    if (busId != null) {
      try {
        await _fs.deactivateBus(busId!);
      } catch (_) {
        cloudDeactivateFailed = true;
      }
    }

    tracking = false;
    busId = null;
    lastLat = null;
    lastLng = null;
    lastSpeed = null;
    lastUpdate = null;
    _segmentStartStopId = null;
    _segmentEndStopId = null;
    _segmentProgress = null;
    _distanceToNextStopKm = null;
    _remainingRouteKm = null;
    _snappedLat = null;
    _snappedLng = null;
    _effectiveSpeedKmh = null;
    statusMessage = cloudDeactivateFailed
        ? 'Trip ended locally · cloud clear failed'
        : 'Trip ended';
    await _clearPersistedSession();
    notifyListeners();
  }

  Future<void> startDebugSimulation({double speedKmh = 24}) async {
    if (!tracking || activeRoute == null || busId == null) return;

    _simulationSpeedKmh = speedKmh.clamp(8.0, 40.0);
    _mockScenario = MockCoordinateScenarios.forRoute(activeRoute!.routeId);
    _mockScenarioIndex = 0;
    _debugSimulationActive = true;
    await _positionSub?.cancel();
    _positionSub = null;
    _simulationTimer?.cancel();
    statusMessage = _mockScenario == null
        ? 'Debug simulation running at ${_simulationSpeedKmh.toStringAsFixed(0)} km/h'
        : 'Debug stream: ${_mockScenario!.displayName}';
    await _persistSession();
    notifyListeners();

    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_emitSimulatedTick());
    });

    await _emitSimulatedTick();
  }

  Future<void> stopDebugSimulation({bool resumeGps = true}) async {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _mockScenario = null;
    _mockScenarioIndex = 0;

    final wasActive = _debugSimulationActive;
    _debugSimulationActive = false;

    if (resumeGps && wasActive && tracking) {
      await _startPositionStream();
    }

    if (wasActive) {
      statusMessage = 'Debug simulation stopped';
      await _persistSession();
      notifyListeners();
    }
  }

  Future<void> _startPositionStream() async {
    await _positionSub?.cancel();
    final settings = _buildLocationSettings();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      try {
        final route = activeRoute;
        if (!tracking || route == null || busId == null) {
          return;
        }

        final sampleTime = DateTime.now();
        final lat = position.latitude;
        final lng = position.longitude;
        final speed = _normalizedSpeedKmh(
          rawSpeedKmh: position.speed * 3.6,
          lat: lat,
          lng: lng,
          sampleTime: sampleTime,
        );
        _advanceStopFromLocation(lat: lat, lng: lng);
        _ensureManualStopSelected();

        if (selectedStopId == null) {
          statusMessage =
              'Waiting for GPS to align with route ${route.number}...';
          await _persistSession();
          notifyListeners();
          return;
        }

        await _pushUpdate(lat: lat, lng: lng, speed: speed);
      } catch (e) {
        statusMessage = 'Tracking update failed: $e';
        await _persistSession();
        notifyListeners();
      }
    }, onError: (Object error) async {
      statusMessage = 'Location stream error: $error';
      await _persistSession();
      notifyListeners();
    });
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Vizag Bus Live tracking',
          notificationText: 'Conductor trip is running in the background.',
          enableWakeLock: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );
  }

  Future<void> _pushUpdate({
    required double lat,
    required double lng,
    required double speed,
  }) async {
    if (activeRoute == null || selectedStopId == null || busId == null) return;

    _effectiveSpeedKmh = RouteProgressService.effectiveSpeedKmh(
      route: activeRoute!,
      rawSpeedKmh: speed,
      previousEffectiveSpeedKmh: _effectiveSpeedKmh,
    );

    final nextStopEtaMins = nextStopId == null
        ? 0
        : RouteProgressService.etaMinutesForDistance(
            distanceKm: _distanceToNextStopKm ?? 0,
            route: activeRoute!,
            effectiveSpeedKmh: _effectiveSpeedKmh,
          );

    var cloudSyncFailed = false;
    String? cloudSyncError;
    final displaySpeed = (_effectiveSpeedKmh ?? speed).clamp(0.0, 120.0);
    try {
      await _fs.pushConductorLocation(
        busId: busId!,
        routeKey: activeRoute!.routeId,
        routeNumber: activeRoute!.number,
        busPlateNumber: '',
        lat: lat,
        lng: lng,
        speedKmh: displaySpeed,
        crowd: crowd,
        currentStopId: selectedStopId!,
        nextStopId: nextStopId,
        segmentStartStopId: _segmentStartStopId,
        segmentEndStopId: _segmentEndStopId,
        segmentProgress: _segmentProgress,
        distanceToNextStopKm: _distanceToNextStopKm,
        remainingRouteKm: _remainingRouteKm,
        snappedLat: _snappedLat,
        snappedLng: _snappedLng,
        effectiveSpeedKmh: _effectiveSpeedKmh,
        etaToNextStopMins: nextStopEtaMins,
        busType: resolvedBusType,
        tripToStopId: tripToStopId,
      );
    } catch (e) {
      cloudSyncFailed = true;
      cloudSyncError = e.toString();
    }

    final updateTime = DateTime.now();
    lastLat = lat;
    lastLng = lng;
    lastSpeed = displaySpeed;
    lastUpdate = updateTime;
    _lastCloudSyncSucceeded = !cloudSyncFailed;
    _lastCloudSyncError = cloudSyncError;
    final progressMessage = _progressStatusMessage(updateTime);
    statusMessage = cloudSyncFailed
        ? '$progressMessage · cloud sync failed'
        : progressMessage;
    await _persistSession();
    notifyListeners();
  }

  Future<void> _emitSimulatedTick() async {
    if (_mockScenario != null) {
      await _emitMockScenarioTick();
      return;
    }

    final route = activeRoute;
    if (!_debugSimulationActive ||
        !tracking ||
        route == null ||
        busId == null ||
        selectedStopId == null) {
      return;
    }

    final currentIndex = route.stopIds.indexOf(selectedStopId!);
    if (currentIndex < 0) return;

    if (currentIndex >= route.stopIds.length - 1) {
      final terminal = VizagStops.get(route.stopIds.last);
      if (terminal != null) {
        _segmentStartStopId = terminal.id;
        _segmentEndStopId = null;
        _segmentProgress = 1;
        _distanceToNextStopKm = 0;
        _remainingRouteKm = 0;
        _snappedLat = terminal.lat;
        _snappedLng = terminal.lng;
        await _pushUpdate(lat: terminal.lat, lng: terminal.lng, speed: 0);
      }
      await stopDebugSimulation(resumeGps: false);
      statusMessage =
          'Debug simulation reached ${terminal?.name ?? 'terminus'}';
      await _persistSession();
      notifyListeners();
      return;
    }

    var segmentIndex = currentIndex;
    var progress = (_segmentProgress ?? 0).clamp(0.0, 1.0);
    var remainingStepKm = _simulationSpeedKmh * (4 / 3600);

    while (remainingStepKm > 0 && segmentIndex < route.stopIds.length - 1) {
      final segmentKm =
          RouteProgressService.segmentDistanceKmForRoute(route, segmentIndex);
      if (segmentKm <= 0) {
        segmentIndex++;
        progress = 0;
        continue;
      }

      final remainingSegmentKm = segmentKm * (1 - progress);
      if (remainingStepKm < remainingSegmentKm) {
        progress += remainingStepKm / segmentKm;
        remainingStepKm = 0;
      } else {
        remainingStepKm -= remainingSegmentKm;
        segmentIndex++;
        progress = 0;
      }
    }

    if (segmentIndex >= route.stopIds.length - 1) {
      final terminal = VizagStops.get(route.stopIds.last);
      if (terminal == null) return;

      _segmentStartStopId = terminal.id;
      _segmentEndStopId = null;
      _segmentProgress = 1;
      _distanceToNextStopKm = 0;
      _remainingRouteKm = 0;
      _snappedLat = terminal.lat;
      _snappedLng = terminal.lng;
      await _pushUpdate(lat: terminal.lat, lng: terminal.lng, speed: 0);
      await stopDebugSimulation(resumeGps: false);
      statusMessage = 'Debug simulation reached ${terminal.name}';
      await _persistSession();
      notifyListeners();
      return;
    }

    final startStop = VizagStops.get(route.stopIds[segmentIndex]);
    final endStop = VizagStops.get(route.stopIds[segmentIndex + 1]);
    if (startStop == null || endStop == null) return;

    final lat = startStop.lat + ((endStop.lat - startStop.lat) * progress);
    final lng = startStop.lng + ((endStop.lng - startStop.lng) * progress);

    final snapshot = RouteProgressService.snapToRoute(
      route: route,
      lat: lat,
      lng: lng,
      hintCurrentStopId: selectedStopId,
    );
    if (snapshot != null) {
      _applyProgressSnapshot(snapshot);
    }

    await _pushUpdate(
      lat: lat,
      lng: lng,
      speed: _simulationSpeedKmh,
    );
  }

  Future<void> _emitMockScenarioTick() async {
    final route = activeRoute;
    final scenario = _mockScenario;
    if (!_debugSimulationActive ||
        !tracking ||
        route == null ||
        busId == null ||
        scenario == null ||
        scenario.samples.isEmpty) {
      return;
    }

    if (_mockScenarioIndex >= scenario.samples.length) {
      final terminalName = VizagStops.get(route.stopIds.last)?.name ?? route.to;
      await stopDebugSimulation(resumeGps: false);
      statusMessage = 'Debug stream reached $terminalName';
      await _persistSession();
      notifyListeners();
      return;
    }

    final sample = scenario.samples[_mockScenarioIndex];
    final snapshot = RouteProgressService.snapToRoute(
      route: route,
      lat: sample.lat,
      lng: sample.lng,
      hintCurrentStopId: selectedStopId,
    );
    if (snapshot != null) {
      _applyProgressSnapshot(snapshot);
    }

    await _pushUpdate(
      lat: sample.lat,
      lng: sample.lng,
      speed: sample.speedKmh,
    );
    _mockScenarioIndex += 1;

    if (_mockScenarioIndex >= scenario.samples.length) {
      final terminalName = VizagStops.get(route.stopIds.last)?.name ?? route.to;
      await stopDebugSimulation(resumeGps: false);
      statusMessage = 'Debug stream reached $terminalName';
      await _persistSession();
      notifyListeners();
    }
  }

  Future<void> _resolveCurrentStopFromLocation() async {
    final route = activeRoute;
    if (route == null) return;

    double? lat = lastLat;
    double? lng = lastLng;

    try {
      final sampleTime = DateTime.now();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lat = pos.latitude;
      lng = pos.longitude;
      lastLat = lat;
      lastLng = lng;
      lastSpeed = _normalizedSpeedKmh(
        rawSpeedKmh: pos.speed * 3.6,
        lat: lat,
        lng: lng,
        sampleTime: sampleTime,
      );
    } catch (e) {
      debugPrint(
          'ConductorTrackingService: failed to resolve current stop: $e');
    }

    if (lat == null || lng == null) {
      if (route.stopIds.isNotEmpty) {
        selectedStopId = route.stopIds.first;
        _segmentStartStopId = selectedStopId;
        _segmentEndStopId = route.stopIds.length > 1 ? route.stopIds[1] : null;
        _segmentProgress = 0;
        _distanceToNextStopKm = _segmentEndStopId == null
            ? 0
            : RouteProgressService.segmentDistanceKmForRoute(route, 0);
        _remainingRouteKm = route.stopIds.length > 1
            ? _remainingDistanceFromSegment(route, 0, _distanceToNextStopKm!)
            : 0;
      }
      return;
    }

    final snapshot = RouteProgressService.snapToRoute(
      route: route,
      lat: lat,
      lng: lng,
      hintCurrentStopId: selectedStopId,
    );
    if (snapshot != null) {
      _applyProgressSnapshot(snapshot);
      final stopName = VizagStops.get(snapshot.currentStopId)?.name ??
          snapshot.currentStopId;
      statusMessage = 'Tracking from $stopName';
    }
  }

  void _advanceStopFromLocation({
    required double lat,
    required double lng,
  }) {
    final route = activeRoute;
    if (route == null) return;

    final snapshot = RouteProgressService.snapToRoute(
      route: route,
      lat: lat,
      lng: lng,
      hintCurrentStopId: selectedStopId,
    );
    if (snapshot != null) {
      if (!autoStopEnabled) {
        _applyManualProgressSnapshot(snapshot);
        return;
      }

      final previousStopId = selectedStopId;
      _applyProgressSnapshot(snapshot);

      if (previousStopId != selectedStopId) {
        statusMessage =
            'Auto-detected stop: ${VizagStops.get(selectedStopId!)?.name ?? selectedStopId!}';
      }
    }
  }

  void _applyManualProgressSnapshot(RouteProgressSnapshot snapshot) {
    final route = activeRoute;
    if (route == null) return;

    if (selectedStopId == null) {
      _applyProgressSnapshot(snapshot);
      return;
    }

    final currentIndex = route.stopIds.indexOf(selectedStopId!);
    if (currentIndex < 0) {
      _applyProgressSnapshot(snapshot);
      return;
    }

    if (currentIndex >= route.stopIds.length - 1) {
      _segmentStartStopId = selectedStopId;
      _segmentEndStopId = null;
      _segmentProgress = 1;
      _distanceToNextStopKm = 0;
      _remainingRouteKm = 0;
      _snappedLat = snapshot.snappedLat;
      _snappedLng = snapshot.snappedLng;
      return;
    }

    _segmentStartStopId = selectedStopId;
    _segmentEndStopId = route.stopIds[currentIndex + 1];
    _snappedLat = snapshot.snappedLat;
    _snappedLng = snapshot.snappedLng;

    if (snapshot.currentStopIndex < currentIndex) {
      _segmentProgress = 0;
      _distanceToNextStopKm =
          RouteProgressService.segmentDistanceKmForRoute(route, currentIndex);
      _remainingRouteKm = _remainingDistanceFromSegment(
        route,
        currentIndex,
        _distanceToNextStopKm!,
      );
      return;
    }

    if (snapshot.currentStopIndex == currentIndex) {
      _segmentProgress = snapshot.segmentProgress;
      _distanceToNextStopKm = snapshot.distanceToNextStopKm;
      _remainingRouteKm = _remainingDistanceFromSegment(
        route,
        currentIndex,
        snapshot.distanceToNextStopKm,
      );
      return;
    }

    _segmentProgress = 1;
    _distanceToNextStopKm = 0;
    _remainingRouteKm =
        _remainingDistanceFromSegment(route, currentIndex + 1, 0);
    final nextStopName =
        VizagStops.get(_segmentEndStopId!)?.name ?? _segmentEndStopId!;
    statusMessage = 'Reached $nextStopName · tap Next stop in manual mode';
  }

  void _applyProgressSnapshot(RouteProgressSnapshot snapshot) {
    selectedStopId = snapshot.currentStopId;
    _segmentStartStopId = snapshot.currentStopId;
    _segmentEndStopId =
        snapshot.nextStopId.isEmpty ? null : snapshot.nextStopId;
    _segmentProgress = snapshot.segmentProgress;
    _distanceToNextStopKm = snapshot.distanceToNextStopKm;
    _remainingRouteKm = snapshot.remainingRouteKm;
    _snappedLat = snapshot.snappedLat;
    _snappedLng = snapshot.snappedLng;
  }

  void _clearProgressState() {
    _segmentStartStopId = null;
    _segmentEndStopId = null;
    _segmentProgress = null;
    _distanceToNextStopKm = null;
    _remainingRouteKm = null;
    _snappedLat = null;
    _snappedLng = null;
  }

  double _remainingDistanceFromSegment(
    BusRoute route,
    int currentSegmentIndex,
    double distanceToNextStopKm,
  ) {
    var remaining = distanceToNextStopKm;
    for (var i = currentSegmentIndex + 1; i < route.stopIds.length - 1; i++) {
      remaining += RouteProgressService.segmentDistanceKmForRoute(route, i);
    }
    return remaining;
  }

  String _progressStatusMessage(DateTime updateTime) {
    final nextId = nextStopId;
    if (selectedStopId == null) {
      return 'Tracking live at ${_timeAgo(updateTime)}';
    }

    final currentName =
        VizagStops.get(selectedStopId!)?.name ?? selectedStopId!;
    final reachedTripEnd = tripToStopId != null &&
        selectedStopId == tripToStopId &&
        (nextId == null || nextId.isEmpty || nextId == tripToStopId) &&
        (_segmentProgress ?? 0) >= 0.98;
    if (reachedTripEnd) {
      return '${_t('Reached', 'చేరుకుంది')} $currentName · '
          '${_t('trip complete', 'ట్రిప్ పూర్తయింది')} · '
          '${_t('updated', 'అప్డేట్')} ${_timeAgo(updateTime)}';
    }

    if (nextId == null || nextId.isEmpty) {
      return '${_t('Reached', 'చేరుకుంది')} $currentName · '
          '${_t('updated', 'అప్డేట్')} ${_timeAgo(updateTime)}';
    }

    final nextName = VizagStops.get(nextId)?.name ?? nextId;
    final progress = (_segmentProgress ?? 0).clamp(0.0, 1.0);
    final progressPct = (progress * 100).round();
    final distanceLabel = _distanceToNextStopKm == null
        ? ''
        : ' · ${_distanceToNextStopKm!.toStringAsFixed(2)} km left';
    return '${_t('Passed', 'దాటింది')} $currentName · '
        '$progressPct% ${_t('to', 'కఁ')} $nextName$distanceLabel · '
        '${_t('updated', 'అప్డేట్')} ${_timeAgo(updateTime)}';
  }

  void _ensureManualStopSelected() {
    final route = activeRoute;
    if (route == null || selectedStopId != null) return;

    if (autoStopEnabled) return;

    selectedStopId = route.stopIds.firstOrNull;
    if (selectedStopId != null) {
      _resetManualProgressForSelectedStop();
    }
  }

  void _resetManualProgressForSelectedStop() {
    final route = activeRoute;
    if (route == null || selectedStopId == null) return;

    final index = route.stopIds.indexOf(selectedStopId!);
    if (index < 0) return;

    _segmentStartStopId = selectedStopId;
    _segmentEndStopId =
        index < route.stopIds.length - 1 ? route.stopIds[index + 1] : null;
    _segmentProgress = _segmentEndStopId == null ? 1 : 0;
    _distanceToNextStopKm = _segmentEndStopId == null
        ? 0
        : RouteProgressService.segmentDistanceKmForRoute(route, index);
    _remainingRouteKm = _segmentEndStopId == null
        ? 0
        : _remainingDistanceFromSegment(route, index, _distanceToNextStopKm!);
  }

  double _normalizedSpeedKmh({
    required double rawSpeedKmh,
    required double lat,
    required double lng,
    required DateTime sampleTime,
  }) {
    var speedKmh = rawSpeedKmh.clamp(0.0, 120.0);

    if (lastLat != null && lastLng != null && lastUpdate != null) {
      final elapsedSeconds =
          sampleTime.difference(lastUpdate!).inMilliseconds / 1000;
      if (elapsedSeconds >= 2) {
        final movedKm =
            LocationService.distanceKm(lastLat!, lastLng!, lat, lng);
        final movementSpeedKmh = (movedKm / elapsedSeconds) * 3600;

        if (movedKm < 0.015 && elapsedSeconds >= 4) {
          return 0;
        }

        speedKmh = math.min(speedKmh, movementSpeedKmh);
      }
    }

    return speedKmh < 2.5 ? 0 : speedKmh;
  }

  Future<bool> _ensurePermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    }

    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }

    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      return false;
    }

    if (locationPermission != LocationPermission.always) {
      locationPermission = await Geolocator.requestPermission();
    }

    final notificationStatus =
        await permission_handler.Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await permission_handler.Permission.notification.request();
    }

    final backgroundStatus =
        await permission_handler.Permission.locationAlways.status;
    if (!backgroundStatus.isGranted) {
      await permission_handler.Permission.locationAlways.request();
    }

    // Battery-optimization exemption: without it, aggressive battery savers
    // (Doze/Vivo/Oppo/Realme etc.) can silently kill the background location
    // stream mid-trip. The system dialog is only shown once; skipping the
    // request never blocks tracking.
    try {
      final batteryStatus =
          await permission_handler.Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await permission_handler.Permission.ignoreBatteryOptimizations
            .request();
      }
    } catch (e) {
      debugPrint(
        'ConductorTrackingService: battery optimization request skipped: $e',
      );
    }

    final finalPermission = await Geolocator.checkPermission();
    return finalPermission == LocationPermission.whileInUse ||
        finalPermission == LocationPermission.always;
  }

  String _buildBusId(String routeId) =>
      'bus_${routeId.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    tracking = prefs.getBool(prefsKeyTracking) ?? false;
    selectedRoute = prefs.getString(prefsKeyRoute);
    selectedStopId = prefs.getString(prefsKeyStopId);
    final storedBusType = prefs.getString(prefsKeyBusType);
    if (storedBusType != null) {
      selectedBusType = BusType.values
          .where((type) => type.name == storedBusType)
          .firstOrNull;
    }

    final crowdIndex = prefs.getInt(prefsKeyCrowd);
    if (crowdIndex != null &&
        crowdIndex >= 0 &&
        crowdIndex < BusCrowd.values.length) {
      crowd = BusCrowd.values[crowdIndex];
    }

    busId = prefs.getString(prefsKeyBusId);
    statusMessage = prefs.getString(prefsKeyStatus);
    lastLat = prefs.getDouble(prefsKeyLat);
    lastLng = prefs.getDouble(prefsKeyLng);
    lastSpeed = prefs.getDouble(prefsKeySpeed);

    tripFromStopId = prefs.getString(prefsKeyTripFrom);
    tripToStopId = prefs.getString(prefsKeyTripTo);
    draftRouteHint = prefs.getString(prefsKeyRouteHint);
    final restoredRoute = activeRoute;
    if (restoredRoute == null) {
      tripFromStopId = null;
      tripToStopId = null;
    } else {
      if (tripFromStopId == null ||
          !restoredRoute.stopIds.contains(tripFromStopId!)) {
        tripFromStopId = restoredRoute.stopIds.isEmpty
            ? null
            : restoredRoute.stopIds.first;
      }
      if (tripToStopId == null ||
          !restoredRoute.stopIds.contains(tripToStopId!)) {
        tripToStopId = restoredRoute.stopIds.length < 2
            ? null
            : restoredRoute.stopIds.last;
      }
      final fromIdx = restoredRoute.stopIds.indexOf(tripFromStopId!);
      final toIdx = restoredRoute.stopIds.indexOf(tripToStopId!);
      if (fromIdx < 0 || toIdx < 0 || fromIdx >= toIdx) {
        tripFromStopId = restoredRoute.stopIds.isEmpty
            ? null
            : restoredRoute.stopIds.first;
        tripToStopId = restoredRoute.stopIds.length < 2
            ? null
            : restoredRoute.stopIds.last;
      }
    }

    final updateMs = prefs.getInt(prefsKeyUpdateMs);
    lastUpdate =
        updateMs == null ? null : DateTime.fromMillisecondsSinceEpoch(updateMs);

    autoStopEnabled = prefs.getBool(prefsKeyAutoStop) ?? true;
    _segmentStartStopId = selectedStopId;
    _segmentEndStopId = null;
    _segmentProgress = null;
    _distanceToNextStopKm = null;
    _remainingRouteKm = null;
    _snappedLat = null;
    _snappedLng = null;
    _effectiveSpeedKmh = null;

    if (activeRoute == null || busId == null) {
      tracking = false;
    }

    // Auto-expire sessions from a previous day's service window.
    if (tracking && lastUpdate != null) {
      final now = DateTime.now();
      DateTime currentServiceStart;
      if (now.hour < 5) {
        currentServiceStart = DateTime(now.year, now.month, now.day - 1, 5);
      } else {
        currentServiceStart = DateTime(now.year, now.month, now.day, 5);
      }

      if (lastUpdate!.isBefore(currentServiceStart)) {
        tracking = false;
        statusMessage = 'Previous session expired (new day)';
        if (busId != null) {
          try {
            await _fs.deactivateBus(busId!);
          } catch (_) {}
          busId = null;
        }
        await _clearPersistedSession();
        return;
      }
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKeyTracking, tracking);

    if (selectedRoute != null) {
      await prefs.setString(prefsKeyRoute, selectedRoute!);
    } else {
      await prefs.remove(prefsKeyRoute);
    }

    if (selectedStopId != null) {
      await prefs.setString(prefsKeyStopId, selectedStopId!);
    } else {
      await prefs.remove(prefsKeyStopId);
    }

    if (tripFromStopId != null) {
      await prefs.setString(prefsKeyTripFrom, tripFromStopId!);
    } else {
      await prefs.remove(prefsKeyTripFrom);
    }

    if (tripToStopId != null) {
      await prefs.setString(prefsKeyTripTo, tripToStopId!);
    } else {
      await prefs.remove(prefsKeyTripTo);
    }

    if (draftRouteHint != null) {
      await prefs.setString(prefsKeyRouteHint, draftRouteHint!);
    } else {
      await prefs.remove(prefsKeyRouteHint);
    }

    if (selectedBusType != null) {
      await prefs.setString(prefsKeyBusType, selectedBusType!.name);
    } else {
      await prefs.remove(prefsKeyBusType);
    }

    await prefs.setInt(prefsKeyCrowd, crowd.index);
    await prefs.setBool(prefsKeyAutoStop, autoStopEnabled);

    if (busId != null) {
      await prefs.setString(prefsKeyBusId, busId!);
    } else {
      await prefs.remove(prefsKeyBusId);
    }

    if (statusMessage != null) {
      await prefs.setString(prefsKeyStatus, statusMessage!);
    } else {
      await prefs.remove(prefsKeyStatus);
    }

    if (lastLat != null) {
      await prefs.setDouble(prefsKeyLat, lastLat!);
    } else {
      await prefs.remove(prefsKeyLat);
    }

    if (lastLng != null) {
      await prefs.setDouble(prefsKeyLng, lastLng!);
    } else {
      await prefs.remove(prefsKeyLng);
    }

    if (lastSpeed != null) {
      await prefs.setDouble(prefsKeySpeed, lastSpeed!);
    } else {
      await prefs.remove(prefsKeySpeed);
    }

    if (lastUpdate != null) {
      await prefs.setInt(prefsKeyUpdateMs, lastUpdate!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(prefsKeyUpdateMs);
    }
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKeyTracking);
    await prefs.remove(prefsKeyRoute);
    await prefs.remove(prefsKeyStopId);
    await prefs.remove(prefsKeyBusType);
    await prefs.remove(prefsKeyCrowd);
    await prefs.remove(prefsKeyBusId);
    await prefs.remove(prefsKeyStatus);
    await prefs.remove(prefsKeyLat);
    await prefs.remove(prefsKeyLng);
    await prefs.remove(prefsKeySpeed);
    await prefs.remove(prefsKeyUpdateMs);
    await prefs.remove(prefsKeyAutoStop);
    await prefs.remove(prefsKeyTripFrom);
    await prefs.remove(prefsKeyTripTo);
    await prefs.remove(prefsKeyRouteHint);
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t).inSeconds;
    if (diff < 10) return 'just now';
    if (diff < 60) return '${diff}s ago';
    return '${diff ~/ 60}m ago';
  }
}

/// Result of [ConductorTrackingService.startTracking].
class StartTrackingResult {
  final bool ok;
  final String? title;
  final String? message;
  final BusRoute? route;
  final String? detectedStopName;
  final double? detectedDistanceKm;

  const StartTrackingResult.ok()
      : ok = true,
        title = null,
        message = null,
        route = null,
        detectedStopName = null,
        detectedDistanceKm = null;

  const StartTrackingResult.failure({
    required this.title,
    required this.message,
    this.route,
    this.detectedStopName,
    this.detectedDistanceKm,
  }) : ok = false;
}
