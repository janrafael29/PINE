import 'package:flutter_test/flutter_test.dart';
import 'package:pine/utils/phone_e164.dart';

void main() {
  test('normalizeToE164 handles PH 09...', () {
    expect(normalizeToE164('09171234567'), '+639171234567');
  });

  test('looksLikeE164 accepts +63...', () {
    expect(looksLikeE164('+639171234567'), isTrue);
    expect(looksLikeE164('0917'), isFalse);
  });
}
