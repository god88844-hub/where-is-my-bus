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
  FirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // --- NEW METHOD TO FIX HOME_SCREEN ERROR ---
  /// Updates the current user's role to 'conductor' in Firestore.
  Future<void> promoteToConductor() async {
    try {
      final uid = await ensureUserId();
      await _db.collection('users').doc(uid).set({
        'role': 'conductor',
        'last_seen_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('User $uid promoted to conductor');
    } catch (e) {
      debugPrint('FirestoreService.promoteToConductor failed: $e');
      rethrow;
    }
  }

  Future<String> ensureUserId() async {
    final current = _auth.currentUser;
    if (current != null) {
      await _ensureUserProfile(current);
      return current.uid;
    }
    final cred = await _auth.signInAnonymously();
    final user = cred.user!;
    await _ensureUserProfile(user);
    return user.uid;
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
    BusType? busType,
    String? writerUid,
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
      'eta': 0,
      'crowd': crowd.index,
      'source': BusDataSource.beacon.index,
      'writer_uid': writerUid,
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
    BusType? busType,
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
      busType: busType,
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
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              final ts = d['ts'] as Timestamp?;
              final rawRoute = d['route'] as String? ?? '?';
              final routeKey = d['route_key'] as String? ?? rawRoute;
              final route = VizagRoutes.byRouteId(routeKey) ??
                  VizagRoutes.byNumber(rawRoute);
              return LiveBus(
                id: doc.id,
                routeKey: routeKey,
                routeNumber: route?.number ?? rawRoute,
                busType: _busTypeFromValue(d['bus_type']),
                busPlateNumber: d['bus_plate'] as String? ?? '',
                currentStopId: d['current_stop'] as String? ?? '',
                lat: (d['lat'] as num?)?.toDouble() ?? 0,
                lng: (d['lng'] as num?)?.toDouble() ?? 0,
                speedKmh: (d['speed'] as num?)?.toDouble() ?? 0,
                etaToNextStopMins: (d['eta'] as num?)?.toInt() ?? 0,
                nextStopId: d['next_stop'] as String? ?? '',
                crowd: _crowdFromValue(d['crowd']),
                source: _sourceFromValue(d['source']),
                lastUpdated: ts?.toDate() ?? DateTime.now(),
              );
            }).toList());
  }

  BusType? _busTypeFromValue(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    for (final type in BusType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  BusCrowd _crowdFromValue(dynamic value) {
    final index = (value as num?)?.toInt() ?? BusCrowd.moderate.index;
    return BusCrowd.values[index.clamp(0, BusCrowd.values.length - 1)];
  }

  BusDataSource _sourceFromValue(dynamic value) {
    final index = (value as num?)?.toInt() ?? BusDataSource.beacon.index;
    return BusDataSource
        .values[index.clamp(0, BusDataSource.values.length - 1)];
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
