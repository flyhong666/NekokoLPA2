import 'dart:math';
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
    expect(tacDigitsFromStoredBytes(stored), '35209900');
    expect(
      encodeDeviceInfoImei(stored),
      Uint8List.fromList([0x53, 0x02, 0x99, 0x00, 0x71, 0x16, 0x84, 0xf1]),
    );
  });

  test('builds stored IMEI bytes from default TAC', () {
    final stored = storedImeiBytesFromDigits(
      defaultDeviceTac,
      random: Random(1),
    );
    final digits = imeiDigitsFromStoredBytes(stored);

    expect(digits, hasLength(15));
    expect(digits, startsWith(defaultDeviceTac));
    expect(
      digits[14],
      calculateImeiLuhnChecksum(digits.substring(0, 14)).toString(),
    );
    expect(tacDigitsFromStoredBytes(stored), defaultDeviceTac);
  });

  test('normalizes full IMEI digits to stored bytes with filler nibble', () {
    final stored = storedImeiBytesFromDigits('353837410000013');

    expect(imeiDigitsFromStoredBytes(stored), '353837410000013');
    expect(stored.last & 0x0f, 0);
  });
}
