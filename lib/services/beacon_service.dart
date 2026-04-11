import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';

class BeaconService {
  BeaconService(this._fs);

  final FirestoreService _fs;
  Timer? _timer;
  bool _active = false;
  String? _sessionId;
  String? _routeNumber;
  Position? _lastPos;

  bool get isActive => _active;
  String? get activeRoute => _routeNumber;

  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> start({required String routeNumber}) async {
    if (!await requestPermission()) {
      throw Exception('Location permission denied');
    }
    _routeNumber = routeNumber;
    _sessionId = await _fs.startPassengerSession(routeNumber: routeNumber);
    _active = true;
    await _push();
    _timer = Timer.periodic(
      Duration(seconds: AppConstants.beaconIntervalSec),
      (_) => _push(),
    );
  }

  Future<void> _push() async {
    if (!_active || _sessionId == null || _routeNumber == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final speed = (pos.speed * 3.6).clamp(0.0, 120.0);
      _lastPos = pos;
      await _fs.updatePassengerHeartbeat(
        sessionId: _sessionId!,
        routeNumber: _routeNumber!,
        lat: pos.latitude,
        lng: pos.longitude,
        speedKmh: speed,
      );
      if (speed >= AppConstants.minSpeedKmh) {
        await _fs.submitPassengerReport(
          sessionId: _sessionId!,
          routeNumber: _routeNumber!,
          lat: pos.latitude,
          lng: pos.longitude,
          speedKmh: speed,
        );
      }
    } catch (_) {
      if (_lastPos != null) {
        await _fs.updatePassengerHeartbeat(
          sessionId: _sessionId!,
          routeNumber: _routeNumber!,
          lat: _lastPos!.latitude,
          lng: _lastPos!.longitude,
          speedKmh: 0,
        );
      }
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _active = false;
    if (_sessionId != null) {
      await _fs.endPassengerSession(_sessionId!);
    }
    _sessionId = null;
    _routeNumber = null;
  }
}
