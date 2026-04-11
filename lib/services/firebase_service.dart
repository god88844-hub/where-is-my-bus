// lib/services/firebase_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/bus.dart';
import '../utils/constants.dart';

class FirebaseService {
  FirebaseDatabase get _db => FirebaseDatabase.instance;  StreamSubscription? _sub;
  final _ctrl = StreamController<List<LiveBus>>.broadcast();

  Stream<List<LiveBus>> get stream => _ctrl.stream;

  void start() {
    _sub = _db.ref(AppConstants.busLocPath).onValue.listen((event) {
      final raw = event.snapshot.value as Map<dynamic, dynamic>?;
      if (raw == null) { _ctrl.add([]); return; }
      final buses = raw.entries
          .map((e) => LiveBus.fromMap(e.key as String, e.value as Map))
          .toList();
      _ctrl.add(buses);
    }, onError: _ctrl.addError);
  }

  void stop() { _sub?.cancel(); _ctrl.close(); }

  // ── Beacon push ──
  Future<void> pushLocation(LiveBus bus) =>
      _db.ref('${AppConstants.busLocPath}/${bus.id}').set(bus.toMap());

  Future<void> removeBus(String id) =>
      _db.ref('${AppConstants.busLocPath}/$id').remove();

  // ── Manual update (admin / fallback) ──
  Future<void> manualUpdate(LiveBus bus) =>
      _db.ref('${AppConstants.manualPath}/${bus.id}').set(bus.toMap());

  // ── Crowd report ──
  Future<void> reportCrowd(String busId, BusCrowd crowd) =>
      _db.ref('${AppConstants.reportPath}/$busId').set({
        'crowd': crowd.index,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
}
