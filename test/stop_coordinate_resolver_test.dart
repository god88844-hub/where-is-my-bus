import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/services/stop_coordinate_resolver.dart';

void main() {
  group('BusStopCoordinateResolver', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('keeps existing coordinates without calling the fetcher', () async {
      final resolver = BusStopCoordinateResolver(
        fetcher: (_) async => throw StateError('fetcher should not be used'),
      );

      final stop = VizagStops.get('rtc_complex')!;
      final resolved = await resolver.resolveStop(stop);

      expect(resolved.lat, stop.lat);
      expect(resolved.lng, stop.lng);
    });

    test('hydrates missing coordinates and reuses the cached result', () async {
      var fetchCount = 0;
      final resolver = BusStopCoordinateResolver(
        fetcher: (_) async {
          fetchCount++;
          return {
            'lat': 17.777,
            'lng': 83.299,
          };
        },
      );

      const stop = BusStop(
        id: 'temporary_stop',
        name: 'Temporary Stop',
        nameTelugu: 'తాత్కాలిక స్టాప్',
        lat: 0,
        lng: 0,
      );

      final first = await resolver.resolveStop(stop);
      final second = await resolver.resolveStop(stop);

      expect(fetchCount, 1);
      expect(first.hasCoordinates, isTrue);
      expect(first.lat, 17.777);
      expect(first.lng, 83.299);
      expect(second.lat, first.lat);
      expect(second.lng, first.lng);
    });
  });
}
