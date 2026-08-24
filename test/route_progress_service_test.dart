import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/models/bus.dart';
import 'package:vizag_bus_live/services/route_progress_service.dart';

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

    test('projects a fix onto the active segment', () {
      // 35% along the segment — clearly nearer to stop A than stop B, even
      // with the flat 1 km arrival radius.
      final lat = stopA.lat + ((stopB.lat - stopA.lat) * 0.35);
      final lng = stopA.lng + ((stopB.lng - stopA.lng) * 0.35);

      final snapshot = RouteProgressService.snapToRoute(
        route: route,
        lat: lat,
        lng: lng,
        hintCurrentStopId: stopA.id,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentStopId, stopA.id);
      expect(snapshot.nextStopId, stopB.id);
      expect(snapshot.segmentProgress, closeTo(0.35, 0.05));
      expect(snapshot.distanceToNextStopKm, greaterThan(0));
    });

    test('advances to the next segment even when a stop was skipped', () {
      final fixture = _findLongSegmentFixture(2.4, minSegmentIndex: 1);
      final previousStop =
          VizagStops.get(fixture.route.stopIds[fixture.segmentIndex - 1])!;
      final endStopRadiusKm = RouteProgressService.stopArrivalRadiusKmForRoute(
        fixture.route,
        fixture.segmentIndex + 1,
      );
      final progress = 1 -
          ((endStopRadiusKm + 0.25) / fixture.segmentKm);
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

    test('keeps forward fixes pinned to the Sabbavaram corridor', () {
      final route = VizagRoutes.byRouteId('300C')!;
      final sabbavaram = VizagStops.get('sabbavaram')!;

      final snapshot = RouteProgressService.snapToRoute(
        route: route,
        lat: sabbavaram.lat,
        lng: sabbavaram.lng,
        hintCurrentStopId: 'pendurthi',
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentStopId, 'sabbavaram');
      expect(snapshot.nextStopId, 'gottivada');
      expect(snapshot.currentStopId, isNot('pendurthi'));
      expect(snapshot.projectedDistanceKm, greaterThan(0));
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

    test('28K carries the full Excel stop list from RK Beach to Kothavalasa',
        () {
      final route = VizagRoutes.byRouteId('28K');

      expect(route, isNotNull);
      expect(route!.number, '28K');
      expect(route.from, 'RK Beach');
      expect(route.to, 'Kothavalasa JN');
      expect(route.stopIds.first, 'rk_beach');
      expect(route.stopIds.last, 'kothavalasa_jn');
      // Every Excel stop is owner-curated, so all stops are visible.
      expect(route.visibleStopIds, route.stopIds);
      expect(route.hasHiddenSubStops, isFalse);
      expect(
        route.stopIds,
        containsAllInOrder([
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'railway_station_vsp',
          'kancharapalem',
          'gopalapatnam',
          'vepagunta',
          'sujathanagar',
          'chinnamusidivada',
          'pendurthi',
          'mangalapalem',
          'kothavalasa_jn',
        ]),
      );
      expect(
        route.stopIds,
        isNot(contains('maddilapalem')),
        reason: '28K runs via the railway corridor, not Maddilapalem',
      );
    });

    test('28K reverse direction mirrors the forward stop order', () {
      final forward = VizagRoutes.byRouteId('28K')!;
      final route = VizagRoutes.byRouteId('28K-R');

      expect(route, isNotNull);
      expect(route!.number, '28K');
      expect(route.from, 'Kothavalasa JN');
      expect(route.to, 'RK Beach');
      expect(route.stopIds.first, 'kothavalasa_jn');
      expect(route.stopIds.last, 'rk_beach');
      expect(route.stopIds, forward.stopIds.reversed);
      expect(route.returnRouteNumber, '28K');
    });

    test('68K shares the Pendurthi corridor but runs via Maddilapalem', () {
      final route = VizagRoutes.byRouteId('68K')!;
      final route28K = VizagRoutes.byRouteId('28K')!;

      expect(route.number, '68K');
      expect(route.stopIds.first, 'rk_beach');
      expect(route.stopIds.last, 'kothavalasa_jn');
      expect(
        route.stopIds,
        containsAllInOrder([
          'rk_beach',
          'rtc_complex',
          'maddilapalem',
          'isukathota',
          'venkojipalem',
          'simhachalam',
          'vepagunta',
          'pendurthi',
          'mangalapalem',
          'kothavalasa_jn',
        ]),
      );
      // 28K and 68K stay distinct corridors even though they share stops.
      expect(route.stopIds.length, isNot(route28K.stopIds.length));
      expect(route.stopIds, contains('maddilapalem'));
      expect(route28K.stopIds, isNot(contains('maddilapalem')));
    });

    test('300C follows the RTC Complex to Chodavaram corridor', () {
      final route = VizagRoutes.byRouteId('300C')!;

      expect(route.number, '300C');
      expect(route.stopIds.first, 'rtc_complex');
      expect(route.stopIds.last, 'chodavaram');
      expect(route.visibleStopIds, route.stopIds);
      expect(
        route.stopIds,
        containsAllInOrder([
          'rtc_complex',
          'railway_station_vsp',
          'kancharapalem',
          'gopalapatnam',
          'vepagunta',
          'pendurthi',
          'sabbavaram',
          'adduru',
          'chodavaram',
        ]),
      );
    });

    test('300C reverse direction keeps the shared corridor stops too', () {
      final forward = VizagRoutes.byRouteId('300C')!;
      final route = VizagRoutes.byRouteId('300C-R');

      expect(route, isNotNull);
      expect(route!.stopIds.first, 'chodavaram');
      expect(route.stopIds.last, 'rtc_complex');
      expect(route.stopIds, forward.stopIds.reversed);
      expect(
        route.stopIds,
        containsAllInOrder([
          'chodavaram',
          'adduru',
          'sabbavaram',
          'pendurthi',
          'gopalapatnam',
          'rtc_complex',
        ]),
      );
    });

    test('10K keeps its beach-road anchors from the railway station', () {
      final route = VizagRoutes.byRouteId('10K')!;

      expect(route.number, '10K');
      expect(route.stopIds.first, 'railway_station_vsp');
      expect(route.stopIds.last, 'kailasagiri');
      expect(
        route.stopIds,
        containsAllInOrder([
          'rtc_complex',
          'jagadamba',
          'r_k_beach',
          'vuda_park',
          'tenneti_park',
          'kailasagiri',
        ]),
      );
    });

    test('12D imports intermediate corridor stops without changing anchors',
        () {
      final route = VizagRoutes.byRouteId('12D')!;

      expect(route.number, '12D');
      expect(route.stopIds.first, 'maddilapalem');
      expect(route.stopIds.last, 'devarapalli');
      expect(
        route.stopIds,
        containsAllInOrder([
          'rtc_complex',
          'railway_station_vsp',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa_jn',
          'anandapuram_2',
          'devarapalli',
        ]),
      );
    });

    test('12D reverse direction also keeps imported intermediate stops', () {
      final forward = VizagRoutes.byRouteId('12D')!;
      final route = VizagRoutes.byRouteId('12D-R');

      expect(route, isNotNull);
      expect(route!.stopIds.first, 'devarapalli');
      expect(route.stopIds.last, 'maddilapalem');
      expect(route.stopIds, forward.stopIds.reversed);
    });

    test('222 now uses the Bheemili x-road to Kasuluvada corridor', () {
      final route = VizagRoutes.byRouteId('222')!;

      expect(route.number, '222');
      expect(route.stopIds.first, 'railway_station_vsp');
      expect(route.stopIds.last, 'kasuluvada');
      expect(
        route.stopIds,
        containsAllInOrder([
          'railway_station_vsp',
          'rtc_complex',
          'maddilapalem',
          'hanumanthuwaka',
          'madhurawada',
          'kommadi',
          'bheemili_x_road',
          'anandapuram',
          'kasuluvada',
        ]),
      );
    });

    test('222 reverse trip keeps the same corridor back to the railway', () {
      final forward = VizagRoutes.byRouteId('222')!;
      final route = VizagRoutes.byRouteId('222-R');

      expect(route, isNotNull);
      expect(route!.stopIds.first, 'kasuluvada');
      expect(route.stopIds.last, 'railway_station_vsp');
      expect(route.stopIds, forward.stopIds.reversed);
      expect(route.returnRouteNumber, '222');
    });
  });

  group('RouteProgressService stop radius handling', () {
    final fixture = _findLongSegmentFixture(2.4);

    test('advances only after the live fix enters the next stop arrival radius',
        () {
      final endStopRadiusKm = RouteProgressService.stopArrivalRadiusKmForRoute(
        fixture.route,
        fixture.segmentIndex + 1,
      );
      final outsideRadiusKm = endStopRadiusKm + 0.08;
      final insideRadiusKm = endStopRadiusKm - 0.08;
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

  group('RouteProgressService adaptive geofencing', () {
    test('arrival radius scales with stop spacing, clamped 0.5-1.0 km', () {
      // Dense corridor: 10K's RTC Complex sits ~1 km from its neighbours ->
      // radius clamps to the 0.5 km floor for precise crossing.
      final cityRoute = VizagRoutes.byRouteId('10K')!;
      final cityIndex = cityRoute.stopIds.indexOf('rtc_complex');
      // Rural corridor: 25-IT's Timmapuram has 5+ km neighbours -> the full
      // 1 km ceiling.
      final ruralRoute = VizagRoutes.byRouteId('25_IT')!;
      final ruralIndex = ruralRoute.stopIds.indexOf('timmapuram');

      final cityRadius = RouteProgressService.stopArrivalRadiusKmForRoute(
        cityRoute,
        cityIndex,
      );
      final ruralRadius = RouteProgressService.stopArrivalRadiusKmForRoute(
        ruralRoute,
        ruralIndex,
      );

      expect(cityRadius, greaterThanOrEqualTo(0.5));
      expect(cityRadius, lessThan(1.0));
      expect(ruralRadius, 1.0);
    });

    test('snap tolerance never drops below the legacy 450 m', () {
      expect(
        RouteProgressService.snapToleranceKmForSegment(0.5),
        greaterThanOrEqualTo(0.45),
      );
      expect(
        RouteProgressService.snapToleranceKmForSegment(10),
        lessThanOrEqualTo(1.0),
      );
    });

    test('a mid-corridor fix between two city stops does not jump ahead', () {
      // On a dense corridor the bus must stay pinned to the earlier stop
      // until it genuinely approaches the next one.
      final route = VizagRoutes.byRouteId('10K')!;
      final stopA = VizagStops.get(route.stopIds[0])!;
      final stopB = VizagStops.get(route.stopIds[1])!;
      final segmentKm =
          RouteProgressService.segmentDistanceKm(stopA, stopB);
      final nextRadius = RouteProgressService.stopArrivalRadiusKmForRoute(
        route,
        1,
      );
      expect(segmentKm, greaterThan(nextRadius));

      // Fix placed just outside the next stop's arrival radius.
      final progress = 1 - ((nextRadius + 0.15) / segmentKm);
      final snapshot = RouteProgressService.snapToRoute(
        route: route,
        lat: stopA.lat + ((stopB.lat - stopA.lat) * progress),
        lng: stopA.lng + ((stopB.lng - stopA.lng) * progress),
        hintCurrentStopId: stopA.id,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentStopId, stopA.id);
      expect(snapshot.nextStopId, stopB.id);
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
