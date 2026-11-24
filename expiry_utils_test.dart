import 'package:flutter_test/flutter_test.dart';
import 'package:frigoself/core/utils/expiry_utils.dart';

void main() {
  final now = DateTime(2026, 11, 23, 15, 30); // l'orario non deve influire

  group('ExpiryUtils.daysLeft', () {
    test('oggi = 0', () => expect(ExpiryUtils.daysLeft(DateTime(2026, 11, 23), now: now), 0));
    test('domani = 1', () => expect(ExpiryUtils.daysLeft(DateTime(2026, 11, 24), now: now), 1));
    test('ieri = -1', () => expect(ExpiryUtils.daysLeft(DateTime(2026, 11, 22), now: now), -1));
    test('ignora l\'orario della scadenza',
        () => expect(ExpiryUtils.daysLeft(DateTime(2026, 11, 23, 23, 59), now: now), 0));
  });

  group('ExpiryUtils.level (verde > 7, giallo 3-7, rosso < 3 o scaduto)', () {
    ExpiryLevel at(int y, int m, int d) => ExpiryUtils.level(DateTime(y, m, d), now: now);

    test('scaduto = rosso', () => expect(at(2026, 11, 20), ExpiryLevel.red));
    test('oggi = rosso', () => expect(at(2026, 11, 23), ExpiryLevel.red));
    test('2 giorni = rosso', () => expect(at(2026, 11, 25), ExpiryLevel.red));
    test('3 giorni = giallo', () => expect(at(2026, 11, 26), ExpiryLevel.yellow));
    test('7 giorni = giallo', () => expect(at(2026, 11, 30), ExpiryLevel.yellow));
    test('8 giorni = verde', () => expect(at(2026, 12, 1), ExpiryLevel.green));
    test('60 giorni = verde', () => expect(at(2027, 1, 22), ExpiryLevel.green));
  });

  test('isExpired', () {
    expect(ExpiryUtils.isExpired(DateTime(2026, 11, 22), now: now), isTrue);
    expect(ExpiryUtils.isExpired(DateTime(2026, 11, 23), now: now), isFalse);
  });

  test('priorità: rosso prima di giallo prima di verde', () {
    final sorted = [...ExpiryLevel.values]..sort((a, b) => a.priority.compareTo(b.priority));
    expect(sorted, [ExpiryLevel.red, ExpiryLevel.yellow, ExpiryLevel.green]);
  });
}
