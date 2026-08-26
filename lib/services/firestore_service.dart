import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/vizag_data.dart';
import '../models/bus.dart';

class StaffAccessStatus {
  const StaffAccessStatus({
    required this.uid,
    required this.role,
  });

  final String uid;
  final String role;

  bool get isConductor => role == 'conductor' || role == 'admin';
}

class FirestoreService {
  /// Username of the shared depot staff account. Not a secret — the
  /// password is. Conductors sign in with this account, so approval is
  /// granted ONCE to the account (users/{staffUid}.role = conductor) and
  /// every device that knows the password becomes a conductor. Rotate the
  /// password from the Firebase console (Authentication -> Users) to revoke
  /// access; no app release, no per-device approval.
  static const String staffEmail = 'staff@vizagbus.in';

  FirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  String? _fallbackUid;

  Future<String> ensureUserId() async {
    final current = _auth.currentUser;
    if (current != null) {
      await _ensureUserProfile(current);
      return current.uid;
    }
    try {
      final cred = await _auth.signInAnonymously();
      final user = cred.user!;
      await _ensureUserProfile(user);
      return user.uid;
    } catch (e) {
      debugPrint('FirestoreService.ensureUserId anonymous sign-in failed: $e');
      _fallbackUid ??=
          'guest_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      try {
        await _db.collection('users').doc(_fallbackUid).set({
          'uid': _fallbackUid,
          'role': 'passenger',
          'anonymous': true,
          'auth_provider': 'fallback_guest',
          'created_at': FieldValue.serverTimestamp(),
          'last_seen_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (fallbackError) {
        debugPrint(
          'FirestoreService.ensureUserId fallback profile write failed: $fallbackError',
        );
      }
      return _fallbackUid!;
    }
  }

  Future<void> _ensureUserProfile(User user) async {
    try {
      final ref = _db.collection('users').doc(user.uid);
      final snap = await ref.get();

      final data = <String, dynamic>{
        'uid': user.uid,
        'anonymous': user.isAnonymous,
        'last_seen_at': FieldValue.serverTimestamp(),
      };

      if (!snap.exists) {
        data['role'] = 'passenger';
        data['created_at'] = FieldValue.serverTimestamp();
      }

      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService._ensureUserProfile failed: $e');
    }
  }

  Future<StaffAccessStatus> getStaffAccessStatus() async {
    final uid = await ensureUserId();
    final snap = await _db.collection('users').doc(uid).get();
    final role = snap.data()?['role'] as String? ?? 'passenger';
    return StaffAccessStatus(uid: uid, role: role);
  }

  /// Signs the device in with the shared staff account. The entered
  /// passcode is the Firebase Auth password — verification, brute-force
  /// protection and revocation are all handled by Firebase Auth. Signing
  /// in as the staff account makes the device a conductor immediately:
  /// no approval step anywhere.
  /// Throws [FirebaseAuthException] on a wrong password or a missing
  /// account (first-time setup).
  Future<StaffAccessStatus> signInAsStaff(String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: staffEmail,
      password: password,
    );
    final user = cred.user!;
    await _ensureUserProfile(user);
    // Password holders are conductors by definition — the security rules
    // grant live_buses writes to this account's email directly.
    return StaffAccessStatus(uid: user.uid, role: 'conductor');
  }

  Future<StaffAccessStatus> requireConductorAccess() async {
    final status = await getStaffAccessStatus();
    if (!status.isConductor) {
      throw StateError(
        'This Firebase user is not approved for live conductor writes. '
        'Set users/${status.uid}.role to conductor or admin in Firestore.',
      );
    }
    return status;
  }

  Future<void> upsertLiveBus({
    required String busId,
    required String routeKey,
    required String routeNumber,
    required String busPlateNumber,
    required double lat,
    required double lng,
    required double speedKmh,
    required BusCrowd crowd,
    required String currentStopId,
    String? nextStopId,
    String? segmentStartStopId,
    String? segmentEndStopId,
    double? segmentProgress,
    double? distanceToNextStopKm,
    double? remainingRouteKm,
    double? snappedLat,
    double? snappedLng,
    double? effectiveSpeedKmh,
    int? etaToNextStopMins,
    BusType? busType,
    String? writerUid,
    String? tripFromStopId,
    String? tripToStopId,
  }) async {
    await _db.collection('live_buses').doc(busId).set({
      'bus_id': busId,
      'route_key': routeKey,
      'route': routeNumber,
      'bus_type': (busType ??
              VizagRoutes.byRouteId(routeKey)?.busType ??
              VizagRoutes.byNumber(routeNumber)?.busType ??
              BusType.redOrdinary)
          .name,
      'bus_plate': busPlateNumber,
      'current_stop': currentStopId,
      'next_stop': nextStopId ?? '',
      'lat': lat,
      'lng': lng,
      'speed': speedKmh,
      'eta': etaToNextStopMins ?? 0,
      'segment_start_stop': segmentStartStopId ?? currentStopId,
      'segment_end_stop': segmentEndStopId ?? nextStopId ?? '',
      'segment_progress': segmentProgress,
      'distance_to_next_stop_km': distanceToNextStopKm,
      'remaining_route_km': remainingRouteKm,
      'snapped_lat': snappedLat,
      'snapped_lng': snappedLng,
      'effective_speed_kmh': effectiveSpeedKmh,
      'crowd': crowd.index,
      'source': BusDataSource.beacon.index,
      'writer_uid': writerUid,
      'trip_from_stop': tripFromStopId ?? '',
      'trip_to_stop': tripToStopId ?? '',
      'ts': FieldValue.serverTimestamp(),
      'active': true,
    }, SetOptions(merge: true));
  }

  Future<void> pushConductorLocation({
    required String busId,
    required String routeKey,
    required String routeNumber,
    required String busPlateNumber,
    required double lat,
    required double lng,
    required double speedKmh,
    required BusCrowd crowd,
    required String currentStopId,
    String? nextStopId,
    String? segmentStartStopId,
    String? segmentEndStopId,
    double? segmentProgress,
    double? distanceToNextStopKm,
    double? remainingRouteKm,
    double? snappedLat,
    double? snappedLng,
    double? effectiveSpeedKmh,
    int? etaToNextStopMins,
    BusType? busType,
    String? tripFromStopId,
    String? tripToStopId,
  }) async {
    final uid = await ensureUserId();
    await upsertLiveBus(
      busId: busId,
      routeKey: routeKey,
      routeNumber: routeNumber,
      busPlateNumber: busPlateNumber,
      lat: lat,
      lng: lng,
      speedKmh: speedKmh,
      crowd: crowd,
      currentStopId: currentStopId,
      nextStopId: nextStopId,
      segmentStartStopId: segmentStartStopId,
      segmentEndStopId: segmentEndStopId,
      segmentProgress: segmentProgress,
      distanceToNextStopKm: distanceToNextStopKm,
      remainingRouteKm: remainingRouteKm,
      snappedLat: snappedLat,
      snappedLng: snappedLng,
      effectiveSpeedKmh: effectiveSpeedKmh,
      etaToNextStopMins: etaToNextStopMins,
      busType: busType,
      tripFromStopId: tripFromStopId,
      tripToStopId: tripToStopId,
      writerUid: uid,
    );
  }

  Future<void> deactivateBus(String busId) async {
    await _db.collection('live_buses').doc(busId).update({
      'active': false,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<LiveBus>> liveBusStream() {
    return _db
        .collection('live_buses')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final buses = <LiveBus>[];

      for (final doc in snap.docs) {
        try {
          final d = doc.data();
          // 'route' is the conductor-typed display number — publish it
          // VERBATIM. The corridor (route_key) is internal GPS geometry and
          // its number must never replace what the conductor typed. Legacy
          // docs missing the field fall back to the corridor's number.
          final published = d['route']?.toString();
          final routeKey = _stringValue(
            d['route_key'],
            fallback: published ?? '?',
          );
          final route = VizagRoutes.byRouteId(routeKey) ??
              VizagRoutes.byNumber(published ?? '?');

          buses.add(
            LiveBus(
              id: doc.id,
              routeKey: routeKey,
              routeNumber: published ?? route?.number ?? '?',
              busType: _busTypeFromValue(d['bus_type']),
              busPlateNumber: _stringValue(d['bus_plate']),
              currentStopId: _stringValue(d['current_stop']),
              lat: _doubleValue(d['lat']),
              lng: _doubleValue(d['lng']),
              speedKmh: _doubleValue(d['speed']),
              etaToNextStopMins: _intValue(d['eta']),
              nextStopId: _stringValue(d['next_stop']),
              segmentStartStopId: _nullableStringValue(d['segment_start_stop']),
              segmentEndStopId: _nullableStringValue(d['segment_end_stop']),
              segmentProgress: _nullableDoubleValue(d['segment_progress']),
              distanceToNextStopKm:
                  _nullableDoubleValue(d['distance_to_next_stop_km']),
              remainingRouteKm:
                  _nullableDoubleValue(d['remaining_route_km']),
              snappedLat: _nullableDoubleValue(d['snapped_lat']),
              snappedLng: _nullableDoubleValue(d['snapped_lng']),
              effectiveSpeedKmh:
                  _nullableDoubleValue(d['effective_speed_kmh']),
              crowd: _crowdFromValue(d['crowd']),
              source: _sourceFromValue(d['source']),
              tripFromStopId: _nullableStringValue(d['trip_from_stop']),
              tripToStopId: _nullableStringValue(d['trip_to_stop']),
              lastUpdated: _dateTimeValue(d['ts']),
            ),
          );
        } catch (e) {
          debugPrint(
            'FirestoreService.liveBusStream skipped malformed doc ${doc.id}: $e',
          );
        }
      }

      return buses;
    });
  }

  BusType? _busTypeFromValue(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    for (final type in BusType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  BusCrowd _crowdFromValue(dynamic value) {
    if (value is String) {
      for (final crowd in BusCrowd.values) {
        if (crowd.name == value) return crowd;
      }
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return BusCrowd.values[parsed.clamp(0, BusCrowd.values.length - 1)];
      }
    }
    final index = (value as num?)?.toInt() ?? BusCrowd.moderate.index;
    return BusCrowd.values[index.clamp(0, BusCrowd.values.length - 1)];
  }

  BusDataSource _sourceFromValue(dynamic value) {
    if (value is String) {
      for (final source in BusDataSource.values) {
        if (source.name == value) return source;
      }
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return BusDataSource
            .values[parsed.clamp(0, BusDataSource.values.length - 1)];
      }
    }
    final index = (value as num?)?.toInt() ?? BusDataSource.beacon.index;
    return BusDataSource
        .values[index.clamp(0, BusDataSource.values.length - 1)];
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  String? _nullableStringValue(dynamic value) {
    final resolved = _stringValue(value);
    return resolved.isEmpty ? null : resolved;
  }

  double _doubleValue(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? _nullableDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _dateTimeValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsedEpoch = int.tryParse(value);
      if (parsedEpoch != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsedEpoch);
      }
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Future<String> startPassengerSession({
    required String routeNumber,
  }) async {
    final uid = await ensureUserId();
    final sessionRef = _db.collection('active_sessions').doc(uid);
    await sessionRef.set({
      'session_id': uid,
      'user_id': uid,
      'role': 'passenger',
      'route': routeNumber,
      'active': true,
      'started_at': FieldValue.serverTimestamp(),
      'last_seen_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return uid;
  }

  Future<void> updatePassengerHeartbeat({
    required String sessionId,
    required String routeNumber,
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    final uid = await ensureUserId();
    await _db.collection('active_sessions').doc(sessionId).set({
      'session_id': sessionId,
      'user_id': uid,
      'role': 'passenger',
      'route': routeNumber,
      'active': true,
      'lat': lat,
      'lng': lng,
      'speed': speedKmh,
      'last_seen_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitPassengerReport({
    required String sessionId,
    required String routeNumber,
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    final uid = await ensureUserId();
    await _db.collection('passenger_reports').add({
      'session_id': sessionId,
      'user_id': uid,
      'route': routeNumber,
      'lat': lat,
      'lng': lng,
      'speed': speedKmh,
      'confidence': speedKmh >= 8 ? 0.7 : 0.3,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endPassengerSession(String sessionId) async {
    await _db.collection('active_sessions').doc(sessionId).set({
      'active': false,
      'ended_at': FieldValue.serverTimestamp(),
      'last_seen_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Passenger complaint (e.g. "bus didn't stop at my stop").
  /// Best-effort: returns false when Firestore rejects the write (rules not
  /// deployed yet) so the UI can inform the passenger.
  Future<bool> submitComplaint({
    required String type,
    String? routeNumber,
    String? stopId,
    String? busId,
    String? note,
  }) async {
    try {
      final uid = await ensureUserId();
      await _db.collection('complaints').add({
        'type': type,
        'route': routeNumber ?? '',
        'stop_id': stopId ?? '',
        'bus_id': busId ?? '',
        'note': note ?? '',
        'reporter_uid': uid,
        'ts': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('FirestoreService.submitComplaint failed: $e');
      return false;
    }
  }

  /// Emergency report (women safety / breakdown / medical / accident).
  /// Best-effort like complaints; GPS coordinates attached by the caller
  /// when available.
  Future<bool> submitEmergencyReport({
    required String type,
    String note = '',
    double? lat,
    double? lng,
  }) async {
    try {
      final uid = await ensureUserId();
      await _db.collection('emergency_reports').add({
        'type': type,
        'note': note,
        'route': '',
        'stop_id': '',
        'lat': lat,
        'lng': lng,
        'reporter_uid': uid,
        'ts': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('FirestoreService.submitEmergencyReport failed: $e');
      return false;
    }
  }

  /// Best-effort cleanup: deactivate buses not updated within [maxAgeMins].
  /// Runs on app startup so stale data from yesterday / crashed sessions
  /// doesn't keep showing as live. Silently ignores Firestore rule rejections.
  Future<void> cleanupStaleBuses({int maxAgeMins = 30}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(minutes: maxAgeMins));
      final snap = await _db
          .collection('live_buses')
          .where('active', isEqualTo: true)
          .get();

      final batch = _db.batch();
      var count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['ts'] as Timestamp?;
        if (ts == null || ts.toDate().isBefore(cutoff)) {
          batch.update(doc.reference, {
            'active': false,
            'ts': FieldValue.serverTimestamp(),
          });
          count++;
        }
      }
      if (count > 0) await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.cleanupStaleBuses failed: $e');
    }
  }
}
