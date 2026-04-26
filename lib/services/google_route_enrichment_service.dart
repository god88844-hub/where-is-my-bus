import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../data/vizag_data.dart';

class GoogleEnrichedStop {
  const GoogleEnrichedStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.projectedDistanceKm,
    this.nameTelugu = '',
    this.placeId = '',
  });

  final String id;
  final String name;
  final String nameTelugu;
  final double lat;
  final double lng;
  final double projectedDistanceKm;
  final String placeId;
}

class GoogleRouteEnrichmentResult {
  const GoogleRouteEnrichmentResult({
    required this.routeId,
    required this.baseRoute,
    required this.from,
    required this.to,
    required this.stopIds,
    required this.majorStopIds,
    required this.discoveredStops,
    required this.encodedPolyline,
  });

  final String routeId;
  final String baseRoute;
  final String from;
  final String to;
  final List<String> stopIds;
  final List<String> majorStopIds;
  final List<GoogleEnrichedStop> discoveredStops;
  final String encodedPolyline;
}

class GoogleRouteEnrichmentService {
  GoogleRouteEnrichmentService({
    required this.routesApiKey,
    required this.placesApiKey,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  static const List<String> defaultSearchTerms = [
    'bus stop',
    'bus station',
    'junction',
  ];
  static const double _candidateSpacingKm = 0.18;
  static const double _existingStopMatchDistanceKm = 0.22;
  static const double _segmentEdgeBufferKm = 0.03;

  final String routesApiKey;
  final String placesApiKey;
  final HttpClient _httpClient;

  Future<GoogleRouteEnrichmentResult?> enrichRoute(
    BusRoute route, {
    Map<String, BusStop> knownStopsById = const {},
    Iterable<String>? searchTerms,
  }) async {
    if (routesApiKey.trim().isEmpty || placesApiKey.trim().isEmpty) {
      return null;
    }

    final majorStops = route.visibleStopIds
        .map(VizagStops.get)
        .whereType<BusStop>()
        .where((stop) => stop.hasCoordinates)
        .toList(growable: false);
    if (majorStops.length < 2) {
      return null;
    }

    final encodedPolyline = await _computeRoutePolyline(majorStops);
    if (encodedPolyline == null || encodedPolyline.isEmpty) {
      return null;
    }

    final polylinePoints = _decodePolyline(encodedPolyline);
    if (polylinePoints.length < 2) {
      return null;
    }

    final majorProjections = <_ProjectedCandidate>[];
    for (final stop in majorStops) {
      final projection = _projectToPolyline(polylinePoints, stop.lat, stop.lng);
      if (projection == null) {
        return null;
      }
      majorProjections.add(
        _ProjectedCandidate(
          stopId: stop.id,
          name: stop.name,
          lat: stop.lat,
          lng: stop.lng,
          projectedDistanceKm: projection.projectedDistanceKm,
          placeId: stop.id,
          types: const [],
        ),
      );
    }

    for (var i = 0; i < majorProjections.length - 1; i++) {
      if (majorProjections[i + 1].projectedDistanceKm <=
          majorProjections[i].projectedDistanceKm) {
        return null;
      }
    }

    final knownStops = <String, BusStop>{
      ...VizagStops.all,
      ...knownStopsById,
    };
    final routeCandidateMap = <String, _ProjectedCandidate>{};
    final allSearchTerms = (searchTerms ?? defaultSearchTerms)
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toSet();

    for (final term in allSearchTerms) {
      final rawCandidates = await _searchAlongRoute(term, encodedPolyline);
      for (final rawCandidate in rawCandidates) {
        if (!_looksLikeTransitStop(rawCandidate)) {
          continue;
        }

        final projection = _projectToPolyline(
          polylinePoints,
          rawCandidate.lat,
          rawCandidate.lng,
        );
        if (projection == null) {
          continue;
        }

        final stopId = _resolveStopId(
          candidate: rawCandidate,
          knownStopsById: knownStops,
        );
        final projectedCandidate = _ProjectedCandidate(
          stopId: stopId,
          name: rawCandidate.name,
          lat: rawCandidate.lat,
          lng: rawCandidate.lng,
          projectedDistanceKm: projection.projectedDistanceKm,
          placeId: rawCandidate.placeId,
          types: rawCandidate.types,
        );

        final existing = routeCandidateMap[stopId];
        if (existing == null ||
            _candidateScore(projectedCandidate) > _candidateScore(existing)) {
          routeCandidateMap[stopId] = projectedCandidate;
        }
      }
    }

    final finalStopIds = <String>[];
    final usedCandidates = <String, _ProjectedCandidate>{};

    for (var i = 0; i < majorProjections.length - 1; i++) {
      final start = majorProjections[i];
      final end = majorProjections[i + 1];
      if (finalStopIds.isEmpty || finalStopIds.last != start.stopId) {
        finalStopIds.add(start.stopId);
      }

      final betweenStops = routeCandidateMap.values
          .where(
            (candidate) =>
                candidate.projectedDistanceKm >
                    start.projectedDistanceKm + _segmentEdgeBufferKm &&
                candidate.projectedDistanceKm <
                    end.projectedDistanceKm - _segmentEdgeBufferKm &&
                candidate.stopId != start.stopId &&
                candidate.stopId != end.stopId,
          )
          .toList(growable: false)
        ..sort(
          (a, b) => a.projectedDistanceKm.compareTo(b.projectedDistanceKm),
        );

      var lastDistanceKm = start.projectedDistanceKm;
      for (final candidate in betweenStops) {
        if (candidate.projectedDistanceKm - lastDistanceKm <
            _candidateSpacingKm) {
          continue;
        }
        if (end.projectedDistanceKm - candidate.projectedDistanceKm <
            _candidateSpacingKm / 2) {
          continue;
        }
        if (finalStopIds.isNotEmpty && finalStopIds.last == candidate.stopId) {
          continue;
        }

        finalStopIds.add(candidate.stopId);
        usedCandidates[candidate.stopId] = candidate;
        lastDistanceKm = candidate.projectedDistanceKm;
      }
    }

    finalStopIds.add(majorProjections.last.stopId);
    final collapsedStopIds = _collapseAdjacentDuplicates(finalStopIds);
    if (collapsedStopIds.length < route.visibleStopIds.length) {
      return null;
    }

    final discoveredStops = usedCandidates.values
        .map(
          (candidate) => GoogleEnrichedStop(
            id: candidate.stopId,
            name: candidate.name,
            lat: candidate.lat,
            lng: candidate.lng,
            projectedDistanceKm: candidate.projectedDistanceKm,
            placeId: candidate.placeId,
          ),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.projectedDistanceKm.compareTo(b.projectedDistanceKm),
      );

    if (_stringListsEqual(collapsedStopIds, route.stopIds) &&
        discoveredStops.isEmpty) {
      return null;
    }

    return GoogleRouteEnrichmentResult(
      routeId: route.routeId,
      baseRoute: route.number,
      from: route.from,
      to: route.to,
      stopIds: collapsedStopIds,
      majorStopIds: route.visibleStopIds,
      discoveredStops: discoveredStops,
      encodedPolyline: encodedPolyline,
    );
  }

  void close() {
    _httpClient.close(force: true);
  }

  Future<String?> _computeRoutePolyline(List<BusStop> majorStops) async {
    final uri = Uri.https(
      'routes.googleapis.com',
      '/directions/v2:computeRoutes',
    );
    final intermediates = majorStops
        .sublist(1, math.max(majorStops.length - 1, 1))
        .map(
          (stop) => {
            'location': {
              'latLng': {
                'latitude': stop.lat,
                'longitude': stop.lng,
              },
            },
          },
        )
        .toList(growable: false);
    final payload = <String, Object?>{
      'origin': {
        'location': {
          'latLng': {
            'latitude': majorStops.first.lat,
            'longitude': majorStops.first.lng,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': majorStops.last.lat,
            'longitude': majorStops.last.lng,
          },
        },
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_UNAWARE',
      'computeAlternativeRoutes': false,
      'polylineQuality': 'HIGH_QUALITY',
      if (intermediates.isNotEmpty) 'intermediates': intermediates,
    };

    final response = await _postJson(
      uri,
      headers: {
        'X-Goog-Api-Key': routesApiKey,
        'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
      },
      payload: payload,
    );
    final routes = response['routes'];
    if (routes is! List || routes.isEmpty) {
      return null;
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map) {
      return null;
    }

    final polyline = firstRoute['polyline'];
    if (polyline is! Map) {
      return null;
    }

    return polyline['encodedPolyline'] as String?;
  }

  Future<List<_SearchCandidate>> _searchAlongRoute(
    String term,
    String encodedPolyline,
  ) async {
    final uri = Uri.https(
      'places.googleapis.com',
      '/v1/places:searchText',
    );
    final response = await _postJson(
      uri,
      headers: {
        'X-Goog-Api-Key': placesApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.types,places.primaryType',
      },
      payload: {
        'textQuery': '$term Visakhapatnam',
        'languageCode': 'en',
        'regionCode': 'IN',
        'maxResultCount': 20,
        'searchAlongRouteParameters': {
          'polyline': {
            'encodedPolyline': encodedPolyline,
          },
        },
      },
    );

    final places = response['places'];
    if (places is! List) {
      return const [];
    }

    final candidates = <_SearchCandidate>[];
    for (final place in places) {
      if (place is! Map) {
        continue;
      }

      final displayName = place['displayName'];
      final location = place['location'];
      if (displayName is! Map || location is! Map) {
        continue;
      }

      final name = displayName['text'] as String?;
      final lat = (location['latitude'] as num?)?.toDouble();
      final lng = (location['longitude'] as num?)?.toDouble();
      if (name == null || name.trim().isEmpty || lat == null || lng == null) {
        continue;
      }

      final types = (place['types'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[];
      candidates.add(
        _SearchCandidate(
          name: name.trim(),
          lat: lat,
          lng: lng,
          placeId: place['id'] as String? ?? '',
          types: types,
        ),
      );
    }

    return candidates;
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object?> payload,
  }) async {
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    request.write(jsonEncode(payload));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Google Maps Platform request failed '
        '(${response.statusCode}): $body',
        uri: uri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object response.');
    }
    return decoded;
  }

  String _resolveStopId({
    required _SearchCandidate candidate,
    required Map<String, BusStop> knownStopsById,
  }) {
    final normalizedId = VizagStops.canonicalStopIdForLabel(candidate.name);
    final canonicalStop = knownStopsById[normalizedId];
    if (canonicalStop != null &&
        (!canonicalStop.hasCoordinates ||
            _distanceKm(
                  canonicalStop.lat,
                  canonicalStop.lng,
                  candidate.lat,
                  candidate.lng,
                ) <=
                _existingStopMatchDistanceKm)) {
      return canonicalStop.id;
    }

    BusStop? nearestMatchingStop;
    var nearestDistanceKm = double.infinity;
    final normalizedName = _normalizeLabel(candidate.name);
    for (final stop in knownStopsById.values) {
      if (_normalizeLabel(stop.name) != normalizedName ||
          !stop.hasCoordinates) {
        continue;
      }
      final distanceKm =
          _distanceKm(stop.lat, stop.lng, candidate.lat, candidate.lng);
      if (distanceKm < nearestDistanceKm) {
        nearestMatchingStop = stop;
        nearestDistanceKm = distanceKm;
      }
    }
    if (nearestMatchingStop != null &&
        nearestDistanceKm <= _existingStopMatchDistanceKm) {
      return nearestMatchingStop.id;
    }

    final baseId =
        normalizedId.isEmpty ? _normalizeLabel(candidate.name) : normalizedId;
    var resolvedId = baseId.isEmpty ? 'generated_stop' : baseId;
    var suffix = 2;
    while (knownStopsById.containsKey(resolvedId)) {
      final existingStop = knownStopsById[resolvedId];
      if (existingStop == null ||
          !existingStop.hasCoordinates ||
          _distanceKm(
                existingStop.lat,
                existingStop.lng,
                candidate.lat,
                candidate.lng,
              ) <=
              _existingStopMatchDistanceKm) {
        return resolvedId;
      }
      resolvedId = '${baseId}_$suffix';
      suffix += 1;
    }
    return resolvedId;
  }

  bool _looksLikeTransitStop(_SearchCandidate candidate) {
    const transitTypes = {
      'bus_station',
      'transit_station',
      'train_station',
    };
    if (candidate.types.any(transitTypes.contains)) {
      return true;
    }

    final normalizedName = _normalizeLabel(candidate.name);
    return normalizedName.contains('junction') ||
        normalizedName.endsWith('jn') ||
        normalizedName.contains('bus_stop') ||
        normalizedName.contains('station') ||
        normalizedName.contains('complex') ||
        normalizedName.contains('circle') ||
        normalizedName.contains('x_road');
  }

  int _candidateScore(_ProjectedCandidate candidate) {
    final typeScore = candidate.types.any(
      (type) => type == 'bus_station' || type == 'transit_station',
    )
        ? 100
        : 0;
    final nameScore = _looksLikeTransitStop(
      _SearchCandidate(
        name: candidate.name,
        lat: candidate.lat,
        lng: candidate.lng,
        placeId: candidate.placeId,
        types: candidate.types,
      ),
    )
        ? 10
        : 0;
    return typeScore + nameScore;
  }

  List<_PolylinePoint> _decodePolyline(String encoded) {
    final points = <_PolylinePoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var result = 1;
      var shift = 0;
      var b = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 1;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(
        _PolylinePoint(
          lat / 1e5,
          lng / 1e5,
        ),
      );
    }

    return points;
  }

  _PolylineProjection? _projectToPolyline(
    List<_PolylinePoint> points,
    double lat,
    double lng,
  ) {
    if (points.length < 2) {
      return null;
    }

    _PolylineProjection? best;
    var travelledKm = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final segmentLengthKm =
          _distanceKm(start.lat, start.lng, end.lat, end.lng);
      if (segmentLengthKm <= 0) {
        continue;
      }

      final dx = end.lng - start.lng;
      final dy = end.lat - start.lat;
      final lengthSquared = (dx * dx) + (dy * dy);
      var progress = 0.0;
      if (lengthSquared > 0) {
        progress = (((lng - start.lng) * dx) + ((lat - start.lat) * dy)) /
            lengthSquared;
        progress = progress.clamp(0.0, 1.0);
      }

      final snappedLat = start.lat + (dy * progress);
      final snappedLng = start.lng + (dx * progress);
      final distanceFromPolylineKm =
          _distanceKm(lat, lng, snappedLat, snappedLng);
      final projection = _PolylineProjection(
        projectedDistanceKm: travelledKm + (segmentLengthKm * progress),
        distanceFromPolylineKm: distanceFromPolylineKm,
      );
      if (best == null ||
          projection.distanceFromPolylineKm < best.distanceFromPolylineKm) {
        best = projection;
      }
      travelledKm += segmentLengthKm;
    }
    return best;
  }

  List<String> _collapseAdjacentDuplicates(Iterable<String> stopIds) {
    final collapsed = <String>[];
    for (final stopId in stopIds) {
      if (stopId.isEmpty) {
        continue;
      }
      if (collapsed.isEmpty || collapsed.last != stopId) {
        collapsed.add(stopId);
      }
    }
    return collapsed;
  }

  bool _stringListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  String _normalizeLabel(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  double _distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180.0);
}

class _SearchCandidate {
  const _SearchCandidate({
    required this.name,
    required this.lat,
    required this.lng,
    required this.placeId,
    required this.types,
  });

  final String name;
  final double lat;
  final double lng;
  final String placeId;
  final List<String> types;
}

class _ProjectedCandidate {
  const _ProjectedCandidate({
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.projectedDistanceKm,
    required this.placeId,
    required this.types,
  });

  final String stopId;
  final String name;
  final double lat;
  final double lng;
  final double projectedDistanceKm;
  final String placeId;
  final List<String> types;
}

class _PolylinePoint {
  const _PolylinePoint(this.lat, this.lng);

  final double lat;
  final double lng;
}

class _PolylineProjection {
  const _PolylineProjection({
    required this.projectedDistanceKm,
    required this.distanceFromPolylineKm,
  });

  final double projectedDistanceKm;
  final double distanceFromPolylineKm;
}
