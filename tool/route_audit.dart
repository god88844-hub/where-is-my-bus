import 'dart:io';

import 'package:vizag_bus_live/data/vizag_data.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/route_audit.dart <route-number-or-id> [more selectors]',
    );
    exitCode = 64;
    return;
  }

  final seenRouteIds = <String>{};
  final matches = <BusRoute>[];

  for (final selector in args) {
    for (final route in _matchesForSelector(selector)) {
      if (seenRouteIds.add(route.routeId)) {
        matches.add(route);
      }
    }
  }

  if (matches.isEmpty) {
    stderr.writeln('No routes matched: ${args.join(', ')}');
    exitCode = 1;
    return;
  }

  for (var i = 0; i < matches.length; i++) {
    if (i > 0) {
      stdout.writeln('');
    }
    _printRoute(matches[i]);
  }
}

Iterable<BusRoute> _matchesForSelector(String selector) {
  final normalized = selector.trim().toLowerCase();
  return VizagRoutes.all.where((route) {
    return route.routeId.toLowerCase() == normalized ||
        route.number.toLowerCase() == normalized;
  });
}

void _printRoute(BusRoute route) {
  stdout.writeln(
      '${route.routeId} (${route.number}) ${route.from} -> ${route.to}');
  stdout.writeln(
    'major: ${route.visibleStopIds.length}, total: ${route.stopIds.length}, hiddenMinorStops: ${route.stopIds.length - route.visibleStopIds.length}',
  );

  for (final group in route.stopGroups) {
    final anchor = VizagStops.resolve(group.anchorStopId);
    stdout.writeln(
      '- ${anchor.name}${group.minorStopIds.isEmpty ? '' : ' [${group.minorStopIds.length} minor]'}',
    );
    for (final minorStopId in group.minorStopIds) {
      final stop = VizagStops.resolve(minorStopId);
      stdout.writeln('  * ${stop.name}');
    }
  }
}
