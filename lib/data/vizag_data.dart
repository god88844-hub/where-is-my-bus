// lib/data/vizag_data.dart
// Complete Vizag APSRTC route database — 80+ routes, 81 canonical stops
// Stop coordinates are approximate based on known Vizag geography.
// Verify key stops on the ground and update lat/lng as needed.

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
  final List<String> stopIds; // ordered stop IDs
  final BusType busType;
  final int frequencyMins;
  // Some routes share the same physical bus but different numbers
  // e.g. 28K outbound / 68K return. Set returnRoute to link them.
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

// ─────────────────────────────────────────────────────────────
//  ALL STOPS
// ─────────────────────────────────────────────────────────────
class VizagStops {
  static const _cityCore = _StopArea(17.7125, 83.3013);
  static const _beachRoad = _StopArea(17.7215, 83.3180);
  static const _kancharapalemArea = _StopArea(17.7280, 83.2800);
  static const _nadArea = _StopArea(17.7430, 83.2620);
  static const _portArea = _StopArea(17.6920, 83.2840);
  static const _gajuwakaArea = _StopArea(17.7000, 83.2000);
  static const _maddilapalemArea = _StopArea(17.7420, 83.3170);
  static const _mvpArea = _StopArea(17.7400, 83.3350);
  static const _simhachalamArea = _StopArea(17.7660, 83.2500);
  static const _pendurthiArea = _StopArea(17.7830, 83.2150);
  static const _madhurawadaArea = _StopArea(17.8200, 83.3600);
  static const _anandapuramArea = _StopArea(17.8600, 83.3000);
  static const _tagarapuvalasaArea = _StopArea(17.9200, 83.3500);
  static const _kothavalasaArea = _StopArea(17.8900, 83.2000);
  static const _anakapalleArea = _StopArea(17.6910, 83.0060);
  static const _parawadaArea = _StopArea(17.6660, 83.1500);
  static const _yelamanchiliArea = _StopArea(17.5400, 82.8700);
  static const _vizianagaramArea = _StopArea(18.1067, 83.3956);

  static const Map<String, _ExactStopCoordinate> _verifiedCoordinates = {
    'au_outgate': _ExactStopCoordinate(17.7325, 83.3185),
    'achutapuram': _ExactStopCoordinate(17.5805, 82.9005),
    'adavivaram': _ExactStopCoordinate(17.7555, 83.2955),
    'aganampudi': _ExactStopCoordinate(17.6790, 83.1610),
    'akkayyapalem': _ExactStopCoordinate(17.7305, 83.3055),
    'anakapalli': _ExactStopCoordinate(17.6915, 83.0035),
    'anandapuram': _ExactStopCoordinate(17.7855, 83.3920),
    'arilova': _ExactStopCoordinate(17.7600, 83.3200),
    'bhpv': _ExactStopCoordinate(17.7105, 83.2520),
    'bhimili': _ExactStopCoordinate(17.8905, 83.4520),
    'cbm': _ExactStopCoordinate(17.7205, 83.2960),
    'carshed': _ExactStopCoordinate(17.7485, 83.3530),
    'chodavaram': _ExactStopCoordinate(17.8280, 82.9350),
    'collector_office': _ExactStopCoordinate(17.7220, 83.3060),
    'convent_junction': _ExactStopCoordinate(17.7160, 83.3070),
    'devarapalli': _ExactStopCoordinate(17.7450, 83.0350),
    'duvvada': _ExactStopCoordinate(17.6705, 83.2060),
    'endada': _ExactStopCoordinate(17.7425, 83.3410),
    'fishing_harbour': _ExactStopCoordinate(17.7055, 83.2860),
    'gajuwaka': _ExactStopCoordinate(17.6868, 83.2185),
    'gangavaram': _ExactStopCoordinate(17.6415, 83.2350),
    'gopalapatnam': _ExactStopCoordinate(17.7480, 83.2180),
    'gurudwara': _ExactStopCoordinate(17.7360, 83.3110),
    'hb_colony': _ExactStopCoordinate(17.7270, 83.2960),
    'hanumanthawaka': _ExactStopCoordinate(17.7740, 83.3010),
    'ins_kalinga': _ExactStopCoordinate(17.7490, 83.3610),
    'jagadamba': _ExactStopCoordinate(17.7175, 83.2990),
    'kailasagiri': _ExactStopCoordinate(17.7490, 83.3420),
    'kailasapuram': _ExactStopCoordinate(17.7325, 83.3030),
    'kambalakonda': _ExactStopCoordinate(17.7705, 83.2990),
    'kancharapalem': _ExactStopCoordinate(17.7390, 83.3160),
    'kommadi': _ExactStopCoordinate(17.7760, 83.3820),
    'kothavalasa': _ExactStopCoordinate(17.9000, 83.1500),
    'kurmannapalem': _ExactStopCoordinate(17.6760, 83.2210),
    'mvp_colony': _ExactStopCoordinate(17.7510, 83.3360),
    'maddilapalem': _ExactStopCoordinate(17.7360, 83.3110),
    'madhavadhara': _ExactStopCoordinate(17.7390, 83.2960),
    'madhurawada': _ExactStopCoordinate(17.8200, 83.3500),
    'malkapuram': _ExactStopCoordinate(17.7060, 83.2760),
    'mindi': _ExactStopCoordinate(17.6810, 83.2410),
    'muralinagar': _ExactStopCoordinate(17.7360, 83.3010),
    'nad_junction': _ExactStopCoordinate(17.7400, 83.2300),
    'ntpc': _ExactStopCoordinate(17.6305, 83.1810),
    'narava': _ExactStopCoordinate(17.7610, 83.2710),
    'naval_base': _ExactStopCoordinate(17.7010, 83.2810),
    'old_post_office': _ExactStopCoordinate(17.7210, 83.3110),
    'pm_palem': _ExactStopCoordinate(17.7510, 83.3610),
    'parawada': _ExactStopCoordinate(17.6510, 83.1510),
    'pedagantyada': _ExactStopCoordinate(17.6610, 83.2110),
    'pendurthi': _ExactStopCoordinate(17.8330, 83.2000),
    'purna_market': _ExactStopCoordinate(17.7210, 83.3050),
    'rk_beach': _ExactStopCoordinate(17.7141, 83.3368),
    'rtc_complex': _ExactStopCoordinate(17.7260, 83.3010),
    'railway_station': _ExactStopCoordinate(17.7135, 83.2990),
    'rajeev_nagar': _ExactStopCoordinate(17.6685, 83.2210),
    'rushikonda': _ExactStopCoordinate(17.7610, 83.3820),
    'sabbavaram': _ExactStopCoordinate(17.7230, 83.0570),
    'sagar_nagar': _ExactStopCoordinate(17.7560, 83.3720),
    'satyam_junction': _ExactStopCoordinate(17.7270, 83.3090),
    'scindia': _ExactStopCoordinate(17.6900, 83.2700),
    'sheelanagar': _ExactStopCoordinate(17.7210, 83.2510),
    'simhachalam': _ExactStopCoordinate(17.7660, 83.2860),
    'simhachalam_hilltop': _ExactStopCoordinate(17.7710, 83.2790),
    'siripuram': _ExactStopCoordinate(17.7225, 83.3190),
    'sitammadhara': _ExactStopCoordinate(17.7290, 83.3060),
    'sontyam': _ExactStopCoordinate(17.7900, 83.1200),
    'steel_plant': _ExactStopCoordinate(17.6400, 83.1700),
    'tagarapuvalasa': _ExactStopCoordinate(17.8110, 83.4120),
    'tenneti_park': _ExactStopCoordinate(17.7205, 83.3460),
    'town_kotharoad': _ExactStopCoordinate(17.7200, 83.3090),
    'ukkunagaram': _ExactStopCoordinate(17.6960, 83.2320),
    'vuda_park': _ExactStopCoordinate(17.7235, 83.3400),
    'venkojipalem': _ExactStopCoordinate(17.7430, 83.3490),
    'vepagunta': _ExactStopCoordinate(17.7810, 83.3110),
    'airport': _ExactStopCoordinate(17.7212, 83.2246),
    'port': _ExactStopCoordinate(17.6865, 83.2780),
    'vizianagaram': _ExactStopCoordinate(18.1067, 83.3956),
    'waltair': _ExactStopCoordinate(17.7340, 83.3310),
    'yarada': _ExactStopCoordinate(17.6610, 83.2620),
    'yelamanchili': _ExactStopCoordinate(17.5480, 82.8560),
    'vizag_zoo': _ExactStopCoordinate(17.7625, 83.2905),
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

  static final Map<String, BusStop> all = {
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
      latOffset: -0.0190,
      lngOffset: -0.0970,
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
        })
        .join(' ');
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

  static List<BusRoute> _generateAllRoutes() {
    final routes = <BusRoute>[];
    for (final base in _baseRoutes) {
      routes.add(base);
      // Auto-generate a return route if one isn't explicitly linked
      if (base.returnRouteNumber == null && !base.number.endsWith('-R')) {
        routes.add(BusRoute(
          routeId: '${base.routeId}-R',
          number: base.number,
          from: base.to,
          to: base.from,
          fromTelugu: base.toTelugu,
          toTelugu: base.fromTelugu,
          viaStops: base.viaStops.reversed.toList(),
          stopIds: base.stopIds.reversed.toList(),
          busType: base.busType,
          frequencyMins: base.frequencyMins,
          returnRouteNumber: base.number,
        ));
      }
    }
    return routes;
  }

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
          'jagadamba',
          'collector_office',
          'rtc_complex',
          'railway_station',
          'kancharapalem',
          'nad_junction',
          'gopalapatnam',
          'pendurthi',
          'kothavalasa'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20,
        returnRouteNumber: '68K'),
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
          'hanumanthawaka',
          'simhachalam',
          'nad_junction',
          'kancharapalem',
          'railway_station',
          'rtc_complex',
          'jagadamba',
          'rk_beach'
        ],
        busType: BusType.redOrdinary,
        frequencyMins: 20,
        returnRouteNumber: '28K'),

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
        stopIds: [
          'rtc_complex',
          'gurudwara',
          'nad_junction',
          'sheelanagar'
        ],
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
        stopIds: [
          'rtc_complex',
          'maddilapalem',
          'endada',
          'carshed'
        ],
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
