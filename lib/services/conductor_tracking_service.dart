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

  Future<void> setDraftRoute(BusRoute route) async {
    if (tracking) {
      throw StateError('Stop tracking before changing the route');
    }
    selectedRoute = route.routeId;
    if (selectedStopId != null && !route.stopIds.contains(selectedStopId)) {
      selectedStopId = null;
    }
    statusMessage ??= 'Trip details saved';
    await _persistSession();
    notifyListeners();
  }

  Future<void> clearDraftRoute() async {
    if (tracking) return;
    selectedRoute = null;
    selectedStopId = null;
    _clearProgressState();
    statusMessage = 'Route selection cleared';
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
    statusMessage =
        value ? 'Auto stop detection is on' : 'Auto stop detection is off';
    if (!value) {
      _ensureManualStopSelected();
    } else if (lastLat != null && lastLng != null) {
      _advanceStopFromLocation(lat: lastLat!, lng: lastLng!);
    }
    await _persistSession();
    notifyListeners();
  }

  Future<bool> startTracking() async {
    if (_starting) return tracking;
    _starting = true;
    try {
      if (activeRoute == null) {
        statusMessage = 'Missing trip details';
        await _persistSession();
        notifyListeners();
        return false;
      }

      final permission = await _ensurePermission();
      if (!permission) {
        tracking = false;
        statusMessage = 'Location permission is required for live tracking';
        await _persistSession();
        notifyListeners();
        return false;
      }

      selectedBusType ??= activeRoute!.busType;
      busId ??= _buildBusId(activeRoute!.routeId);
      tracking = true;
      _lastCloudSyncSucceeded = true;
      _lastCloudSyncError = null;
      statusMessage = 'Starting live tracking...';
      await _resolveCurrentStopFromLocation();
      await _persistSession();
      notifyListeners();

      await _startPositionStream();
      await syncNow();
      return true;
    } finally {
      _starting = false;
    }
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
    if (nextId == null || nextId.isEmpty) {
      return 'Reached $currentName · updated ${_timeAgo(updateTime)}';
    }

    final nextName = VizagStops.get(nextId)?.name ?? nextId;
    final progress = (_segmentProgress ?? 0).clamp(0.0, 1.0);
    final progressPct = (progress * 100).round();
    final distanceLabel = _distanceToNextStopKm == null
        ? ''
        : ' · ${_distanceToNextStopKm!.toStringAsFixed(2)} km left';
    return 'Passed $currentName · $progressPct% to $nextName$distanceLabel · updated ${_timeAgo(updateTime)}';
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
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t).inSeconds;
    if (diff < 10) return 'just now';
    if (diff < 60) return '${diff}s ago';
    return '${diff ~/ 60}m ago';
  }
}
