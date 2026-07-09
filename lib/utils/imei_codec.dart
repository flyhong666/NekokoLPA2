import 'dart:typed_data';

/// Converts the app's ordinary digit-order IMEI bytes into the swapped BCD
/// encoding used by GSMA deviceInfo.imei.
Uint8List encodeDeviceInfoImei(List<int> imei) {
  final digits = imeiDigitsFromStoredBytes(imei);
  return _encodeSwappedBcd(digits);
}

/// Reads IMEI digits from the app's persisted byte format.
///
/// The settings value is 8 bytes in ordinary digit order, with the final
/// nibble used as filler for a 15-digit IMEI. deviceInfo.imei must not expose
/// that filler as a real digit.
String imeiDigitsFromStoredBytes(List<int> imei) {
  if (imei.length != 8) {
    throw ArgumentError.value(imei.length, 'imei.length', 'must be 8 bytes');
  }

  final digits = StringBuffer();
  for (var index = 0; index < imei.length; index++) {
    final byte = imei[index];
    final nibbles = [(byte >> 4) & 0x0f, byte & 0x0f];
    for (var nibbleIndex = 0; nibbleIndex < nibbles.length; nibbleIndex++) {
      final isLastNibble = index == imei.length - 1 && nibbleIndex == 1;
      final nibble = nibbles[nibbleIndex];
      if (isLastNibble) {
        break;
      }
      if (nibble > 9) {
        throw FormatException(
          'invalid IMEI digit nibble: 0x${nibble.toRadixString(16)}',
        );
      }
      digits.write(nibble);
    }
  }

  return digits.toString();
}

Uint8List _encodeSwappedBcd(String digits) {
  if (digits.length.isOdd) {
    digits += 'F';
  }

  final out = Uint8List(digits.length ~/ 2);
  for (var index = 0; index < out.length; index++) {
    final first = int.parse(digits[index * 2], radix: 16);
    final second = int.parse(digits[index * 2 + 1], radix: 16);
    out[index] = ((second << 4) & 0xf0) | (first & 0x0f);
  }
  return out;
}
