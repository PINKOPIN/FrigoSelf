import 'package:flutter_test/flutter_test.dart';
import 'package:frigoself/data/services/ocr_service.dart';
import 'package:frigoself/data/services/recipe_service.dart';
import 'package:frigoself/domain/models/food_item.dart';
import 'package:frigoself/core/constants/categories.dart';

void main() {
  final now = DateTime(2026, 11, 23);
  DateTime? parse(String s) => OcrService.parseExpiryDate(s, now: now);

  group('OCR: lettura data di scadenza', () {
    test('formato 31/12/2026', () => expect(parse('Scad. 31/12/2026'), DateTime(2026, 12, 31)));
    test('anno a due cifre', () => expect(parse('EXP 15.03.27'), DateTime(2027, 3, 15)));
    test('data completa non viene scambiata con mese/anno',
        () => expect(parse('15/03/2027'), DateTime(2027, 3, 15)));
    test('solo mese/anno = fine mese', () => expect(parse('12/2026'), DateTime(2026, 12, 31)));
    test('mese a lettere italiano', () => expect(parse('Da consumarsi entro 10 DIC 2026'), DateTime(2026, 12, 10)));
    test('OTT non viene rovinato dalla correzione O→0', () => expect(parse('5 OTT 2027'), DateTime(2027, 10, 5)));
    test('con più date sceglie la più lontana (scadenza, non produzione)',
        () => expect(parse('Prod 01/06/2026  Scad 01/06/2027'), DateTime(2027, 6, 1)));
    test('O al posto di 0 nelle cifre', () => expect(parse('1O/12/2026'), DateTime(2026, 12, 10)));
    test('giorno inesistente scartato', () => expect(parse('31/02/2027'), isNull));
    test('nessuna data', () => expect(parse('Lotto L123 Peso 500 g'), isNull));
    test('data troppo vecchia scartata', () => expect(parse('01/01/2020'), isNull));
  });

  group('Ricette anti-spreco', () {
    final service = RecipeService();
    FoodItem f(String name, String cat, int days) {
      final t = DateTime.now();
      return FoodItem(
        id: name,
        name: name,
        category: cat,
        location: StorageLocation.fridge,
        expiryDate: DateTime(t.year, t.month, t.day + days),
      );
    }

    test('nessun alimento urgente = nessuna ricetta', () {
      expect(service.suggest([f('Pasta', 'pasta', 90)]), isEmpty);
    });
    test('uova e verdura in scadenza suggeriscono la frittata', () {
      final r = service.suggest([f('Uova', 'eggs', 1), f('Zucchine', 'vegetables', 2)]);
      expect(r, isNotEmpty);
      expect(r.first.title.toLowerCase(), contains('frittata'));
    });
    test('alimenti già consumati vengono ignorati', () {
      final consumed = f('Uova', 'eggs', 1).copyWith(status: FoodStatus.consumed);
      expect(service.suggest([consumed]), isEmpty);
    });
  });
}
