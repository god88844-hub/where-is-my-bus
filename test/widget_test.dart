import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/widgets/shared_widgets.dart';

void main() {
  test('28K keeps the same public number in both directions', () {
    final outbound = VizagRoutes.byRouteId('28K');
    final inbound = VizagRoutes.byRouteId('68K');

    expect(outbound, isNotNull);
    expect(inbound, isNotNull);
    expect(outbound!.number, '28K');
    expect(inbound!.number, '28K');
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
    expect(bus.routeRef!.number, '28K');
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
