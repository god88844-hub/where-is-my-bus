import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/vizag_data.dart';
import '../models/bus.dart';

/// Ongoing "following this bus" notification.
///
/// When a passenger opens a live bus, a persistent notification shows where
/// the bus is right now and where it is heading next — visible on top of the
/// screen even after returning to the home screen (while the app is running).
class FollowBusNotification {
  FollowBusNotification._();

  static final FollowBusNotification instance = FollowBusNotification._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _activeBusId;
  bool _permissionRequested = false;

  String? get activeBusId => _activeBusId;

  static const _channelId = 'bus_follow';
  static const _notificationId = 2828;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> _ensurePermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('FollowBusNotification: permission request failed: $e');
    }
  }

  /// Start (or replace) the ongoing notification for a bus.
  Future<void> follow(LiveBus bus) async {
    await _ensureInit();
    await _ensurePermission();
    _activeBusId = bus.id;
    await _render(bus, following: true);
  }

  /// Refresh the notification content with the latest bus state.
  Future<void> updateIfFollowing(LiveBus bus) async {
    if (_activeBusId != bus.id) return;
    await _render(bus, following: true);
  }

  Future<void> stop() async {
    _activeBusId = null;
    await _plugin.cancel(_notificationId);
  }

  /// Auto-stop when the followed bus disappears or expires.
  Future<void> reconcile(List<LiveBus> buses) async {
    if (_activeBusId == null) return;
    final bus = buses.where((b) => b.id == _activeBusId).firstOrNull;
    if (bus == null || bus.isExpired) {
      await stop();
    } else {
      await updateIfFollowing(bus);
    }
  }

  Future<void> _render(LiveBus bus, {required bool following}) async {
    final currentName =
        VizagStops.resolve(bus.segmentStartIdResolved).name;
    final nextId = bus.segmentEndIdResolved;
    final nextName = nextId.isEmpty ? '' : VizagStops.resolve(nextId).name;
    final progressPct = (bus.segmentProgressResolved * 100).round();

    final title = '${bus.routeNumber} · $currentName';
    final body = nextName.isEmpty
        ? 'At $currentName · ${bus.crowdLabel}'
        : 'Next: $nextName · $progressPct% · ${bus.crowdLabel}';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Live bus tracking',
      channelDescription: 'Shows where your bus is and where it is heading',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
      styleInformation: BigTextStyleInformation(
        following ? '$body\nOpen the app and tap the bell to stop following.'
                  : body,
        contentTitle: title,
        summaryText: 'Live bus',
      ),
    );
    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(_notificationId, title, body, details);
    } catch (e) {
      debugPrint('FollowBusNotification: show failed: $e');
    }
  }
}
