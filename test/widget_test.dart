import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/screens/bus_journey_screen.dart';
import 'package:vizag_bus_live/widgets/shared_widgets.dart';

void main() {
  test('28K and 68K stay separate and each gets its own reverse trip', () {
    final outbound = VizagRoutes.byRouteId('28K');
    final outboundReverse = VizagRoutes.byRouteId('28K-R');
    final inbound = VizagRoutes.byRouteId('68K');
    final inboundReverse = VizagRoutes.byRouteId('68K-R');

    expect(outbound, isNotNull);
    expect(outboundReverse, isNotNull);
    expect(inbound, isNotNull);
    expect(inboundReverse, isNotNull);
    expect(outbound!.number, '28K');
    expect(inbound!.number, '68K');
    expect(outbound.returnRouteNumber, '28K-R');
    expect(outboundReverse!.returnRouteNumber, '28K');
    expect(inbound.returnRouteNumber, '68K-R');
    expect(inboundReverse!.returnRouteNumber, '68K');
    expect(outboundReverse.from, 'Kothavalasa JN');
    expect(outboundReverse.to, 'RK Beach');
    // In the Excel both 28K and 68K run RK Beach -> Kothavalasa JN, so both
    // reverses head back to RK Beach.
    expect(inboundReverse.from, 'Kothavalasa JN');
    expect(inboundReverse.to, 'RK Beach');
  });

  test(
      'primary route list keeps conductor choices free of auto-generated returns',
      () {
    final primaryRouteIds =
        VizagRoutes.primaryRoutes.map((route) => route.routeId);

    expect(primaryRouteIds, contains('28K'));
    expect(primaryRouteIds, contains('68K'));
    expect(primaryRouteIds, isNot(contains('28K-R')));
    expect(primaryRouteIds, isNot(contains('68K-R')));
  });

  test('live bus resolves the route shape by route key', () {
    final bus = LiveBus(
      id: 'demo',
      routeKey: '68K',
      routeNumber: '28K',
      currentStopId: 'kothavalasa',
      nextStopId: 'pendurthi',
      lat: 17.7,
      lng: 83.1,
      lastUpdated: DateTime.now(),
    );

    expect(bus.routeRef, isNotNull);
    expect(bus.routeRef!.routeId, '68K');
    expect(bus.routeRef!.number, '68K');
  });

  test('display identity prefers route number and plate id', () {
    final bus = LiveBus(
      id: 'demo',
      routeKey: '28K',
      routeNumber: '28K',
      busType: BusType.ultraDeluxe,
      busPlateNumber: 'AP31Z1234',
      currentStopId: 'rtc_complex',
      lat: 17.7,
      lng: 83.3,
      lastUpdated: DateTime.now(),
    );

    expect(bus.displayBusIdentity, '28K • AP31Z1234');
  });

  test(
      'approaching helper excludes buses that already passed the boarding stop',
      () {
    final bus = LiveBus(
      id: 'demo',
      routeKey: '28K',
      routeNumber: '28K',
      currentStopId: 'nad',
      nextStopId: 'baji_jn',
      lat: 17.7,
      lng: 83.3,
      lastUpdated: DateTime.now(),
    );

    expect(bus.isApproachingStop('baji_jn'), isTrue);
    expect(bus.isApproachingStop('rk_beach'), isFalse);
  });

  testWidgets('route badge renders the public route number',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RouteBadge('28K'),
        ),
      ),
    );

    expect(find.text('28K'), findsOneWidget);
  });

  testWidgets('reverse 28K journey screen keeps timeline rows visible',
      (WidgetTester tester) async {
    final route = VizagRoutes.byRouteId('28K-R')!;
    final stop = VizagStops.resolve('chinnamusidivada');
    final bus = LiveBus(
      id: 'demo_reverse_28k',
      routeKey: route.routeId,
      routeNumber: '28K',
      currentStopId: stop.id,
      nextStopId: 'sujathanagar',
      segmentStartStopId: stop.id,
      segmentEndStopId: 'sujathanagar',
      segmentProgress: 0,
      etaToNextStopMins: 5,
      remainingRouteKm: 22.9,
      lat: stop.lat,
      lng: stop.lng,
      crowd: BusCrowd.empty,
      source: BusDataSource.beacon,
      lastUpdated: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BusJourneyScreen(
          bus: bus,
          stop: stop,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // All Excel stops are owner-curated, so the full timeline is always
    // visible — no expand-to-reveal step. The list is lazy, so assert the
    // stops around the bus position.
    expect(find.text('Kothavalasa JN -> RK Beach'), findsWidgets);
    expect(find.text('Chinnamusidivada'), findsOneWidget);
    expect(find.text('Sujathanagar', skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining('Tap this live card to reveal'),
      findsNothing,
    );
  });

  testWidgets('reverse 300C journey screen keeps corridor stops visible',
      (WidgetTester tester) async {
    final route = VizagRoutes.byRouteId('300C-R')!;
    final stop = VizagStops.resolve('pendurthi');
    final bus = LiveBus(
      id: 'demo_reverse_300c',
      routeKey: route.routeId,
      routeNumber: '300C',
      currentStopId: 'gopalapatnam',
      nextStopId: 'simhachalam_railway_station',
      segmentStartStopId: 'gopalapatnam',
      segmentEndStopId: 'simhachalam_railway_station',
      segmentProgress: 0.3,
      etaToNextStopMins: 4,
      remainingRouteKm: 18.2,
      lat: stop.lat,
      lng: stop.lng,
      crowd: BusCrowd.moderate,
      source: BusDataSource.beacon,
      lastUpdated: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BusJourneyScreen(
          bus: bus,
          stop: stop,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Chodavaram -> RTC Complex'), findsWidgets);
    expect(find.text('Gopalapatnam', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Simhachalam Railway Station', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('Tap this live card to reveal'),
      findsNothing,
    );
  });
}
