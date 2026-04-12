import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/vizag_data.dart';
import '../models/bus.dart';
import 'firestore_service.dart';
import 'location_service.dart';

class ConductorTrackingService extends ChangeNotifier {
  ConductorTrackingService._();

  static final ConductorTrackingService instance = ConductorTrackingService._();

  static const prefsKeyTracking = 'conductor_tracking';
  static const prefsKeyRoute = 'conductor_route';
  static const prefsKeyStopId = 'conductor_stop_id';
  static const prefsKeyBusType = 'conductor_bus_type';
  static const prefsKeyPlate = 'conductor_plate'; // deprecated
  static const prefsKeyCrowd = 'conductor_crowd';
  static const prefsKeyBusId = 'conductor_bus_id';
  static const prefsKeyStatus = 'conductor_status';
  static const prefsKeyLat = 'conductor_last_lat';
  static const prefsKeyLng = 'conductor_last_lng';
  static const prefsKeySpeed = 'conductor_last_speed';
  static const prefsKeyUpdateMs = 'conductor_last_update_ms';
  static const prefsKeyAutoStop = 'conductor_auto_stop';
  static const double autoStopArrivalRadiusKm = 0.18;

  final FirestoreService _fs = FirestoreService();

  StreamSubscription<Position>? _positionSub;
  bool _initialized = false;
  bool _starting = false;

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

  BusRoute? get activeRoute {
    if (selectedRoute == null) return null;
    return VizagRoutes.byNumber(selectedRoute!);
  }

  String get normalizedPlate => ''; // Deprecated: bus type no longer uses plate

  int get currentStopIndex {
    final route = activeRoute;
    if (route == null || selectedStopId == null) return -1;
    return route.stopIds.indexOf(selectedStopId!);
  }

  String? get nextStopId {
    final route = activeRoute;
    final index = currentStopIndex;
    if (route == null || index < 0 || index >= route.stopIds.length - 1) {
      return null;
    }
    return route.stopIds[index + 1];
  }

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
    selectedRoute = route.number;
    selectedStopId = route.stopIds.isNotEmpty ? route.stopIds.first : null;
    selectedBusType ??= _defaultBusTypeForRoute(route);
    statusMessage ??= 'Trip details saved';
    await _persistSession();
    notifyListeners();
  }

  Future<void> setDraftBusType(BusType type) async {
    selectedBusType = type;
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
    await _persistSession();
    notifyListeners();
  }

  Future<bool> startTracking() async {
    if (_starting) return tracking;
    _starting = true;
    try {
      if (activeRoute == null ||
          selectedBusType == null ||
          selectedStopId == null) {
        statusMessage = 'Missing trip details';
        await _persistSession();
        notifyListeners();
        return false;
      }

      busId ??= _buildBusId();
      tracking = true;
      statusMessage = 'Starting live tracking...';
      await _persistSession();
      notifyListeners();

      final permission = await _ensurePermission();
      if (!permission) {
        tracking = false;
        statusMessage = 'Location permission is required for live tracking';
        await _persistSession();
        notifyListeners();
        return false;
      }

      await _startPositionStream();
      await syncNow();
      return true;
    } finally {
      _starting = false;
    }
  }

  Future<void> syncNow() async {
    if (!tracking ||
        activeRoute == null ||
        selectedStopId == null ||
        busId == null) {
      return;
    }

    final fallbackStop = VizagStops.get(selectedStopId!);
    double lat = fallbackStop?.lat ?? 0;
    double lng = fallbackStop?.lng ?? 0;
    double speed = 0;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lat = pos.latitude;
      lng = pos.longitude;
      speed = (pos.speed * 3.6).clamp(0.0, 120.0);
      _advanceStopFromLocation(lat: lat, lng: lng);
    } catch (_) {
      // Keep fallback stop coordinates when the live fix fails.
    }

    await _pushUpdate(lat: lat, lng: lng, speed: speed);
  }

  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    if (busId != null) {
      await _fs.deactivateBus(busId!);
    }

    tracking = false;
    busId = null;
    lastLat = null;
    lastLng = null;
    lastSpeed = null;
    lastUpdate = null;
    statusMessage = 'Trip ended';
    await _clearPersistedSession();
    notifyListeners();
  }

  Future<void> _startPositionStream() async {
    await _positionSub?.cancel();
    final settings = _buildLocationSettings();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      if (!tracking ||
          activeRoute == null ||
          selectedStopId == null ||
          busId == null) {
        return;
      }

      final lat = position.latitude;
      final lng = position.longitude;
      final speed = (position.speed * 3.6).clamp(0.0, 120.0);
      _advanceStopFromLocation(lat: lat, lng: lng);
      await _pushUpdate(lat: lat, lng: lng, speed: speed);
    }, onError: (Object error) async {
      statusMessage = 'Location stream error: $error';
      await _persistSession();
      notifyListeners();
    });
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 20,
        intervalDuration: const Duration(seconds: 12),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Vizag Bus Live tracking',
          notificationText: 'Conductor trip is running in the background.',
          enableWakeLock: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
  }

  Future<void> _pushUpdate({
    required double lat,
    required double lng,
    required double speed,
  }) async {
    if (activeRoute == null || selectedStopId == null || busId == null) return;

    await _fs.pushConductorLocation(
      busId: busId!,
      routeKey: activeRoute!.routeId,
      routeNumber: activeRoute!.number,
      busPlateNumber: '', // No longer using plate
      lat: lat,
      lng: lng,
      speedKmh: speed,
      crowd: crowd,
      currentStopId: selectedStopId!,
      nextStopId: nextStopId,
      busType: resolvedBusType,
    );

    lastLat = lat;
    lastLng = lng;
    lastSpeed = speed;
    lastUpdate = DateTime.now();
    statusMessage = 'Tracking live at ${_timeAgo(lastUpdate!)}';
    await _persistSession();
    notifyListeners();
  }

  void _advanceStopFromLocation({
    required double lat,
    required double lng,
  }) {
    if (!autoStopEnabled) return;

    final route = activeRoute;
    final currentIndex = currentStopIndex;
    if (route == null || currentIndex < 0) return;

    final lastIndex = route.stopIds.length - 1;
    var bestIndex = currentIndex;
    var bestDistance = double.infinity;

    for (var i = currentIndex; i <= currentIndex + 2 && i <= lastIndex; i++) {
      final stop = VizagStops.get(route.stopIds[i]);
      if (stop == null) continue;
      final distance = LocationService.distanceKm(lat, lng, stop.lat, stop.lng);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    if (bestIndex > currentIndex && bestDistance <= autoStopArrivalRadiusKm) {
      selectedStopId = route.stopIds[bestIndex];
      statusMessage =
          'Auto-detected stop: ${VizagStops.get(selectedStopId!)?.name ?? selectedStopId!}';
    }
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

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    tracking = prefs.getBool(prefsKeyTracking) ?? false;
    selectedRoute = prefs.getString(prefsKeyRoute);
    selectedStopId = prefs.getString(prefsKeyStopId);
    selectedBusType = _busTypeFromName(prefs.getString(prefsKeyBusType)) ??
        _defaultBusTypeForRoute(activeRoute);

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

    if (activeRoute == null ||
        selectedStopId == null ||
        selectedBusType == null) {
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

    // Clean up old plate preference
    await prefs.remove(prefsKeyPlate);

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
    await prefs.remove(prefsKeyPlate); // Also clean up deprecated plate key
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

  String _buildBusId() {
    final routeToken = (selectedRoute ?? 'route')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();
    final typeToken = resolvedBusType.name;
    final nonce = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'bus_${routeToken}_${typeToken}_$nonce';
  }

  BusType? _defaultBusTypeForRoute(BusRoute? route) {
    if (route == null) return null;
    return switch (route.busType) {
      BusType.redOrdinary => BusType.redOrdinary,
      BusType.ultraDeluxe => BusType.ultraDeluxe,
      BusType.metro || BusType.metroExpress || BusType.greenCity => BusType.metro,
      BusType.palleVelugu || BusType.blueExpress => BusType.palleVelugu,
    };
  }

  BusType? _busTypeFromName(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in BusType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
