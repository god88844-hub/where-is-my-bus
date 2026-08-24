import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/firebase_options.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/screens/conductor_screen.dart';
import 'package:vizag_bus_live/services/conductor_tracking_service.dart';

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

  void seedService({
    required String routeId,
    required bool tracking,
  }) {
    final service = ConductorTrackingService.instance;
    service.tracking = tracking;
    service.selectedRoute = routeId;
    service.selectedStopId = null;
    service.selectedBusType = VizagRoutes.byRouteId(routeId)?.busType;
    service.crowd = BusCrowd.moderate;
    service.busId = tracking ? 'debug_bus' : null;
    service.statusMessage = null;
    service.lastLat = null;
    service.lastLng = null;
    service.lastSpeed = null;
    service.lastUpdate = null;
    service.autoStopEnabled = true;
    final route = VizagRoutes.byRouteId(routeId);
    service.tripFromStopId = route?.stopIds.firstOrNull;
    service.tripToStopId = route?.stopIds.lastOrNull;
  }

  void resetService() {
    final service = ConductorTrackingService.instance;
    service.tracking = false;
    service.selectedRoute = null;
    service.selectedStopId = null;
    service.selectedBusType = null;
    service.busId = null;
    service.statusMessage = null;
    service.lastLat = null;
    service.lastLng = null;
    service.lastSpeed = null;
    service.lastUpdate = null;
    service.autoStopEnabled = true;
    service.tripFromStopId = null;
    service.tripToStopId = null;
  }

  setUp(resetService);
  tearDown(resetService);

  testWidgets('saved draft route keeps the clear button visible',
      (WidgetTester tester) async {
    seedService(routeId: '10K', tracking: false);

    await tester.pumpWidget(
      const MaterialApp(
        home: ConductorScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Clear route'), findsOneWidget);
  });

  testWidgets('route number search locks while tracking is active',
      (WidgetTester tester) async {
    seedService(routeId: '10K', tracking: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: ConductorScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    final routeField = tester.widget<TextField>(find.byType(TextField).first);
    expect(routeField.enabled, isFalse);
    expect(find.textContaining('Stop tracking before choosing another route'),
        findsOneWidget);
  });

  testWidgets('from-to sections are separate and pickable', (WidgetTester tester) async {
    seedService(routeId: '28K', tracking: false);
    final service = ConductorTrackingService.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: ConductorScreen(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The two sections render independently.
    expect(find.text('Route ID (optional)'), findsOneWidget);
    expect(find.text('From - To Stops'), findsOneWidget);
    expect(find.text('28K'), findsWidgets);
    expect(find.text('RK Beach'), findsWidgets);

    // Bring the From row on-screen, then tap it -> picker sheet opens.
    await tester.scrollUntilVisible(
      find.text('From'),
      120,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('From'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Pick start stop'), findsOneWidget);

    // Pick RTC Complex from 28K's own corridor.
    await tester.scrollUntilVisible(
      find.text('RTC Complex').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('RTC Complex').last);
    await tester.pumpAndSettle();

    expect(service.tripFromStopId, 'rtc_complex');
    expect(service.tripToStopId, 'kothavalasa_jn');
  });

  testWidgets('trip stops reset when the route changes', (WidgetTester tester) async {
    final service = ConductorTrackingService.instance;
    service.tripFromStopId = 'rk_beach';
    service.tripToStopId = 'kothavalasa_jn';

    final route12D = VizagRoutes.byRouteId('12D')!;
    await service.setDraftRoute(route12D);

    expect(service.tripFromStopId, 'maddilapalem');
    expect(service.tripToStopId, 'devarapalli');
  });

  test('route id is optional: From-To alone resolves a route', () async {
    final service = ConductorTrackingService.instance;
    await service.setDraftRouteHint(null);
    await service.setDraftTripStops(
      fromStopId: 'pendurthi',
      toStopId: 'kothavalasa_jn',
    );

    final resolved = service.resolveTripRoute();
    expect(resolved, isNotNull);
    expect(
      resolved!.stopIds.indexOf('pendurthi'),
      lessThan(resolved.stopIds.indexOf('kothavalasa_jn')),
    );
    // The hint narrows the resolution and must serve the range.
    await service.setDraftRouteHint('28K');
    expect(service.resolveTripRoute()!.routeId, '28K');
    // A hint that does not serve the range fails resolution.
    await service.setDraftRouteHint('10K');
    expect(service.resolveTripRoute(), isNull);
    await service.setDraftRouteHint(null);
  });
}
