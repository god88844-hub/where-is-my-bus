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

  test('searchRoutes keeps the route visible after a bus passes the stop', () {
    final provider = AppProvider();
    final route = VizagRoutes.byRouteId('300C-R')!;
    final from = VizagStops.resolve('sabbavaram');
    final to = VizagStops.resolve('rtc_complex');

    provider.debugSetBuses([
      LiveBus(
        id: 'bus_300c_reverse',
        routeKey: route.routeId,
        routeNumber: route.number,
        currentStopId: 'gopalapatnam',
        nextStopId: 'simhachalam_railway_station',
        segmentStartStopId: 'gopalapatnam',
        segmentEndStopId: 'simhachalam_railway_station',
        lat: 17.7773,
        lng: 83.2135,
        lastUpdated: DateTime.now(),
        source: BusDataSource.beacon,
      ),
    ]);

    final results = provider.searchRoutes(from, to);
    final routeResult =
        results.firstWhere((result) => result.route.routeId == route.routeId);

    expect(routeResult.liveBuses, isEmpty);
    expect(routeResult.nextBusEtaMins, route.frequencyMins);
  });

  test('searchConnectingRoutes suggests one-transfer bus options', () {
    final provider = AppProvider();
    final from = VizagStops.resolve('railway_station_vsp');
    final to = VizagStops.resolve('1_town');

    final directResults = provider.searchRoutes(from, to);
    final connectingResults = provider.searchConnectingRoutes(from, to);

    expect(directResults, isEmpty);
    expect(connectingResults, isNotEmpty);

    final best = connectingResults.first;
    expect(best.firstLeg.fromStop.id, from.id);
    expect(best.secondLeg.toStop.id, to.id);
    expect(best.transferStop.id, isNot(from.id));
    expect(best.transferStop.id, isNot(to.id));
    expect(best.firstLeg.route.routeId, isNot(best.secondLeg.route.routeId));
    expect(best.firstLeg.route.number, isNot(best.secondLeg.route.number));
    expect(best.totalEtaMins, greaterThan(best.firstLeg.rideMins));
  });
}
