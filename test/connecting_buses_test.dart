import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/data/vizag_data.dart';
import 'package:vizag_bus_live/firebase_options.dart';
import 'package:vizag_bus_live/services/app_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') {
        rethrow;
      }
    }
  });

  test('Pendurthi -> Kailasagiri shows connecting buses (no direct)', () {
    final p = AppProvider();
    final from = VizagStops.resolve('pendurthi');
    final to = VizagStops.resolve('kailasagiri');

    final direct = p.searchRoutes(from, to);
    final connecting = p.searchConnectingRoutes(from, to);

    // ignore: avoid_print
    print('direct: ${direct.map((r) => r.route.routeId).toList()}');
    // ignore: avoid_print
    print('connecting:');
    for (final c in connecting) {
      // ignore: avoid_print
      print('  ${c.legs.map((l) => '${l.route.number}: ${l.fromStop.name} -> ${l.toStop.name}').join(' THEN ')}'
          ' | total ${c.totalEtaMins} min');
    }

    expect(direct, isEmpty, reason: 'no single route covers this pair');
    expect(connecting, isNotEmpty);
    final best = connecting.first;
    expect(best.legs.length, 2);
    expect(best.firstLeg.fromStop.id, 'pendurthi');
    expect(best.secondLeg.toStop.id, 'kailasagiri');
  });

  test('more real connecting pairs across the network', () {
    final p = AppProvider();
    final pairs = [
      ('pendurthi', 'kailasagiri'),
      ('gajuwaka', 'madhurawada'),
      ('bheemili', 'rtc_complex'),
      ('simhachalam', 'kailasagiri'),
      ('anandapuram', 'gajuwaka'),
    ];
    for (final (f, t) in pairs) {
      final from = VizagStops.resolve(f);
      final to = VizagStops.resolve(t);
      final direct = p.searchRoutes(from, to);
      final connecting = p.searchConnectingRoutes(from, to);
      // ignore: avoid_print
      print('$f -> $t | direct=${direct.length} connecting=${connecting.length}'
          '${connecting.isNotEmpty ? ' via ${connecting.first.transferStop.name} (${connecting.first.legs.map((l) => l.route.number).join("+")})' : ''}');
      if (direct.isEmpty) {
        expect(connecting, isNotEmpty, reason: '$f -> $t needs connections');
      }
    }
  });
}
