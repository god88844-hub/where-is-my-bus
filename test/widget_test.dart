import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/widgets/shared_widgets.dart';

void main() {
  test('28K and 68K keep their own public numbers by direction', () {
    final outbound = VizagRoutes.byRouteId('28K');
    final inbound = VizagRoutes.byRouteId('68K');

    expect(outbound, isNotNull);
    expect(inbound, isNotNull);
    expect(outbound!.number, '28K');
    expect(inbound!.number, '68K');
    expect(outbound.returnRouteNumber, '68K');
    expect(inbound.returnRouteNumber, '28K');
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

  test('approaching helper excludes buses that already passed the boarding stop', () {
    final bus = LiveBus(
      id: 'demo',
      routeKey: '28K',
      routeNumber: '28K',
      currentStopId: 'nad_junction',
      nextStopId: 'gopalapatnam',
      lat: 17.7,
      lng: 83.3,
      lastUpdated: DateTime.now(),
    );

    expect(bus.isApproachingStop('gopalapatnam'), isTrue);
    expect(bus.isApproachingStop('rtc_complex'), isFalse);
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
}
