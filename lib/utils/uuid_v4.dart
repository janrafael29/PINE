library;

import 'dart:math';

/// RFC 4122 version-4 UUID (random), for offline-created Supabase rows.
String randomUuidV4() {
  final Random rnd = Random.secure();
  final List<int> b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const String h = '0123456789abcdef';
  String two(int n) => '${h[n >> 4]}${h[n & 0xf]}';
  return '${two(b[0])}${two(b[1])}${two(b[2])}${two(b[3])}-'
      '${two(b[4])}${two(b[5])}-'
      '${two(b[6])}${two(b[7])}-'
      '${two(b[8])}${two(b[9])}-'
      '${two(b[10])}${two(b[11])}${two(b[12])}${two(b[13])}${two(b[14])}${two(b[15])}';
}
