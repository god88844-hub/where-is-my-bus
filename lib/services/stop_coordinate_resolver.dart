import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/vizag_data.dart';

typedef CoordinateLookup = Future<Map<String, double>?> Function(String place);

class SmartGeoService {
  SmartGeoService._();

  static const String apiKey =
      String.fromEnvironment('GOOGLE_MAPS_GEOCODE_API_KEY');

  static Future<Map<String, double>?> fetch(String place) async {
    final query = place.trim();
    if (query.isEmpty || apiKey.isEmpty) {
      return null;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': '$query,Visakhapatnam',
        'key': apiKey,
      },
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final results = data['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }

      final firstResult = results.first;
      if (firstResult is! Map) {
        return null;
      }

      final geometry = firstResult['geometry'];
      if (geometry is! Map) {
        return null;
      }

      final location = geometry['location'];
      if (location is! Map) {
        return null;
      }

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return null;
      }

      return {
        'lat': lat,
        'lng': lng,
      };
    } catch (e) {
      debugPrint('SmartGeoService.fetch("$place") failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class BusStopCoordinateCache {
  BusStopCoordinateCache._();

  static const _cachePrefix = 'bus_stop_coordinate_cache:';

  static Future<BusStop?> loadFromCache(String stopId) async {
    final cacheKey = _cacheKey(stopId);
    if (cacheKey == null) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      return BusStop.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('BusStopCoordinateCache: corrupt cache entry for $stopId: $e');
      return null;
    }
  }

  static Future<void> saveToCache(BusStop stop) async {
    if (!stop.hasCoordinates) {
      return;
    }

    final cacheKey = _cacheKey(stop.id);
    if (cacheKey == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, jsonEncode(stop.toJson()));
  }

  static String? _cacheKey(String stopId) {
    final normalized = stopId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return '$_cachePrefix$normalized';
  }
}

class BusStopCoordinateResolver {
  const BusStopCoordinateResolver({
    CoordinateLookup? fetcher,
  }) : _fetcher = fetcher ?? SmartGeoService.fetch;

  final CoordinateLookup _fetcher;

  Future<BusStop> resolveStop(BusStop stop) async {
    if (stop.hasCoordinates) {
      return stop;
    }

    final cached = await BusStopCoordinateCache.loadFromCache(stop.id);
    if (cached != null && cached.hasCoordinates) {
      return stop.copyWith(
        lat: cached.lat,
        lng: cached.lng,
      );
    }

    final coords = await _fetcher(stop.name);
    final lat = coords?['lat'];
    final lng = coords?['lng'];
    if (lat == null || lng == null) {
      return stop;
    }

    final updated = stop.copyWith(
      lat: lat,
      lng: lng,
    );
    await BusStopCoordinateCache.saveToCache(updated);
    return updated;
  }
}
