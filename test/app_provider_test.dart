import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/firebase_options.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/services/app_provider.dart';

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

  test('searchRoutes keeps matching route cards even without a live bus', () {
    final provider = AppProvider();
    final from = VizagStops.resolve('gopalapatnam');
    final to = VizagStops.resolve('rtc_complex');

    final results = provider.searchRoutes(from, to);
    final routeResult =
        results.firstWhere((result) => result.route.routeId == '300C-R');

    expect(routeResult.liveBuses, isEmpty);
    expect(routeResult.nextBusEtaMins, routeResult.route.frequencyMins);
  });

  test(
      'searchRoutes keeps a tracked route visible after the bus passes the stop',
      () {
    final provider = AppProvider();
    final route = VizagRoutes.byRouteId('300C-R')!;
    final from = VizagStops.resolve('pendurthi');
    final to = VizagStops.resolve('rtc_complex');

    provider.debugSetBuses([
      LiveBus(
        id: 'bus_300c_reverse',
        routeKey: route.routeId,
        routeNumber: route.number,
        currentStopId: 'gopalapatnam',
        nextStopId: 'nad_junction',
        segmentStartStopId: 'gopalapatnam',
        segmentEndStopId: 'nad_junction',
        lat: 17.7773,
        lng: 83.2135,
        lastUpdated: DateTime.now(),
        source: BusDataSource.beacon,
      ),
    ]);

    final results = provider.searchRoutes(from, to);
    final routeResult =
        results.firstWhere((result) => result.route.routeId == route.routeId);

    expect(routeResult.liveBuses, hasLength(1));
    expect(routeResult.liveBuses.first.id, 'bus_300c_reverse');
    expect(routeResult.nextBusEtaMins, route.frequencyMins);
  });
}
