import 'package:flutter_test/flutter_test.dart';

import 'package:ems_mobile/core/utils/fmt.dart';

void main() {
  test('Fmt.num formats numbers with unit', () {
    expect(Fmt.num(23.456, decimals: 1, unit: '°C'), '23.5°C');
    expect(Fmt.num(null), '—');
  });
}
