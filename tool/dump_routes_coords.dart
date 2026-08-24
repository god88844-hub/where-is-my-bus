import 'dart:convert';
import 'dart:io';

import 'package:vizag_bus_live/data/vizag_data.dart';

void main() {
  final List<Map<String, dynamic>> output = [];

  for (final route in VizagRoutes.all) {
    final List<Map<String, dynamic>> stops = [];
    for (final stopId in route.stopIds) {
      try {
        final stop = VizagStops.resolve(stopId);
        stops.add({
          'id': stop.id,
          'name': stop.name,
          'lat': stop.lat,
          'lng': stop.lng,
        });
      } catch (e) {
        stops.add({
          'id': stopId,
          'name': stopId,
          'lat': 0.0,
          'lng': 0.0,
        });
      }
    }

    output.add({
      'routeId': route.routeId,
      'number': route.number,
      'from': route.from,
      'to': route.to,
      'stops': stops,
    });
  }

  final jsonStr = jsonEncode(output);
  final file = File('route_coords_dump.json');
  file.writeAsStringSync(jsonStr);
  print('Successfully dumped ${output.length} routes to route_coords_dump.json');
}
