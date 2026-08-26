// Regression tests for the conductor reverse-trip flow.
//
// Reported bug: pick 28K in staff mode, tap the reverse button
// (Kothavalasa -> RK Beach), press Start Tracking and the app failed with
// "Route id does not match". After dismissing the error the reverse button
// vanished until the route was typed again.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/firebase_options.dart';
import 'package:vizag_bus_live/services/conductor_tracking_service.dart';

/// Resolved lazily per call: touching the singleton before
/// Firebase.initializeApp (setUpAll) would construct Firestore without a
/// default app and crash at load time.
ConductorTrackingService get _service => ConductorTrackingService.instance;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') {
        rethrow;
      }
    }
  });

  setUp(() {
    _service.tracking = false;
    _service.selectedStopId = null;
    _service.tripFromStopId = null;
    _service.tripToStopId = null;
    _service.lastLat = null;
    _service.lastLng = null;
    _service.draftRouteHint = null;
    _service.selectedRoute = null;
  });

  tearDown(() async {
    await _service.clearDraftRoute();
  });

  test('28K data is a linked forward/return pair', () {
    final forward = VizagRoutes.byRouteId('28K');
    expect(forward, isNotNull);
    expect(forward!.returnRouteNumber, '28K-R');
    final back = VizagRoutes.byRouteId('28K-R');
    expect(back, isNotNull);
    expect(back!.returnRouteNumber, '28K');
    expect(
      forward.stopIds.reversed.toList(),
      back.stopIds,
    );
  });

  test('pick 28K, reverse direction, trip still resolves (28K-R)', () async {
    final forward = VizagRoutes.byRouteId('28K')!;
    await _service.setDraftRoute(forward);
    expect(_service.resolveTripRoute()!.routeId, '28K');

    await _service.reverseDirection();

    expect(_service.selectedRoute, '28K-R');
    // The public number does not change on the return trip — only the
    // internal geometry corridor flips.
    expect(_service.draftRouteHint, '28K');
    expect(_service.publishedRouteNumber, '28K');

    final resolved = _service.resolveTripRoute();
    expect(resolved, isNotNull);
    expect(resolved!.routeId, '28K-R');
    expect(
      resolved.stopIds.indexOf(_service.tripFromStopId!),
      lessThan(resolved.stopIds.indexOf(_service.tripToStopId!)),
    );
  });

  test('stale hint self-corrects when From - To was reversed', () async {
    // Simulates a session drafted before the hint-follow fix (or restored
    // from an older app build): the hint still says 28K while the picked
    // range is Kothavalasa -> RK Beach. Resolution must switch to the
    // return direction instead of failing with "route id does not match".
    final returnRoute = VizagRoutes.byRouteId('28K-R')!;
    await _service.setDraftRouteHint('28K');
    await _service.setDraftTripStops(
      fromStopId: returnRoute.stopIds.first,
      toStopId: returnRoute.stopIds.last,
    );

    final resolved = _service.resolveTripRoute();
    expect(resolved, isNotNull);
    expect(resolved!.routeId, '28K-R');
    // The display label is never rewritten by resolution.
    expect(_service.draftRouteHint, '28K');
  });

  test('brand-new route number attaches to the From - To trip', () async {
    // 99B does not exist in the database — it must still be accepted as
    // the public number while the geometry comes from the network.
    await _service.setDraftRouteHint('99B');
    await _service.setDraftTripStops(
      fromStopId: 'pendurthi',
      toStopId: 'kothavalasa_jn',
    );

    final resolved = _service.resolveTripRoute();
    expect(resolved, isNotNull);
    expect(
      resolved!.stopIds.indexOf('pendurthi'),
      lessThan(resolved.stopIds.indexOf('kothavalasa_jn')),
    );
    expect(_service.publishedRouteNumber, '99B');
  });

  test('no route number means a numberless From - To trip', () async {
    await _service.setDraftRouteHint(null);
    await _service.setDraftTripStops(
      fromStopId: 'pendurthi',
      toStopId: 'kothavalasa_jn',
    );

    expect(_service.resolveTripRoute(), isNotNull);
    expect(_service.publishedRouteNumber, isNull);
  });

  test('reverse twice restores the original direction', () async {
    await _service.setDraftRoute(VizagRoutes.byRouteId('28K')!);

    await _service.reverseDirection();
    expect(_service.selectedRoute, '28K-R');

    await _service.reverseDirection();
    expect(_service.selectedRoute, '28K');
    expect(_service.draftRouteHint, '28K');
    final resolved = _service.resolveTripRoute()!;
    expect(
      resolved.stopIds.indexOf(_service.tripFromStopId!),
      lessThan(resolved.stopIds.indexOf(_service.tripToStopId!)),
    );
  });

  test('unusable hint falls back to a network route that serves the pair',
      () async {
    await _service.setDraftRouteHint('10K');
    await _service.setDraftTripStops(
      fromStopId: 'pendurthi',
      toStopId: 'kothavalasa_jn',
    );

    final resolved = _service.resolveTripRoute();
    expect(resolved, isNotNull);
    expect(
      resolved!.stopIds.indexOf('pendurthi'),
      lessThan(resolved.stopIds.indexOf('kothavalasa_jn')),
    );
  });
}
