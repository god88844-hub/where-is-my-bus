import 'dart:math' as math;

import '../data/vizag_data.dart';
import '../utils/constants.dart';
import 'location_service.dart';

class RouteProgressSnapshot {
  const RouteProgressSnapshot({
    required this.currentStopId,
    required this.nextStopId,
    required this.currentStopIndex,
    required this.nextStopIndex,
    required this.segmentProgress,
    required this.routeProgress,
    required this.projectedDistanceKm,
    required this.totalRouteKm,
    required this.distanceToNextStopKm,
    required this.remainingRouteKm,
    required this.snappedLat,
    required this.snappedLng,
    required this.distanceFromRouteKm,
  });

  final String currentStopId;
  final String nextStopId;
  final int currentStopIndex;
  final int nextStopIndex;
  final double segmentProgress;
  final double routeProgress;
  final double projectedDistanceKm;
  final double totalRouteKm;
  final double distanceToNextStopKm;
  final double remainingRouteKm;
  final double snappedLat;
  final double snappedLng;
  final double distanceFromRouteKm;

  bool get isTerminal =>
      nextStopId.isEmpty || nextStopIndex <= currentStopIndex;
}

class RouteProgressService {
  static const int _localWindowBackSegments = 2;
  static const int _localWindowAheadSegments = 8;
  static const double _localWindowToleranceKm = 0.18;
  static const double _backtrackToleranceKm = 0.08;
  static const double _maxHintLeapKm = 8.0;
  static const double _backtrackPenaltyMultiplier = 10.0;
  static const double _forwardLeapPenaltyMultiplier = 0.15;
  static const double _maxRouteSnapDistanceKm = 0.45;
  static const double _stopArrivalDistanceKm = 0.35;

  // Geofence tuning — radius adapts to the spacing of the neighbouring stops
  // so a bus "crosses" each location precisely:
  //
  //   radius = clamp(min(prevGap, nextGap) * 0.4, 0.5 km, 1.0 km)
  //
  //   - Dense city stops (~800 m apart) -> ~500 m radius: the bus crosses
  //     one stop before it can be mistaken for the next.
  //   - Normal spacing (>= 2.5 km) -> full 1 km radius: the bus shows as
  //     entering the next stop before passengers see it there.
  //   - Wrong-stop risk is handled by nearest-coordinate-wins, not by the
  //     radius alone.
  static const double _arrivalRadiusFloorKm = 0.50;
  static const double _arrivalRadiusCeilingKm = 1.00;
  static const double _arrivalRadiusSpacingFactor = 0.40;

  // Path-snap tolerance scales gently with the segment length but never
  // drops below the legacy 450 m — tight enough for city corridors,
  // forgiving on long rural ones.
  static const double _snapToleranceFloorKm = 0.45;
  static const double _snapToleranceCeilingKm = 1.00;
  static const double _snapToleranceSegmentFactor = 0.12;

  static double get stopArrivalDistanceKm => _stopArrivalDistanceKm;

  static double get maxRouteSnapDistanceKm => _maxRouteSnapDistanceKm;

  /// Arrival radius (geofence) for the stop at [stopIndex] on [route].
  ///
  /// Scales with the closest neighbouring stop spacing, clamped to
  /// [0.5 km .. 1.0 km].
  static double stopArrivalRadiusKmForRoute(
    BusRoute route,
    int stopIndex,
  ) {
    if (stopIndex < 0 || stopIndex >= route.stopIds.length) {
      return _arrivalRadiusCeilingKm;
    }

    double? nearestNeighbourKm;
    for (final i in [stopIndex - 1, stopIndex]) {
      if (i < 0 || i >= route.stopIds.length - 1) continue;
      final segmentKm = segmentDistanceKmForRoute(route, i);
      if (segmentKm <= 0) continue;
      if (nearestNeighbourKm == null || segmentKm < nearestNeighbourKm) {
        nearestNeighbourKm = segmentKm;
      }
    }

    if (nearestNeighbourKm == null) return _arrivalRadiusCeilingKm;

    return (nearestNeighbourKm * _arrivalRadiusSpacingFactor).clamp(
      _arrivalRadiusFloorKm,
      _arrivalRadiusCeilingKm,
    );
  }

  /// How far from the route path a GPS fix may be and still snap, given the
  /// length of the segment it projects onto.
  static double snapToleranceKmForSegment(double segmentLengthKm) {
    if (segmentLengthKm <= 0) return _maxRouteSnapDistanceKm;
    return (segmentLengthKm * _snapToleranceSegmentFactor).clamp(
      _snapToleranceFloorKm,
      _snapToleranceCeilingKm,
    );
  }

  static RouteProgressSnapshot? snapToRoute({
    required BusRoute route,
    required double lat,
    required double lng,
    String? hintCurrentStopId,
  }) {
    if (route.stopIds.isEmpty) return null;

    if (route.stopIds.length == 1) {
      final onlyStop = VizagStops.get(route.stopIds.first);
      if (onlyStop == null) return null;
      return RouteProgressSnapshot(
        currentStopId: onlyStop.id,
        nextStopId: '',
        currentStopIndex: 0,
        nextStopIndex: 0,
        segmentProgress: 1,
        routeProgress: 1,
        projectedDistanceKm: 0,
        totalRouteKm: 0,
        distanceToNextStopKm: 0,
        remainingRouteKm: 0,
        snappedLat: onlyStop.lat,
        snappedLng: onlyStop.lng,
        distanceFromRouteKm:
            LocationService.distanceKm(lat, lng, onlyStop.lat, onlyStop.lng),
      );
    }

    final segments = _routeSegments(route);
    if (segments.isEmpty) return null;

    final hintIndex = route.stopIds.indexOf(hintCurrentStopId ?? '');
    final hintDistanceKm =
        hintIndex >= 0 ? distanceFromRouteStartKm(route, hintIndex) : null;

    var best = _bestProjectionForSegments(
      segments: segments,
      lat: lat,
      lng: lng,
      hintDistanceKm: hintDistanceKm,
    );

    if (hintIndex >= 0) {
      final localStart = math.max(0, hintIndex - _localWindowBackSegments);
      final localEnd = math.min(
        route.stopIds.length - 2,
        hintIndex + _localWindowAheadSegments,
      );
      final localSegments = segments
          .where(
            (segment) =>
                segment.startStopIndex >= localStart &&
                segment.startStopIndex <= localEnd,
          )
          .toList(growable: false);
      final localBest = _bestProjectionForSegments(
        segments: localSegments,
        lat: lat,
        lng: lng,
        hintDistanceKm: hintDistanceKm,
      );

      if (best == null) {
        best = localBest;
      } else if (localBest != null) {
        final globalScore = _projectionScore(
          best,
          hintDistanceKm: hintDistanceKm,
        );
        final localScore = _projectionScore(
          localBest,
          hintDistanceKm: hintDistanceKm,
        );
        final globalBacktracks = hintDistanceKm != null &&
            best.projectedDistanceKm < hintDistanceKm - _backtrackToleranceKm;

        if (localBest.distanceFromRouteKm <=
                best.distanceFromRouteKm + _localWindowToleranceKm ||
            localScore <= globalScore ||
            globalBacktracks) {
          best = localBest;
        }
      }
    }

    if (best == null) return null;

    final totalRouteKm = routeDistanceKm(route);
    final currentStopId = route.stopIds[best.startStopIndex];
    final nextStopId = route.stopIds[best.endStopIndex];
    final currentStop = VizagStops.get(currentStopId);
    final nextStop = VizagStops.get(nextStopId);
    final currentArrivalRadiusKm =
        stopArrivalRadiusKmForRoute(route, best.startStopIndex);
    final nextArrivalRadiusKm =
        stopArrivalRadiusKmForRoute(route, best.endStopIndex);
    final snapToleranceKm = snapToleranceKmForSegment(best.segmentLengthKm);
    final distanceToCurrentStopCoordinateKm = currentStop == null
        ? double.infinity
        : LocationService.distanceKm(lat, lng, currentStop.lat, currentStop.lng);
    final distanceToNextStopCoordinateKm = nextStop == null
        ? double.infinity
        : LocationService.distanceKm(lat, lng, nextStop.lat, nextStop.lng);

    if (best.distanceFromRouteKm > snapToleranceKm &&
        distanceToCurrentStopCoordinateKm > currentArrivalRadiusKm &&
        distanceToNextStopCoordinateKm > nextArrivalRadiusKm) {
      return null;
    }

    var resolvedCurrentStopIndex = best.startStopIndex;
    var resolvedNextStopIndex = best.endStopIndex;
    var resolvedCurrentStopId = currentStopId;
    var resolvedNextStopId = nextStopId;
    var projectedDistanceKm = best.projectedDistanceKm;
    var segmentProgress = best.progress;
    var snappedLat = best.snappedLat;
    var snappedLng = best.snappedLng;

    final arrivedAtNextStop = nextStop != null &&
        distanceToNextStopCoordinateKm <= nextArrivalRadiusKm &&
        distanceToNextStopCoordinateKm <= distanceToCurrentStopCoordinateKm;

    if (arrivedAtNextStop) {
      resolvedCurrentStopIndex = best.endStopIndex;
      resolvedCurrentStopId = route.stopIds[resolvedCurrentStopIndex];
      projectedDistanceKm =
          distanceFromRouteStartKm(route, resolvedCurrentStopIndex);
      snappedLat = nextStop.lat;
      snappedLng = nextStop.lng;

      if (resolvedCurrentStopIndex >= route.stopIds.length - 1) {
        return RouteProgressSnapshot(
          currentStopId: resolvedCurrentStopId,
          nextStopId: '',
          currentStopIndex: resolvedCurrentStopIndex,
          nextStopIndex: resolvedCurrentStopIndex,
          segmentProgress: 1,
          routeProgress: 1,
          projectedDistanceKm: totalRouteKm,
          totalRouteKm: totalRouteKm,
          distanceToNextStopKm: 0,
          remainingRouteKm: 0,
          snappedLat: snappedLat,
          snappedLng: snappedLng,
          distanceFromRouteKm: distanceToNextStopCoordinateKm,
        );
      }

      resolvedNextStopIndex = resolvedCurrentStopIndex + 1;
      resolvedNextStopId = route.stopIds[resolvedNextStopIndex];
      segmentProgress = 0;
    } else if (currentStop != null &&
        distanceToCurrentStopCoordinateKm <= _stopArrivalDistanceKm &&
        distanceToCurrentStopCoordinateKm < distanceToNextStopCoordinateKm) {
      // "Pinned at stop" uses the tight at-stop threshold so the segment
      // progress keeps its granularity; the wide 1 km radius is only for
      // advancing onto the NEXT stop (early-entry preview).
      projectedDistanceKm =
          distanceFromRouteStartKm(route, resolvedCurrentStopIndex);
      segmentProgress = 0;
      snappedLat = currentStop.lat;
      snappedLng = currentStop.lng;
    }

    final nextStopDistanceKm =
        distanceFromRouteStartKm(route, resolvedNextStopIndex);
    final distanceToNextStopKm =
        math.max(0, nextStopDistanceKm - projectedDistanceKm).toDouble();
    final remainingRouteKm =
        math.max(0, totalRouteKm - projectedDistanceKm).toDouble();
    final routeProgress = totalRouteKm <= 0
        ? (resolvedNextStopIndex <= resolvedCurrentStopIndex ? 1.0 : 0.0)
        : (projectedDistanceKm / totalRouteKm).clamp(0.0, 1.0).toDouble();

    return RouteProgressSnapshot(
      currentStopId: resolvedCurrentStopId,
      nextStopId: resolvedNextStopId,
      currentStopIndex: resolvedCurrentStopIndex,
      nextStopIndex: resolvedNextStopIndex,
      segmentProgress: segmentProgress.clamp(0.0, 1.0).toDouble(),
      routeProgress: routeProgress,
      projectedDistanceKm: projectedDistanceKm,
      totalRouteKm: totalRouteKm,
      distanceToNextStopKm: distanceToNextStopKm,
      remainingRouteKm: remainingRouteKm,
      snappedLat: snappedLat,
      snappedLng: snappedLng,
      distanceFromRouteKm: best.distanceFromRouteKm,
    );
  }

  static int etaMinutesForDistance({
    required double distanceKm,
    required BusRoute route,
    double? effectiveSpeedKmh,
  }) {
    if (distanceKm <= 0) return 0;
    final speed =
        (effectiveSpeedKmh ?? defaultRouteSpeedKmh(route)).clamp(8.0, 40.0);
    final etaHours = distanceKm / speed;
    return math.max(1, (etaHours * 60).ceil());
  }

  static double effectiveSpeedKmh({
    required BusRoute route,
    required double rawSpeedKmh,
    double? previousEffectiveSpeedKmh,
  }) {
    final boundedRaw = rawSpeedKmh.clamp(0.0, 60.0);
    if (boundedRaw < 2.5) {
      return 0;
    }

    if (previousEffectiveSpeedKmh == null) {
      return boundedRaw.clamp(0.0, 40.0);
    }

    return ((previousEffectiveSpeedKmh * 0.45) + (boundedRaw * 0.55))
        .clamp(0.0, 40.0);
  }

  static double defaultRouteSpeedKmh(BusRoute route) {
    return AppConstants.defaultEtaSpeedKmh;
  }

  static double routeDistanceKm(BusRoute route) {
    var totalDistanceKm = 0.0;
    for (var i = 0; i < route.stopIds.length - 1; i++) {
      totalDistanceKm += segmentDistanceKmForRoute(route, i);
    }
    return totalDistanceKm;
  }

  static double distanceFromRouteStartKm(BusRoute route, int stopIndex) {
    if (stopIndex <= 0) return 0;

    var distanceKm = 0.0;
    for (var i = 0; i < stopIndex && i < route.stopIds.length - 1; i++) {
      distanceKm += segmentDistanceKmForRoute(route, i);
    }
    return distanceKm;
  }

  static double segmentDistanceKmForRoute(BusRoute route, int startIndex) {
    if (startIndex < 0 || startIndex >= route.stopIds.length - 1) return 0;
    final start = VizagStops.get(route.stopIds[startIndex]);
    final end = VizagStops.get(route.stopIds[startIndex + 1]);
    if (start == null || end == null) return 0;
    if (!start.hasCoordinates || !end.hasCoordinates) return 0;
    return segmentDistanceKm(start, end);
  }

  static double segmentDistanceKm(BusStop start, BusStop end) {
    return LocationService.distanceKm(start.lat, start.lng, end.lat, end.lng);
  }

  static List<_RouteSegment> _routeSegments(BusRoute route) {
    final segments = <_RouteSegment>[];
    var distanceFromStartKm = 0.0;

    for (var i = 0; i < route.stopIds.length - 1; i++) {
      final startStop = VizagStops.get(route.stopIds[i]);
      final endStop = VizagStops.get(route.stopIds[i + 1]);
      final segmentLengthKm = startStop == null ||
              endStop == null ||
              !startStop.hasCoordinates ||
              !endStop.hasCoordinates
          ? 0.0
          : segmentDistanceKm(startStop, endStop);

      if (segmentLengthKm > 0) {
        segments.add(
          _RouteSegment(
            startStopIndex: i,
            endStopIndex: i + 1,
            startStop: startStop!,
            endStop: endStop!,
            startDistanceKm: distanceFromStartKm,
            endDistanceKm: distanceFromStartKm + segmentLengthKm,
            segmentLengthKm: segmentLengthKm,
          ),
        );
      }

      distanceFromStartKm += segmentLengthKm;
    }

    return segments;
  }

  static _SegmentProjection? _bestProjectionForSegments({
    required List<_RouteSegment> segments,
    required double lat,
    required double lng,
    double? hintDistanceKm,
  }) {
    _SegmentProjection? best;

    for (final segment in segments) {
      final candidate = _projectToSegment(
        segment: segment,
        lat: lat,
        lng: lng,
      );

      if (best == null ||
          _projectionScore(candidate, hintDistanceKm: hintDistanceKm) <
              _projectionScore(best, hintDistanceKm: hintDistanceKm)) {
        best = candidate;
      }
    }

    return best;
  }

  static _SegmentProjection _projectToSegment({
    required _RouteSegment segment,
    required double lat,
    required double lng,
  }) {
    final dx = segment.endStop.lng - segment.startStop.lng;
    final dy = segment.endStop.lat - segment.startStop.lat;
    final lengthSquared = (dx * dx) + (dy * dy);

    var progress = 0.0;
    if (lengthSquared > 0) {
      progress = (((lng - segment.startStop.lng) * dx) +
              ((lat - segment.startStop.lat) * dy)) /
          lengthSquared;
      progress = progress.clamp(0.0, 1.0);
    }

    final snappedLng = segment.startStop.lng + (dx * progress);
    final snappedLat = segment.startStop.lat + (dy * progress);
    final distanceFromRouteKm =
        LocationService.distanceKm(lat, lng, snappedLat, snappedLng);

    return _SegmentProjection(
      startStopIndex: segment.startStopIndex,
      endStopIndex: segment.endStopIndex,
      startDistanceKm: segment.startDistanceKm,
      endDistanceKm: segment.endDistanceKm,
      progress: progress,
      projectedDistanceKm:
          segment.startDistanceKm + (segment.segmentLengthKm * progress),
      snappedLat: snappedLat,
      snappedLng: snappedLng,
      distanceFromRouteKm: distanceFromRouteKm,
      segmentLengthKm: segment.segmentLengthKm,
    );
  }

  static double _projectionScore(
    _SegmentProjection projection, {
    double? hintDistanceKm,
  }) {
    var score = projection.distanceFromRouteKm;
    if (hintDistanceKm == null) {
      return score;
    }

    final backtrackKm =
        math.max(0, hintDistanceKm - projection.projectedDistanceKm);
    final forwardLeapKm =
        math.max(0, projection.projectedDistanceKm - hintDistanceKm);

    if (backtrackKm > _backtrackToleranceKm) {
      score +=
          (backtrackKm - _backtrackToleranceKm) * _backtrackPenaltyMultiplier;
    }

    if (forwardLeapKm > _maxHintLeapKm) {
      score +=
          (forwardLeapKm - _maxHintLeapKm) * _forwardLeapPenaltyMultiplier;
    }

    return score;
  }
}

class _RouteSegment {
  const _RouteSegment({
    required this.startStopIndex,
    required this.endStopIndex,
    required this.startStop,
    required this.endStop,
    required this.startDistanceKm,
    required this.endDistanceKm,
    required this.segmentLengthKm,
  });

  final int startStopIndex;
  final int endStopIndex;
  final BusStop startStop;
  final BusStop endStop;
  final double startDistanceKm;
  final double endDistanceKm;
  final double segmentLengthKm;
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.startStopIndex,
    required this.endStopIndex,
    required this.startDistanceKm,
    required this.endDistanceKm,
    required this.progress,
    required this.projectedDistanceKm,
    required this.snappedLat,
    required this.snappedLng,
    required this.distanceFromRouteKm,
    required this.segmentLengthKm,
  });

  final int startStopIndex;
  final int endStopIndex;
  final double startDistanceKm;
  final double endDistanceKm;
  final double progress;
  final double projectedDistanceKm;
  final double snappedLat;
  final double snappedLng;
  final double distanceFromRouteKm;
  final double segmentLengthKm;
}
