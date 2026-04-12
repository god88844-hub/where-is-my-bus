import '../data/vizag_data.dart';

class MockGpsSample {
  const MockGpsSample({
    required this.lat,
    required this.lng,
    required this.speedKmh,
  });

  final double lat;
  final double lng;
  final double speedKmh;
}

class MockCoordinateScenario {
  const MockCoordinateScenario({
    required this.routeId,
    required this.displayName,
    required this.samples,
  });

  final String routeId;
  final String displayName;
  final List<MockGpsSample> samples;
}

class MockCoordinateScenarios {
  static MockCoordinateScenario? forRoute(String routeId) {
    switch (routeId) {
      case '111':
        return _buildLinearScenario(
          routeId: '111',
          displayName: '111 Kurmannapalem to Tagarapuvalasa',
        );
      case '111-R':
        return _buildLinearScenario(
          routeId: '111-R',
          displayName: '111 Tagarapuvalasa to Kurmannapalem',
        );
      default:
        return null;
    }
  }

  static MockCoordinateScenario? _buildLinearScenario({
    required String routeId,
    required String displayName,
  }) {
    final route = VizagRoutes.byRouteId(routeId);
    if (route == null || route.stopIds.length < 2) return null;

    final samples = <MockGpsSample>[];
    const segmentProgresses = [0.0, 0.18, 0.38, 0.58, 0.78, 0.96, 1.0];

    for (var i = 0; i < route.stopIds.length - 1; i++) {
      final start = VizagStops.get(route.stopIds[i]);
      final end = VizagStops.get(route.stopIds[i + 1]);
      if (start == null || end == null) {
        continue;
      }

      for (final progress in segmentProgresses) {
        if (i > 0 && progress == 0.0) {
          continue;
        }

        final lat = start.lat + ((end.lat - start.lat) * progress);
        final lng = start.lng + ((end.lng - start.lng) * progress);
        final speedKmh = progress == 0.0 || progress == 1.0 ? 8.0 : 24.0;

        samples.add(MockGpsSample(
          lat: lat,
          lng: lng,
          speedKmh: speedKmh,
        ));
      }
    }

    final terminal = VizagStops.get(route.stopIds.last);
    if (terminal != null) {
      samples.add(MockGpsSample(
        lat: terminal.lat,
        lng: terminal.lng,
        speedKmh: 0,
      ));
    }

    return MockCoordinateScenario(
      routeId: routeId,
      displayName: displayName,
      samples: samples,
    );
  }
}
