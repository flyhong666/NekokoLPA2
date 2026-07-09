import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/utils/imei_codec.dart';

void main() {
  test('encodes stored 15 digit IMEI as swapped BCD with F filler', () {
    final stored = Uint8List.fromList([
      0x35,
      0x20,
      0x99,
      0x00,
      0x17,
      0x61,
      0x48,
      0x10,
    ]);

    expect(imeiDigitsFromStoredBytes(stored), '352099001761481');
    expect(
      encodeDeviceInfoImei(stored),
      Uint8List.fromList([0x53, 0x02, 0x99, 0x00, 0x71, 0x16, 0x84, 0xf1]),
    );
  });
}
