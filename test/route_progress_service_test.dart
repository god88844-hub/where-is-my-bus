import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/services/route_progress_service.dart';

void main() {
  group('RouteProgressService.snapToRoute', () {
    final route = VizagRoutes.byRouteId('10K')!;
    final stopA = VizagStops.get(route.stopIds[0])!;
    final stopB = VizagStops.get(route.stopIds[1])!;
    final stopC = VizagStops.get(route.stopIds[2])!;

    test('projects a midpoint fix onto the active segment', () {
      final lat = (stopA.lat + stopB.lat) / 2;
      final lng = (stopA.lng + stopB.lng) / 2;

      final snapshot = RouteProgressService.snapToRoute(
        route: route,
        lat: lat,
        lng: lng,
        hintCurrentStopId: stopA.id,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentStopId, stopA.id);
      expect(snapshot.nextStopId, stopB.id);
      expect(snapshot.segmentProgress, closeTo(0.5, 0.02));
      expect(snapshot.distanceToNextStopKm, greaterThan(0));
    });

    test('advances to the next segment even when a stop was skipped', () {
      final lat = stopB.lat + ((stopC.lat - stopB.lat) * 0.65);
      final lng = stopB.lng + ((stopC.lng - stopB.lng) * 0.65);

      final snapshot = RouteProgressService.snapToRoute(
        route: route,
        lat: lat,
        lng: lng,
        hintCurrentStopId: stopA.id,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentStopId, stopB.id);
      expect(snapshot.nextStopId, stopC.id);
      expect(snapshot.segmentProgress, greaterThan(0.55));
    });
  });

  group('LiveBus continuous distance helpers', () {
    final route = VizagRoutes.byRouteId('10K')!;

    test('sums distance from current segment to a downstream stop', () {
      final bus = LiveBus(
        id: 'bus_1',
        routeKey: route.routeId,
        routeNumber: route.number,
        currentStopId: route.stopIds[0],
        nextStopId: route.stopIds[1],
        segmentStartStopId: route.stopIds[0],
        segmentEndStopId: route.stopIds[1],
        segmentProgress: 0.25,
        lat: 0,
        lng: 0,
        lastUpdated: DateTime.now(),
      );

      final toNext = bus.distanceToStopKm(route.stopIds[1]);
      final toThird = bus.distanceToStopKm(route.stopIds[2]);

      expect(toNext, isNotNull);
      expect(toThird, isNotNull);
      expect(toThird!, greaterThan(toNext!));
    });
  });
}
