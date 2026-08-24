#!/usr/bin/env python3
"""Generate lib/data/vizag_data.dart from the master route Excel.

Source: docs/data/Route_Numbers_and_Stops.xlsx (single sheet, pairs of rows:
  row A: route number | 'FROM-TO' | stop names...
  row B: 'COORDINATES' |          | 'lat, lng' strings aligned to the same columns

Import decisions (confirmed by the project owner, 2026-08-24):
  - 222V: keep the first (43-stop) variant only.
  - 25E, 38R, 400R duplicate numbers: keep every entry as an independent route;
    the second occurrence gets route id '<NUMBER>-B' (public number unchanged).
  - The Excel fully replaces the previous hardcoded route/stop dataset.

Coordinate policy:
  - Same normalized stop name within 2 km  -> one canonical stop (first coords win).
  - Same name further apart than 2 km      -> split into distinct stops (id suffixed).
  - Stops without any coordinates are emitted with lat/lng 0 (hasCoordinates=false);
    the app already skips coordinate-less segments when snapping/ETA.

Run:  python tool/generate_vizag_data.py
"""

import json
import math
import re
from collections import OrderedDict
from datetime import datetime
import os.path

import openpyxl

HERE = os.path.dirname(__file__)
ROOT = os.path.dirname(HERE)
XLSX = os.path.join(ROOT, 'docs', 'data', 'Route_Numbers_and_Stops.xlsx')
OLD_DUMP = os.path.join(HERE, 'old_data_dump.json')
OUT_DART = os.path.join(ROOT, 'lib', 'data', 'vizag_data.dart')
OUT_REPORT = os.path.join(ROOT, 'docs', 'route_import_report.md')

# Owner confirmed: the Excel routes are served by BOTH ordinary and metro
# buses — the conductor picks the actual type per trip — so no route is
# type-bound and every route defaults to ordinary. Palle Velugu (green)
# service is planned but excluded for now.

SAME_STOP_MAX_KM = 2.0     # same name within this distance -> same stop
VARIANCE_REPORT_KM = 0.25  # report coordinate variance above this

# Spelling variants merged into one canonical stop.
# Every alias below was confirmed by identical/near-identical coordinates
# across the routes where both spellings occur.
ALIASES = {
    'GURUDWAR': 'GURUDWARA',
    'MADDILAPLEM': 'MADDILAPALEM',
    'PENDHURTHI': 'PENDURTHI',
    'PENDHURTHI JUNIOR COLLEGE': 'PENDURTHI JUNIOR COLLEGE',
    'COVENT JN': 'CONVENT JN',
    'KURMANPALEM': 'KURMANNAPALEM',
    'ANAKAPALLI BUS DIPOT': 'ANAKAPALLI BUS DEPOT',
    'BORAVANIPALEM': 'BORRAVANIPALEM',
    'OOTAGEDA': 'OOTAGEDDA',
    'PADMANABAM': 'PADMANABHAM',
    'PARWADA': 'PARAWADA',
    'DAKAMARRI': 'DAKAMAARI',
    'VIJAYRAMRAJUPETA': 'VIJAYARAMARAJUPETA',
    'VIJAYRAMARAJU PETA': 'VIJAYARAMARAJUPETA',
    'KOMMADI JUNCTION': 'KOMMADI',
    'PYDAH COLLEGE COLLEGE': 'PYDAH COLLEGE',
}


def normalize_name(name: str) -> str:
    n = name.upper().strip()
    n = n.replace('&', ' AND ')
    n = re.sub(r'[.\u00b7]', ' ', n)          # R.K.BEACH -> RK BEACH
    n = re.sub(r'SECTOR(\d)', r'SECTOR \1', n)
    n = re.sub(r'\s+', ' ', n).strip()
    return re.sub(r'[.\u00b7]+$', '', n).strip()


def haversine_km(lat1, lng1, lat2, lng2):
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def slugify(normalized: str) -> str:
    s = normalized.lower()
    s = re.sub(r'[^a-z0-9]+', '_', s)
    s = re.sub(r'_+', '_', s).strip('_')
    return s or 'stop'


def display_name(normalized: str) -> str:
    words = []
    for w in normalized.split(' '):
        if not w:
            continue
        words.append(w if len(w) <= 3 else w[0] + w[1:].lower())
    return ' '.join(words)


def route_id_for_number(number: str) -> str:
    s = re.sub(r'[^A-Z0-9]+', '_', number.strip().upper())
    return re.sub(r'_+', '_', s).strip('_')


# ---------------------------------------------------------------------------
# 1. Parse Excel
# ---------------------------------------------------------------------------

def parse_excel():
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    ws = wb[wb.sheetnames[0]]
    rows = list(ws.iter_rows(values_only=True))
    entries = []
    i = 0
    while i < len(rows):
        r = rows[i]
        if not r[0] or str(r[0]).strip().upper() == 'COORDINATES':
            i += 1
            continue
        number = str(r[0]).strip()
        coords_row = rows[i + 1] if i + 1 < len(rows) else []
        has_coords = bool(coords_row) and coords_row[0] is not None \
            and str(coords_row[0]).strip().upper() == 'COORDINATES'
        stops = []
        for c in range(2, len(r)):
            raw = r[c]
            if raw is None or not str(raw).strip():
                continue
            lat = lng = None
            if has_coords and c < len(coords_row) and coords_row[c]:
                parts = str(coords_row[c]).split(',')
                if len(parts) == 2:
                    try:
                        lat = float(parts[0].strip())
                        lng = float(parts[1].strip())
                    except ValueError:
                        pass
            stops.append({'raw': str(raw).strip(), 'lat': lat, 'lng': lng})
        entries.append({
            'number': number,
            'title': str(r[1]).strip() if r[1] else '',
            'stops': stops,
        })
        i += 2 if has_coords else 1
    return entries


# ---------------------------------------------------------------------------
# 2. Owner decisions + duplicate numbering
# ---------------------------------------------------------------------------

def apply_decisions(entries, report):
    kept = []
    seen_222v = 0
    for e in entries:
        if e['number'] == '222V':
            seen_222v += 1
            if seen_222v == 2:
                report['dropped_entries'].append(
                    "222V variant 2 (41 stops, ends 'VIZIANAGARAM.') dropped "
                    "per owner decision — 43-stop variant kept")
                continue
        kept.append(e)

    seen = {}
    for e in kept:
        n = e['number']
        seen[n] = seen.get(n, 0) + 1
        if seen[n] > 1:
            e['id_suffix'] = '-B'
            report['suffixed_ids'].append(
                f"{n} entry #{seen[n]} ({e['stops'][0]['raw']} -> "
                f"{e['stops'][-1]['raw']}) got route id "
                f"'{route_id_for_number(n)}-B'")
        else:
            e['id_suffix'] = ''
    return kept


# ---------------------------------------------------------------------------
# 3. Canonical stop registry with coordinate clustering
# ---------------------------------------------------------------------------

def build_stops(kept, old, report):
    old_by_norm = {}
    for s in old['stops']:
        old_by_norm.setdefault(normalize_name(s['name']), s)

    # resolve every occurrence to its canonical normalized name
    for e in kept:
        for s in e['stops']:
            n = normalize_name(s['raw'])
            s['norm'] = ALIASES.get(n, n)

    clusters = OrderedDict()
    for e in kept:
        for s in e['stops']:
            clusters.setdefault(s['norm'], []).append(s)

    stops = OrderedDict()
    norm_to_ids = {}
    for norm, occs in clusters.items():
        groups = []  # list of (lat, lng); group 0 is the primary
        group_variances = []  # (group_idx, lat, lng, dist_km) beyond report threshold
        for o in occs:
            if o['lat'] is None:
                o['group'] = 0
                continue
            if not groups:
                groups.append((o['lat'], o['lng']))
                o['group'] = 0
                continue
            # join the NEAREST existing group within the same-stop threshold
            best_gi, best_d = None, None
            for gi, (glat, glng) in enumerate(groups):
                d = haversine_km(glat, glng, o['lat'], o['lng'])
                if best_d is None or d < best_d:
                    best_gi, best_d = gi, d
            if best_d > SAME_STOP_MAX_KM:
                groups.append((o['lat'], o['lng']))
                o['group'] = len(groups) - 1
            else:
                o['group'] = best_gi
                if best_d > VARIANCE_REPORT_KM:
                    group_variances.append((best_gi, o['lat'], o['lng'], best_d))
        for gi, lat, lng, d in group_variances:
            glat, glng = groups[gi]
            report['coord_variances'].append(
                f"{norm}: occurrence ({lat:.5f}, {lng:.5f}) is {d * 1000:.0f} m "
                f"from group {gi} anchor ({glat:.5f}, {glng:.5f}) — anchor kept")

        old_stop = old_by_norm.get(norm)
        if not groups:
            # no occurrence anywhere has coordinates — still register the stop
            groups.append((None, None))
        ids = []
        for gi in range(len(groups)):
            base = slugify(norm)
            if gi == 0 and old_stop is not None and old_stop.get('id'):
                sid = old_stop['id']
            else:
                sid = base if gi == 0 else f'{base}_{gi + 1}'
            if sid in stops:
                sid = f'{base}_{gi + 1}'
            telugu = (old_stop or {}).get('nameTelugu') or ''
            stops[sid] = {
                'id': sid,
                'norm': norm,
                'name': display_name(norm),
                'nameTelugu': telugu,
                'lat': groups[gi][0],
                'lng': groups[gi][1],
            }
            ids.append(sid)

        norm_to_ids[norm] = ids
        if len(groups) > 1:
            report['split_stops'].append(
                f"{norm}: {len(groups)} distinct locations -> stop ids {ids}")

    for e in kept:
        for s in e['stops']:
            ids = norm_to_ids[s['norm']]
            if len(ids) == 1:
                s['stop_id'] = ids[0]
                continue
            # pick the location group closest to this occurrence's coords
            best, best_d = ids[0], None
            for sid in ids:
                st = stops[sid]
                if s['lat'] is None:
                    best, best_d = sid, 0.0
                    break
                d = haversine_km(st['lat'], st['lng'], s['lat'], s['lng'])
                if best_d is None or d < best_d:
                    best, best_d = sid, d
            s['stop_id'] = best
    return stops


# ---------------------------------------------------------------------------
# 4. Routes
# ---------------------------------------------------------------------------

def build_routes(kept, old, report):
    routes = []
    for e in kept:
        stop_ids = []
        for s in e['stops']:
            if stop_ids and stop_ids[-1] == s['stop_id']:
                continue
            stop_ids.append(s['stop_id'])
        if len(stop_ids) < 2:
            report['skipped_routes'].append(
                f"{e['number']}: fewer than 2 unique stops")
            continue

        seen_ids = {}
        for idx, sid in enumerate(stop_ids):
            seen_ids.setdefault(sid, []).append(idx)
        for sid, idxs in seen_ids.items():
            if len(idxs) > 1:
                report['repeated_stops'].append(
                    f"{e['number']}{e['id_suffix']}: stop '{sid}' appears at "
                    f"positions {idxs} (loop route?)")

        first, last = e['stops'][0], e['stops'][-1]
        routes.append({
            'route_id': route_id_for_number(e['number']) + e['id_suffix'],
            'number': e['number'],
            'from': display_name(first['norm']),
            'to': display_name(last['norm']),
            'from_norm': first['norm'],
            'to_norm': last['norm'],
            'stop_ids': stop_ids,
            'bus_type': 'redOrdinary',
            'frequency_mins': 20,
        })
    return routes


# ---------------------------------------------------------------------------
# 5. Emit Dart + report
# ---------------------------------------------------------------------------

def dart_str(value: str) -> str:
    return "'" + value.replace('\\', '\\\\').replace("'", "\\'") + "'"


def emit(stops, routes, old, report):
    old_by_norm = {}
    for s in old['stops']:
        old_by_norm.setdefault(normalize_name(s['name']), s)

    stop_lines = []
    for sid, st in stops.items():
        lat = st['lat'] if st['lat'] is not None else 0
        lng = st['lng'] if st['lng'] is not None else 0
        telugu = dart_str(st['nameTelugu']) if st['nameTelugu'] else "''"
        stop_lines.append(
            f"  {dart_str(sid)}: Stop(\n"
            f"    id: {dart_str(sid)},\n"
            f"    name: {dart_str(st['name'])},\n"
            f"    nameTelugu: {telugu},\n"
            f"    lat: {lat},\n"
            f"    lng: {lng},\n"
            f"  ),")

    alias_lines = [
        f'  {dart_str(a)}: {dart_str(b)},'
        for a, b in sorted(ALIASES.items()) if a != b
    ]

    route_lines = []
    for r in routes:
        telugu_from = (old_by_norm.get(r['from_norm']) or {}).get('nameTelugu') or ''
        telugu_to = (old_by_norm.get(r['to_norm']) or {}).get('nameTelugu') or ''
        # Evenly-spaced corridor sample: routes sharing the same from-to
        # (e.g. 28K vs 68K) then show visibly different via hints.
        middle = r['stop_ids'][1:-1]
        if len(middle) > 6:
            step = len(middle) / 6.0
            picks = sorted({min(int(i * step), len(middle) - 1) for i in range(6)})
            middle_sample = [middle[i] for i in picks]
        else:
            middle_sample = middle
        via_names = [stops[sid]['name'] for sid in middle_sample]
        ids_str = ',\n          '.join(dart_str(sid) for sid in r['stop_ids'])
        route_lines.append('    BusRoute(')
        route_lines.append(f"      routeId: {dart_str(r['route_id'])},")
        route_lines.append(f"      number: {dart_str(r['number'])},")
        route_lines.append(f"      from: {dart_str(r['from'])},")
        route_lines.append(f"      to: {dart_str(r['to'])},")
        if telugu_from:
            route_lines.append(f"      fromTelugu: {dart_str(telugu_from)},")
        if telugu_to:
            route_lines.append(f"      toTelugu: {dart_str(telugu_to)},")
        if via_names:
            via = ', '.join(dart_str(v) for v in via_names)
            route_lines.append(f'      viaStops: [{via}],')
        route_lines.append('      stopIds: [')
        route_lines.append(f'          {ids_str},')
        route_lines.append('        ],')
        # every Excel stop is owner-curated: all stops are major/visible
        route_lines.append('      majorStopIds: [')
        route_lines.append(f'          {ids_str},')
        route_lines.append('        ],')
        route_lines.append(f"      busType: BusType.{r['bus_type']},")
        route_lines.append(f"      frequencyMins: {r['frequency_mins']},")
        route_lines.append('    ),')

    content = DART_TEMPLATE.format(
        generated_at=datetime.now().strftime('%Y-%m-%d %H:%M'),
        route_count=len({r['number'] for r in routes}),
        total_directions=len(routes) * 2,
        stop_count=len(stops),
        no_coord_stops=sum(1 for s in stops.values() if s['lat'] is None),
        stop_entries='\n'.join(stop_lines),
        alias_entries='\n'.join(alias_lines),
        route_entries='\n'.join(route_lines),
    # Substitute Dart's '$' interpolation after .format() so Python does not
    # treat '{base.routeId}' as a placeholder.
    ).replace("'__REVERSE_ROUTE_ID_EXPR__'", "'${base.routeId}-R'")
    with open(OUT_DART, 'w', encoding='utf-8') as f:
        f.write(content)


def emit_report(stops, routes, report):
    lines = [
        '# Route data import report', '',
        'Source: `docs/data/Route_Numbers_and_Stops.xlsx`',
        f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M")}', '',
        f'Forward routes: **{len(routes)}** '
        f'({len({r["number"] for r in routes})} public numbers, '
        'each with an auto-generated reverse trip)',
        f'Canonical stops: **{len(stops)}** '
        f'({sum(1 for s in stops.values() if s["lat"] is None)} awaiting coordinates)',
        '',
    ]
    sections = [
        ('dropped_entries', 'Dropped entries (owner decision)'),
        ('suffixed_ids', 'Duplicate numbers kept as independent routes'),
        ('split_stops', 'Same stop name, distinct locations (split into separate stops)'),
        ('coord_variances', 'Coordinate variance within one stop (>250 m, anchor kept)'),
        ('repeated_stops', 'Routes visiting the same stop twice (review for loop routes)'),
        ('skipped_routes', 'Skipped entries'),
    ]
    for key, title in sections:
        if report[key]:
            lines += [f'## {title}', '']
            lines += [f'- {d}' for d in report[key]] + ['']
    no_coords = sorted(s['name'] for s in stops.values() if s['lat'] is None)
    lines += ['## Stops awaiting coordinates (name added, lat/lng = 0)', '']
    lines += [f'- {n}' for n in no_coords] + ['']
    lines += ['## Applied spelling aliases', '']
    lines += [f'- {a} -> {b}' for a, b in sorted(ALIASES.items()) if a != b] + ['']
    with open(OUT_REPORT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


# ---------------------------------------------------------------------------
# Dart template (class definitions preserved verbatim from the previous file)
# ---------------------------------------------------------------------------

DART_TEMPLATE = '''// lib/data/vizag_data.dart
// GENERATED FILE — do not edit by hand.
// Source: docs/data/Route_Numbers_and_Stops.xlsx
// Regenerate: python tool/generate_vizag_data.py
// Generated: {generated_at}
//
// {route_count} public route numbers ({total_directions} directional trips
// including auto-generated reverses), {stop_count} canonical stops
// ({no_coord_stops} awaiting coordinates — emitted with lat/lng 0).

// ─────────────────────────────────────────────────────────────
//  BUS TYPES
// ─────────────────────────────────────────────────────────────
enum BusType {{ redOrdinary, blueExpress, greenCity, ultraDeluxe, metroExpress }}

extension BusTypeExt on BusType {{
  String get label {{
    switch (this) {{
      case BusType.redOrdinary:
        return 'Red Ordinary';
      case BusType.blueExpress:
        return 'Blue Express';
      case BusType.greenCity:
        return 'Green City';
      case BusType.ultraDeluxe:
        return 'Ultra Deluxe';
      case BusType.metroExpress:
        return 'Metro Express';
    }}
  }}

  String get labelTelugu {{
    switch (this) {{
      case BusType.redOrdinary:
        return 'ఎర్ర సాధారణ';
      case BusType.blueExpress:
        return 'నీలి ఎక్స్‌ప్రెస్';
      case BusType.greenCity:
        return 'పచ్చ సిటీ';
      case BusType.ultraDeluxe:
        return 'అల్ట్రా డీలక్స్';
      case BusType.metroExpress:
        return 'మెట్రో ఎక్స్‌ప్రెస్';
    }}
  }}

  // Hex colour for bus icon
  int get colorValue {{
    switch (this) {{
      case BusType.redOrdinary:
        return 0xFFE24B4A;
      case BusType.blueExpress:
        return 0xFF185FA5;
      case BusType.greenCity:
        return 0xFF1D9E75;
      case BusType.ultraDeluxe:
        return 0xFF534AB7;
      case BusType.metroExpress:
        return 0xFF185FA5;
    }}
  }}
}}

// ─────────────────────────────────────────────────────────────
//  SERVICE TYPES IN OPERATION
// ─────────────────────────────────────────────────────────────
// The imported RTC network is served by Ordinary and Metro Express buses —
// the same route number may run with either, so the conductor selects the
// type per trip. Palle Velugu (green) is planned but excluded for now.
class BusTypes {{
  static const List<BusType> inService = [
    BusType.redOrdinary,
    BusType.metroExpress,
  ];
}}

// ─────────────────────────────────────────────────────────────
//  STOP GRAPH
// ─────────────────────────────────────────────────────────────
class Stop {{
  final String id;
  final String name;
  final String nameTelugu;
  final double lat;
  final double lng;

  const Stop({{
    required this.id,
    required this.name,
    required this.nameTelugu,
    required this.lat,
    required this.lng,
  }});

  bool get hasCoordinates => lat != 0 && lng != 0;

  Stop copyWith({{
    String? id,
    String? name,
    String? nameTelugu,
    double? lat,
    double? lng,
  }}) {{
    return Stop(
      id: id ?? this.id,
      name: name ?? this.name,
      nameTelugu: nameTelugu ?? this.nameTelugu,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }}

  Map<String, dynamic> toJson() => {{
        'id': id,
        'name': name,
        'nameTelugu': nameTelugu,
        'lat': lat,
        'lng': lng,
      }};

  factory Stop.fromJson(Map<String, dynamic> json) {{
    return Stop(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameTelugu: json['nameTelugu'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }}
}}

typedef BusStop = Stop;

class RouteStop {{
  const RouteStop({{
    required this.stopId,
    required this.sequence,
    this.isMajor = false,
  }});

  final String stopId;
  final int sequence;
  final bool isMajor;

  RouteStop copyWith({{
    String? stopId,
    int? sequence,
    bool? isMajor,
  }}) {{
    return RouteStop(
      stopId: stopId ?? this.stopId,
      sequence: sequence ?? this.sequence,
      isMajor: isMajor ?? this.isMajor,
    );
  }}
}}

// ─────────────────────────────────────────────────────────────
//  ROUTE
// ─────────────────────────────────────────────────────────────
class BusRoute {{
  final String id; // internal directional key
  final String baseRoute;
  final bool isForward;
  final String from;
  final String to;
  final String fromTelugu;
  final String toTelugu;
  final List<String> viaStops; // display only — intermediate landmarks
  final List<RouteStop> stops; // ordered stop refs
  final BusType busType;
  final int frequencyMins;
  // Directional route id to switch to when the conductor starts the return trip.
  // If omitted, the app auto-generates a reverse trip using the same public
  // route number.
  final String? returnRouteId;

  BusRoute({{
    String? id,
    String? routeId,
    String? baseRoute,
    String? number,
    bool? isForward,
    required this.from,
    required this.to,
    this.fromTelugu = '',
    this.toTelugu = '',
    this.viaStops = const [],
    List<RouteStop>? stops,
    List<String>? stopIds,
    List<String> majorStopIds = const [],
    this.busType = BusType.redOrdinary,
    this.frequencyMins = 20,
    String? returnRouteId,
    String? returnRouteNumber,
  }})  : assert(baseRoute != null || number != null),
        assert(stops != null || stopIds != null),
        assert(stops == null || stopIds == null),
        id = id ?? routeId ?? baseRoute ?? number!,
        baseRoute = baseRoute ?? number!,
        isForward = isForward ??
            !(id ?? routeId ?? baseRoute ?? number!).endsWith('-R'),
        stops = _buildRouteStops(
          stops: stops,
          stopIds: stopIds,
          majorStopIds: majorStopIds,
        ),
        returnRouteId = returnRouteId ?? returnRouteNumber;

  String get routeId => id;
  String get number => baseRoute;
  String? get returnRouteNumber => returnRouteId;

  static List<RouteStop> _buildRouteStops({{
    List<RouteStop>? stops,
    List<String>? stopIds,
    required List<String> majorStopIds,
  }}) {{
    if (stops != null) {{
      final sortedStops = [...stops]
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      final normalized = <RouteStop>[];
      for (final stop in sortedStops) {{
        final stopId = stop.stopId.trim();
        if (stopId.isEmpty) continue;
        if (normalized.isNotEmpty && normalized.last.stopId == stopId) {{
          final previous = normalized.removeLast();
          normalized.add(
            RouteStop(
              stopId: stopId,
              sequence: previous.sequence,
              isMajor: previous.isMajor || stop.isMajor,
            ),
          );
          continue;
        }}
        normalized.add(
          RouteStop(
            stopId: stopId,
            sequence: normalized.length,
            isMajor: stop.isMajor,
          ),
        );
      }}
      return List.unmodifiable(normalized);
    }}

    final majorSet = majorStopIds.toSet();
    final normalized = <RouteStop>[];
    for (final rawStopId in stopIds ?? const <String>[]) {{
      final stopId = rawStopId.trim();
      if (stopId.isEmpty) continue;
      if (normalized.isNotEmpty && normalized.last.stopId == stopId) {{
        final previous = normalized.removeLast();
        normalized.add(
          RouteStop(
            stopId: stopId,
            sequence: previous.sequence,
            isMajor: previous.isMajor || majorSet.contains(stopId),
          ),
        );
        continue;
      }}
      normalized.add(
        RouteStop(
          stopId: stopId,
          sequence: normalized.length,
          isMajor: majorSet.contains(stopId),
        ),
      );
    }}
    return List.unmodifiable(normalized);
  }}

  late final List<RouteStop> orderedStops = List.unmodifiable(
    [...stops]..sort((a, b) => a.sequence.compareTo(b.sequence)),
  );

  late final List<String> stopIds =
      List.unmodifiable(orderedStops.map((stop) => stop.stopId));

  late final List<String> majorStopIds = List.unmodifiable(() {{
    final majorStopIds = <String>[];
    final seenStopIds = <String>{{}};
    for (final stop in orderedStops) {{
      if (!stop.isMajor || !seenStopIds.add(stop.stopId)) continue;
      majorStopIds.add(stop.stopId);
    }}
    return majorStopIds;
  }}());

  String get displayName => '$baseRoute: $from → $to';
  String get viaLabel => viaStops.isEmpty ? '' : 'via ${{viaStops.join(', ')}}';

  // Compatibility getters used by screens/widgets
  String get name => '$from → $to';
  String get nameTelugu => fromTelugu.isNotEmpty && toTelugu.isNotEmpty
      ? '$fromTelugu → $toTelugu'
      : '$from → $to';
  String get origin => stopIds.firstOrNull ?? '';
  String get terminus => stopIds.lastOrNull ?? '';
  List<String> get visibleStopIds {{
    if (majorStopIds.isEmpty) return stopIds;

    final visible = <String>[];
    final majorSet = majorStopIds.toSet();
    for (final stopId in stopIds) {{
      if (majorSet.contains(stopId) && !visible.contains(stopId)) {{
        visible.add(stopId);
      }}
    }}

    return visible.isEmpty ? stopIds : visible;
  }}

  bool get hasHiddenSubStops => visibleStopIds.length < stopIds.length;

  RouteStop? stopRef(String stopId) =>
      orderedStops.where((stop) => stop.stopId == stopId).firstOrNull;

  List<String> stopIdsBetween(String fromStopId, String toStopId) {{
    final fromIndex = stopIds.indexOf(fromStopId);
    final toIndex = stopIds.indexOf(toStopId);
    if (fromIndex < 0 || toIndex < fromIndex) return const [];
    return stopIds.sublist(fromIndex, toIndex + 1);
  }}

  List<String> visibleStopIdsBetween(String fromStopId, String toStopId) {{
    final segment = stopIdsBetween(fromStopId, toStopId);
    if (segment.isEmpty) return const [];

    final visibleSet = visibleStopIds.toSet();
    final visibleSegment = <String>[segment.first];
    if (segment.length > 2) {{
      for (final stopId in segment.sublist(1, segment.length - 1)) {{
        if (visibleSet.contains(stopId) && !visibleSegment.contains(stopId)) {{
          visibleSegment.add(stopId);
        }}
      }}
    }}
    if (segment.length > 1 && visibleSegment.last != segment.last) {{
      visibleSegment.add(segment.last);
    }}

    return visibleSegment;
  }}

  List<RouteStopGroup> get stopGroups {{
    final anchors = visibleStopIds;
    if (stopIds.isEmpty) return const [];
    if (anchors.isEmpty) {{
      return [
        RouteStopGroup(
          anchorStopId: stopIds.first,
          startIndex: 0,
          stopIds: stopIds,
        ),
      ];
    }}

    final groups = <RouteStopGroup>[];
    for (var i = 0; i < anchors.length; i++) {{
      final anchorStopId = anchors[i];
      final startIndex = stopIds.indexOf(anchorStopId);
      if (startIndex < 0) continue;

      final nextAnchorIndex = i == anchors.length - 1
          ? stopIds.length
          : stopIds.indexOf(anchors[i + 1]);
      final endExclusive =
          nextAnchorIndex <= startIndex ? startIndex + 1 : nextAnchorIndex;

      groups.add(
        RouteStopGroup(
          anchorStopId: anchorStopId,
          startIndex: startIndex,
          stopIds: stopIds.sublist(startIndex, endExclusive),
        ),
      );
    }}

    return groups.isEmpty
        ? [
            RouteStopGroup(
              anchorStopId: stopIds.first,
              startIndex: 0,
              stopIds: stopIds,
            ),
          ]
        : groups;
  }}
}}

class RouteStopGroup {{
  const RouteStopGroup({{
    required this.anchorStopId,
    required this.startIndex,
    required this.stopIds,
  }});

  final String anchorStopId;
  final int startIndex;
  final List<String> stopIds;

  List<String> get minorStopIds =>
      stopIds.length <= 1 ? const [] : stopIds.sublist(1);

  bool get hasMinorStops => stopIds.length > 1;
}}

// ─────────────────────────────────────────────────────────────
//  GENERATED STOP REGISTRY
// ─────────────────────────────────────────────────────────────
const Map<String, Stop> _kStops = {{
{stop_entries}
}};

// Spelling variants merged into canonical stops (kept for search/lookup).
const Map<String, String> _kStopAliases = {{
{alias_entries}
}};

// ─────────────────────────────────────────────────────────────
//  GENERATED ROUTE DATA (forward direction; reverses auto-generated)
// ─────────────────────────────────────────────────────────────
final List<BusRoute> _kRoutes = [
{route_entries}
];

// ─────────────────────────────────────────────────────────────
//  STOP REGISTRY API
// ─────────────────────────────────────────────────────────────
class VizagStops {{
  static const Map<String, BusStop> all = _kStops;

  static BusStop? get(String id) => all[id];

  static String normalizeStopToken(String label) {{
    var n = label.toUpperCase().trim();
    n = n.replaceAll('&', ' AND ');
    n = n.replaceAll('.', ' ');
    n = n.replaceAll(RegExp(r'SECTOR(\\d)'), r'SECTOR \\1');
    n = n.replaceAll(RegExp(r'\\s+'), ' ').trim();
    return n;
  }}

  static String canonicalStopIdForLabel(String label) {{
    final norm = normalizeStopToken(label);
    final aliased = _kStopAliases[norm] ?? norm;
    return slugifyStopToken(aliased);
  }}

  static String slugifyStopToken(String normalized) {{
    var s = normalized.toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.startsWith('_')) s = s.substring(1);
    if (s.endsWith('_')) s = s.substring(0, s.length - 1);
    return s.isEmpty ? 'stop' : s;
  }}

  static BusStop resolve(
    String? id, {{
    String? fallbackName,
    String fallbackTelugu = '',
  }}) {{
    final resolvedId = id?.trim() ?? '';
    final existing = all[resolvedId];
    if (existing != null) return existing;

    return BusStop(
      id: resolvedId.isEmpty ? 'unknown_stop' : resolvedId,
      name: fallbackName?.trim().isNotEmpty == true
          ? fallbackName!.trim()
          : _formatIdAsName(resolvedId),
      nameTelugu: fallbackTelugu,
      lat: 0,
      lng: 0,
    );
  }}

  static String label(String? id, {{String? fallbackName}}) =>
      resolve(id, fallbackName: fallbackName).name;

  static String labelTelugu(String? id, {{String fallback = ''}}) {{
    final resolved = id?.trim() ?? '';
    return all[resolved]?.nameTelugu ?? fallback;
  }}

  static String _formatIdAsName(String id) {{
    final cleaned = id.trim();
    if (cleaned.isEmpty) return 'Unknown stop';

    return cleaned
        .split(RegExp(r'[ _-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {{
      if (part.length <= 3) {{
        return part.toUpperCase();
      }}
      return '${{part[0].toUpperCase()}}${{part.substring(1)}}';
    }}).join(' ');
  }}

  static List<BusStop> get list => all.values.toList();

  // Search stops by name (English or Telugu)
  static List<BusStop> search(String query) {{
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return list;
    return list
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.nameTelugu.contains(q) ||
            s.id.contains(q))
        .toList();
  }}
}}

// ─────────────────────────────────────────────────────────────
//  ALL ROUTES
// ─────────────────────────────────────────────────────────────
class VizagRoutes {{
  static final List<BusRoute> all = _generateAllRoutes();

  static List<BusRoute> _generateAllRoutes() {{
    final routes = <BusRoute>[];
    for (final base in _kRoutes) {{
      // Standard routes can always be reversed by the conductor. When a route
      // does not define an explicit return route id, generate one and link the
      // forward and reverse trips to each other.
      if (base.returnRouteNumber == null &&
          !base.routeId.endsWith('-R') &&
          !base.number.endsWith('-R')) {{
        final reverseRouteId = '__REVERSE_ROUTE_ID_EXPR__';
        final forwardRoute = BusRoute(
          routeId: base.routeId,
          number: base.number,
          from: base.from,
          to: base.to,
          fromTelugu: base.fromTelugu,
          toTelugu: base.toTelugu,
          viaStops: base.viaStops,
          stopIds: base.stopIds,
          majorStopIds: base.visibleStopIds,
          busType: base.busType,
          frequencyMins: base.frequencyMins,
          returnRouteNumber: reverseRouteId,
        );
        routes.add(forwardRoute);
        routes.add(BusRoute(
          routeId: reverseRouteId,
          number: base.number,
          from: base.to,
          to: base.from,
          fromTelugu: base.toTelugu,
          toTelugu: base.fromTelugu,
          viaStops: base.viaStops.reversed.toList(),
          stopIds: base.stopIds.reversed.toList(),
          majorStopIds: base.visibleStopIds.reversed.toList(),
          busType: base.busType,
          frequencyMins: base.frequencyMins,
          returnRouteNumber: forwardRoute.routeId,
        ));
        continue;
      }}

      routes.add(base);
    }}
    return routes;
  }}

  static BusRoute? byRouteId(String routeId) =>
      all.where((r) => r.routeId == routeId).firstOrNull;

  static BusRoute? byNumber(String n) =>
      all.where((r) => r.number == n).firstOrNull;

  static List<BusRoute> get primaryRoutes =>
      all.where((route) => !route.routeId.endsWith('-R')).toList();

  static List<BusRoute> get passengerRoutes {{
    final seen = <String>{{}};
    return all.where((route) => seen.add(route.number)).toList();
  }}

  static List<BusRoute> servingStop(String stopId) =>
      all.where((r) => r.stopIds.contains(stopId)).toList();

  // Search routes by number or stop name
  static List<BusRoute> search(String query) {{
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return all;
    return all
        .where((r) =>
            r.number.toLowerCase().contains(q) ||
            r.from.toLowerCase().contains(q) ||
            r.to.toLowerCase().contains(q) ||
            r.viaStops.any((v) => v.toLowerCase().contains(q)))
        .toList();
  }}
}}
'''

# ---------------------------------------------------------------------------


def main():
    report = {k: [] for k in [
        'dropped_entries', 'suffixed_ids', 'split_stops',
        'coord_variances', 'repeated_stops', 'skipped_routes']}
    entries = parse_excel()
    with open(OLD_DUMP, encoding='utf-8') as f:
        old = json.load(f)
    kept = apply_decisions(entries, report)
    stops = build_stops(kept, old, report)
    routes = build_routes(kept, old, report)
    emit(stops, routes, old, report)
    emit_report(stops, routes, report)
    print(f'routes: {len(routes)} ({len({r["number"] for r in routes})} numbers)')
    print(f'stops: {len(stops)} '
          f'({sum(1 for s in stops.values() if s["lat"] is None)} without coordinates)')
    print(f'wrote {OUT_DART}')
    print(f'wrote {OUT_REPORT}')


if __name__ == '__main__':
    main()
