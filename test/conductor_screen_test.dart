import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/firebase_options.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/screens/conductor_screen.dart';
import 'package:vizag_bus_live/services/conductor_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
