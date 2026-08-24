import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';

void main() {
  test('28K and 68K via hints are distinguishable', () {
    final a = VizagRoutes.byRouteId('28K')!;
    final b = VizagRoutes.byRouteId('68K')!;
    // ignore: avoid_print
    print('28K via: ${a.viaStops.join(", ")}');
    // ignore: avoid_print
    print('68K via: ${b.viaStops.join(", ")}');
    expect(a.viaStops, isNot(equals(b.viaStops)));
    expect(a.from, b.from);
    expect(a.to, b.to);
  });
}
