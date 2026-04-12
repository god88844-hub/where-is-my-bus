// lib/data/vizag_data.dart
// Complete Vizag APSRTC route database — 80+ routes, 60+ stops
// Stop coordinates are approximate based on known Vizag geography.
// Verify key stops on the ground and update lat/lng as needed.

// ─────────────────────────────────────────────────────────────
//  BUS TYPES
// ─────────────────────────────────────────────────────────────
enum BusType {
  redOrdinary,
  blueExpress,
  greenCity,
  ultraDeluxe,
  metroExpress,
  metro,
  palleVelugu,
}

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
      case BusType.metro:
        return 'Metro';
      case BusType.palleVelugu:
        return 'Palle Velugu';
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
      case BusType.metro:
        return 'మెట్రో';
      case BusType.palleVelugu:
        return 'పల్లె వెలుగు';
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
      case BusType.metro:
        return 0xFFBA7517;
      case BusType.palleVelugu:
        return 0xFF1D9E75;
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
  String get origin => stopIds.first;
  String get terminus => stopIds.last;
}

// ─────────────────────────────────────────────────────────────
//  ALL STOPS
// ─────────────────────────────────────────────────────────────
class VizagStops {
  static const Map<String, BusStop> all = {
    // ── Core city hubs ──
    'rtc_complex': BusStop(
        id: 'rtc_complex',
        name: 'RTC Complex',
        nameTelugu: 'ఆర్టీసీ కాంప్లెక్స్',
        lat: 17.7231,
        lng: 83.3012),
    'rk_beach': BusStop(
        id: 'rk_beach',
        name: 'RK Beach',
        nameTelugu: 'ఆర్కే బీచ్',
        lat: 17.7141,
        lng: 83.3368),
    'jagadamba': BusStop(
        id: 'jagadamba',
        name: 'Jagadamba Centre',
        nameTelugu: 'జగదాంబ సెంటర్',
        lat: 17.7170,
        lng: 83.2980),
    'railway_station': BusStop(
        id: 'railway_station',
        name: 'Railway Station',
        nameTelugu: 'రైల్వే స్టేషన్',
        lat: 17.7133,
        lng: 83.2988),
    'old_post_office': BusStop(
        id: 'old_post_office',
        name: 'Old Post Office (OHPO)',
        nameTelugu: 'పాత పోస్ట్ ఆఫీస్',
        lat: 17.7200,
        lng: 83.3100),
    'collector_office': BusStop(
        id: 'collector_office',
        name: 'Collector Office',
        nameTelugu: 'కలెక్టర్ ఆఫీస్',
        lat: 17.7210,
        lng: 83.3050),
    'town_kotharoad': BusStop(
        id: 'town_kotharoad',
        name: 'Town Kotha Road',
        nameTelugu: 'టౌన్ కొత్త రోడ్',
        lat: 17.7190,
        lng: 83.3080),
    'purna_market': BusStop(
        id: 'purna_market',
        name: 'Purna Market',
        nameTelugu: 'పూర్ణ మార్కెట్',
        lat: 17.7200,
        lng: 83.3040),

    // ── Waltair / Beach corridor ──
    'waltair': BusStop(
        id: 'waltair',
        name: 'Waltair',
        nameTelugu: 'వాల్తేరు',
        lat: 17.7330,
        lng: 83.3300),
    'mvp_colony': BusStop(
        id: 'mvp_colony',
        name: 'MVP Colony',
        nameTelugu: 'ఎంవీపీ కాలనీ',
        lat: 17.7500,
        lng: 83.3350),
    'siripuram': BusStop(
        id: 'siripuram',
        name: 'Siripuram',
        nameTelugu: 'శ్రీపురం',
        lat: 17.7220,
        lng: 83.3180),
    'cbm': BusStop(
        id: 'cbm',
        name: 'CBM Compound',
        nameTelugu: 'సీబీఎం కాంపౌండ్',
        lat: 17.7200,
        lng: 83.2950),
    'au_outgate': BusStop(
        id: 'au_outgate',
        name: 'AU Out Gate',
        nameTelugu: 'ఏయూ అవుట్ గేట్',
        lat: 17.7320,
        lng: 83.3180),
    'convent_junction': BusStop(
        id: 'convent_junction',
        name: 'Convent Junction',
        nameTelugu: 'కాన్వెంట్ జంక్షన్',
        lat: 17.7150,
        lng: 83.3060),

    // ── NAD / Gopalapatnam corridor ──
    'nad_junction': BusStop(
        id: 'nad_junction',
        name: 'NAD Junction',
        nameTelugu: 'ఎన్ఏడీ జంక్షన్',
        lat: 17.7450,
        lng: 83.3250),
    'gopalapatnam': BusStop(
        id: 'gopalapatnam',
        name: 'Gopalapatnam',
        nameTelugu: 'గోపాలపట్నం',
        lat: 17.7550,
        lng: 83.3450),
    'kancharapalem': BusStop(
        id: 'kancharapalem',
        name: 'Kancharapalem',
        nameTelugu: 'కంచరపాలెం',
        lat: 17.7380,
        lng: 83.3150),
    'gurudwara': BusStop(
        id: 'gurudwara',
        name: 'Gurudwara',
        nameTelugu: 'గురుద్వారా',
        lat: 17.7350,
        lng: 83.3100),

    // ── Scindia / Gajuwaka corridor ──
    'scindia': BusStop(
        id: 'scindia',
        name: 'Scindia',
        nameTelugu: 'సింధియా',
        lat: 17.7400,
        lng: 83.3200),
    'malkapuram': BusStop(
        id: 'malkapuram',
        name: 'Malkapuram',
        nameTelugu: 'మాల్కాపురం',
        lat: 17.7050,
        lng: 83.2750),
    'gajuwaka': BusStop(
        id: 'gajuwaka',
        name: 'Gajuwaka',
        nameTelugu: 'గాజువాక',
        lat: 17.6868,
        lng: 83.2185),
    'bhpv': BusStop(
        id: 'bhpv',
        name: 'BHPV',
        nameTelugu: 'బీహెచ్‌పీవీ',
        lat: 17.7100,
        lng: 83.2500),
    'kurmannapalem': BusStop(
        id: 'kurmannapalem',
        name: 'Kurmannapalem',
        nameTelugu: 'కుర్మన్నపాలెం',
        lat: 17.6750,
        lng: 83.2200),
    'pedagantyada': BusStop(
        id: 'pedagantyada',
        name: 'Pedagantyada',
        nameTelugu: 'పెదగంట్యాడ',
        lat: 17.6600,
        lng: 83.2100),
    'steel_plant': BusStop(
        id: 'steel_plant',
        name: 'Steel Plant',
        nameTelugu: 'స్టీల్ ప్లాంట్',
        lat: 17.6980,
        lng: 83.2180),

    // ── Maddilapalem / Endada ──
    'maddilapalem': BusStop(
        id: 'maddilapalem',
        name: 'Maddilapalem',
        nameTelugu: 'మడ్డిలపాలెం',
        lat: 17.7350,
        lng: 83.3100),
    'endada': BusStop(
        id: 'endada',
        name: 'Endada',
        nameTelugu: 'ఎందాడ',
        lat: 17.7420,
        lng: 83.3400),
    'arilova': BusStop(
        id: 'arilova',
        name: 'Arilova Colony',
        nameTelugu: 'అరిలోవ కాలనీ',
        lat: 17.7300,
        lng: 83.2900),
    'sitammadhara': BusStop(
        id: 'sitammadhara',
        name: 'Sitammadhara',
        nameTelugu: 'సీతమ్మధార',
        lat: 17.7280,
        lng: 83.3050),
    'satyam_junction': BusStop(
        id: 'satyam_junction',
        name: 'Satyam Junction',
        nameTelugu: 'సత్యం జంక్షన్',
        lat: 17.7260,
        lng: 83.3080),
    'hb_colony': BusStop(
        id: 'hb_colony',
        name: 'HB Colony',
        nameTelugu: 'హెచ్‌బీ కాలనీ',
        lat: 17.7260,
        lng: 83.2950),

    // ── Madhurawada / North ──
    'madhurawada': BusStop(
        id: 'madhurawada',
        name: 'Madhurawada',
        nameTelugu: 'మధురవాడ',
        lat: 17.7680,
        lng: 83.3700),
    'kommadi': BusStop(
        id: 'kommadi',
        name: 'Kommadi',
        nameTelugu: 'కొమ్మాడి',
        lat: 17.7750,
        lng: 83.3800),
    'anandapuram': BusStop(
        id: 'anandapuram',
        name: 'Anandapuram',
        nameTelugu: 'ఆనందాపురం',
        lat: 17.7850,
        lng: 83.3900),
    'tagarapuvalasa': BusStop(
        id: 'tagarapuvalasa',
        name: 'Tagarapuvalasa',
        nameTelugu: 'తాగరపువలస',
        lat: 17.8100,
        lng: 83.4100),
    'rushikonda': BusStop(
        id: 'rushikonda',
        name: 'Rushikonda',
        nameTelugu: 'రుషికొండ',
        lat: 17.7600,
        lng: 83.3800),
    'sagarnagar': BusStop(
        id: 'sagarnagar',
        name: 'Sagarnagar',
        nameTelugu: 'సాగర్‌నగర్',
        lat: 17.7550,
        lng: 83.3700),
    'ins_kalinga': BusStop(
        id: 'ins_kalinga',
        name: 'INS Kalinga',
        nameTelugu: 'ఐఎన్‌ఎస్ కాలింగ',
        lat: 17.7480,
        lng: 83.3600),
    'bhimili': BusStop(
        id: 'bhimili',
        name: 'Bhimili',
        nameTelugu: 'భీమిలి',
        lat: 17.8900,
        lng: 83.4600),

    // ── Simhachalam ──
    'simhachalam': BusStop(
        id: 'simhachalam',
        name: 'Simhachalam',
        nameTelugu: 'సింహాచలం',
        lat: 17.7650,
        lng: 83.2850),
    'simhachalam_hilltop': BusStop(
        id: 'simhachalam_hilltop',
        name: 'Simhachalam Hill Top',
        nameTelugu: 'సింహాచలం కొండపైన',
        lat: 17.7700,
        lng: 83.2780),
    'adavivaram': BusStop(
        id: 'adavivaram',
        name: 'Adavivaram',
        nameTelugu: 'అడవివరం',
        lat: 17.7550,
        lng: 83.2950),
    'vepagunta': BusStop(
        id: 'vepagunta',
        name: 'Vepagunta',
        nameTelugu: 'వేపగుంట',
        lat: 17.7800,
        lng: 83.3100),
    'hanumanthawaka': BusStop(
        id: 'hanumanthawaka',
        name: 'Hanumanthawaka Jn',
        nameTelugu: 'హనుమంతవాక జంక్షన్',
        lat: 17.7730,
        lng: 83.3000),

    // ── Pendurthi / Kothavalasa ──
    'pendurthi': BusStop(
        id: 'pendurthi',
        name: 'Pendurthi',
        nameTelugu: 'పెందుర్తి',
        lat: 17.7100,
        lng: 83.2600),
    'kothavalasa': BusStop(
        id: 'kothavalasa',
        name: 'Kothavalasa',
        nameTelugu: 'కొత్తవలస',
        lat: 17.7000,
        lng: 83.1800),
    'duvvada': BusStop(
        id: 'duvvada',
        name: 'Duvvada Railway Station',
        nameTelugu: 'దువ్వాడ రైల్వే స్టేషన్',
        lat: 17.6700,
        lng: 83.2050),

    // ── Kailasagiri ──
    'vuda_park': BusStop(
        id: 'vuda_park',
        name: 'VUDA Park',
        nameTelugu: 'వుడా పార్క్',
        lat: 17.7230,
        lng: 83.3390),
    'tenneti_park': BusStop(
        id: 'tenneti_park',
        name: 'Tenneti Park',
        nameTelugu: 'తెన్నేటి పార్క్',
        lat: 17.7200,
        lng: 83.3450),
    'kailasagiri': BusStop(
        id: 'kailasagiri',
        name: 'Kailasagiri',
        nameTelugu: 'కైలాసగిరి',
        lat: 17.7100,
        lng: 83.3520),

    // ── Anakapalli / outer ──
    'anakapalli': BusStop(
        id: 'anakapalli',
        name: 'Anakapalle',
        nameTelugu: 'అనకాపల్లి',
        lat: 17.6910,
        lng: 83.0060),
    'aganampudi': BusStop(
        id: 'aganampudi',
        name: 'Aganampudi',
        nameTelugu: 'అగనంపూడి',
        lat: 17.6780,
        lng: 83.1600),
    'parawada': BusStop(
        id: 'parawada',
        name: 'Parawada',
        nameTelugu: 'పరవాడ',
        lat: 17.6500,
        lng: 83.1500),
    'sabbavaram': BusStop(
        id: 'sabbavaram',
        name: 'Sabbavaram',
        nameTelugu: 'సబ్బవరం',
        lat: 17.7200,
        lng: 83.0500),
    'chodavaram': BusStop(
        id: 'chodavaram',
        name: 'Chodavaram',
        nameTelugu: 'చోడవరం',
        lat: 17.8100,
        lng: 82.9300),
    'sontyam': BusStop(
        id: 'sontyam',
        name: 'Sontyam',
        nameTelugu: 'సోంత్యం',
        lat: 17.7900,
        lng: 83.1500),
    'yelamanchili': BusStop(
        id: 'yelamanchili',
        name: 'Yelamanchili',
        nameTelugu: 'ఏలమంచిలి',
        lat: 17.5400,
        lng: 82.8700),
    'devarapalli': BusStop(
        id: 'devarapalli',
        name: 'Devarapalli',
        nameTelugu: 'దేవరపల్లి',
        lat: 17.7500,
        lng: 83.0500),
    'vizianagaram': BusStop(
        id: 'vizianagaram',
        name: 'Vizianagaram',
        nameTelugu: 'విజయనగరం',
        lat: 18.1067,
        lng: 83.3956),

    // ── Misc stops ──
    'pm_palem': BusStop(
        id: 'pm_palem',
        name: 'PM Palem',
        nameTelugu: 'పీఎం పాలెం',
        lat: 17.7500,
        lng: 83.3600),
    'mindi': BusStop(
        id: 'mindi',
        name: 'Mindi',
        nameTelugu: 'మింఢి',
        lat: 17.6800,
        lng: 83.2400),
    'naval_base': BusStop(
        id: 'naval_base',
        name: 'Naval Base / Dockyard',
        nameTelugu: 'నావల్ బేస్',
        lat: 17.7000,
        lng: 83.2800),
    'sagar_nagar': BusStop(
        id: 'sagar_nagar',
        name: 'Sagar Nagar',
        nameTelugu: 'సాగర్‌నగర్',
        lat: 17.7550,
        lng: 83.3700),
    'madhavadhara': BusStop(
        id: 'madhavadhara',
        name: 'Madhavadhara',
        nameTelugu: 'మాధవధార',
        lat: 17.7380,
        lng: 83.2950),
    'muralinagar': BusStop(
        id: 'muralinagar',
        name: 'Muralinagar',
        nameTelugu: 'మురళీనగర్',
        lat: 17.7350,
        lng: 83.3000),
    'kailasapuram': BusStop(
        id: 'kailasapuram',
        name: 'Kailasapuram',
        nameTelugu: 'కైలాసపురం',
        lat: 17.7320,
        lng: 83.3020),
    'akkayyapalem': BusStop(
        id: 'akkayyapalem',
        name: 'Akkayapalem',
        nameTelugu: 'అక్కయ్యపాలెం',
        lat: 17.7300,
        lng: 83.3040),
    'yarada': BusStop(
        id: 'yarada',
        name: 'Yarada',
        nameTelugu: 'యారాడ',
        lat: 17.6600,
        lng: 83.2600),
    'airport': BusStop(
        id: 'airport',
        name: 'Visakhapatnam Airport',
        nameTelugu: 'విశాఖ విమానాశ్రయం',
        lat: 17.7212,
        lng: 83.2246),
    'it_park': BusStop(
        id: 'it_park',
        name: 'IT Park',
        nameTelugu: 'ఐటీ పార్క్',
        lat: 17.7480,
        lng: 83.3520),
    'carshed': BusStop(
        id: 'carshed',
        name: 'Carshed / IT Park',
        nameTelugu: 'కార్ షెడ్',
        lat: 17.7480,
        lng: 83.3520),
    'port': BusStop(
        id: 'port',
        name: 'Visakhapatnam Port',
        nameTelugu: 'విశాఖ పోర్ట్',
        lat: 17.6880,
        lng: 83.2920),
    'venkojipalem': BusStop(
        id: 'venkojipalem',
        name: 'Venkojipalem',
        nameTelugu: 'వేంకోజీపాలెం',
        lat: 17.7420,
        lng: 83.3480),
    'fishing_harbour': BusStop(
        id: 'fishing_harbour',
        name: 'Fishing Harbour',
        nameTelugu: 'ఫిషింగ్ హార్బర్',
        lat: 17.7050,
        lng: 83.2850),
    'gangavaram': BusStop(
        id: 'gangavaram',
        name: 'Gangavaram',
        nameTelugu: 'గంగవరం',
        lat: 17.6400,
        lng: 83.2300),
    'narava': BusStop(
        id: 'narava',
        name: 'Narava',
        nameTelugu: 'నారవ',
        lat: 17.7600,
        lng: 83.2700),
    'sheelanagar': BusStop(
        id: 'sheelanagar',
        name: 'Sheelanagar',
        nameTelugu: 'శీలానగర్',
        lat: 17.7200,
        lng: 83.2500),
    'mvp_complex': BusStop(
        id: 'mvp_complex',
        name: 'MVP Complex',
        nameTelugu: 'ఎంవీపీ కాంప్లెక్స్',
        lat: 17.7500,
        lng: 83.3350),
    'rajeev_nagar': BusStop(
        id: 'rajeev_nagar',
        name: 'Rajeev Nagar',
        nameTelugu: 'రాజీవ్ నగర్',
        lat: 17.6680,
        lng: 83.2200),
    'ukkunagaram': BusStop(
        id: 'ukkunagaram',
        name: 'Ukkunagaram',
        nameTelugu: 'ఉక్కు నగరం',
        lat: 17.6950,
        lng: 83.2310),
    'vizag_zoo': BusStop(
        id: 'vizag_zoo',
        name: 'Zoo Park',
        nameTelugu: 'జూ పార్క్',
        lat: 17.7620,
        lng: 83.2900),
    'kambalakonda': BusStop(
        id: 'kambalakonda',
        name: 'Kambalakonda',
        nameTelugu: 'కంబాలకొండ',
        lat: 17.7700,
        lng: 83.2980),
    'ntpc': BusStop(
        id: 'ntpc',
        name: 'NTPC',
        nameTelugu: 'ఎన్‌టీపీసీ',
        lat: 17.6300,
        lng: 83.1800),
    'achutapuram': BusStop(
        id: 'achutapuram',
        name: 'Achutapuram',
        nameTelugu: 'అచ్యుతాపురం',
        lat: 17.5800,
        lng: 82.9000),
  };

  static BusStop? get(String id) => all[id];
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
        number: '28K',
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
          'carshed',
          'it_park'
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
          'mvp_complex',
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
          'sagarnagar',
          'ins_kalinga',
          'bhimili'
        ],
        busType: BusType.blueExpress,
        frequencyMins: 20),
    BusRoute(
        number: '900R',
        from: 'RTC Complex',
        to: 'Rushikonda',
        viaStops: ['INS Kalinga', 'Sagarnagar'],
        stopIds: ['rtc_complex', 'ins_kalinga', 'sagarnagar', 'rushikonda'],
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
          'carshed',
          'it_park'
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
        from: 'MVP Complex',
        to: 'Simhachalam',
        viaStops: ['Maddilapalem', 'Gurudwara', 'NAD', 'Gopalapatnam'],
        stopIds: [
          'mvp_complex',
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
        from: 'MVP Complex',
        to: 'Gajuwaka',
        viaStops: ['Maddilapalem', 'Gurudwara', 'NAD', 'BHPV'],
        stopIds: [
          'mvp_complex',
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
