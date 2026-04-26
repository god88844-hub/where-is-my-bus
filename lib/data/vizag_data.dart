// lib/data/vizag_data.dart
// Complete Vizag APSRTC route database — 80+ routes, 81 canonical stops
// Stop coordinates are approximate based on known Vizag geography.
// Verify key stops on the ground and update lat/lng as needed.

import 'osm_route_enrichment_data.dart';

// ─────────────────────────────────────────────────────────────
//  BUS TYPES
// ─────────────────────────────────────────────────────────────
enum BusType { redOrdinary, blueExpress, greenCity, ultraDeluxe, metroExpress }

extension BusTypeExt on BusType {
  String get label {
    switch (this) {
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
    }
  }

  String get labelTelugu {
    switch (this) {
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
    }
  }

  // Hex colour for bus icon
  int get colorValue {
    switch (this) {
      case BusType.redOrdinary:
        return 0xFFE24B4A;
      case BusType.blueExpress:
        return 0xFF185FA5;
      case BusType.greenCity:
        return 0xFF1D9E75;
      case BusType.ultraDeluxe:
        return 0xFF534AB7;
      case BusType.metroExpress:
        return 0xFFBA7517;
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  STOP
// ─────────────────────────────────────────────────────────────
class BusStop {
  final String id;
  final String name;
  final String nameTelugu;
  final double lat;
  final double lng;

  const BusStop({
    required this.id,
    required this.name,
    required this.nameTelugu,
    required this.lat,
    required this.lng,
  });

  bool get hasCoordinates => lat != 0 && lng != 0;

  BusStop copyWith({
    String? id,
    String? name,
    String? nameTelugu,
    double? lat,
    double? lng,
  }) {
    return BusStop(
      id: id ?? this.id,
      name: name ?? this.name,
      nameTelugu: nameTelugu ?? this.nameTelugu,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameTelugu': nameTelugu,
        'lat': lat,
        'lng': lng,
      };

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameTelugu: json['nameTelugu'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ROUTE
// ─────────────────────────────────────────────────────────────
class BusRoute {
  final String routeId; // internal directional key
  final String number;
  final String from;
  final String to;
  final String fromTelugu;
  final String toTelugu;
  final List<String> viaStops; // display only — intermediate landmarks
  final List<String> stopIds; // full ordered stop IDs, including minor stops
  final List<String> majorStopIds; // default visible timeline stops
  final BusType busType;
  final int frequencyMins;
  // Directional route id to switch to when the conductor starts the return trip.
  // If omitted, the app auto-generates a reverse trip using the same public
  // route number.
  final String? returnRouteNumber;

  const BusRoute({
    String? routeId,
    required this.number,
    required this.from,
    required this.to,
    this.fromTelugu = '',
    this.toTelugu = '',
    this.viaStops = const [],
    required this.stopIds,
    this.majorStopIds = const [],
    this.busType = BusType.redOrdinary,
    this.frequencyMins = 20,
    this.returnRouteNumber,
  }) : routeId = routeId ?? number;

  String get displayName => '$number: $from → $to';
  String get viaLabel => viaStops.isEmpty ? '' : 'via ${viaStops.join(', ')}';

  // Compatibility getters used by screens/widgets
  String get name => '$from → $to';
  String get nameTelugu => fromTelugu.isNotEmpty && toTelugu.isNotEmpty
      ? '$fromTelugu → $toTelugu'
      : '$from → $to';
  String get origin => stopIds.firstOrNull ?? '';
  String get terminus => stopIds.lastOrNull ?? '';
  List<String> get visibleStopIds {
    if (majorStopIds.isEmpty) return stopIds;

    final visible = <String>[];
    final majorSet = majorStopIds.toSet();
    for (final stopId in stopIds) {
      if (majorSet.contains(stopId) && !visible.contains(stopId)) {
        visible.add(stopId);
      }
    }

    return visible.isEmpty ? stopIds : visible;
  }

  bool get hasHiddenSubStops => visibleStopIds.length < stopIds.length;

  List<String> stopIdsBetween(String fromStopId, String toStopId) {
    final fromIndex = stopIds.indexOf(fromStopId);
    final toIndex = stopIds.indexOf(toStopId);
    if (fromIndex < 0 || toIndex < fromIndex) return const [];
    return stopIds.sublist(fromIndex, toIndex + 1);
  }

  List<String> visibleStopIdsBetween(String fromStopId, String toStopId) {
    final segment = stopIdsBetween(fromStopId, toStopId);
    if (segment.isEmpty) return const [];

    final visibleSet = visibleStopIds.toSet();
    final visibleSegment = <String>[segment.first];
    if (segment.length > 2) {
      for (final stopId in segment.sublist(1, segment.length - 1)) {
        if (visibleSet.contains(stopId) && !visibleSegment.contains(stopId)) {
          visibleSegment.add(stopId);
        }
      }
    }
    if (segment.length > 1 && visibleSegment.last != segment.last) {
      visibleSegment.add(segment.last);
    }

    return visibleSegment;
  }

  List<RouteStopGroup> get stopGroups {
    final anchors = visibleStopIds;
    if (stopIds.isEmpty) return const [];
    if (anchors.isEmpty) {
      return [
        RouteStopGroup(
          anchorStopId: stopIds.first,
          startIndex: 0,
          stopIds: stopIds,
        ),
      ];
    }

    final groups = <RouteStopGroup>[];
    for (var i = 0; i < anchors.length; i++) {
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
    }

    return groups.isEmpty
        ? [
            RouteStopGroup(
              anchorStopId: stopIds.first,
              startIndex: 0,
              stopIds: stopIds,
            ),
          ]
        : groups;
  }
}

class RouteStopGroup {
  const RouteStopGroup({
    required this.anchorStopId,
    required this.startIndex,
    required this.stopIds,
  });

  final String anchorStopId;
  final int startIndex;
  final List<String> stopIds;

  List<String> get minorStopIds =>
      stopIds.length <= 1 ? const [] : stopIds.sublist(1);

  bool get hasMinorStops => stopIds.length > 1;
}

class _StopArea {
  const _StopArea(this.lat, this.lng);

  final double lat;
  final double lng;
}

class _ExactStopCoordinate {
  const _ExactStopCoordinate(this.lat, this.lng);

  final double lat;
  final double lng;
}

class _ManualRouteSpec {
  const _ManualRouteSpec({
    required this.routeId,
    required this.number,
    required this.majorStopLabels,
    required this.stopLabels,
  });

  factory _ManualRouteSpec.parse(String source) {
    final parts = source.split('|');
    if (parts.length != 3) {
      throw FormatException(
        'Manual route source must be routeId|number|stop -> stop',
        source,
      );
    }

    final stopLabels = parts[2]
        .split('->')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    if (stopLabels.length < 2) {
      throw FormatException(
        'Manual route must include at least two stops',
        source,
      );
    }

    return _ManualRouteSpec(
      routeId: parts[0].trim(),
      number: parts[1].trim(),
      majorStopLabels: stopLabels,
      stopLabels: stopLabels,
    );
  }

  final String routeId;
  final String number;
  final List<String> majorStopLabels;
  final List<String> stopLabels;
}

String _normalizeManualStopToken(String label) => label
    .trim()
    .toLowerCase()
    .replaceAll('&', ' and ')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

const Map<String, String> _manualStopIdAliases = {
  'aganampudi': 'aganampudi',
  'airport': 'airport',
  'air_port': 'airport',
  'anakapalli': 'anakapalli',
  'anakapalle': 'anakapalli',
  'arilova': 'arilova',
  'arilova_colony': 'arilova',
  'carshed': 'carshed',
  'chodavaram': 'chodavaram',
  'collector_office': 'collector_office',
  'co_office': 'collector_office',
  'co_off': 'collector_office',
  'bheemili_x_road': 'bheemili_x_road',
  'c_office': 'collector_office',
  'car_shed': 'carshed',
  'col_office': 'collector_office',
  'col_off': 'collector_office',
  'convent': 'convent_junction',
  'convent_jn': 'convent_junction',
  'conventjn': 'convent_junction',
  'baji_jn': 'baji_junction',
  'devarapalli': 'devarapalli',
  'duvvada': 'duvvada',
  'endada': 'endada',
  'estate': 'industrial_estate',
  'gajuwaka': 'gajuwaka',
  'gangavaram': 'gangavaram',
  'gopalpatnam': 'gopalapatnam',
  'gopalapatnam': 'gopalapatnam',
  'gurudwar': 'gurudwara',
  'gurudwara': 'gurudwara',
  'gurudwara_jn': 'gurudwara',
  'hanumanthuwaka': 'hanumanthawaka',
  'i_estate': 'industrial_estate',
  'jagadamba': 'jagadamba',
  'kancharapalam': 'kancharapalem',
  'kancharapalem': 'kancharapalem',
  'kommadi': 'kommadi',
  'kothavalasa': 'kothavalasa',
  'kurmannapalem': 'kurmannapalem',
  'kurmanapalem': 'kurmannapalem',
  'maddilapalem': 'maddilapalem',
  'madhurawada': 'madhurawada',
  'malkapuram': 'malkapuram',
  'marripalam': 'marripalem',
  'nad': 'nad_junction',
  'nad_jn': 'nad_junction',
  'nad_junction': 'nad_junction',
  'nad_x_road': 'nad_junction',
  'old_post_office': 'old_post_office',
  'old_bus_stand': 'town_kotharoad',
  'old_bustand': 'town_kotharoad',
  'ohpo': 'old_post_office',
  'o_h_p_o': 'old_post_office',
  'parawada': 'parawada',
  'pendurthi': 'pendurthi',
  'pendurthy': 'pendurthi',
  'purna_market': 'purna_market',
  'poornamarket': 'purna_market',
  'prn_market': 'purna_market',
  'purushotapuram': 'purushottapuram',
  'purushottapuram_sml': 'purushottapuram',
  'railway_station': 'railway_station',
  'rly_station': 'railway_station',
  'rk_beach': 'rk_beach',
  'r_k_beach': 'rk_beach',
  'rkbh': 'rk_beach',
  'rama_talkies': 'rama_talkies',
  'rtc_complex': 'rtc_complex',
  'sabbavaram': 'sabbavaram',
  'scindia': 'scindia',
  'sheelanagar': 'sheelanagar',
  'simhachalam': 'simhachalam',
  'simhachalam_hill': 'simhachalam_hilltop',
  'sujatha_nagar': 'sujatha_nagar',
  'sujathanagar': 'sujatha_nagar',
  'sujatanagar': 'sujatha_nagar',
  'sml_hill': 'simhachalam_hilltop',
  'siripuram': 'siripuram',
  'tagarapuvalasa_junction': 'tagarapuvalasa',
  'tagarapuvalasa_town': 'tagarapuvalasa',
  'chinna_mushidivada': 'chinnamushidivada',
  'chinamushidvada': 'chinnamushidivada',
  'chinamushidivada': 'chinnamushidivada',
  'chinnamusidivada': 'chinnamushidivada',
  'tagarapuvalasa': 'tagarapuvalasa',
  'vepagunta': 'vepagunta',
  'venkojipalem': 'venkojipalem',
  'vizianagaram': 'vizianagaram',
  'vizainagaram': 'vizianagaram',
  'vijayanagaram': 'vizianagaram',
  'vuda_park': 'vuda_park',
  'waltair': 'waltair',
  'yarada': 'yarada',
  'yarada_beach': 'yarada',
  'yelamanchili': 'yelamanchili',
  'zoo_park': 'vizag_zoo',
};

String _manualStopIdForLabel(String label) {
  final normalized = _normalizeManualStopToken(label);
  return _manualStopIdAliases[normalized] ?? normalized;
}

String _importedStopIdForLabel(String label) {
  final normalized = _normalizeManualStopToken(label);
  return _resolveImportedStopId(normalized) ?? normalized;
}

String? _resolveImportedStopId(String token) {
  if (token.isEmpty) return null;

  final explicit = osmImportedStopAliases[token];
  if (explicit != null) return explicit;

  final manual = _manualStopIdAliases[token];
  if (manual != null) return manual;

  if (token.startsWith('apsrtc_bus_station_')) {
    return _resolveImportedStopId(
        token.substring('apsrtc_bus_station_'.length));
  }
  if (token.startsWith('apsrtc_bus_stand_')) {
    return _resolveImportedStopId(token.substring('apsrtc_bus_stand_'.length));
  }
  if (token.startsWith('apsrtc_city_bus_stop_')) {
    return _resolveImportedStopId(
        token.substring('apsrtc_city_bus_stop_'.length));
  }
  if (token.startsWith('apsrtc_complex_')) {
    return 'rtc_complex';
  }
  if (token.endsWith('_junction_bus_stop')) {
    return _resolveImportedStopId(
      token.substring(0, token.length - '_junction_bus_stop'.length),
    );
  }
  if (token.endsWith('_bus_stop')) {
    return _resolveImportedStopId(
      token.substring(0, token.length - '_bus_stop'.length),
    );
  }
  if (token.endsWith('_junction')) {
    return _resolveImportedStopId(
      token.substring(0, token.length - '_junction'.length),
    );
  }
  if (token.endsWith('_town')) {
    return _resolveImportedStopId(
      token.substring(0, token.length - '_town'.length),
    );
  }

  return null;
}

final List<_ManualRouteSpec> _manualDepotRouteSpecs = [
  // To add hidden sub-stops later, replace a `.parse(...)` entry with an
  // explicit `_ManualRouteSpec(...)` and keep `majorStopLabels` shorter than
  // `stopLabels`. `stopLabels` should contain the full travel path in order.
  const _ManualRouteSpec(
    routeId: '222',
    number: '222',
    majorStopLabels: [
      'RTC Complex',
      'MVP Colony',
      'Hanumanthawaka',
      'Madhurawada',
      'Anandapuram',
      'Tagarapuvalasa',
    ],
    stopLabels: [
      'RTC Complex',
      'Rama Talkies',
      'MVP Colony',
      'Venkojipalem',
      'Hanumanthawaka',
      'Old Dairy Farm',
      'Vizag Zoo',
      'Endada',
      'Carshed',
      'Madhurawada',
      'Kommadi',
      'Marikavalasa',
      'Boravanipalem',
      'Paradesipalem',
      'Boyapalem',
      'Pyda Engineering College',
      'Bheemili X Road',
      'Anandapuram',
      'Peddipalem',
      'Tallavalasa',
      'Tagarapuvalasa',
    ],
  ),
  const _ManualRouteSpec(
    routeId: '222R',
    number: '222R',
    majorStopLabels: [
      'Railway Station',
      'RTC Complex',
      'MVP Colony',
      'Hanumanthawaka',
      'Madhurawada',
      'Anandapuram',
      'Tagarapuvalasa',
    ],
    stopLabels: [
      'Railway Station',
      'RTC Complex',
      'Rama Talkies',
      'MVP Colony',
      'Venkojipalem',
      'Hanumanthawaka',
      'Old Dairy Farm',
      'Vizag Zoo',
      'Endada',
      'Carshed',
      'Madhurawada',
      'Kommadi',
      'Marikavalasa',
      'Boravanipalem',
      'Paradesipalem',
      'Boyapalem',
      'Pyda Engineering College',
      'Bheemili X Road',
      'Anandapuram',
      'Peddipalem',
      'Tallavalasa',
      'Tagarapuvalasa',
    ],
  ),

  // GWK depot
  _ManualRouteSpec.parse(
    'gwk-99|99|Old GWK -> New GWK -> Sriharipuram/CG -> Malkapuram/PQ -> '
    'Scindia -> Pipeline/K Gate -> Dockyard Godowns -> Maruthi Circle -> '
    'INS Dega -> Solar Plant',
  ),
  _ManualRouteSpec.parse(
    'gwk-38d|38D|Nadupuru D.Col -> Gantyada -> Gajuwaka -> Birla -> '
    'Kancharapalem -> Tatichetlapalem -> Gurudwar',
  ),
  _ManualRouteSpec.parse(
    'gwk-38h|38H|Gantyada HB Colony -> RTC Complex',
  ),
  _ManualRouteSpec.parse(
    'gwk-38g65|38G/65|Gangavaram Colony -> Gangavaram -> '
    'Venkannapalem/Kranthingr -> Gantyada/J.Colony -> Gajuwaka -> Old GWK -> '
    'Port Qtrs -> Scindia',
  ),
  _ManualRouteSpec.parse(
    'gwk-38j|38J|Kranthi Nagar -> Janatha Colony -> Birla -> Kancharapalem -> '
    'Tathichetlapalem -> Gurudwar',
  ),
  _ManualRouteSpec.parse(
    'gwk-38r|38R|Maddilapalem -> Gurudwar/CBS -> '
    'Tadichettlapalem/Conv.Jn -> Kancharapalem/Essar -> '
    'Birla/Solar Plant -> Rajakoduru -> Krishna Palem -> Appanna Palem -> '
    'Kondavarapalem',
  ),
  _ManualRouteSpec.parse(
    'gwk-38y|38Y|Duvvada R/S -> Fakeertakya -> Birla -> Kancharapalem -> '
    'Tatichetlapalem -> RTC Complex',
  ),
  _ManualRouteSpec.parse(
    'gwk-16|16|Purna Market -> Old Bus Stand -> Convent -> Yarada Beach',
  ),
  _ManualRouteSpec.parse(
    'gwk-55d|55D & 55D/V|Scindia -> Malkapuram/Port Qtrs -> '
    'Sriharipuram/Coromandal -> Gajuwaka -> Old Gajuwaka -> Sub Station -> '
    'Natayyapalem -> Jaggayyapalem -> New Airport -> Chandrayyapeta -> '
    'Santapalem -> Kothavalasa Jn -> RCPuram/Pata Valasa -> K Kotapadu',
  ),
  _ManualRouteSpec.parse(
    'gwk-55k|55K|Durga Temple -> HCC Company/Gangavaram Colony -> '
    'Scindia/Main Gate/Gangavaram -> Malkapuram/Port Qtrs/Venkatapuram Jn -> '
    'Sriharipuram/Coramandal/Gantyada -> Gajuwaka -> Old Gajuwaka -> '
    'Substation -> Sheelanagar -> New Airport -> NAD X Road -> '
    'Gopalapatnam/Bunk -> Vepagunta -> Purushotapuram -> Kothavalasa',
  ),
  _ManualRouteSpec.parse(
    'gwk-55t|55T|Gajuwaka Depot -> Old Gajuwaka -> Sub Station -> '
    'Dukkavanipalem -> Egalavanipalem -> Tagarapuvalasa',
  ),
  _ManualRouteSpec.parse(
    'gwk-63a|63A|Appikonda/Palavalasa -> Dasaripeta/Gollapeta -> '
    'Nammidoddi Jn -> Islampeta -> Dockyard Godowns -> Maruthi Circle -> '
    'INS Dega -> Solar Plant -> Essar -> RK Beach',
  ),
  _ManualRouteSpec.parse(
    'gwk-66v99|66V/99|Vangali -> Nayanammapalem -> Gorlavanipalem -> '
    'Sabbavaram -> Essar -> Convent -> Old Bustand -> Poornamarket -> '
    'RK Beach',
  ),
  _ManualRouteSpec.parse(
    'gwk-67|67|Maddilapalem -> Sabbavaram/Bus Station -> Asakapalli X Road -> '
    'Askapalli -> Pydivada -> Gollapalem -> Narapadu',
  ),
  _ManualRouteSpec.parse(
    'gwk-400|400|Old Gajuwaka -> Gajuwaka -> Sriharipuram/Coromandal -> '
    'Scindia -> Pipeline/K Gate -> Dockyard Godowns -> Maruthi Circle -> '
    'Maddilapalem',
  ),
  _ManualRouteSpec.parse(
    'gwk-400p|400P|Palavalsa/Kalapaka -> Gollapeta/Pittavanipalem -> '
    'Nammidoddi/Chinnapalem -> Islam Peta -> Madeenabagh -> '
    'Steel Plant Gate -> Venkateswara Gudi -> Ukku Nagaram Jn -> K.B.R.Jn -> '
    'Kurmannapalem -> Srinagar -> Old Gajuwaka -> RTC Complex',
  ),
  _ManualRouteSpec.parse(
    'gwk-400r|400R|Maddilapalem -> RTC Complex -> Convent -> Essar -> '
    'Solar Plant -> INS Dega -> Maruthi Circle -> Yathapalem/Kothapeta -> '
    'Kothaptm/KG Palem',
  ),
  _ManualRouteSpec.parse(
    'gwk-400sy|400S/400Y|Sabbavaram -> Amruthapuram -> '
    'Amarapinivanipalem/Jn -> Gowri Deg Col/Chinthagatla X Road -> '
    'Jerupothulapalem -> Narava -> Scindia -> Pipeline/K Gate -> '
    'Dockyard Godowns -> Maruthi Circle -> RTC Complex',
  ),
  _ManualRouteSpec.parse(
    'gwk-411v|411V|Old Gajuwaka -> VT Agraharam/Court -> Inada/APSP Q Rtrs -> '
    'Jonnada/Lendi -> Dakamarri/Raghu -> Modavalasa -> Maddilapalem -> '
    'RTC Complex -> Convent -> Essar -> Solar Plant -> INS Dega -> '
    'Vizainagaram',
  ),
  _ManualRouteSpec.parse(
    'gwk-500y|500Y|Yelamanchili -> RTC Complex -> Gurudwara -> '
    'Thatichetlapalem',
  ),
  _ManualRouteSpec.parse(
    'gwk-311|311|Scindia -> Lagisettypalem -> Aripaka/Tekkalipalem -> '
    'Chinayathapalem -> Lingalatirugudu -> Chodavaram',
  ),

  // MDWD depot
  _ManualRouteSpec.parse(
    'mdwd-500p|500P|Madhurawada Depot -> VBC -> Caeshed -> Law College -> '
    'Yandada -> Zoo Park -> Venkojipalem -> Maddilapalem -> RTC Complex -> '
    'Gurudawar/RL -> Thatichetulapalem -> Kancharapalem -> Birla -> '
    'Salavanipalem -> Sirasapalli -> Kotharu -> Koppaka -> '
    'Desapathrunipalem -> Jajulavanipalem -> Sub Station -> Parawada -> '
    'Pudimadaka',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25dm|25D/M|OHPO / RK Beach -> Purna Market / Co.Off -> Jagadamba -> '
    'RTC Complex -> Maddilapalem -> Venkojipalem -> Zoo Park -> Endada -> '
    'Law College -> Carshed/MVVCity -> VBC/MDWD/KMD -> '
    'NGRP/SS Nagar/YSR/AMVT Clny',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25dv|25D/V|OHPO/TKR -> Purna Market -> Jagadamba -> RTC Complex -> '
    'Maddilapalem -> Venkojipalem -> Zoo Park -> Endada -> Law College -> '
    'Carshed/MVVCity -> VBC/MDWD/KMD',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25k|25K|OHPO/TKR -> Purna Market -> Jagadamba -> RTC Complex -> '
    'Maddilapalem -> Venkojipalem -> Zoo Park -> Endada -> Amaravathi Nagar',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25j|25J|Rly.Station -> RTC Complex -> Maddilapalem -> Venkojipalem '
    '-> Zoo Park -> Endada -> Law College -> Sevanagar',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25r|25R|Rly Station -> RTC Complex -> Maddilapalem -> Venkojipalem '
    '-> Zoo Park -> Endada -> Law College -> Carshed -> Bakkannapalem -> '
    'AMBTKR Clny/AMVT Nagar',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25e|25E|Amaravathi Nagar -> Marikavalsa -> MDWD/KMD Jn -> Carshed '
    '-> Law College -> Endada -> Zoo Park -> Venkojipalem -> '
    'Old Post Office',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25p|25P|OHPO/RK Beach -> PRN-Market -> Jagadamba/Rlystation -> '
    'RTC Complex -> Maddilapalem -> Venkojipalem -> Zoo Park -> Endada -> '
    'P.M.Palem',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25v|25V|R.K.Beach/TKR -> Collector Office/PRN Market -> Jagadamba '
    '-> Marikavalasa Colony',
  ),
  _ManualRouteSpec.parse(
    'mdwd-jp01|JP01|Madhurawada Depot -> Kommadi/Madhurawada -> VSP -> NAD '
    '-> Pendurthy -> Sabbavaram -> Chodavaram -> Vaddadi -> Ghatroad/MDGL -> '
    'KDR/KPRM -> Jolaput',
  ),
  _ManualRouteSpec.parse(
    'mdwd-25m|25M|MDWD-Depot -> ITSEZ Road/Haritha Jn -> Marikavalsa -> '
    'Boravanipalem/MCV-Clny -> IIM/Anandapuram -> Bheemili X Road -> '
    'Boyapalem -> Paradesipalem -> Madhurawada -> Carshed -> NAD X Road',
  ),

  // SML depot
  _ManualRouteSpec.parse(
    'sml-28|28 / 28H|Simhachalam Hill -> Simhachalam -> Srinivanagar -> '
    'Gopalapatnam -> NAD X Road -> Marripalem -> Estate -> Kancharapalem -> '
    'Rly.Newcolony -> RTC Complex -> Jagadamba -> Col.Office -> RK.Beach',
  ),
  _ManualRouteSpec.parse(
    'sml-28zh|28Z/H|Simhachalam Hill -> Simhachalam -> Srinivanagar -> '
    'Gopalapatnam -> NAD X Road -> Birla Jn -> Kancharapalem Highway -> '
    'Thatichetlapalem -> Gurudwara Jn -> RTC Complex -> Jagadamba/Baraks -> '
    'Zillaparishad/RK.Beach',
  ),
  const _ManualRouteSpec(
    routeId: '28K',
    number: '28K',
    majorStopLabels: [
      'RK Beach',
      'Jagadamba',
      'RTC Complex',
      'NAD',
      'Gopalapatnam',
      'Pendurthi',
      'Kothavalasa',
    ],
    stopLabels: [
      'RK Beach',
      'Collector Office',
      'Jagadamba',
      'RTC Complex',
      'Railway Station',
      'Convent Junction',
      'Gnanapuram',
      'Urvasi',
      'Kancharapalem',
      'Industrial Estate',
      '104 Area',
      'Marripalem',
      'Karasa',
      'NAD Junction',
      'Baji Junction',
      'Simhachalam Railway Station',
      'Gopalapatnam',
      'Gopalapatnam Bunk',
      'Naidu Thota',
      'Vepagunta',
      'Purushottapuram',
      'Sujatha Nagar',
      'Chinnamushidivada',
      'Pendurti College',
      'Pendurthi',
      'Saripalli',
      'Chintalapalem',
      'Desapatrunipalem',
      'Mangalapalem',
      'Kothavalasa Railway Station',
      'Kothavalasa Junction',
      'Kothavalasa',
    ],
  ),
  _ManualRouteSpec.parse(
    'sml-55|55|Scindia Jn -> Malkapuram -> Sriharipuram -> New Gajuwaka -> '
    'Old Gajuwaka -> Sub Station -> Nathayyapalem -> Sheelanagar -> '
    'Air Port -> NAD X Road -> Gopalapatnam -> Simhachalam/SML Hill',
  ),
  _ManualRouteSpec.parse(
    'sml-505|505|Scindia Jn -> Pipeline -> Dockyard/Godowns -> Maruthi Circle '
    '-> INS Dega -> Solor Plant -> CWC Godowns -> MOV Jn. -> '
    'Loco Shed Jn -> 104 Area -> Marripalem -> Simhachalam',
  ),
  _ManualRouteSpec.parse(
    'sml-55y|55Y|JNNURM Colony -> Mangalapalem -> Duvvada -> Pakeertakiya -> '
    'Kurmanapalem -> Srinagar -> Old Gajuwaka -> Sub-Station -> '
    'Natayyapalem -> Sheelanagar -> Airport -> Simhachalam/Pendurthi',
  ),
  _ManualRouteSpec.parse(
    'sml-6|6 / 6H|Pendurthi/SS.NGR/VUDA Colony/Sujatha Nagar C2 Zone -> '
    'Chinamushidvada -> Purushottapuram -> Vepagunta -> Gopalapatnam -> '
    'NAD X Road -> Marripalem -> Estate -> Kancharapalem -> O.H.P.O. -> '
    'Simhachalam Hill',
  ),
  _ManualRouteSpec.parse(
    'sml-6d|6D|Dabbanda -> China Dabbanda/Colony -> Dabbanda X Road -> '
    'SR.Puram -> Adivivaram -> Simhachalam -> Srinivasanagar -> OHPO',
  ),
  _ManualRouteSpec.parse(
    'sml-6a|6A|Simhachalam -> Srinivanagar -> Gopalapatnam -> NAD X Road -> '
    'Marripalem -> Industrial Estate -> Kancharapalem -> Convent Jn -> '
    'Rly.Station -> RTC Complex',
  ),
  _ManualRouteSpec.parse(
    'sml-60|60|SML Hill -> Simhachalam -> Adivivaram -> Pineapple Colony -> '
    'Sri Krishnapuram -> Mudasarlova Park -> Pedagadili -> Venkojipalem -> '
    'Maddilapalem -> RTC Complex -> Jagadamba -> Market/Col.Office -> OHPO',
  ),
  _ManualRouteSpec.parse(
    'sml-68k|68K|R.K.Beach/OHPO -> Collector Office/VUDA Park/P.M -> '
    'Jagadamba/Waltair Depot -> RTC Complex -> Maddilapalem -> Venkojipalem '
    '-> Pedagadili -> Nallabilli/Peda Gudipala -> Vayalapadu Jn. -> '
    'Kasipuram -> Devarapalli',
  ),
  _ManualRouteSpec.parse(
    'sml-300c|300C|RTC Complex -> Rly.Station -> Rly.Newcolony -> '
    'Kancharapalem -> Estate -> Marripalem -> NAD X Road -> Gopalapatnam -> '
    'Vepagunta -> Patharoad -> Sabbavaram -> Gottivada -> Lagisettypalem -> '
    'Aripaka/Tekkalipalem -> Chinayathapalem -> Lingalatirugudu -> '
    'KM Stone 1 -> Adduru -> KM Stone 2 -> Chodavaram',
  ),
  _ManualRouteSpec.parse(
    'sml-300s|300S|RTC Complex -> Rly.Station -> Rly.Newcolony/Convent Jn -> '
    'Kancharapalem -> Estate -> Marripalem -> Gopalapatnam -> '
    'Vepagunta/Srinivasanagar -> Purushottapuram/SML -> '
    'Chinamushidivada -> Sabbavaram',
  ),
  _ManualRouteSpec.parse(
    'sml-700|700 / 700H|Simhachalam Depot/Hill -> Simhachalam -> S.R.Puram '
    '-> Satrav/Checkpost -> Sontyam -> Neelakundeelu -> Padmanabham -> '
    'Reddipalli -> Chinnapuram -> VSP X Road -> VZM',
  ),
  _ManualRouteSpec.parse(
    'sml-55s|55S|Simhachalam Hill -> Simhachalam -> Adivivaram -> '
    'Chinamushidivada -> Purushottapuram -> Vepagunta -> Pandragi -> '
    'Egalavanipalem/Reganigudem -> Anandapuram/Mukundapuram -> '
    'R T.Valasa/Boni Vill -> Tagarapuvalasa',
  ),

  // VSC depot
  _ManualRouteSpec.parse(
    'vsc-111v|111V|Kurmannapalem -> Srinagar -> Old Gajuwaka -> Autonagar -> '
    'Natayyapalem -> Sheelanagar -> Airport -> NAD -> Birla -> '
    'Kancharapalem -> Tatichetlapalem -> Railway Station -> RTC Complex -> '
    'Maddilapalem -> Venkojipalem -> Zoo Park -> Endeda -> Carshed -> '
    'Madhurawada/Kommadi -> Marikavalasa -> Boyapalem -> Vijayanagaram',
  ),
  _ManualRouteSpec.parse(
    'vsc-111|111|Duvvada -> Pakheertakya -> Kurmannapalem -> Srinagr -> '
    'Old Gajuwka -> Tagarapuvalasa',
  ),
  _ManualRouteSpec.parse(
    'vsc-38k|38K|Sector-5 -> Ukkunagaram -> KBR -> Kurmannapalem -> '
    'Srinagar -> Old Gajuwaka -> Autonagar -> Natayyapalem -> Sheelanagar -> '
    'Airport -> NAD -> RTC Complex',
  ),
  _ManualRouteSpec.parse(
    'vsc-38y|38Y|Duvvada Rly Station -> RTC Complex -> CBS -> GWK',
  ),
  _ManualRouteSpec.parse(
    'vsc-38ry|38R/Y|RTC Complex -> Gurudwara -> Tatichetlapalem -> '
    'Kancharapalem -> Birla -> NAD Jn -> Airport -> Sheelanagar -> '
    'Rajianagar/Duvvada',
  ),
  _ManualRouteSpec.parse(
    'vsc-400n|400N|RTC Complex -> Convent/Gurudwara -> Essar/TT.Palem -> '
    'Solar Plant/Kancharapalem -> INS Dega/Birla -> '
    'Vadacheepurapalli/MTYPalem',
  ),
  _ManualRouteSpec.parse(
    'vsc-500a|500A|RTC Complex -> Gurudwara -> Tatichetlapalem -> '
    'Kancharapalem -> Birla -> Srinagar -> Kurmannapalem -> Aganampudi -> '
    'Lankelapalem -> Salapuvanipalem -> Atchutapuram',
  ),
  _ManualRouteSpec.parse(
    'vsc-600|600 / 600S|Anakapalli -> VZM Road -> Koppaka -> Kotturu -> '
    'Sirasapalli -> Salapuvanipalem -> Lankelapalem -> EM Palem Road -> '
    'Aganampudi -> Toll Gate -> Kurmannapalem -> Srinagar/KBR -> '
    'Old Gajuwaka/Ukkungaram -> New Gajuwaka/SMG -> Scindia',
  ),
  _ManualRouteSpec.parse(
    'vsc-400lp500|400L/P/500|Anakapalli -> VZM Road -> Koppaka -> Kotturu -> '
    'Sirasapalli -> Salapuvanipalem -> Lankelapalem -> '
    'New Gajuwaka/NAD Jn/Pipeline -> Sriharipuram/Birla Jn/Dockyard -> '
    'Malkapuram/Kancharapalem/Maruthi Circle -> '
    'Scindia/Tatichetlapalem/INS Dega -> Steel Plant Schools/RTC Complex',
  ),
  _ManualRouteSpec.parse(
    'vsc-744|744|Anakapalli/Dosuru -> VZM Road/Gandivanipalem -> '
    'Koppaka/Rajannapalem -> Kotturu/Bandharupalem -> '
    'Sirasapalli/Vadacheepurapalli -> Tollgate/Substation -> '
    'Kurmannapalem/Jajulavanipalem -> Srinagar/Desapatrunipalem -> '
    'Old Gajuwaka/Sector-8 -> New Gajuwaka/General Hospital -> Scindia',
  ),
  _ManualRouteSpec.parse(
    'vsc-311|311|Scindia -> Malkapuram/Port Qtrs -> Sriharipuram/CG -> '
    'New Gajuwaka -> Old Gajuwaka -> Srinagar -> Kurmanpalem -> '
    'Fakeertakiya X Road -> Duvvada -> Narava -> Chodavaram -> '
    'Diddupalem -> Venkannapalem -> Govada/S.Factory -> Gajapathinagaram',
  ),
  _ManualRouteSpec.parse(
    'vsc-gunupur|GUNUPUR|Kurmannapalem -> Old Gajuwaka -> NAD Junction -> '
    'Visakhapatnam -> Carshed/Madhurawada -> Anadapuram -> Tagarapuvalasa -> '
    'Bhogapuram -> Nathavalasa -> Pusapatirega -> Pydibheemavaram -> '
    'Ranastalam/OBS -> Chilakapalem -> Srikakulam -> Narasannapeta -> '
    'Challapeta Jn -> Saravakota -> Gunupur',
  ),

  // Waltair depot
  _ManualRouteSpec.parse(
    'wtr-68k68d|68K / 68D|RK Beach -> Collector Office -> Jagadamba -> '
    'RTC Complex -> Maddilapalem -> Venkojipalem -> Kothavalasa / '
    'Devarapalli',
  ),
  _ManualRouteSpec.parse(
    'wtr-333|333|OBS/Town Kotta Road / Waltair Depot -> VUDA Park -> '
    'R.K.Beach/MVP R.B -> C.Office/MDP/TKRD-R -> Devarapalli',
  ),
  _ManualRouteSpec.parse(
    'wtr-60c|60C|OHPO / R K Beach -> Purna Market / C.Office -> '
    'Arilova Colony',
  ),
  _ManualRouteSpec.parse(
    'wtr-52d|52D|OHPO / R K Beach -> Purna Market / C.Office -> '
    'Ravindra Nagar',
  ),
  _ManualRouteSpec.parse(
    'wtr-48a48s|48A/48S|OHPO/RKB -> Purna Market / ZP/C.Office -> '
    'Madhavadhara VUDA Colony/SML',
  ),
  _ManualRouteSpec.parse(
    'wtr-14|14|Venkojipalem -> Appughar -> Waltair Jn. (Depot) -> '
    'Chinawaltair -> OHPO',
  ),
  _ManualRouteSpec.parse(
    'wtr-999|999|RTC Complex -> Maddilapalem/Siripuram -> Boyapalem -> '
    'Boddapalem -> Bheemili',
  ),
  _ManualRouteSpec.parse(
    'wtr-900k|900K|OBS/KRD -> Railway Station -> Bheemili',
  ),
  _ManualRouteSpec.parse(
    'wtr-12d|12D|RTC Complex -> Railway Station -> Rly New Colony -> '
    'Kancharapalem -> Nallabilli -> Vayalapadu Jn. -> Devarapalli',
  ),
];

// ─────────────────────────────────────────────────────────────
//  ALL STOPS
// ─────────────────────────────────────────────────────────────
class VizagStops {
  static const _cityCore = _StopArea(17.724044586973633, 83.30707513638193);
  static const _beachRoad = _StopArea(17.711497390294234, 83.31811820871287);
  static const _kancharapalemArea =
      _StopArea(17.73239409467747, 83.27799289458622);
  static const _nadArea = _StopArea(17.74279634488214, 83.23550511882578);
  static const _portArea = _StopArea(17.68811827821838, 83.24960432025021);
  static const _gajuwakaArea = _StopArea(17.690008733886543, 83.22348803257371);
  static const _maddilapalemArea =
      _StopArea(17.735976634718714, 83.32088655628978);
  static const _mvpArea = _StopArea(17.742888294530275, 83.3279246927025);
  static const _simhachalamArea =
      _StopArea(17.77232576103274, 83.24339618949288);
  static const _pendurthiArea = _StopArea(17.822211272584937, 83.2050411674474);
  static const _madhurawadaArea =
      _StopArea(17.81647302589971, 83.35674215777088);
  static const _anandapuramArea =
      _StopArea(17.894901577346417, 83.37762676648626);
  static const _tagarapuvalasaArea =
      _StopArea(17.932587899019126, 83.42676591136784);
  static const _kothavalasaArea =
      _StopArea(17.896970472566025, 83.18532471449139);
  static const _anakapalleArea =
      _StopArea(17.689651085658205, 83.0023607303745);
  static const _parawadaArea = _StopArea(17.62445568461084, 83.08582889911706);
  static const _yelamanchiliArea =
      _StopArea(17.54774790354826, 82.85402221798682);
  static const _vizianagaramArea =
      _StopArea(18.106625706188016, 83.39558591934815);

  static const Map<String, _ExactStopCoordinate> _verifiedCoordinates = {
    '104_area': _ExactStopCoordinate(17.7389487, 83.2570021),
    'au_outgate': _ExactStopCoordinate(17.722201402907455, 83.32734693840492),
    'achutapuram': _ExactStopCoordinate(17.563775665980852, 82.97908605785608),
    'adavivaram': _ExactStopCoordinate(17.780415421644747, 83.25265653441035),
    'aganampudi': _ExactStopCoordinate(17.688308791621164, 83.12517773491024),
    'akkayyapalem': _ExactStopCoordinate(17.73524302600154, 83.29995446301888),
    'anakapalli': _ExactStopCoordinate(17.689651085658205, 83.0023607303745),
    'anandapuram': _ExactStopCoordinate(17.894901577346417, 83.37762676648626),
    'arilova': _ExactStopCoordinate(17.75971389220103, 83.32105142204054),
    'baji_junction': _ExactStopCoordinate(17.7441257, 83.2279861),
    'bhpv': _ExactStopCoordinate(17.702152156880658, 83.20561102228203),
    'bhimili': _ExactStopCoordinate(17.892554182561323, 83.453218638804),
    'cbm': _ExactStopCoordinate(17.724599083333377, 83.30864710597724),
    'carshed': _ExactStopCoordinate(17.8035495291326, 83.3531076324752),
    'chinnamushidivada': _ExactStopCoordinate(17.8063886, 83.2086317),
    'chintalapalem': _ExactStopCoordinate(17.851132, 83.19556),
    'chodavaram': _ExactStopCoordinate(17.82744494216951, 82.9352841698859),
    'collector_office':
        _ExactStopCoordinate(17.708743005671018, 83.30702866022884),
    'convent_junction':
        _ExactStopCoordinate(17.717146175809056, 83.2898968133065),
    'desapatrunipalem': _ExactStopCoordinate(17.8661634, 83.1914891),
    'devarapalli': _ExactStopCoordinate(17.99055168753284, 82.9807434173196),
    'duvvada': _ExactStopCoordinate(17.70403637708094, 83.15151410285544),
    'endada': _ExactStopCoordinate(17.782165460333573, 83.3583397356011),
    'fishing_harbour':
        _ExactStopCoordinate(17.697491334083118, 83.29910527788323),
    'gajuwaka': _ExactStopCoordinate(17.690008733886543, 83.22348803257371),
    'gangavaram': _ExactStopCoordinate(17.643407630087204, 83.2292091616115),
    'gnanapuram': _ExactStopCoordinate(17.7210917, 83.2869877),
    'gopalapatnam_bunk': _ExactStopCoordinate(17.7527467, 83.2177002),
    'gopalapatnam': _ExactStopCoordinate(17.75183293706425, 83.21784190654942),
    'gurudwara': _ExactStopCoordinate(17.7365862288982, 83.3075160467041),
    'hb_colony': _ExactStopCoordinate(17.745956316232608, 83.32309677945763),
    'hanumanthawaka':
        _ExactStopCoordinate(17.755138799198114, 83.33186522858041),
    'ins_kalinga': _ExactStopCoordinate(17.855434559762365, 83.41625821512292),
    'industrial_estate': _ExactStopCoordinate(17.7368204, 83.2638254),
    'jagadamba': _ExactStopCoordinate(17.71206765708635, 83.30249739782423),
    'kailasagiri': _ExactStopCoordinate(17.747415331681864, 83.34628558404164),
    'kailasapuram': _ExactStopCoordinate(17.740651368024675, 83.28879401053344),
    'kambalakonda': _ExactStopCoordinate(17.76801566042918, 83.3429641790169),
    'karasa': _ExactStopCoordinate(17.7409553, 83.2439078),
    'kancharapalem': _ExactStopCoordinate(17.73239409467747, 83.27799289458622),
    'kommadi': _ExactStopCoordinate(17.824417121280245, 83.3565806008761),
    'kothavalasa': _ExactStopCoordinate(17.896970472566025, 83.18532471449139),
    'kothavalasa_junction': _ExactStopCoordinate(17.8972996, 83.185235),
    'kothavalasa_railway_station': _ExactStopCoordinate(17.8909912, 83.1864598),
    'kurmannapalem':
        _ExactStopCoordinate(17.685289956188655, 83.16764523824004),
    'mvp_colony': _ExactStopCoordinate(17.742888294530275, 83.3279246927025),
    'maddilapalem': _ExactStopCoordinate(17.735976634718714, 83.32088655628978),
    'madhavadhara': _ExactStopCoordinate(17.74977901942765, 83.24891570575984),
    'madhurawada': _ExactStopCoordinate(17.81647302589971, 83.35674215777088),
    'malkapuram': _ExactStopCoordinate(17.68863872588815, 83.24581148364551),
    'mangalapalem': _ExactStopCoordinate(17.8765897, 83.189386),
    'marripalem': _ExactStopCoordinate(17.740433, 83.2495589),
    'mindi': _ExactStopCoordinate(17.70199953424382, 83.21542163379708),
    'muralinagar': _ExactStopCoordinate(17.747113832411678, 83.26325627984068),
    'nad_junction': _ExactStopCoordinate(17.74279634488214, 83.23550511882578),
    'naidu_thota': _ExactStopCoordinate(17.7692577, 83.2171472),
    'ntpc': _ExactStopCoordinate(17.571668967078267, 83.08823248250994),
    'narava': _ExactStopCoordinate(17.74410580408655, 83.18223789542121),
    'naval_base': _ExactStopCoordinate(17.692370509767372, 83.26818092693208),
    'old_post_office':
        _ExactStopCoordinate(17.6936347360638, 83.29213510745258),
    'pm_palem': _ExactStopCoordinate(17.8043162195604, 83.34442192802376),
    'parawada': _ExactStopCoordinate(17.62445568461084, 83.08582889911706),
    'pedagantyada': _ExactStopCoordinate(17.66687589603718, 83.20616506455174),
    'pendurthi': _ExactStopCoordinate(17.822163955417253, 83.20503083491597),
    'pendurti_college': _ExactStopCoordinate(17.8121652, 83.207114),
    'purna_market': _ExactStopCoordinate(17.706518406139903, 83.29849101266711),
    'purushottapuram': _ExactStopCoordinate(17.79096, 83.2127314),
    'rk_beach': _ExactStopCoordinate(17.711497390294234, 83.31811820871287),
    'rtc_complex': _ExactStopCoordinate(17.724044586973633, 83.30707513638193),
    'railway_station':
        _ExactStopCoordinate(17.722383918239547, 83.29090823893287),
    'rajeev_nagar': _ExactStopCoordinate(17.674444520598975, 83.19204975816568),
    'rushikonda': _ExactStopCoordinate(17.792696018364524, 83.38411417747774),
    'sabbavaram': _ExactStopCoordinate(17.79095201905506, 83.12411936404783),
    'sagar_nagar': _ExactStopCoordinate(17.766214011571947, 83.3587514725315),
    'satyam_junction':
        _ExactStopCoordinate(17.734376910398886, 83.31290553487592),
    'scindia': _ExactStopCoordinate(17.687797833164364, 83.26444801811117),
    'sheelanagar': _ExactStopCoordinate(17.718989685422486, 83.2032147928549),
    'simhachalam': _ExactStopCoordinate(17.77232576103274, 83.24339618949288),
    'simhachalam_hilltop':
        _ExactStopCoordinate(17.767548764556327, 83.24833933232567),
    'simhachalam_railway_station': _ExactStopCoordinate(17.7466609, 83.2215738),
    'siripuram': _ExactStopCoordinate(17.72300011952982, 83.31776117785729),
    'sitammadhara': _ExactStopCoordinate(17.7429392912984, 83.3143017276225),
    'sontyam': _ExactStopCoordinate(17.872300133367357, 83.29536248410979),
    'saripalli': _ExactStopCoordinate(17.8404629, 83.1990301),
    'steel_plant': _ExactStopCoordinate(17.685019182479433, 83.16530112827884),
    'sujatha_nagar': _ExactStopCoordinate(17.7986359, 83.2107136),
    'tagarapuvalasa':
        _ExactStopCoordinate(17.932587899019126, 83.42676591136784),
    'tenneti_park': _ExactStopCoordinate(17.747826148648866, 83.34938853634995),
    'town_kotharoad':
        _ExactStopCoordinate(17.702068187780064, 83.29638707158956),
    'ukkunagaram': _ExactStopCoordinate(17.652654270282426, 83.15958329108672),
    'urvasi': _ExactStopCoordinate(17.7350067, 83.2709818),
    'vuda_park': _ExactStopCoordinate(17.725304232693844, 83.338887732702),
    'venkojipalem': _ExactStopCoordinate(17.746535561674218, 83.32864749132816),
    'vepagunta': _ExactStopCoordinate(17.77602269891302, 83.2164654068468),
    'airport': _ExactStopCoordinate(17.732238188306773, 83.22351472124394),
    'port': _ExactStopCoordinate(17.68811827821838, 83.24960432025021),
    'vizianagaram': _ExactStopCoordinate(18.106625706188016, 83.39558591934815),
    'waltair': _ExactStopCoordinate(17.731811395973004, 83.34270646688502),
    'yarada': _ExactStopCoordinate(17.66473114881509, 83.27828361410154),
    'yelamanchili': _ExactStopCoordinate(17.54774790354826, 82.85402221798682),
    'vizag_zoo': _ExactStopCoordinate(17.769297064004434, 83.34400148979927),
    'rama_talkies': _ExactStopCoordinate(17.7278055, 83.311448),
    'old_dairy_farm': _ExactStopCoordinate(17.763125, 83.3361134),
    'marikavalasa': _ExactStopCoordinate(17.8370764, 83.3586865),
    'boravanipalem': _ExactStopCoordinate(17.8459761, 83.3592485),
    'paradesipalem': _ExactStopCoordinate(17.8584832, 83.3636069),
    'boyapalem': _ExactStopCoordinate(17.8694017, 83.3680055),
    'pyda_engineering_college': _ExactStopCoordinate(17.8728521, 83.3709375),
    'bheemili_x_road': _ExactStopCoordinate(17.8823398, 83.3759579),
    'peddipalem': _ExactStopCoordinate(17.9026532, 83.3999171),
    'tallavalasa': _ExactStopCoordinate(17.9103926, 83.4119912),
  };

  static BusStop _areaStop({
    required String id,
    required String name,
    required String nameTelugu,
    required _StopArea area,
    double latOffset = 0,
    double lngOffset = 0,
  }) {
    final verified = _verifiedCoordinates[id];
    return BusStop(
      id: id,
      name: name,
      nameTelugu: nameTelugu,
      lat: verified?.lat ?? area.lat + latOffset,
      lng: verified?.lng ?? area.lng + lngOffset,
    );
  }

  static bool _containsAnyToken(String value, List<String> tokens) =>
      tokens.any(value.contains);

  static _StopArea _guessManualStopArea(String id) {
    if (_containsAnyToken(id, const [
      'rk_beach',
      'ohpo',
      'old_post_office',
      'collector',
      'waltair',
      'appughar',
      'chinawaltair',
      'vuda_park',
      'siripuram',
      'beach',
      'zillaparishad',
      'obs',
    ])) {
      return _beachRoad;
    }

    if (_containsAnyToken(id, const [
      'rtc',
      'jagadamba',
      'convent',
      'market',
      'railway',
      'town_kotta',
      'town_kotha',
      'old_bus_stand',
      'old_bustand',
      'c_office',
      'co_office',
      'co_off',
      'rly',
      'cbs',
    ])) {
      return _cityCore;
    }

    if (_containsAnyToken(id, const [
      'scindia',
      'malkapuram',
      'sriharipuram',
      'coromandal',
      'coramandal',
      'pipeline',
      'dockyard',
      'maruthi',
      'dega',
      'solar',
      'port',
      'yarada',
      'appikonda',
      'islampeta',
      'birla',
      'essar',
      'tt_palem',
    ])) {
      return _portArea;
    }

    if (_containsAnyToken(id, const [
      'gajuwaka',
      'gwk',
      'kurmannapalem',
      'kurmanapalem',
      'srinagar',
      'autonagar',
      'duvvada',
      'fakeert',
      'pakeert',
      'natayyapalem',
      'nathayyapalem',
      'jaggayyapalem',
      'sheelanagar',
      'sub_station',
      'substation',
      'airport',
      'old_gajuwaka',
      'new_gajuwaka',
      'ukku',
      'ukkunagaram',
      'sector',
      'kbr',
      'aganampudi',
      'lankelapalem',
      'salapuvanipalem',
      'salavanipalem',
      'desapathrunipalem',
      'jajulavanipalem',
      'toll',
      'nadupuru',
      'gantyada',
      'gangavaram',
      'mindi',
    ])) {
      return _gajuwakaArea;
    }

    if (_containsAnyToken(id, const [
      'maddilapalem',
      'venkojipalem',
      'zoo',
      'endada',
      'carshed',
      'law',
      'mvv',
      'madhurawada',
      'kommadi',
      'marikaval',
      'boyapalem',
      'paradesipalem',
      'andadapuram',
      'anadapuram',
      'anandapuram',
      'bheemili',
      'bhimili',
      'arilova',
      'pedagadili',
      'mudasarlova',
      'iim',
      'haritha',
      'itsez',
      'yandada',
      'boddapalem',
      'nallabilli',
      'vayalapadu',
      'ravindra_nagar',
      'amaravathi_nagar',
      'amaravathi',
      'sevanagar',
      'bakkannapalem',
    ])) {
      return _madhurawadaArea;
    }

    if (_containsAnyToken(id, const [
      'simhachalam',
      'sml',
      'gopalapatnam',
      'nad',
      'marripalem',
      'estate',
      'industrial',
      'vepagunta',
      'purushottapuram',
      'purushotapuram',
      'chinamushid',
      'adavivaram',
      'pineapple',
      'sr_puram',
      'srinivasanagar',
      'srinivanagar',
      'sujatha',
      'dabbanda',
      'satra',
      'checkpost',
      'pandragi',
    ])) {
      return _simhachalamArea;
    }

    if (_containsAnyToken(id, const [
      'pendurthi',
      'pendurthy',
      'kothavalasa',
      'vaddadi',
      'sabbavaram',
      'patharoad',
      'gottivada',
      'lagisetty',
      'aripaka',
      'tekkalipalem',
      'chinayathapalem',
      'lingalatirugudu',
      'padmanabham',
      'reddipalli',
      'chinnapuram',
      'vsp_x_road',
      'neelakundeelu',
      'vzm',
    ])) {
      return _pendurthiArea;
    }

    if (_containsAnyToken(id, const [
      'anakapalli',
      'vzm_road',
      'koppaka',
      'kotturu',
      'sirasapalli',
      'gandivanipalem',
      'dosuru',
      'pudimadaka',
      'atchutapuram',
      'achutapuram',
      'yelamanchili',
      'vangali',
      'govada',
      'factory',
    ])) {
      return _anakapalleArea;
    }

    if (_containsAnyToken(id, const [
      'tagarapuvalasa',
      'bhogapuram',
      'nathavalasa',
      'pusapatirega',
      'pydibheemavaram',
      'ranastalam',
      'srikakulam',
      'narasannapeta',
      'challapeta',
      'saravakota',
      'gunupur',
      'jolaput',
    ])) {
      return _tagarapuvalasaArea;
    }

    if (_containsAnyToken(id, const [
      'vizianagaram',
      'vizainagaram',
      'vijayanagaram',
      'devarapalli',
      'gajapathinagaram',
      'vadacheepurapalli',
      'vadacheepurupalli',
      'mtypalem',
    ])) {
      return _vizianagaramArea;
    }

    if (_containsAnyToken(id, const [
      'parawada',
      'ntpc',
      'madeenabagh',
      'palavalasa',
      'kalapaka',
      'gollapeta',
      'nammidoddi',
      'steel_plant_gate',
      'venkateswara_gudi',
      'kotharu',
    ])) {
      return _parawadaArea;
    }

    return _cityCore;
  }

  static BusStop _draftManualStop(String label, {String? stopId}) {
    final id = stopId ?? _manualStopIdForLabel(label);
    final area = _guessManualStopArea(id);
    final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final latOffset = ((seed % 11) - 5) * 0.0011;
    final lngOffset = (((seed ~/ 11) % 11) - 5) * 0.0011;
    final verified = _verifiedCoordinates[id];

    return BusStop(
      id: id,
      name: label.trim(),
      nameTelugu: '',
      lat: verified?.lat ?? area.lat + latOffset,
      lng: verified?.lng ?? area.lng + lngOffset,
    );
  }

  static Map<String, BusStop> _buildManualStops() {
    final stops = <String, BusStop>{};

    for (final spec in _manualDepotRouteSpecs) {
      for (final label in spec.stopLabels) {
        final id = _manualStopIdForLabel(label);
        if (_baseStops.containsKey(id) || stops.containsKey(id)) continue;
        stops[id] = _draftManualStop(label);
      }
    }

    return stops;
  }

  static Map<String, BusStop> _buildImportedStops() {
    final stops = <String, BusStop>{};

    for (final spec in osmImportedRouteSpecs) {
      for (final label in spec.stopLabels) {
        final id = _importedStopIdForLabel(label);
        if (_baseStops.containsKey(id) ||
            _manualStops.containsKey(id) ||
            stops.containsKey(id)) {
          continue;
        }
        stops[id] = _draftManualStop(label, stopId: id);
      }
    }

    return stops;
  }

  static final Map<String, BusStop> _baseStops = {
    // Area anchors keep nearby stops clustered so route snapping and mock GPS
    // interpolation follow realistic city corridors instead of random points.
    // ── Core city hubs ──
    'rtc_complex': _areaStop(
      id: 'rtc_complex',
      name: 'RTC Complex',
      nameTelugu: 'ఆర్టీసీ కాంప్లెక్స్',
      area: _cityCore,
    ),
    'rk_beach': _areaStop(
      id: 'rk_beach',
      name: 'RK Beach',
      nameTelugu: 'ఆర్‌కే బీచ్',
      area: _beachRoad,
      latOffset: -0.0075,
      lngOffset: 0.0057,
    ),
    'jagadamba': _areaStop(
      id: 'jagadamba',
      name: 'Jagadamba Centre',
      nameTelugu: 'జగదాంబ సెంటర్',
      area: _cityCore,
      latOffset: -0.0029,
      lngOffset: -0.0003,
    ),
    'railway_station': _areaStop(
      id: 'railway_station',
      name: 'Railway Station',
      nameTelugu: 'రైల్వే స్టేషన్',
      area: _cityCore,
      latOffset: 0.0030,
      lngOffset: -0.0058,
    ),
    'old_post_office': _areaStop(
      id: 'old_post_office',
      name: 'Old Post Office (OHPO)',
      nameTelugu: 'పాత పోస్ట్ ఆఫీస్',
      area: _cityCore,
      latOffset: -0.0036,
      lngOffset: 0.0006,
    ),
    'collector_office': _areaStop(
      id: 'collector_office',
      name: 'Collector Office',
      nameTelugu: 'కలెక్టర్ ఆఫీస్',
      area: _cityCore,
      latOffset: -0.0011,
      lngOffset: 0.0021,
    ),
    'town_kotharoad': _areaStop(
      id: 'town_kotharoad',
      name: 'Town Kotha Road',
      nameTelugu: 'టౌన్ కొత్త రోడ్',
      area: _cityCore,
      latOffset: -0.0057,
      lngOffset: -0.0025,
    ),
    'purna_market': _areaStop(
      id: 'purna_market',
      name: 'Purna Market',
      nameTelugu: 'పూర్ణ మార్కెట్',
      area: _cityCore,
      latOffset: -0.0020,
      lngOffset: -0.0008,
    ),

    // ── Waltair / Beach corridor ──
    'waltair': _areaStop(
      id: 'waltair',
      name: 'Waltair',
      nameTelugu: 'వాల్తేరు',
      area: _beachRoad,
      latOffset: 0.0095,
      lngOffset: 0.0040,
    ),
    'mvp_colony': _areaStop(
      id: 'mvp_colony',
      name: 'MVP Colony',
      nameTelugu: 'ఎంవీపీ కాలనీ',
      area: _mvpArea,
    ),
    'siripuram': _areaStop(
      id: 'siripuram',
      name: 'Siripuram',
      nameTelugu: 'శ్రీపురం',
      area: _beachRoad,
      latOffset: -0.0013,
      lngOffset: -0.0034,
    ),
    'cbm': _areaStop(
      id: 'cbm',
      name: 'CBM Compound',
      nameTelugu: 'సీబీఎం కాంపౌండ్',
      area: _cityCore,
      latOffset: 0.0013,
      lngOffset: -0.0049,
    ),
    'au_outgate': _areaStop(
      id: 'au_outgate',
      name: 'AU Out Gate',
      nameTelugu: 'ఏయూ అవుట్ గేట్',
      area: _beachRoad,
      latOffset: 0.0115,
      lngOffset: 0.0025,
    ),
    'convent_junction': _areaStop(
      id: 'convent_junction',
      name: 'Convent Junction',
      nameTelugu: 'కాన్వెంట్ జంక్షన్',
      area: _cityCore,
      latOffset: -0.0077,
      lngOffset: -0.0045,
    ),

    // ── NAD / Gopalapatnam corridor ──
    'nad_junction': _areaStop(
      id: 'nad_junction',
      name: 'NAD Junction',
      nameTelugu: 'ఎన్‌ఏడీ జంక్షన్',
      area: _nadArea,
    ),
    'gopalapatnam': _areaStop(
      id: 'gopalapatnam',
      name: 'Gopalapatnam',
      nameTelugu: 'గోపాలపట్నం',
      area: _nadArea,
      latOffset: 0.0020,
      lngOffset: -0.0120,
    ),
    'kancharapalem': _areaStop(
      id: 'kancharapalem',
      name: 'Kancharapalem',
      nameTelugu: 'కంచరపాలెం',
      area: _kancharapalemArea,
    ),
    'gurudwara': _areaStop(
      id: 'gurudwara',
      name: 'Gurudwara',
      nameTelugu: 'గురుద్వారా',
      area: _kancharapalemArea,
      latOffset: 0.0060,
      lngOffset: 0.0060,
    ),

    // ── Scindia / Gajuwaka corridor ──
    'scindia': _areaStop(
      id: 'scindia',
      name: 'Scindia',
      nameTelugu: 'సింధియా',
      area: _portArea,
      latOffset: 0.0038,
      lngOffset: 0.0008,
    ),
    'malkapuram': _areaStop(
      id: 'malkapuram',
      name: 'Malkapuram',
      nameTelugu: 'మాల్కాపురం',
      area: _portArea,
      latOffset: 0.0020,
      lngOffset: -0.0150,
    ),
    'gajuwaka': _areaStop(
      id: 'gajuwaka',
      name: 'Gajuwaka',
      nameTelugu: 'గాజువాక',
      area: _gajuwakaArea,
    ),
    'bhpv': _areaStop(
      id: 'bhpv',
      name: 'BHPV',
      nameTelugu: 'బీహెచ్‌పీవీ',
      area: _gajuwakaArea,
      latOffset: 0.0060,
      lngOffset: 0.0230,
    ),
    'kurmannapalem': _areaStop(
      id: 'kurmannapalem',
      name: 'Kurmannapalem',
      nameTelugu: 'కుర్మన్నపాలెం',
      area: _gajuwakaArea,
      latOffset: -0.0200,
      lngOffset: 0.0050,
    ),
    'pedagantyada': _areaStop(
      id: 'pedagantyada',
      name: 'Pedagantyada',
      nameTelugu: 'పెదగంట్యాడ',
      area: _gajuwakaArea,
      latOffset: -0.0275,
      lngOffset: -0.0040,
    ),
    'steel_plant': _areaStop(
      id: 'steel_plant',
      name: 'Steel Plant',
      nameTelugu: 'స్టీల్ ప్లాంట్',
      area: _gajuwakaArea,
      latOffset: -0.0165,
      lngOffset: 0.0095,
    ),

    // ── Maddilapalem / Endada ──
    'maddilapalem': _areaStop(
      id: 'maddilapalem',
      name: 'Maddilapalem',
      nameTelugu: 'మద్దిలపాలెం',
      area: _maddilapalemArea,
    ),
    'endada': _areaStop(
      id: 'endada',
      name: 'Endada',
      nameTelugu: 'ఎందాడ',
      area: _mvpArea,
      latOffset: 0.0290,
      lngOffset: 0.0065,
    ),
    'arilova': _areaStop(
      id: 'arilova',
      name: 'Arilova Colony',
      nameTelugu: 'అరిలోవ కాలనీ',
      area: _kancharapalemArea,
      latOffset: 0.0200,
      lngOffset: 0.0210,
    ),
    'sitammadhara': _areaStop(
      id: 'sitammadhara',
      name: 'Sitammadhara',
      nameTelugu: 'సీతమ్మధార',
      area: _kancharapalemArea,
      latOffset: 0.0080,
      lngOffset: 0.0180,
    ),
    'satyam_junction': _areaStop(
      id: 'satyam_junction',
      name: 'Satyam Junction',
      nameTelugu: 'సత్యం జంక్షన్',
      area: _kancharapalemArea,
      latOffset: 0.0105,
      lngOffset: 0.0210,
    ),
    'hb_colony': _areaStop(
      id: 'hb_colony',
      name: 'HB Colony',
      nameTelugu: 'హెచ్‌బీ కాలనీ',
      area: _kancharapalemArea,
      latOffset: 0.0140,
      lngOffset: 0.0250,
    ),

    // ── Madhurawada / North ──
    'madhurawada': _areaStop(
      id: 'madhurawada',
      name: 'Madhurawada',
      nameTelugu: 'మధురవాడ',
      area: _madhurawadaArea,
      latOffset: 0.0040,
      lngOffset: -0.0040,
    ),
    'kommadi': _areaStop(
      id: 'kommadi',
      name: 'Kommadi',
      nameTelugu: 'కొమ్మాడి',
      area: _madhurawadaArea,
      latOffset: 0.0250,
      lngOffset: -0.0400,
    ),
    'anandapuram': _areaStop(
      id: 'anandapuram',
      name: 'Anandapuram',
      nameTelugu: 'ఆనందపురం',
      area: _anandapuramArea,
    ),
    'tagarapuvalasa': _areaStop(
      id: 'tagarapuvalasa',
      name: 'Tagarapuvalasa',
      nameTelugu: 'తగరాపువలస',
      area: _tagarapuvalasaArea,
      latOffset: 0.0120,
      lngOffset: 0.0770,
    ),
    'rushikonda': _areaStop(
      id: 'rushikonda',
      name: 'Rushikonda',
      nameTelugu: 'రుషికొండ',
      area: _madhurawadaArea,
      latOffset: -0.0340,
      lngOffset: 0.0000,
    ),
    'ins_kalinga': _areaStop(
      id: 'ins_kalinga',
      name: 'INS Kalinga',
      nameTelugu: 'ఐఎన్‌ఎస్ కాలింగ',
      area: _madhurawadaArea,
      latOffset: -0.0620,
      lngOffset: -0.0030,
    ),
    'bhimili': _areaStop(
      id: 'bhimili',
      name: 'Bhimili',
      nameTelugu: 'భీమిలి',
      area: _tagarapuvalasaArea,
      latOffset: -0.0300,
      lngOffset: 0.1020,
    ),

    // ── Simhachalam ──
    'simhachalam': _areaStop(
      id: 'simhachalam',
      name: 'Simhachalam',
      nameTelugu: 'సింహాచలం',
      area: _simhachalamArea,
      latOffset: 0.0006,
      lngOffset: 0.0001,
    ),
    'simhachalam_hilltop': _areaStop(
      id: 'simhachalam_hilltop',
      name: 'Simhachalam Hill Top',
      nameTelugu: 'సింహాచలం కొండపైన',
      area: _simhachalamArea,
      latOffset: 0.0040,
      lngOffset: 0.0001,
    ),
    'adavivaram': _areaStop(
      id: 'adavivaram',
      name: 'Adavivaram',
      nameTelugu: 'అడవివరం',
      area: _simhachalamArea,
      latOffset: -0.0080,
      lngOffset: 0.0100,
    ),
    'vepagunta': _areaStop(
      id: 'vepagunta',
      name: 'Vepagunta',
      nameTelugu: 'వేపగుంట',
      area: _simhachalamArea,
      latOffset: 0.0130,
      lngOffset: -0.0160,
    ),
    'hanumanthawaka': _areaStop(
      id: 'hanumanthawaka',
      name: 'Hanumanthawaka Jn',
      nameTelugu: 'హనుమంతవాక జంక్షన్',
      area: _simhachalamArea,
      latOffset: 0.0030,
      lngOffset: 0.0250,
    ),

    // ── Pendurthi / Kothavalasa ──
    'pendurthi': _areaStop(
      id: 'pendurthi',
      name: 'Pendurthi',
      nameTelugu: 'పెందుర్తి',
      area: _pendurthiArea,
    ),
    'kothavalasa': _areaStop(
      id: 'kothavalasa',
      name: 'Kothavalasa',
      nameTelugu: 'కొత్తవలస',
      area: _kothavalasaArea,
    ),
    'duvvada': _areaStop(
      id: 'duvvada',
      name: 'Duvvada Railway Station',
      nameTelugu: 'దువ్వాడ రైల్వే స్టేషన్',
      area: _gajuwakaArea,
      latOffset: 0.0030,
      lngOffset: -0.0500,
    ),

    // ── Kailasagiri ──
    'vuda_park': _areaStop(
      id: 'vuda_park',
      name: 'VUDA Park',
      nameTelugu: 'వుడా పార్క్',
      area: _beachRoad,
      latOffset: 0.0010,
      lngOffset: 0.0120,
    ),
    'tenneti_park': _areaStop(
      id: 'tenneti_park',
      name: 'Tenneti Park',
      nameTelugu: 'తెన్నేటి పార్క్',
      area: _beachRoad,
      latOffset: 0.0070,
      lngOffset: 0.0205,
    ),
    'kailasagiri': _areaStop(
      id: 'kailasagiri',
      name: 'Kailasagiri',
      nameTelugu: 'కైలాసగిరి',
      area: _beachRoad,
      latOffset: 0.0145,
      lngOffset: 0.0255,
    ),

    // ── Anakapalli / outer ──
    'anakapalli': _areaStop(
      id: 'anakapalli',
      name: 'Anakapalle',
      nameTelugu: 'అనకాపల్లి',
      area: _anakapalleArea,
    ),
    'aganampudi': _areaStop(
      id: 'aganampudi',
      name: 'Aganampudi',
      nameTelugu: 'అగనంపూడి',
      area: _parawadaArea,
      latOffset: 0.0130,
      lngOffset: 0.0160,
    ),
    'parawada': _areaStop(
      id: 'parawada',
      name: 'Parawada',
      nameTelugu: 'పరవాడ',
      area: _parawadaArea,
    ),
    'sabbavaram': _areaStop(
      id: 'sabbavaram',
      name: 'Sabbavaram',
      nameTelugu: 'సబ్బవరం',
      area: _pendurthiArea,
      latOffset: -0.031259253529877,
      lngOffset: -0.08092180339957,
    ),
    'chodavaram': _areaStop(
      id: 'chodavaram',
      name: 'Chodavaram',
      nameTelugu: 'చోడవరం',
      area: _anandapuramArea,
      latOffset: -0.0380,
      lngOffset: -0.3480,
    ),
    'sontyam': _areaStop(
      id: 'sontyam',
      name: 'Sontyam',
      nameTelugu: 'సోంత్యం',
      area: _pendurthiArea,
      latOffset: 0.0250,
      lngOffset: -0.0680,
    ),
    'yelamanchili': _areaStop(
      id: 'yelamanchili',
      name: 'Yelamanchili',
      nameTelugu: 'ఏలమంచిలి',
      area: _yelamanchiliArea,
    ),
    'devarapalli': _areaStop(
      id: 'devarapalli',
      name: 'Devarapalli',
      nameTelugu: 'దేవరపల్లి',
      area: _pendurthiArea,
      latOffset: 0.0030,
      lngOffset: -0.1360,
    ),
    'vizianagaram': _areaStop(
      id: 'vizianagaram',
      name: 'Vizianagaram',
      nameTelugu: 'విజయనగరం',
      area: _vizianagaramArea,
    ),

    // ── Misc stops ──
    'pm_palem': _areaStop(
      id: 'pm_palem',
      name: 'PM Palem',
      nameTelugu: 'పీఎం పాలెం',
      area: _madhurawadaArea,
      latOffset: -0.0280,
      lngOffset: -0.0180,
    ),
    'mindi': _areaStop(
      id: 'mindi',
      name: 'Mindi',
      nameTelugu: 'మింఢి',
      area: _gajuwakaArea,
      latOffset: -0.0030,
      lngOffset: 0.0320,
    ),
    'naval_base': _areaStop(
      id: 'naval_base',
      name: 'Naval Base / Dockyard',
      nameTelugu: 'నావల్ బేస్',
      area: _portArea,
      latOffset: 0.0085,
      lngOffset: -0.0070,
    ),
    'sagar_nagar': _areaStop(
      id: 'sagar_nagar',
      name: 'Sagar Nagar',
      nameTelugu: 'సాగర్‌నగర్',
      area: _madhurawadaArea,
      latOffset: -0.0560,
      lngOffset: -0.0105,
    ),
    'madhavadhara': _areaStop(
      id: 'madhavadhara',
      name: 'Madhavadhara',
      nameTelugu: 'మాధవధార',
      area: _kancharapalemArea,
      latOffset: 0.0160,
      lngOffset: 0.0080,
    ),
    'muralinagar': _areaStop(
      id: 'muralinagar',
      name: 'Muralinagar',
      nameTelugu: 'మురళీనగర్',
      area: _kancharapalemArea,
      latOffset: 0.0085,
      lngOffset: 0.0095,
    ),
    'kailasapuram': _areaStop(
      id: 'kailasapuram',
      name: 'Kailasapuram',
      nameTelugu: 'కైలాసపురం',
      area: _kancharapalemArea,
      latOffset: 0.0040,
      lngOffset: 0.0070,
    ),
    'akkayyapalem': _areaStop(
      id: 'akkayyapalem',
      name: 'Akkayapalem',
      nameTelugu: 'అక్కయ్యపాలెం',
      area: _kancharapalemArea,
      latOffset: 0.0045,
      lngOffset: 0.0140,
    ),
    'yarada': _areaStop(
      id: 'yarada',
      name: 'Yarada',
      nameTelugu: 'యారాడ',
      area: _portArea,
      latOffset: -0.0350,
      lngOffset: -0.0200,
    ),
    'airport': _areaStop(
      id: 'airport',
      name: 'Visakhapatnam Airport',
      nameTelugu: 'విశాఖ విమానాశ్రయం',
      area: _gajuwakaArea,
      latOffset: 0.0212,
      lngOffset: 0.0246,
    ),
    'carshed': _areaStop(
      id: 'carshed',
      name: 'Carshed / IT Park',
      nameTelugu: 'కార్ షెడ్',
      area: _madhurawadaArea,
      latOffset: -0.0355,
      lngOffset: -0.0165,
    ),
    'port': _areaStop(
      id: 'port',
      name: 'Visakhapatnam Port',
      nameTelugu: 'విశాఖ పోర్ట్',
      area: _portArea,
      latOffset: -0.0005,
      lngOffset: 0.0060,
    ),
    'venkojipalem': _areaStop(
      id: 'venkojipalem',
      name: 'Venkojipalem',
      nameTelugu: 'వేంకోజీపాలెం',
      area: _maddilapalemArea,
      latOffset: 0.0025,
      lngOffset: 0.0090,
    ),
    'fishing_harbour': _areaStop(
      id: 'fishing_harbour',
      name: 'Fishing Harbour',
      nameTelugu: 'ఫిషింగ్ హార్బర్',
      area: _portArea,
      latOffset: 0.0055,
      lngOffset: -0.0010,
    ),
    'gangavaram': _areaStop(
      id: 'gangavaram',
      name: 'Gangavaram',
      nameTelugu: 'గంగవరం',
      area: _gajuwakaArea,
      latOffset: -0.0720,
      lngOffset: 0.0250,
    ),
    'narava': _areaStop(
      id: 'narava',
      name: 'Narava',
      nameTelugu: 'నారవ',
      area: _simhachalamArea,
      latOffset: 0.0090,
      lngOffset: -0.0140,
    ),
    'sheelanagar': _areaStop(
      id: 'sheelanagar',
      name: 'Sheelanagar',
      nameTelugu: 'శీలానగర్',
      area: _nadArea,
      latOffset: -0.0190,
      lngOffset: -0.0200,
    ),
    'rajeev_nagar': _areaStop(
      id: 'rajeev_nagar',
      name: 'Rajeev Nagar',
      nameTelugu: 'రాజీవ్ నగర్',
      area: _gajuwakaArea,
      latOffset: -0.0235,
      lngOffset: 0.0105,
    ),
    'ukkunagaram': _areaStop(
      id: 'ukkunagaram',
      name: 'Ukkunagaram',
      nameTelugu: 'ఉక్కు నగరం',
      area: _gajuwakaArea,
      latOffset: -0.0110,
      lngOffset: 0.0140,
    ),
    'vizag_zoo': _areaStop(
      id: 'vizag_zoo',
      name: 'Zoo Park',
      nameTelugu: 'జూ పార్క్',
      area: _maddilapalemArea,
      latOffset: 0.0237,
      lngOffset: 0.0318,
    ),
    'kambalakonda': _areaStop(
      id: 'kambalakonda',
      name: 'Kambalakonda',
      nameTelugu: 'కంబాలకొండ',
      area: _maddilapalemArea,
      latOffset: 0.0250,
      lngOffset: -0.0240,
    ),
    'ntpc': _areaStop(
      id: 'ntpc',
      name: 'NTPC',
      nameTelugu: 'ఎన్‌టీపీసీ',
      area: _parawadaArea,
      latOffset: -0.0700,
      lngOffset: -0.0620,
    ),
    'achutapuram': _areaStop(
      id: 'achutapuram',
      name: 'Achutapuram',
      nameTelugu: 'అచ్యుతాపురం',
      area: _yelamanchiliArea,
      latOffset: 0.0400,
      lngOffset: 0.0300,
    ),
  };

  static final Map<String, BusStop> _manualStops = _buildManualStops();
  static final Map<String, BusStop> _importedStops = _buildImportedStops();

  static final Map<String, BusStop> all = {
    ..._baseStops,
    ..._manualStops,
    ..._importedStops,
  };

  static BusStop? get(String id) => all[id];

  static BusStop resolve(
    String? id, {
    String? fallbackName,
    String fallbackTelugu = '',
  }) {
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
  }

  static String label(String? id, {String? fallbackName}) =>
      resolve(id, fallbackName: fallbackName).name;

  static String labelTelugu(String? id, {String fallback = ''}) {
    final resolved = id?.trim() ?? '';
    return all[resolved]?.nameTelugu ?? fallback;
  }

  static String _formatIdAsName(String id) {
    final cleaned = id.trim();
    if (cleaned.isEmpty) return 'Unknown stop';

    return cleaned
        .split(RegExp(r'[_-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      if (part.length <= 3) {
        return part.toUpperCase();
      }
      return '${part[0].toUpperCase()}${part.substring(1)}';
    }).join(' ');
  }

  static List<BusStop> get list => all.values.toList();

  // Search stops by name (English or Telugu)
  static List<BusStop> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return list;
    return list
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.nameTelugu.contains(q) ||
            s.id.contains(q))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────
//  ALL ROUTES
// ─────────────────────────────────────────────────────────────
class VizagRoutes {
  static final List<BusRoute> all = _generateAllRoutes();
  static final Map<String, List<OsmImportedRouteSpec>>
      _importedRouteSpecsByNumber = _groupImportedRouteSpecsByNumber();

  static List<BusRoute> _generateAllRoutes() {
    final routes = <BusRoute>[];
    for (final base in _allBaseRoutes) {
      // Standard routes can always be reversed by the conductor. When a route
      // does not define an explicit return route id, generate one and link the
      // forward and reverse trips to each other.
      if (base.returnRouteNumber == null &&
          !base.routeId.endsWith('-R') &&
          !base.number.endsWith('-R')) {
        final reverseRouteId = '${base.routeId}-R';
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
      }

      routes.add(base);
    }
    return routes;
  }

  static Map<String, List<OsmImportedRouteSpec>>
      _groupImportedRouteSpecsByNumber() {
    final grouped = <String, List<OsmImportedRouteSpec>>{};
    for (final spec in osmImportedRouteSpecs) {
      grouped
          .putIfAbsent(spec.number, () => <OsmImportedRouteSpec>[])
          .add(spec);
    }
    return grouped;
  }

  static List<BusRoute> _buildManualDepotRoutes() =>
      _manualDepotRouteSpecs.map(_manualRouteFromSpec).toList(growable: false);

  static BusRoute _manualRouteFromSpec(_ManualRouteSpec spec) {
    final stopIds = <String>[];
    final stopLabels = <String>[];
    final majorStopIds = <String>[];
    final majorStopLabels = <String>[];

    for (final label in spec.stopLabels) {
      final stopId = _manualStopIdForLabel(label);
      stopIds.add(stopId);
      stopLabels.add(VizagStops.label(stopId, fallbackName: label));
    }

    for (final label in spec.majorStopLabels) {
      final stopId = _manualStopIdForLabel(label);
      if (stopIds.contains(stopId) && !majorStopIds.contains(stopId)) {
        majorStopIds.add(stopId);
        majorStopLabels.add(VizagStops.label(stopId, fallbackName: label));
      }
    }

    return BusRoute(
      routeId: spec.routeId,
      number: spec.number,
      from: stopLabels.first,
      to: stopLabels.last,
      viaStops: majorStopLabels.length <= 2
          ? const []
          : majorStopLabels.sublist(1, majorStopLabels.length - 1),
      stopIds: stopIds,
      majorStopIds: majorStopIds,
      busType: BusType.redOrdinary,
      frequencyMins: 20,
    );
  }

  static final List<BusRoute> _manualDepotRoutes = _buildManualDepotRoutes();

  static final Set<String> _manualOverrideRouteNumbers = {
    for (final spec in _manualDepotRouteSpecs)
      if (spec.routeId == spec.number) spec.number,
  };

  static List<BusRoute> _buildAllBaseRoutes() {
    final sourceRoutes = <BusRoute>[
      ..._baseRoutes.where(
        (route) => !_manualOverrideRouteNumbers.contains(route.number),
      ),
      ..._manualDepotRoutes,
    ];

    return sourceRoutes
        .map(_enrichRouteWithImportedStops)
        .map(_applySharedMinorStopCorridors)
        .toList(growable: false);
  }

  static BusRoute _enrichRouteWithImportedStops(BusRoute route) {
    if (route.hasHiddenSubStops) return route;

    final importedStopIds = _bestImportedStopIds(route);
    if (importedStopIds == null ||
        importedStopIds.length <= route.stopIds.length) {
      return route;
    }

    return BusRoute(
      routeId: route.routeId,
      number: route.number,
      from: route.from,
      to: route.to,
      fromTelugu: route.fromTelugu,
      toTelugu: route.toTelugu,
      viaStops: route.viaStops,
      stopIds: importedStopIds,
      majorStopIds: route.visibleStopIds,
      busType: route.busType,
      frequencyMins: route.frequencyMins,
      returnRouteNumber: route.returnRouteNumber,
    );
  }

  static const List<String> _pendurthiCorridorStopIds = [
    'gopalapatnam',
    'vepagunta',
    'purushottapuram',
    'sujatha_nagar',
    'chinnamushidivada',
    'pendurti_college',
    'pendurthi',
  ];

  static BusRoute _applySharedMinorStopCorridors(BusRoute route) {
    final expandedStopIds = _expandSharedCorridor(
      stopIds: route.stopIds,
      corridorStopIds: _pendurthiCorridorStopIds,
    );
    if (_stringListsEqual(expandedStopIds, route.stopIds)) {
      return route;
    }

    return BusRoute(
      routeId: route.routeId,
      number: route.number,
      from: route.from,
      to: route.to,
      fromTelugu: route.fromTelugu,
      toTelugu: route.toTelugu,
      viaStops: route.viaStops,
      stopIds: expandedStopIds,
      majorStopIds: route.visibleStopIds,
      busType: route.busType,
      frequencyMins: route.frequencyMins,
      returnRouteNumber: route.returnRouteNumber,
    );
  }

  static List<String> _expandSharedCorridor({
    required List<String> stopIds,
    required List<String> corridorStopIds,
  }) {
    if (stopIds.length < 2) return stopIds;

    final corridorIndexByStopId = <String, int>{
      for (var i = 0; i < corridorStopIds.length; i++) corridorStopIds[i]: i,
    };
    final expandedStopIds = <String>[];
    var index = 0;

    while (index < stopIds.length) {
      final startCorridorIndex = corridorIndexByStopId[stopIds[index]];
      if (startCorridorIndex == null) {
        expandedStopIds.add(stopIds[index]);
        index += 1;
        continue;
      }

      var segmentEndIndex = index;
      var previousCorridorIndex = startCorridorIndex;
      int? direction;

      while (segmentEndIndex + 1 < stopIds.length) {
        final nextCorridorIndex =
            corridorIndexByStopId[stopIds[segmentEndIndex + 1]];
        if (nextCorridorIndex == null ||
            nextCorridorIndex == previousCorridorIndex) {
          break;
        }

        final nextDirection =
            nextCorridorIndex > previousCorridorIndex ? 1 : -1;
        if (direction != null && direction != nextDirection) {
          break;
        }

        direction ??= nextDirection;
        segmentEndIndex += 1;
        previousCorridorIndex = nextCorridorIndex;
      }

      if (segmentEndIndex == index) {
        expandedStopIds.add(stopIds[index]);
        index += 1;
        continue;
      }

      final originalSegment = stopIds.sublist(index, segmentEndIndex + 1);
      final corridorSegment = _corridorSlice(
        corridorStopIds,
        startCorridorIndex,
        previousCorridorIndex,
      );
      expandedStopIds.addAll(
        _stringListsEqual(originalSegment, corridorSegment)
            ? originalSegment
            : corridorSegment,
      );
      index = segmentEndIndex + 1;
    }

    return _collapseAdjacentDuplicates(expandedStopIds);
  }

  static List<String> _corridorSlice(
    List<String> corridorStopIds,
    int startIndex,
    int endIndex,
  ) {
    if (startIndex <= endIndex) {
      return corridorStopIds.sublist(startIndex, endIndex + 1);
    }

    return corridorStopIds
        .sublist(endIndex, startIndex + 1)
        .reversed
        .toList(growable: false);
  }

  static bool _stringListsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<String>? _bestImportedStopIds(BusRoute route) {
    final anchorStopIds = route.visibleStopIds;
    if (anchorStopIds.length < 2) return null;

    final candidateSpecs = _importedRouteSpecsByNumber[route.number];
    if (candidateSpecs == null || candidateSpecs.isEmpty) {
      return null;
    }

    List<String>? bestStopIds;
    var bestScore = -1;

    for (final spec in candidateSpecs) {
      final mappedStopIds = _collapseAdjacentDuplicates(
        spec.stopLabels.map(_importedStopIdForLabel),
      );
      if (mappedStopIds.length <= route.stopIds.length) continue;

      for (final reversed in [false, true]) {
        final directionalStopIds = reversed
            ? mappedStopIds.reversed.toList(growable: false)
            : mappedStopIds;
        final anchorIndices =
            _orderedAnchorIndices(directionalStopIds, anchorStopIds);
        if (anchorIndices == null) continue;

        final candidateStopIds = directionalStopIds.sublist(
          anchorIndices.first,
          anchorIndices.last + 1,
        );
        if (candidateStopIds.length <= route.stopIds.length) continue;

        final score = _importedCandidateScore(
          route,
          spec,
          reversed: reversed,
          stopCount: candidateStopIds.length,
        );
        if (score > bestScore) {
          bestScore = score;
          bestStopIds = candidateStopIds;
        }
      }
    }

    return bestStopIds;
  }

  static List<int>? _orderedAnchorIndices(
    List<String> stopIds,
    List<String> anchorStopIds,
  ) {
    final indices = <int>[];
    var searchStart = 0;

    for (final anchorStopId in anchorStopIds) {
      final index = stopIds.indexOf(anchorStopId, searchStart);
      if (index < 0) return null;
      indices.add(index);
      searchStart = index + 1;
    }

    return indices;
  }

  static List<String> _collapseAdjacentDuplicates(Iterable<String> stopIds) {
    final collapsed = <String>[];
    for (final stopId in stopIds) {
      if (stopId.isEmpty) continue;
      if (collapsed.isEmpty || collapsed.last != stopId) {
        collapsed.add(stopId);
      }
    }
    return collapsed;
  }

  static int _importedCandidateScore(
    BusRoute route,
    OsmImportedRouteSpec spec, {
    required bool reversed,
    required int stopCount,
  }) {
    final specFrom = _normalizeRouteLabel(reversed ? spec.to : spec.from);
    final specTo = _normalizeRouteLabel(reversed ? spec.from : spec.to);

    var score = stopCount;
    if (_normalizeRouteLabel(route.from) == specFrom) score += 1000;
    if (_normalizeRouteLabel(route.to) == specTo) score += 1000;
    if (!reversed) score += 1;
    return score;
  }

  static String _normalizeRouteLabel(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static final List<BusRoute> _allBaseRoutes = _buildAllBaseRoutes();

  static const List<BusRoute> _baseRoutes = [
    // ── 10K ──────────────────────────────────────────────────
    BusRoute(
        number: '10K',
        from: 'RTC Complex',
        to: 'Kailasagiri',
        viaStops: ['Jagadamba', 'RK Beach', 'VUDA Park', 'Tenneti Park'],
        stopIds: [
          'rtc_complex',
          'jagadamba',
          'rk_beach',
          'vuda_park',
          'tenneti_park',
          'kailasagiri'
        ],
        busType: BusType.greenCity,
        frequencyMins: 20,
        returnRouteNumber: '10K-R'),
    BusRoute(
        routeId: '10K-R',
        number: '10K',
        from: 'Kailasagiri',
        to: 'RTC Complex',
        viaStops: ['Tenneti Park', 'VUDA Park', 'RK Beach', 'Jagadamba'],
        stopIds: [
          'kailasagiri',
          'tenneti_park',
          'vuda_park',
          'rk_beach',
          'jagadamba',
          'rtc_complex'
        ],
        busType: BusType.greenCity,
        frequencyMins: 20),

    // ── 28K / 68K ─────────────────────────────────────────────
    BusRoute(
        number: '28K',
        from: 'RK Beach',
        to: 'Kothavalasa',
        viaStops: ['Jagadamba', 'RTC Complex', 'NAD', 'Gopalapatnam'],
        stopIds: [
          'rk_beach',
          'collector_office',
          'jagadamba',
          'rtc_complex',
          'railway_station',
          'kancharapalem',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        routeId: '68K',
        number: '68K',
        from: 'Kothavalasa',
        to: 'RK Beach',
        viaStops: ['Vepagunta', 'Simhachalam', 'Hanumanthawaka'],
        stopIds: [
          'kothavalasa',
          'pendurthi',
          'vepagunta',
          'simhachalam',
          'hanumanthawaka',
          'rtc_complex',
          'jagadamba',
          'rk_beach'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),

    // ── 38 family ─────────────────────────────────────────────
    BusRoute(
        number: '38Y',
        from: 'RTC Complex',
        to: 'Duvvada Railway Station',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Gajuwaka', 'Kurmannapalem'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'kurmannapalem',
          'duvvada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 15),
    BusRoute(
        number: '38',
        from: 'RTC Complex',
        to: 'Gajuwaka',
        viaStops: ['Gurudwara', 'NAD', 'BHPV'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 15),
    BusRoute(
        number: '38A',
        from: 'RTC Complex',
        to: 'Mindi',
        viaStops: ['Gurudwara', 'NAD', 'BHPV'],
        stopIds: ['rtc_complex', 'gurudwara', 'nad_junction', 'bhpv', 'mindi'],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '38B',
        from: 'RTC Complex',
        to: 'Bhanojithota',
        viaStops: ['Gurudwara', 'NAD', 'Sheelanagar'],
        stopIds: ['rtc_complex', 'gurudwara', 'nad_junction', 'sheelanagar'],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '38C',
        from: 'RTC Complex',
        to: 'Sundarayya Colony',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Gajuwaka'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '38D',
        from: 'RTC Complex',
        to: 'Nadupur Dairy Colony',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Gajuwaka', 'Pedagantyada'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'pedagantyada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '38H',
        from: 'RTC Complex',
        to: 'Gantyada HB Colony',
        viaStops: [
          'Airport',
          'Gurudwara',
          'NAD',
          'BHPV',
          'Gajuwaka',
          'Pedagantyada'
        ],
        stopIds: [
          'rtc_complex',
          'airport',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'pedagantyada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '38IT',
        from: 'Kurmannapalem',
        to: 'IT Park',
        viaStops: [
          'Gajuwaka',
          'NAD',
          'Gurudwara',
          'RTC Complex',
          'Maddilapalem'
        ],
        stopIds: [
          'kurmannapalem',
          'gajuwaka',
          'bhpv',
          'nad_junction',
          'gurudwara',
          'rtc_complex',
          'maddilapalem',
          'carshed'
        ],
        busType: BusType.greenCity,
        frequencyMins: 20),
    BusRoute(
        number: '38J',
        from: 'RTC Complex',
        to: 'Janata Colony',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Gajuwaka', 'Scindia'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'scindia'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '38K',
        from: 'RTC Complex',
        to: 'Steel Plant Sector 5',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Gajuwaka'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'steel_plant'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '38M',
        from: 'Marikavalasa',
        to: 'Kurmannapalem',
        viaStops: [
          'Madhurawada',
          'Maddilapalem',
          'Gurudwara',
          'NAD',
          'BHPV',
          'Gajuwaka'
        ],
        stopIds: [
          'madhurawada',
          'maddilapalem',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'kurmannapalem'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '38N',
        from: 'RTC Complex',
        to: 'Nadupuru',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Gajuwaka', 'Pedagantyada'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'pedagantyada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '38R',
        from: 'Maddilapalem',
        to: 'Rambilli',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Parawada'],
        stopIds: [
          'maddilapalem',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'parawada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '38T',
        from: 'RTC Complex',
        to: 'Steel Plant Sector 11',
        viaStops: ['Gurudwara', 'NAD', 'BHPV', 'Gajuwaka', 'Kurmannapalem'],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'kurmannapalem',
          'steel_plant'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),

    // ── 55 family ─────────────────────────────────────────────
    BusRoute(
        number: '55',
        from: 'Simhachalam',
        to: 'Scindia',
        viaStops: ['Gopalapatnam', 'NAD', 'BHPV', 'Gajuwaka', 'Malkapuram'],
        stopIds: [
          'simhachalam',
          'gopalapatnam',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'malkapuram',
          'scindia'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '55K',
        from: 'Kothavalasa',
        to: 'Scindia',
        viaStops: [
          'Pendurthi',
          'Gopalapatnam',
          'NAD',
          'Gajuwaka',
          'Malkapuram'
        ],
        stopIds: [
          'kothavalasa',
          'pendurthi',
          'gopalapatnam',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'malkapuram',
          'scindia'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '55T',
        from: 'Scindia',
        to: 'Tagarapuvalasa',
        viaStops: [
          'Malkapuram',
          'Gajuwaka',
          'NAD',
          'Gopalapatnam',
          'Pendurthi',
          'Anandapuram'
        ],
        stopIds: [
          'scindia',
          'malkapuram',
          'gajuwaka',
          'bhpv',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'sontyam',
          'anandapuram',
          'tagarapuvalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '55V',
        from: 'Vepada',
        to: 'Scindia',
        viaStops: [
          'Simhachalam',
          'Gopalapatnam',
          'NAD',
          'Gajuwaka',
          'Malkapuram'
        ],
        stopIds: [
          'vepagunta',
          'simhachalam',
          'gopalapatnam',
          'nad_junction',
          'bhpv',
          'gajuwaka',
          'malkapuram',
          'scindia'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),

    // ── 99 family ─────────────────────────────────────────────
    BusRoute(
        number: '99',
        from: 'Collector Office',
        to: 'Gajuwaka',
        viaStops: [
          'Jagadamba',
          'Town Kotha Road',
          'Convent',
          'Scindia',
          'Malkapuram'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'malkapuram',
          'gajuwaka'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '99A',
        from: 'Collector Office',
        to: 'Chodavaram',
        viaStops: [
          'Jagadamba',
          'Convent',
          'Scindia',
          'Gajuwaka',
          'Kurmannapalem',
          'Anakapalle'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'anakapalli',
          'chodavaram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '99K',
        from: 'Collector Office',
        to: 'Kurmannapalem',
        viaStops: ['Jagadamba', 'Convent', 'Scindia', 'Gajuwaka'],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka',
          'kurmannapalem'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),

    // ── 400 family ────────────────────────────────────────────
    BusRoute(
        number: '400',
        from: 'RTC Complex',
        to: 'Kurmannapalem',
        viaStops: ['Railway Station', 'Scindia', 'Malkapuram', 'Gajuwaka'],
        stopIds: [
          'rtc_complex',
          'railway_station',
          'scindia',
          'malkapuram',
          'gajuwaka',
          'kurmannapalem'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 15),
    BusRoute(
        number: '400H',
        from: 'Maddilapalem',
        to: 'Gantyada HB Colony',
        viaStops: [
          'RTC Complex',
          'Railway Station',
          'Scindia',
          'Gajuwaka',
          'Pedagantyada'
        ],
        stopIds: [
          'maddilapalem',
          'rtc_complex',
          'railway_station',
          'scindia',
          'gajuwaka',
          'pedagantyada'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),
    BusRoute(
        number: '400K',
        from: 'Maddilapalem',
        to: 'Duvvada Railway Station',
        viaStops: [
          'RTC Complex',
          'Railway Station',
          'Scindia',
          'Gajuwaka',
          'Kurmannapalem'
        ],
        stopIds: [
          'maddilapalem',
          'rtc_complex',
          'railway_station',
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'duvvada'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),
    BusRoute(
        number: '400N',
        from: 'RTC Complex',
        to: 'Vadacheepurupalli',
        viaStops: [
          'Railway Station',
          'Scindia',
          'Gajuwaka',
          'Kurmannapalem',
          'Parawada',
          'NTPC'
        ],
        stopIds: [
          'rtc_complex',
          'railway_station',
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'parawada',
          'ntpc'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 30),
    BusRoute(
        number: '400S',
        from: 'Maddilapalem',
        to: 'Narava',
        viaStops: [
          'RTC Complex',
          'Railway Station',
          'Scindia',
          'Gajuwaka',
          'Kurmannapalem'
        ],
        stopIds: [
          'maddilapalem',
          'rtc_complex',
          'railway_station',
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'narava'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 25),
    BusRoute(
        number: '400Y',
        from: 'Maddilapalem',
        to: 'Yelamanchili',
        viaStops: [
          'RTC Complex',
          'Railway Station',
          'Scindia',
          'Gajuwaka',
          'Achutapuram'
        ],
        stopIds: [
          'maddilapalem',
          'rtc_complex',
          'railway_station',
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'achutapuram',
          'yelamanchili'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 25),

    // ── 500 family ────────────────────────────────────────────
    BusRoute(
        number: '500',
        from: 'RTC Complex',
        to: 'Anakapalle',
        viaStops: [
          'Gurudwara',
          'NAD',
          'Gajuwaka',
          'Kurmannapalem',
          'Aganampudi'
        ],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'gajuwaka',
          'kurmannapalem',
          'aganampudi',
          'anakapalli'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '500A',
        from: 'Maddilapalem',
        to: 'Addaroad',
        viaStops: [
          'Gurudwara',
          'NAD',
          'Gajuwaka',
          'Kurmannapalem',
          'Anakapalli'
        ],
        stopIds: [
          'maddilapalem',
          'gurudwara',
          'nad_junction',
          'gajuwaka',
          'kurmannapalem',
          'anakapalli'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '500A/C',
        from: 'RTC Complex',
        to: 'Achutapuram',
        viaStops: [
          'Gurudwara',
          'NAD',
          'Gajuwaka',
          'Kurmannapalem',
          'Anakapalle'
        ],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'gajuwaka',
          'kurmannapalem',
          'anakapalli',
          'achutapuram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '500P',
        from: 'Anakapalle',
        to: 'PM Palem',
        viaStops: [
          'Kurmannapalem',
          'Gajuwaka',
          'Scindia',
          'RTC Complex',
          'Maddilapalem'
        ],
        stopIds: [
          'anakapalli',
          'aganampudi',
          'kurmannapalem',
          'gajuwaka',
          'scindia',
          'rtc_complex',
          'maddilapalem',
          'carshed',
          'pm_palem'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '500Y',
        from: 'RTC Complex',
        to: 'Yelamanchili',
        viaStops: [
          'Gurudwara',
          'NAD',
          'Gajuwaka',
          'Kurmannapalem',
          'Anakapalle'
        ],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'gajuwaka',
          'kurmannapalem',
          'anakapalli',
          'yelamanchili'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),

    // ── 541 family ────────────────────────────────────────────
    BusRoute(
        number: '541',
        from: 'Maddilapalem',
        to: 'Kothavalasa',
        viaStops: [
          'Gurudwara',
          'NAD',
          'Gopalapatnam',
          'Vepagunta',
          'Pendurthi'
        ],
        stopIds: [
          'maddilapalem',
          'gurudwara',
          'nad_junction',
          'gopalapatnam',
          'vepagunta',
          'pendurthi',
          'kothavalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20,
        returnRouteNumber: '541-R'),
    BusRoute(
        routeId: '541-R',
        number: '541',
        from: 'Kothavalasa',
        to: 'Maddilapalem',
        viaStops: ['NAD', 'Gurudwara'],
        stopIds: [
          'kothavalasa',
          'pendurthi',
          'nad_junction',
          'gurudwara',
          'maddilapalem'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '541P',
        from: 'Maddilapalem',
        to: 'Padmanabham',
        viaStops: ['Gurudwara', 'NAD', 'Pendurthi', 'Kothavalasa'],
        stopIds: [
          'maddilapalem',
          'gurudwara',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),

    // ── 600 family ────────────────────────────────────────────
    BusRoute(
        number: '600',
        from: 'Anakapalle',
        to: 'Simhachalam',
        viaStops: [
          'Aganampudi',
          'Kurmannapalem',
          'Gajuwaka',
          'NAD',
          'Gopalapatnam'
        ],
        stopIds: [
          'anakapalli',
          'aganampudi',
          'kurmannapalem',
          'gajuwaka',
          'nad_junction',
          'gopalapatnam',
          'simhachalam'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '600C',
        from: 'RTC Complex',
        to: 'Anakapalle',
        viaStops: [
          'Railway Station',
          'Convent',
          'Gajuwaka',
          'Kurmannapalem',
          'Aganampudi'
        ],
        stopIds: [
          'rtc_complex',
          'railway_station',
          'convent_junction',
          'gajuwaka',
          'kurmannapalem',
          'aganampudi',
          'anakapalli'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),

    // ── 900 family ────────────────────────────────────────────
    BusRoute(
        number: '900',
        from: 'Maddilapalem',
        to: 'Railway Station',
        viaStops: ['MVP Colony', 'Waltair', 'RTC Complex'],
        stopIds: [
          'maddilapalem',
          'mvp_colony',
          'waltair',
          'rtc_complex',
          'railway_station'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 15),
    BusRoute(
        number: '900K',
        from: 'Railway Station',
        to: 'Bhimili',
        viaStops: ['Waltair', 'MVP Colony', 'Rushikonda', 'INS Kalinga'],
        stopIds: [
          'railway_station',
          'waltair',
          'mvp_colony',
          'rushikonda',
          'sagar_nagar',
          'ins_kalinga',
          'bhimili'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),
    BusRoute(
        number: '900R',
        from: 'RTC Complex',
        to: 'Rushikonda',
        viaStops: ['INS Kalinga', 'Sagar Nagar'],
        stopIds: ['rtc_complex', 'ins_kalinga', 'sagar_nagar', 'rushikonda'],
        busType: BusType.greenCity,
        frequencyMins: 25),
    BusRoute(
        number: '900T',
        from: 'RTC Complex',
        to: 'Tagarapuvalasa',
        viaStops: ['Waltair', 'MVP Colony', 'Rushikonda', 'INS Kalinga'],
        stopIds: [
          'rtc_complex',
          'waltair',
          'mvp_colony',
          'rushikonda',
          'ins_kalinga',
          'anandapuram',
          'tagarapuvalasa'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),

    // ── 222 family ────────────────────────────────────────────
    BusRoute(
        number: '222',
        from: 'RTC Complex',
        to: 'Tagarapuvalasa',
        viaStops: ['Maddilapalem', 'Endada', 'Madhurawada', 'Anandapuram'],
        stopIds: [
          'rtc_complex',
          'maddilapalem',
          'endada',
          'madhurawada',
          'kommadi',
          'anandapuram',
          'tagarapuvalasa'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 15),
    BusRoute(
        number: '222R',
        from: 'Railway Station',
        to: 'Tagarapuvalasa',
        viaStops: ['RTC Complex', 'Maddilapalem', 'Madhurawada', 'Anandapuram'],
        stopIds: [
          'railway_station',
          'rtc_complex',
          'maddilapalem',
          'madhurawada',
          'anandapuram',
          'tagarapuvalasa'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),
    BusRoute(
        number: '222V',
        from: 'RTC Complex',
        to: 'Vizianagaram',
        viaStops: ['Zoo Park', 'Kambalakonda'],
        stopIds: ['rtc_complex', 'vizag_zoo', 'kambalakonda', 'vizianagaram'],
        busType: BusType.ultraDeluxe,
        frequencyMins: 30),
    BusRoute(
        number: '999',
        from: 'RTC Complex',
        to: 'Bhimili',
        viaStops: ['Maddilapalem', 'Endada', 'Madhurawada', 'Anandapuram'],
        stopIds: [
          'rtc_complex',
          'maddilapalem',
          'endada',
          'madhurawada',
          'anandapuram',
          'tagarapuvalasa',
          'bhimili'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),

    // ── 25 family ─────────────────────────────────────────────
    BusRoute(
        number: '25D/M',
        from: 'OHPO',
        to: 'Midhilapuri Colony',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'Maddilapalem',
          'Endada',
          'Carshed'
        ],
        stopIds: [
          'old_post_office',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'carshed'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '25E',
        from: 'OHPO',
        to: 'Kommadi',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'Maddilapalem',
          'Endada',
          'Madhurawada'
        ],
        stopIds: [
          'old_post_office',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'madhurawada',
          'kommadi'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '25G',
        from: 'OHPO',
        to: 'Ganesh Nagar',
        viaStops: ['Jagadamba', 'RTC Complex', 'Maddilapalem', 'Madhurawada'],
        stopIds: [
          'old_post_office',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'madhurawada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '25IT',
        from: 'RTC Complex',
        to: 'IT Park',
        viaStops: ['Maddilapalem', 'Endada', 'Carshed'],
        stopIds: ['rtc_complex', 'maddilapalem', 'endada', 'carshed'],
        busType: BusType.greenCity,
        frequencyMins: 20),
    BusRoute(
        number: '25K',
        from: 'OHPO',
        to: 'Bakkannapalem',
        viaStops: ['Jagadamba', 'RTC Complex', 'Maddilapalem', 'Madhurawada'],
        stopIds: [
          'old_post_office',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'madhurawada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '25M',
        from: 'OHPO',
        to: 'Marikavalasa',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'Maddilapalem',
          'Endada',
          'Madhurawada'
        ],
        stopIds: [
          'old_post_office',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'madhurawada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '25S',
        from: 'OHPO',
        to: 'Nagarapalem',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'Maddilapalem',
          'Endada',
          'Carshed'
        ],
        stopIds: [
          'old_post_office',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'carshed'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '25P',
        from: 'Ratnagiri HB Colony',
        to: 'Old Post Office',
        viaStops: [
          'PM Palem',
          'Endada',
          'Maddilapalem',
          'RTC Complex',
          'Jagadamba'
        ],
        stopIds: [
          'hb_colony',
          'pm_palem',
          'endada',
          'maddilapalem',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '25J',
        from: 'Railway Station',
        to: 'Sevanagar',
        viaStops: ['RTC Complex', 'Maddilapalem', 'Endada', 'Madhurawada'],
        stopIds: [
          'railway_station',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'madhurawada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '25R',
        from: 'Railway Station',
        to: 'Gurajadanagar',
        viaStops: ['RTC Complex', 'Maddilapalem', 'Endada', 'PM Palem'],
        stopIds: [
          'railway_station',
          'rtc_complex',
          'maddilapalem',
          'endada',
          'pm_palem'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),

    // ── 52 family ─────────────────────────────────────────────
    BusRoute(
        number: '52D',
        from: 'Ravindra Nagar',
        to: 'OHPO',
        viaStops: ['Adarsha Nagar', 'Maddilapalem', 'RTC Complex', 'Jagadamba'],
        stopIds: [
          'madhurawada',
          'hanumanthawaka',
          'maddilapalem',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '52E',
        from: 'Yendada Village',
        to: 'OHPO',
        viaStops: [
          'Rushikonda',
          'Endada',
          'Maddilapalem',
          'RTC Complex',
          'Jagadamba'
        ],
        stopIds: [
          'rushikonda',
          'endada',
          'maddilapalem',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '52S/52V',
        from: 'Sagar Nagar',
        to: 'OHPO',
        viaStops: [
          'Visalakshi Nagar',
          'Maddilapalem',
          'RTC Complex',
          'Jagadamba'
        ],
        stopIds: [
          'sagar_nagar',
          'maddilapalem',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),

    // ── 60 family ─────────────────────────────────────────────
    BusRoute(
        number: '60',
        from: 'Simhachalam',
        to: 'OHPO',
        viaStops: ['Adavivaram', 'Maddilapalem', 'RTC Complex', 'Jagadamba'],
        stopIds: [
          'simhachalam',
          'adavivaram',
          'maddilapalem',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '60C',
        from: 'Arilova Colony',
        to: 'OHPO',
        viaStops: ['Maddilapalem', 'RTC Complex', 'Jagadamba'],
        stopIds: [
          'arilova',
          'maddilapalem',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20,
        returnRouteNumber: '60C-R'),
    BusRoute(
        routeId: '60C-R',
        number: '60C',
        from: 'OHPO',
        to: 'Arilova Colony',
        viaStops: ['RTC Complex', 'Maddilapalem', 'Hanumanthawaka'],
        stopIds: [
          'old_post_office',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'hanumanthawaka',
          'arilova'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '60R',
        from: 'RK Beach',
        to: 'Arilova Colony',
        viaStops: ['Jagadamba', 'RTC Complex', 'Maddilapalem'],
        stopIds: [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'maddilapalem',
          'arilova'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),

    // ── 12 family ─────────────────────────────────────────────
    BusRoute(
        number: '12D',
        from: 'RTC Complex',
        to: 'Devarapalli',
        viaStops: [
          'NAD',
          'Gopalapatnam',
          'Pendurthi',
          'Kothavalasa',
          'Anandapuram'
        ],
        stopIds: [
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa',
          'anandapuram',
          'devarapalli'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25,
        returnRouteNumber: '12D-R'),
    BusRoute(
        routeId: '12D-R',
        number: '12D',
        from: 'Devarapalli',
        to: 'RTC Complex',
        viaStops: ['Kothavalasa', 'NAD', 'Railway Station'],
        stopIds: [
          'devarapalli',
          'kothavalasa',
          'pendurthi',
          'nad_junction',
          'railway_station',
          'rtc_complex'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '12K',
        from: 'Town Kotharoad',
        to: 'Kothavalasa',
        viaStops: [
          'Railway Station',
          'Kancharapalem',
          'NAD',
          'Gopalapatnam',
          'Pendurthi'
        ],
        stopIds: [
          'town_kotharoad',
          'railway_station',
          'kancharapalem',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),

    // ── 28 variants ───────────────────────────────────────────
    BusRoute(
        number: '28',
        from: 'RK Beach',
        to: 'Simhachalam Bus Station',
        viaStops: ['Jagadamba', 'RTC Complex', 'NAD', 'Gopalapatnam'],
        stopIds: [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'simhachalam'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '28C',
        from: 'RK Beach',
        to: 'Chintalagraharam',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'NAD',
          'Gopalapatnam',
          'Vepagunta'
        ],
        stopIds: [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'vepagunta'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '28J',
        from: 'RK Beach',
        to: 'Sujatanagar',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'NAD',
          'Gopalapatnam',
          'Vepagunta'
        ],
        stopIds: [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'vepagunta'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '28P',
        from: 'RK Beach',
        to: 'Sabbavaram',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'NAD',
          'Gopalapatnam',
          'Pendurthi'
        ],
        stopIds: [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'sabbavaram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '28A/D',
        from: 'RK Beach',
        to: 'Denderu',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'Railway Station',
          'NAD',
          'Gopalapatnam',
          'Pendurthi'
        ],
        stopIds: [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'railway_station',
          'nad_junction',
          'gopalapatnam',
          'pendurthi'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '28A/P',
        from: 'RTC Complex',
        to: 'Ravalammapalem',
        viaStops: [
          'Railway Station',
          'Kancharapalem',
          'NAD',
          'Gopalapatnam',
          'Pendurthi'
        ],
        stopIds: [
          'rtc_complex',
          'railway_station',
          'kancharapalem',
          'nad_junction',
          'gopalapatnam',
          'pendurthi'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '28R',
        from: 'RK Beach',
        to: 'Simhachalam Bus Station',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'Railway Station',
          'NAD',
          'Gopalapatnam'
        ],
        stopIds: [
          'rk_beach',
          'jagadamba',
          'rtc_complex',
          'railway_station',
          'nad_junction',
          'gopalapatnam',
          'simhachalam'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '28Z',
        from: 'Zilla Parishad',
        to: 'Simhachalam Hills',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'Gurudwara',
          'NAD',
          'Gopalapatnam'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'gopalapatnam',
          'simhachalam',
          'simhachalam_hilltop'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),

    BusRoute(
        number: '5D',
        from: 'Town Kotharoad',
        to: 'Dabbanda',
        viaStops: [
          'Convent',
          'Kancharapalem',
          'NAD',
          'Gopalapatnam',
          'Pendurthi'
        ],
        stopIds: [
          'town_kotharoad',
          'convent_junction',
          'kancharapalem',
          'nad_junction',
          'gopalapatnam',
          'pendurthi'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),

    // ── 6 family ──────────────────────────────────────────────
    BusRoute(
        number: '6',
        from: 'Simhachalam',
        to: 'OHPO',
        viaStops: ['Gopalapatnam', 'NAD', 'Kancharapalem', 'Convent'],
        stopIds: [
          'simhachalam',
          'gopalapatnam',
          'nad_junction',
          'kancharapalem',
          'convent_junction',
          'town_kotharoad',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '6A',
        from: 'RTC Complex',
        to: 'Simhachalam Hills',
        viaStops: ['Railway Station', 'Kancharapalem', 'NAD', 'Gopalapatnam'],
        stopIds: [
          'rtc_complex',
          'railway_station',
          'kancharapalem',
          'nad_junction',
          'gopalapatnam',
          'simhachalam',
          'simhachalam_hilltop'
        ],
        busType: BusType.greenCity,
        frequencyMins: 20),
    BusRoute(
        number: '6B',
        from: 'OHPO',
        to: 'Chintagatla',
        viaStops: ['Town Kotharoad', 'Convent', 'NAD', 'Sheelanagar', 'Narava'],
        stopIds: [
          'old_post_office',
          'town_kotharoad',
          'convent_junction',
          'nad_junction',
          'sheelanagar',
          'narava'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '6H',
        from: 'RTC Complex',
        to: 'Simhachalam Hills',
        viaStops: ['Market', 'Gnanapuram', 'Gopalapatnam'],
        stopIds: [
          'purna_market',
          'town_kotharoad',
          'nad_junction',
          'gopalapatnam',
          'simhachalam',
          'simhachalam_hilltop'
        ],
        busType: BusType.greenCity,
        frequencyMins: 20),

    // ── 14 family ─────────────────────────────────────────────
    BusRoute(
        number: '14',
        from: 'Venkojipalem',
        to: 'OHPO',
        viaStops: ['MVP Colony', 'Waltair', 'AU Outgate', 'Jagadamba'],
        stopIds: [
          'venkojipalem',
          'mvp_colony',
          'waltair',
          'au_outgate',
          'jagadamba',
          'town_kotharoad',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '14A',
        from: 'Arilova Colony',
        to: 'OHPO',
        viaStops: ['Venkojipalem', 'MVP Colony', 'AU Outgate', 'Jagadamba'],
        stopIds: [
          'arilova',
          'venkojipalem',
          'mvp_colony',
          'waltair',
          'au_outgate',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),

    // ── 48 family ─────────────────────────────────────────────
    BusRoute(
        number: '48',
        from: 'Madhavadhara',
        to: 'MN Club',
        viaStops: [
          'Muralinagar',
          'Kailasapuram',
          'Akkayapalem',
          'RTC Complex',
          'Jagadamba'
        ],
        stopIds: [
          'madhavadhara',
          'muralinagar',
          'kailasapuram',
          'akkayyapalem',
          'rtc_complex',
          'jagadamba'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '48A',
        from: 'Madhavadhara',
        to: 'OHPO',
        viaStops: ['Muralinagar', 'Kailasapuram', 'Akkayapalem', 'RTC Complex'],
        stopIds: [
          'madhavadhara',
          'muralinagar',
          'kailasapuram',
          'akkayyapalem',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),

    // ── 300 family ────────────────────────────────────────────
    BusRoute(
        number: '300C',
        from: 'RTC Complex',
        to: 'Chodavaram',
        viaStops: ['NAD', 'Gopalapatnam', 'Pendurthi', 'Sabbavaram'],
        stopIds: [
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'sabbavaram',
          'chodavaram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '300M',
        from: 'RTC Complex',
        to: 'Madugula',
        viaStops: [
          'NAD',
          'Gopalapatnam',
          'Pendurthi',
          'Sabbavaram',
          'Chodavaram'
        ],
        stopIds: [
          'rtc_complex',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'sabbavaram',
          'chodavaram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 35),
    BusRoute(
        number: '300N',
        from: 'Sabbavaram',
        to: 'RK Beach',
        viaStops: [
          'Narava',
          'Old Gopalapatnam',
          'NAD',
          'Kancharapalem',
          'RTC Complex'
        ],
        stopIds: [
          'sabbavaram',
          'narava',
          'gopalapatnam',
          'nad_junction',
          'kancharapalem',
          'rtc_complex',
          'jagadamba',
          'rk_beach'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),

    // ── 333 family ────────────────────────────────────────────
    BusRoute(
        number: '333',
        from: 'Town Kotharoad',
        to: 'Devarapalle',
        viaStops: [
          'Convent',
          'NAD',
          'Gopalapatnam',
          'Pendurthi',
          'Kothavalasa'
        ],
        stopIds: [
          'town_kotharoad',
          'convent_junction',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa',
          'devarapalli'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '333K',
        from: 'Town Kotharoad',
        to: 'K.Kotapad',
        viaStops: [
          'Convent',
          'Kancharapalem',
          'NAD',
          'Gopalapatnam',
          'Pendurthi'
        ],
        stopIds: [
          'town_kotharoad',
          'convent_junction',
          'kancharapalem',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '328',
        from: 'K.Kotapad',
        to: 'RK Beach',
        viaStops: [
          'Jagadamba',
          'RTC Complex',
          'NAD',
          'Gopalapatnam',
          'Pendurthi'
        ],
        stopIds: [
          'kothavalasa',
          'pendurthi',
          'gopalapatnam',
          'nad_junction',
          'rtc_complex',
          'jagadamba',
          'rk_beach'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),

    // ── 205 / 211 / inter-city ────────────────────────────────
    BusRoute(
        number: '205',
        from: 'Vizianagaram',
        to: 'Anakapalli',
        viaStops: ['Bheemasingi', 'Kothavalasa', 'Pendurthi', 'Sabbavaram'],
        stopIds: [
          'vizianagaram',
          'kothavalasa',
          'pendurthi',
          'sabbavaram',
          'anakapalli'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 30),
    BusRoute(
        number: '201',
        from: 'VS Kota',
        to: 'Visakhapatnam',
        viaStops: ['Kothavalasa', 'NAD'],
        stopIds: ['kothavalasa', 'nad_junction', 'rtc_complex'],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '211',
        from: 'Railway Station',
        to: 'Vizianagaram',
        viaStops: [
          'RTC Complex',
          'Maddilapalem',
          'Madhurawada',
          'Tagarapuvalasa'
        ],
        stopIds: [
          'railway_station',
          'rtc_complex',
          'maddilapalem',
          'madhurawada',
          'anandapuram',
          'tagarapuvalasa',
          'vizianagaram'
        ],
        busType: BusType.ultraDeluxe,
        frequencyMins: 30),
    BusRoute(
        number: '888',
        from: 'Anakapalle',
        to: 'Tagarapuvalasa',
        viaStops: ['Pendurthi', 'Sontyam', 'Anandapuram'],
        stopIds: [
          'anakapalli',
          'pendurthi',
          'sontyam',
          'anandapuram',
          'tagarapuvalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),

    // ── Misc ──────────────────────────────────────────────────
    BusRoute(
        number: '1T',
        from: 'VUDA Park',
        to: 'Kapulatunglam',
        viaStops: [
          'RK Beach',
          'Jagadamba',
          'Town Kotharoad',
          'Convent',
          'Scindia',
          'Gajuwaka'
        ],
        stopIds: [
          'vuda_park',
          'rk_beach',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka'
        ],
        busType: BusType.greenCity,
        frequencyMins: 30),
    BusRoute(
        number: '10A',
        from: 'Visakhapatnam Airport',
        to: 'RK Beach',
        viaStops: ['NAD', 'Gurudwara', 'RTC Complex'],
        stopIds: [
          'airport',
          'nad_junction',
          'gurudwara',
          'rtc_complex',
          'jagadamba',
          'rk_beach'
        ],
        busType: BusType.greenCity,
        frequencyMins: 30),
    BusRoute(
        number: '16',
        from: 'Purna Market',
        to: 'Yarada',
        viaStops: ['Convent Junction', 'Scindia', 'Naval Base'],
        stopIds: [
          'purna_market',
          'convent_junction',
          'scindia',
          'naval_base',
          'yarada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '20A',
        from: 'HB Colony',
        to: 'OHPO',
        viaStops: [
          'Sitammadhara',
          'Satyam Junction',
          'RTC Complex',
          'Jagadamba'
        ],
        stopIds: [
          'hb_colony',
          'sitammadhara',
          'satyam_junction',
          'rtc_complex',
          'jagadamba',
          'old_post_office'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '36',
        from: 'Collector Office',
        to: 'Mindi',
        viaStops: ['Town Kotharoad', 'Convent', 'Scindia', 'Gajuwaka', 'BHPV'],
        stopIds: [
          'collector_office',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka',
          'bhpv',
          'mindi'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '63',
        from: 'RK Beach',
        to: 'Dibbapalem',
        viaStops: [
          'Town Kotharoad',
          'Convent',
          'Scindia',
          'Gajuwaka',
          'Pedagantyada'
        ],
        stopIds: [
          'rk_beach',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka',
          'pedagantyada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '64A',
        from: 'Collector Office',
        to: 'Swayambuvaram',
        viaStops: [
          'Jagadamba',
          'Town Kotharoad',
          'Convent',
          'Scindia',
          'Gajuwaka'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '65F',
        from: 'Fishing Harbour',
        to: 'Gangavaram',
        viaStops: [
          'Collector Office',
          'Jagadamba',
          'Convent',
          'Scindia',
          'Gajuwaka',
          'Pedagantyada'
        ],
        stopIds: [
          'fishing_harbour',
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka',
          'pedagantyada',
          'gangavaram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '69',
        from: 'Arilova Colony',
        to: 'Railway Station',
        viaStops: [
          'HB Colony',
          'Sitammadhara',
          'Satyam Junction',
          'RTC Complex'
        ],
        stopIds: [
          'arilova',
          'hb_colony',
          'sitammadhara',
          'satyam_junction',
          'rtc_complex',
          'railway_station'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '77',
        from: 'Collector Office',
        to: 'Thanam',
        viaStops: [
          'Jagadamba',
          'Town Kotharoad',
          'Convent',
          'Scindia',
          'Gajuwaka'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '77T',
        from: 'Collector Office',
        to: 'Thadi',
        viaStops: [
          'Jagadamba',
          'Town Kotharoad',
          'Convent',
          'Scindia',
          'Gajuwaka'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '111',
        from: 'Kurmannapalem',
        to: 'Tagarapuvalasa',
        viaStops: ['Gajuwaka', 'NAD', 'Gurudwara', 'Zoo Park', 'Madhurawada'],
        stopIds: [
          'kurmannapalem',
          'gajuwaka',
          'nad_junction',
          'gurudwara',
          'rtc_complex',
          'vizag_zoo',
          'madhurawada',
          'tagarapuvalasa'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),
    BusRoute(
        number: '311',
        from: 'Scindia',
        to: 'Chodavaram',
        viaStops: ['Gajuwaka', 'Kurmannapalem', 'Duvvada', 'Sabbavaram'],
        stopIds: [
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'duvvada',
          'sabbavaram',
          'chodavaram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '400-C',
        from: 'RTC Complex',
        to: 'Rajeev Nagar',
        viaStops: ['Railway Station', 'Scindia'],
        stopIds: ['rtc_complex', 'railway_station', 'scindia', 'rajeev_nagar'],
        busType: BusType.blueExpress,
        frequencyMins: 20),
    BusRoute(
        number: '505',
        from: 'Simhachalam',
        to: 'Scindia',
        viaStops: [
          'Gopalapatnam',
          'NAD',
          'Kancharapalem',
          'Convent',
          'Naval Dockyard'
        ],
        stopIds: [
          'simhachalam',
          'gopalapatnam',
          'nad_junction',
          'kancharapalem',
          'convent_junction',
          'naval_base',
          'scindia'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 25),
    BusRoute(
        number: '540',
        from: 'MVP Colony',
        to: 'Simhachalam',
        viaStops: ['Maddilapalem', 'Gurudwara', 'NAD', 'Gopalapatnam'],
        stopIds: [
          'mvp_colony',
          'maddilapalem',
          'gurudwara',
          'nad_junction',
          'gopalapatnam',
          'simhachalam'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '540M',
        from: 'MVP Colony',
        to: 'Gajuwaka',
        viaStops: ['Maddilapalem', 'Gurudwara', 'NAD', 'BHPV'],
        stopIds: [
          'mvp_colony',
          'maddilapalem',
          'gurudwara',
          'nad_junction',
          'bhpv',
          'gajuwaka'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20),
    BusRoute(
        number: '555',
        from: 'RTC Complex',
        to: 'Chodavaram',
        viaStops: [
          'Gurudwara',
          'NAD',
          'Gopalapatnam',
          'Pendurthi',
          'Sabbavaram'
        ],
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'sabbavaram',
          'chodavaram'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '700',
        from: 'Simhachalam',
        to: 'Vizianagaram',
        viaStops: ['Adavivaram', 'Sontyam', 'Anandapuram', 'Padmanabham'],
        stopIds: [
          'simhachalam',
          'adavivaram',
          'sontyam',
          'anandapuram',
          'tagarapuvalasa',
          'vizianagaram'
        ],
        busType: BusType.ultraDeluxe,
        frequencyMins: 30),
    BusRoute(
        number: '744',
        from: 'Collector Office',
        to: 'Dosuru',
        viaStops: [
          'Jagadamba',
          'Town Kotha Road',
          'Convent',
          'Scindia',
          'Gajuwaka',
          'Kurmannapalem',
          'Parawada'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'parawada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
    BusRoute(
        number: '844',
        from: 'Collector Office',
        to: 'Kollivanipalem',
        viaStops: [
          'Jagadamba',
          'Town Kotharoad',
          'Convent',
          'Scindia',
          'Gajuwaka',
          'Kurmannapalem',
          'Parawada'
        ],
        stopIds: [
          'collector_office',
          'jagadamba',
          'town_kotharoad',
          'convent_junction',
          'scindia',
          'gajuwaka',
          'kurmannapalem',
          'parawada'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 30),
  ];

  static BusRoute? byRouteId(String routeId) =>
      all.where((r) => r.routeId == routeId).firstOrNull;

  static BusRoute? byNumber(String n) =>
      all.where((r) => r.number == n).firstOrNull;

  static List<BusRoute> get primaryRoutes =>
      all.where((route) => !route.routeId.endsWith('-R')).toList();

  static List<BusRoute> get passengerRoutes {
    final seen = <String>{};
    return all.where((route) => seen.add(route.number)).toList();
  }

  static List<BusRoute> servingStop(String stopId) =>
      all.where((r) => r.stopIds.contains(stopId)).toList();

  // Search routes by number or stop name
  static List<BusRoute> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return all;
    return all
        .where((r) =>
            r.number.toLowerCase().contains(q) ||
            r.from.toLowerCase().contains(q) ||
            r.to.toLowerCase().contains(q) ||
            r.viaStops.any((v) => v.toLowerCase().contains(q)))
        .toList();
  }
}
