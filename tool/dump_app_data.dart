import 'dart:convert';
import 'dart:io';

import 'package:vizag_bus_live/data/vizag_data.dart';

/// Dumps the app's live route/stop data to JSON for cross-checking against
/// the source Excel. Run: dart tool/dump_app_data.dart
void main() {
  final stops = VizagStops.list.map((s) => {
        'id': s.id,
        'name': s.name,
        'lat': s.lat,
        'lng': s.lng,
      }).toList();

  final routes = <Map<String, dynamic>>[];
  for (final r in VizagRoutes.primaryRoutes) {
    routes.add({
      'route_id': r.routeId,
      'number': r.number,
      'from': r.from,
      'to': r.to,
      'stops': r.stopIds
          .map((id) => {
                'id': id,
                'lat': VizagStops.get(id)?.lat ?? 0,
                'lng': VizagStops.get(id)?.lng ?? 0,
              })
          .toList(),
    });
  }

  File('tool/app_data_dump.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({'stops': stops, 'routes': routes}),
  );
  stdout.writeln('dumped ${stops.length} stops, ${routes.length} routes');
}
