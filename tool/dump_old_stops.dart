import 'dart:convert';
import 'dart:io';

import 'package:vizag_bus_live/data/vizag_data.dart';

void main() {
  final stops = VizagStops.list
      .map((s) => {
            'id': s.id,
            'name': s.name,
            'nameTelugu': s.nameTelugu,
            'lat': s.lat,
            'lng': s.lng,
          })
      .toList();

  final seenNumbers = <String>{};
  final routes = <Map<String, dynamic>>[];
  for (final r in VizagRoutes.all) {
    if (!seenNumbers.add(r.number)) continue;
    routes.add({
      'number': r.number,
      'busType': r.busType.name,
      'frequencyMins': r.frequencyMins,
    });
  }

  File('tool/old_data_dump.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert({'stops': stops, 'routes': routes}),
  );
  stdout.writeln('dumped ${stops.length} stops, ${routes.length} route numbers');
}
