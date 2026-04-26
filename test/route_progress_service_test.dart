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
      final progress = 1 -
          ((RouteProgressService.stopArrivalDistanceKm + 0.25) /
              fixture.segmentKm);
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

    test('keeps forward Pendhurthi fixes on the Pendhurthi corridor', () {
      final route = VizagRoutes.byRouteId('300C')!;
      final pendurthi = VizagStops.get('pendurthi')!;

      final snapshot = RouteProgressService.snapToRoute(
        route: route,
        lat: pendurthi.lat,
        lng: pendurthi.lng,
        hintCurrentStopId: 'gopalapatnam',
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.currentStopId, 'pendurthi');
      expect(snapshot.nextStopId, 'sabbavaram');
      expect(snapshot.currentStopId, isNot('gopalapatnam'));
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

    test('28K keeps a useful major-stop spine while hiding minor stops', () {
      final route = VizagRoutes.byRouteId('28K');

      expect(route, isNotNull);
      expect(route!.number, '28K');
      expect(route.stopIds.first, 'rk_beach');
      expect(route.stopIds.last, 'kothavalasa');
      expect(route.visibleStopIds, [
        'rk_beach',
        'jagadamba',
        'rtc_complex',
        'nad_junction',
        'gopalapatnam',
        'pendurthi',
        'kothavalasa',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIdsBetween('rk_beach', 'kothavalasa'),
        containsAllInOrder([
          'collector_office',
          'jagadamba',
          'rtc_complex',
          'railway_station',
          'kancharapalem',
          'marripalem',
          'nad_junction',
          'gopalapatnam',
          'vepagunta',
          'sujatha_nagar',
          'chinnamushidivada',
          'pendurthi',
          'saripalli',
          'mangalapalem',
        ]),
      );
      expect(
        route.visibleStopIdsBetween('rk_beach', 'kothavalasa'),
        [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa',
        ],
      );
      expect(route.stopGroups.first.minorStopIds, contains('collector_office'));
      expect(route.stopGroups[4].minorStopIds, contains('vepagunta'));
      expect(
          route.stopGroups.first.minorStopIds, isNot(contains('kothavalasa')));
    });

    test('28K reverse direction keeps the same hidden-stop grouping', () {
      final route = VizagRoutes.byRouteId('28K-R');

      expect(route, isNotNull);
      expect(route!.number, '28K');
      expect(route.from, 'Kothavalasa');
      expect(route.to, 'RK Beach');
      expect(route.stopIds.first, 'kothavalasa');
      expect(route.stopIds.last, 'rk_beach');
      expect(route.visibleStopIds, [
        'kothavalasa',
        'pendurthi',
        'gopalapatnam',
        'nad_junction',
        'rtc_complex',
        'jagadamba',
        'rk_beach',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(route.stopGroups, isNotEmpty);
      expect(route.stopGroups.first.minorStopIds,
          contains('kothavalasa_junction'));
      expect(route.stopGroups[1].minorStopIds, contains('pendurti_college'));
      expect(route.stopGroups[5].minorStopIds, contains('collector_office'));
    });

    test('68K shares the same Pendurthi corridor minor stops', () {
      final route = VizagRoutes.byRouteId('68K');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'kothavalasa',
        'pendurthi',
        'vepagunta',
        'simhachalam',
        'hanumanthawaka',
        'rtc_complex',
        'jagadamba',
        'rk_beach',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIds,
        containsAllInOrder([
          'kothavalasa',
          'pendurthi',
          'pendurti_college',
          'chinnamushidivada',
          'sujatha_nagar',
          'purushottapuram',
          'vepagunta',
          'simhachalam',
        ]),
      );
      expect(route.stopGroups[1].minorStopIds, contains('pendurti_college'));
    });

    test('300C now expands the Gopalapatnam-Pendurthi corridor', () {
      final route = VizagRoutes.byRouteId('300C');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'rtc_complex',
        'nad_junction',
        'gopalapatnam',
        'pendurthi',
        'sabbavaram',
        'chodavaram',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIds,
        containsAllInOrder([
          'gopalapatnam',
          'vepagunta',
          'purushottapuram',
          'sujatha_nagar',
          'chinnamushidivada',
          'pendurti_college',
          'pendurthi',
          'sabbavaram',
        ]),
      );
      expect(route.stopGroups[2].minorStopIds, contains('vepagunta'));
    });

    test('300C reverse direction keeps the shared corridor stops too', () {
      final route = VizagRoutes.byRouteId('300C-R');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'chodavaram',
        'sabbavaram',
        'pendurthi',
        'gopalapatnam',
        'nad_junction',
        'rtc_complex',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIds,
        containsAllInOrder([
          'chodavaram',
          'sabbavaram',
          'pendurthi',
          'pendurti_college',
          'chinnamushidivada',
          'sujatha_nagar',
          'purushottapuram',
          'vepagunta',
          'gopalapatnam',
          'nad_junction',
          'rtc_complex',
        ]),
      );
    });

    test('10K keeps its visible beach-road anchors and adds minor stops', () {
      final route = VizagRoutes.byRouteId('10K');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'rtc_complex',
        'jagadamba',
        'rk_beach',
        'vuda_park',
        'tenneti_park',
        'kailasagiri',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIds,
        containsAllInOrder([
          'rk_beach',
          'appughar_bus_stop',
          'vuda_park',
          'tenneti_park',
          'kailasagiri',
        ]),
      );
      expect(
        route.stopIds,
        containsAllInOrder([
          'kgh_out_gate',
          'kgh_in_gate',
          'vuda_park',
        ]),
      );
    });

    test('12D imports intermediate corridor stops without changing anchors',
        () {
      final route = VizagRoutes.byRouteId('12D');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'rtc_complex',
        'nad_junction',
        'gopalapatnam',
        'pendurthi',
        'kothavalasa',
        'anandapuram',
        'devarapalli',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIds,
        containsAllInOrder([
          'railway_station',
          'kancharapalem',
          'gopalapatnam',
          'pendurti_college',
          'kothavalasa',
          'koruvada',
          'anandapuram',
          'devarapalli',
        ]),
      );
    });

    test('12D reverse direction also keeps imported intermediate stops', () {
      final route = VizagRoutes.byRouteId('12D-R');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'devarapalli',
        'kothavalasa',
        'pendurthi',
        'nad_junction',
        'railway_station',
        'rtc_complex',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIds,
        containsAllInOrder([
          'devarapalli',
          'kasipuram',
          'anandapuram',
          'kothavalasa',
          'pendurthi',
          'gopalapatnam',
          'nad_junction',
          'kancharapalem',
          'railway_station',
          'rtc_complex',
        ]),
      );
    });

    test('222 now uses the exact inland corridor with hidden minor stops', () {
      final route = VizagRoutes.byRouteId('222');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'rtc_complex',
        'mvp_colony',
        'hanumanthawaka',
        'madhurawada',
        'anandapuram',
        'tagarapuvalasa',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(
        route.stopIds,
        containsAllInOrder([
          'rtc_complex',
          'rama_talkies',
          'mvp_colony',
          'venkojipalem',
          'hanumanthawaka',
          'old_dairy_farm',
          'vizag_zoo',
          'endada',
          'carshed',
          'madhurawada',
          'marikavalasa',
          'paradesipalem',
          'anandapuram',
          'tagarapuvalasa',
        ]),
      );
      expect(
        route.visibleStopIdsBetween('rtc_complex', 'anandapuram'),
        [
          'rtc_complex',
          'mvp_colony',
          'hanumanthawaka',
          'madhurawada',
          'anandapuram',
        ],
      );
      expect(route.stopGroups.first.minorStopIds, contains('rama_talkies'));
      expect(route.stopGroups[3].minorStopIds, contains('kommadi'));
    });

    test('222R keeps the railway station lead-in on the same OSM corridor', () {
      final route = VizagRoutes.byRouteId('222R');

      expect(route, isNotNull);
      expect(route!.visibleStopIds, [
        'railway_station',
        'rtc_complex',
        'mvp_colony',
        'hanumanthawaka',
        'madhurawada',
        'anandapuram',
        'tagarapuvalasa',
      ]);
      expect(route.hasHiddenSubStops, isTrue);
      expect(route.stopIds.first, 'railway_station');
      expect(route.stopIds.last, 'tagarapuvalasa');
      expect(
        route.stopIds,
        containsAllInOrder([
          'railway_station',
          'rtc_complex',
          'rama_talkies',
          'mvp_colony',
          'hanumanthawaka',
          'madhurawada',
          'pyda_engineering_college',
          'bheemili_x_road',
          'anandapuram',
          'peddipalem',
          'tallavalasa',
          'tagarapuvalasa',
        ]),
      );
    });
  });

  group('RouteProgressService stop radius handling', () {
    final fixture = _findLongSegmentFixture(2.4);

    test('advances only after the live fix enters the next stop arrival radius',
        () {
      final outsideRadiusKm = RouteProgressService.stopArrivalDistanceKm + 0.08;
      final insideRadiusKm = RouteProgressService.stopArrivalDistanceKm - 0.08;
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
