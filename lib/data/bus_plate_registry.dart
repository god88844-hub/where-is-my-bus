import 'vizag_data.dart';

class BusPlateRegistry {
  static final Map<String, BusType> _knownTypes = {
    // Maddilapalem depot sheet sample.
    'AP31TE5929': BusType.redOrdinary,
  };

  static String normalize(String value) {
    final upper = value.toUpperCase().trim();
    return upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static BusType? resolveType({
    required String plateNumber,
    String? routeNumber,
  }) {
    final normalized = normalize(plateNumber);
    if (routeNumber != null) {
      final routeType = VizagRoutes.byRouteId(routeNumber)?.busType ??
          VizagRoutes.byNumber(routeNumber)?.busType;
      if (routeType != null) {
        return routeType;
      }
    }

    if (normalized.isEmpty) return null;
    return _knownTypes[normalized];
  }
}
