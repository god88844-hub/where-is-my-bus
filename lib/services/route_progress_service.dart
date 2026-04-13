import 'dart:math' as math;

import '../data/vizag_data.dart';
import 'location_service.dart';

class RouteProgressSnapshot {
  const RouteProgressSnapshot({
    required this.currentStopId,
    required this.nextStopId,
    required this.currentStopIndex,
    required this.nextStopIndex,
    required this.segmentProgress,
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
  final double distanceToNextStopKm;
  final double remainingRouteKm;
  final double snappedLat;
  final double snappedLng;
  final double distanceFromRouteKm;

  bool get isTerminal =>
      nextStopId.isEmpty || nextStopIndex <= currentStopIndex;
}

class RouteProgressService {
  static const int _localWindowBackSegments = 1;
  static const int _localWindowAheadSegments = 4;
  static const double _backtrackToleranceKm = 0.08;
  static const double _stopArrivalDistanceKm = 0.03;
  static const double _stopArrivalProgress = 0.98;

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
        distanceToNextStopKm: 0,
        remainingRouteKm: 0,
        snappedLat: onlyStop.lat,
        snappedLng: onlyStop.lng,
        distanceFromRouteKm:
            LocationService.distanceKm(lat, lng, onlyStop.lat, onlyStop.lng),
      );
    }

    final hintIndex = route.stopIds.indexOf(hintCurrentStopId ?? '');

    var best = _bestProjectionForRange(
      route: route,
      lat: lat,
      lng: lng,
      startIndex: 0,
      endIndex: route.stopIds.length - 2,
    );

    if (hintIndex >= 0) {
      final localStart = math.max(0, hintIndex - _localWindowBackSegments);
      final localEnd = math.min(
        route.stopIds.length - 2,
        hintIndex + _localWindowAheadSegments,
      );
      final localBest = _bestProjectionForRange(
        route: route,
        lat: lat,
        lng: lng,
        startIndex: localStart,
        endIndex: localEnd,
      );

      // Prefer the globally nearest segment so emulator jumps can advance the
      // bus quickly, but avoid minor backward snaps when two segments are
      // almost equally close.
      if (best != null &&
          localBest != null &&
          best.segmentIndex < hintIndex &&
          localBest.distanceFromRouteKm <=
              best.distanceFromRouteKm + _backtrackToleranceKm) {
        best = localBest;
      }
    }

    if (best == null) return null;

    final currentStopId = route.stopIds[best.segmentIndex];
    final nextStopId = route.stopIds[best.segmentIndex + 1];
    final distanceToNextStopKm = best.segmentLengthKm * (1 - best.progress);

    var remainingRouteKm = distanceToNextStopKm;
    for (var i = best.segmentIndex + 1; i < route.stopIds.length - 1; i++) {
      remainingRouteKm += segmentDistanceKmForRoute(route, i);
    }

    final arrivedAtNextStop =
        best.progress >= _stopArrivalProgress ||
        distanceToNextStopKm <= _stopArrivalDistanceKm;

    if (arrivedAtNextStop) {
      final arrivedStop = VizagStops.get(nextStopId);
      if (arrivedStop != null) {
        final arrivedIndex = best.segmentIndex + 1;
        if (arrivedIndex >= route.stopIds.length - 1) {
          return RouteProgressSnapshot(
            currentStopId: nextStopId,
            nextStopId: '',
            currentStopIndex: route.stopIds.length - 1,
            nextStopIndex: route.stopIds.length - 1,
            segmentProgress: 1,
            distanceToNextStopKm: 0,
            remainingRouteKm: 0,
            snappedLat: arrivedStop.lat,
            snappedLng: arrivedStop.lng,
            distanceFromRouteKm: LocationService.distanceKm(
                lat, lng, arrivedStop.lat, arrivedStop.lng),
          );
        }

        final nextLegStopId = route.stopIds[arrivedIndex + 1];
        final nextLegDistanceKm =
            segmentDistanceKmForRoute(route, arrivedIndex);
        var remainingAfterArrivalKm = nextLegDistanceKm;
        for (var i = arrivedIndex + 1; i < route.stopIds.length - 1; i++) {
          remainingAfterArrivalKm += segmentDistanceKmForRoute(route, i);
        }

        return RouteProgressSnapshot(
          currentStopId: nextStopId,
          nextStopId: nextLegStopId,
          currentStopIndex: arrivedIndex,
          nextStopIndex: arrivedIndex + 1,
          segmentProgress: 0,
          distanceToNextStopKm: nextLegDistanceKm,
          remainingRouteKm: remainingAfterArrivalKm,
          snappedLat: arrivedStop.lat,
          snappedLng: arrivedStop.lng,
          distanceFromRouteKm: LocationService.distanceKm(
              lat, lng, arrivedStop.lat, arrivedStop.lng),
        );
      }
    }

    return RouteProgressSnapshot(
      currentStopId: currentStopId,
      nextStopId: nextStopId,
      currentStopIndex: best.segmentIndex,
      nextStopIndex: best.segmentIndex + 1,
      segmentProgress: best.progress,
      distanceToNextStopKm: distanceToNextStopKm,
      remainingRouteKm: remainingRouteKm,
      snappedLat: best.snappedLat,
      snappedLng: best.snappedLng,
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
    final fallback = defaultRouteSpeedKmh(route);
    final boundedRaw = rawSpeedKmh.clamp(0.0, 60.0);
    if (boundedRaw < 3) {
      return previousEffectiveSpeedKmh == null
          ? fallback
          : ((previousEffectiveSpeedKmh * 0.85) + (fallback * 0.15))
              .clamp(8.0, 40.0);
    }

    if (previousEffectiveSpeedKmh == null) {
      return boundedRaw.clamp(8.0, 40.0);
    }

    return ((previousEffectiveSpeedKmh * 0.65) + (boundedRaw * 0.35))
        .clamp(8.0, 40.0);
  }

  static double defaultRouteSpeedKmh(BusRoute route) {
    if (route.stopIds.length < 2) return 16;

    var totalDistanceKm = 0.0;
    for (var i = 0; i < route.stopIds.length - 1; i++) {
      totalDistanceKm += segmentDistanceKmForRoute(route, i);
    }

    final averageSegmentKm = totalDistanceKm / (route.stopIds.length - 1);
    // Preserve the previous "about 6 minutes per stop" behavior, but shape it
    // from route geometry instead of a fixed constant.
    return (averageSegmentKm * 10).clamp(12.0, 28.0);
  }

  static double segmentDistanceKmForRoute(BusRoute route, int startIndex) {
    if (startIndex < 0 || startIndex >= route.stopIds.length - 1) return 0;
    final start = VizagStops.get(route.stopIds[startIndex]);
    final end = VizagStops.get(route.stopIds[startIndex + 1]);
    if (start == null || end == null) return 0;
    return segmentDistanceKm(start, end);
  }

  static double segmentDistanceKm(BusStop start, BusStop end) {
    return LocationService.distanceKm(start.lat, start.lng, end.lat, end.lng);
  }

  static _SegmentProjection? _bestProjectionForRange({
    required BusRoute route,
    required double lat,
    required double lng,
    required int startIndex,
    required int endIndex,
  }) {
    _SegmentProjection? best;

    for (var i = startIndex; i <= endIndex; i++) {
      final startStop = VizagStops.get(route.stopIds[i]);
      final endStop = VizagStops.get(route.stopIds[i + 1]);
      if (startStop == null || endStop == null) continue;

      final candidate = _projectToSegment(
        segmentIndex: i,
        lat: lat,
        lng: lng,
        startStop: startStop,
        endStop: endStop,
      );

      if (best == null ||
          candidate.distanceFromRouteKm < best.distanceFromRouteKm) {
        best = candidate;
      }
    }

    return best;
  }

  static _SegmentProjection _projectToSegment({
    required int segmentIndex,
    required double lat,
    required double lng,
    required BusStop startStop,
    required BusStop endStop,
  }) {
    final dx = endStop.lng - startStop.lng;
    final dy = endStop.lat - startStop.lat;
    final lengthSquared = (dx * dx) + (dy * dy);

    var progress = 0.0;
    if (lengthSquared > 0) {
      progress = (((lng - startStop.lng) * dx) + ((lat - startStop.lat) * dy)) /
          lengthSquared;
      progress = progress.clamp(0.0, 1.0);
    }

    final snappedLng = startStop.lng + (dx * progress);
    final snappedLat = startStop.lat + (dy * progress);
    final distanceFromRouteKm =
        LocationService.distanceKm(lat, lng, snappedLat, snappedLng);
    final segmentLengthKm = segmentDistanceKm(startStop, endStop);

    return _SegmentProjection(
      segmentIndex: segmentIndex,
      progress: progress,
      snappedLat: snappedLat,
      snappedLng: snappedLng,
      distanceFromRouteKm: distanceFromRouteKm,
      segmentLengthKm: segmentLengthKm,
    );
  }
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.segmentIndex,
    required this.progress,
    required this.snappedLat,
    required this.snappedLng,
    required this.distanceFromRouteKm,
    required this.segmentLengthKm,
  });

  final int segmentIndex;
  final double progress;
  final double snappedLat;
  final double snappedLng;
  final double distanceFromRouteKm;
  final double segmentLengthKm;
}
