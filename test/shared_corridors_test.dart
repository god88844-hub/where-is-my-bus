import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';

void main() {
  test('same from-to route groups are distinguishable', () {
    final groups = <String, List<BusRoute>>{};
    for (final r in VizagRoutes.primaryRoutes) {
      groups.putIfAbsent('${r.from} -> ${r.to}', () => []).add(r);
    }

    final shared = groups.entries.where((e) => e.value.length > 1).toList();
    // ignore: avoid_print
    print('SHARED-GROUPS-BEGIN');
    for (final g in shared) {
      final viaLists = g.value.map((r) => r.viaStops.take(3).join(',')).toSet();
      // ignore: avoid_print
      print('${g.key} :: ${g.value.map((r) => r.routeId).join(", ")}'
          ' | distinctVia=${viaLists.length}/${g.value.length}');
      for (final r in g.value) {
        // ignore: avoid_print
        print('   ${r.routeId}: ${r.viaStops.take(4).join(", ")}'
            ' (${r.stopIds.length} stops)');
      }
    }
    // ignore: avoid_print
    print('SHARED-GROUPS-END total=${shared.length}');
  });
}
