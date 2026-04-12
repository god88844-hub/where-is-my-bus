import 'package:flutter_test/flutter_test.dart';
import 'package:vizag_bus_live/dev/mock_coordinate_scenarios.dart';

void main() {
  test('111 reverse mock stream exists and has multiple samples', () {
    final scenario = MockCoordinateScenarios.forRoute('111-R');

    expect(scenario, isNotNull);
    expect(scenario!.displayName, contains('Tagarapuvalasa'));
    expect(scenario.samples.length, greaterThan(10));
  });

  test('111 forward mock stream exists and has multiple samples', () {
    final scenario = MockCoordinateScenarios.forRoute('111');

    expect(scenario, isNotNull);
    expect(scenario!.displayName, contains('Kurmannapalem'));
    expect(scenario.samples.length, greaterThan(10));
  });
}
