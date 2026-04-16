import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/services/route_progress_service.dart';
import 'package:vizag_bus_live/utils/constants.dart';

class _LongSegmentFixture {
  const _LongSegmentFixture({
    required this.route,
    required this.segmentIndex,
    required this.startStop,
    required this.endStop,
    required this.segmentKm,
  });

  final BusRoute route;
  final int segmentIndex;
  final BusStop startStop;
  final BusStop endStop;
  final double segmentKm;
}

_LongSegmentFixture _findLongSegmentFixture(
  double minSegmentKm, {
  int minSegmentIndex = 0,
}) {
  for (final route in VizagRoutes.primaryRoutes) {
    for (var i = 0; i < route.stopIds.length - 1; i++) {
      if (i < minSegmentIndex) continue;

      final startStop = VizagStops.get(route.stopIds[i]);
      final endStop = VizagStops.get(route.stopIds[i + 1]);
      if (startStop == null || endStop == null) continue;

      final segmentKm =
          RouteProgressService.segmentDistanceKm(startStop, endStop);
      if (segmentKm > minSegmentKm) {
        return _LongSegmentFixture(
          route: route,
          segmentIndex: i,
          startStop: startStop,
          endStop: endStop,
          segmentKm: segmentKm,
        );
      }
    }
  }

  throw StateError('No route segment longer than $minSegmentKm km was found.');
}

({double lat, double lng}) _interpolateFix(
  BusStop startStop,
  BusStop endStop,
  double progress,
) {
  return (
    lat: startStop.lat + ((endStop.lat - startStop.lat) * progress),
    lng: startStop.lng + ((endStop.lng - startStop.lng) * progress),
  );
}

void main() {
  group('RouteProgressService.snapToRoute', () {
    final route = VizagRoutes.byRouteId('10K')!;
    final stopA = VizagStops.get(route.stopIds[0])!;
    final stopB = VizagStops.get(route.stopIds[1])!;

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
      final fixture = _findLongSegmentFixture(2.4, minSegmentIndex: 1);
      final previousStop =
          VizagStops.get(fixture.route.stopIds[fixture.segmentIndex - 1])!;
      final progress =
          1 - ((AppConstants.stopReachRadiusKm + 0.25) / fixture.segmentKm);
      final lat = fixture.startStop.lat +
          ((fixture.endStop.lat - fixture.startStop.lat) * progress);
      final lng = fixture.startStop.lng +
          ((fixture.endStop.lng - fixture.startStop.lng) * progress);

      final snapshot = RouteProgressService.snapToRoute(
        route: fixture.route,
        lat: lat,
        lng: lng,
        hintCurrentStopId: previousStop.id,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentStopId, fixture.startStop.id);
      expect(snapshot.nextStopId, fixture.endStop.id);
      expect(snapshot.segmentProgress, greaterThan(0.35));
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

  group('Route data sanity', () {
    test('68K keeps its public route number and reverse trip separate', () {
      final route = VizagRoutes.byRouteId('68K');
      final reverseRoute = VizagRoutes.byRouteId('68K-R');

      expect(route, isNotNull);
      expect(reverseRoute, isNotNull);
      expect(route!.number, '68K');
      expect(route.returnRouteNumber, '68K-R');
      expect(reverseRoute!.number, '68K');
      expect(reverseRoute.returnRouteNumber, '68K');
    });
  });

  group('RouteProgressService stop radius handling', () {
    final fixture = _findLongSegmentFixture(2.4);

    test('advances only after the live fix enters the next stop 1 km radius',
        () {
      const outsideRadiusKm = AppConstants.stopReachRadiusKm + 0.2;
      const insideRadiusKm = AppConstants.stopReachRadiusKm - 0.2;
      final outsideProgress = 1 - (outsideRadiusKm / fixture.segmentKm);
      final insideProgress = 1 - (insideRadiusKm / fixture.segmentKm);

      final outsideFix = _interpolateFix(
        fixture.startStop,
        fixture.endStop,
        outsideProgress,
      );
      final insideFix = _interpolateFix(
        fixture.startStop,
        fixture.endStop,
        insideProgress,
      );

      final outsideSnapshot = RouteProgressService.snapToRoute(
        route: fixture.route,
        lat: outsideFix.lat,
        lng: outsideFix.lng,
        hintCurrentStopId: fixture.startStop.id,
      );
      final insideSnapshot = RouteProgressService.snapToRoute(
        route: fixture.route,
        lat: insideFix.lat,
        lng: insideFix.lng,
        hintCurrentStopId: fixture.startStop.id,
      );

      expect(outsideSnapshot, isNotNull);
      expect(outsideSnapshot!.currentStopId, fixture.startStop.id);
      expect(outsideSnapshot.nextStopId, fixture.endStop.id);

      expect(insideSnapshot, isNotNull);
      expect(insideSnapshot!.currentStopId, fixture.endStop.id);
    });
  });

  group('RouteProgressService.effectiveSpeedKmh', () {
    final route = VizagRoutes.byRouteId('10K')!;

    test('returns zero for a stopped bus', () {
      final speed = RouteProgressService.effectiveSpeedKmh(
        route: route,
        rawSpeedKmh: 0,
        previousEffectiveSpeedKmh: 18,
      );

      expect(speed, 0);
    });
  });
}
