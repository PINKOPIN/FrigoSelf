import 'package:flutter_test/flutter_test.dart';
import 'package:frigoself/core/constants/categories.dart';
import 'package:frigoself/core/utils/expiry_utils.dart';
import 'package:frigoself/core/utils/food_logic.dart';
import 'package:frigoself/domain/models/food_item.dart';

FoodItem item(
  String name, {
  int days = 10,
  String category = 'other',
  String brand = '',
  bool favorite = false,
  DateTime? opened,
  FoodStatus status = FoodStatus.active,
  DateTime? closedAt,
  double? price,
  StorageLocation location = StorageLocation.fridge,
}) {
  final today = DateTime.now();
  return FoodItem(
    id: name,
    name: name,
    category: category,
    location: location,
    expiryDate: DateTime(today.year, today.month, today.day + days),
    brand: brand,
    favorite: favorite,
    openedDate: opened,
    status: status,
    closedAt: closedAt,
    price: price,
  );
}

void main() {
  group('FoodFilter', () {
    final list = [
      item('Latte', days: 2, category: 'milk', brand: 'Granarolo'),
      item('Pasta', days: 100, category: 'pasta', brand: 'Barilla', favorite: true),
      item('Yogurt', days: 5, category: 'yogurt', opened: DateTime.now()),
    ];

    test('ordina per scadenza (più urgenti prima)', () {
      final r = const FoodFilter().apply(list);
      expect(r.map((e) => e.name), ['Latte', 'Yogurt', 'Pasta']);
    });
    test('ricerca per nome', () {
      expect(const FoodFilter(query: 'pas').apply(list).single.name, 'Pasta');
    });
    test('ricerca per marca', () {
      expect(const FoodFilter(query: 'granarolo').apply(list).single.name, 'Latte');
    });
    test('filtro colore', () {
      expect(const FoodFilter(level: ExpiryLevel.red).apply(list).single.name, 'Latte');
      expect(const FoodFilter(level: ExpiryLevel.yellow).apply(list).single.name, 'Yogurt');
      expect(const FoodFilter(level: ExpiryLevel.green).apply(list).single.name, 'Pasta');
    });
    test('solo preferiti', () {
      expect(const FoodFilter(favoritesOnly: true).apply(list).single.name, 'Pasta');
    });
    test('aperti / chiusi', () {
      expect(const FoodFilter(opened: true).apply(list).single.name, 'Yogurt');
      expect(const FoodFilter(opened: false).apply(list).length, 2);
    });
    test('categoria', () {
      expect(const FoodFilter(category: 'milk').apply(list).single.name, 'Latte');
    });
    test('isActive', () {
      expect(const FoodFilter().isActive, isFalse);
      expect(const FoodFilter(favoritesOnly: true).isActive, isTrue);
    });
  });

  group('groupByLevel', () {
    test('divide nei tre colori e ordina', () {
      final g = groupByLevel([
        item('A', days: 30),
        item('B', days: -2),
        item('C', days: 4),
        item('D', days: 1),
      ]);
      expect(g[ExpiryLevel.red]!.map((e) => e.name), ['B', 'D']);
      expect(g[ExpiryLevel.yellow]!.map((e) => e.name), ['C']);
      expect(g[ExpiryLevel.green]!.map((e) => e.name), ['A']);
    });
  });

  group('findDuplicate', () {
    final list = [item('Latte')];
    test('trova ignorando maiuscole e spazi', () {
      expect(findDuplicate(list, '  latte '), isNotNull);
    });
    test('non trova se il nome è diverso', () {
      expect(findDuplicate(list, 'Pane'), isNull);
    });
    test('esclude l\'alimento in modifica', () {
      expect(findDuplicate(list, 'Latte', excludeId: 'Latte'), isNull);
    });
  });

  group('Stats', () {
    final now = DateTime.now();
    final list = [
      item('A', category: 'milk', status: FoodStatus.consumed, closedAt: now),
      item('B', category: 'milk', status: FoodStatus.wasted, closedAt: now, price: 2.5),
      item('C', category: 'meat', status: FoodStatus.wasted, closedAt: now, price: 7.0),
      item('D', category: 'milk'),
    ];
    final s = Stats(list);

    test('conteggi', () {
      expect(s.inserted, 4);
      expect(s.consumed, 1);
      expect(s.wasted, 2);
    });
    test('costo dello spreco', () => expect(s.wasteCost, 9.5));
    test('categoria più acquistata', () => expect(s.topBoughtCategory, 'milk'));
    test('categoria più sprecata (parità: la prima trovata)', () {
      expect(['milk', 'meat'], contains(s.topWastedCategory));
    });
    test('ultimi 6 mesi: 6 punti e mese corrente popolato', () {
      final m = s.lastMonths(6);
      expect(m.length, 6);
      expect(m.last.consumed, 1);
      expect(m.last.wasted, 2);
      expect(m.first.consumed, 0);
    });
    test('senza dati', () {
      final e = Stats(const []);
      expect(e.topBoughtCategory, isNull);
      expect(e.wasteCost, 0);
    });
  });

  group('FoodItem JSON (backup)', () {
    test('andata e ritorno', () {
      final a = item('Burro', days: 20, category: 'milk', brand: 'X', price: 1.9, favorite: true);
      final b = FoodItem.fromJson('id', a.toJson());
      expect(b.name, 'Burro');
      expect(b.category, 'milk');
      expect(b.brand, 'X');
      expect(b.price, 1.9);
      expect(b.favorite, isTrue);
      expect(b.expiryDate, a.expiryDate);
      expect(b.location, StorageLocation.fridge);
    });
    test('valori mancanti non causano errori', () {
      final b = FoodItem.fromJson('x', {'name': 'Solo nome'});
      expect(b.category, 'other');
      expect(b.status, FoodStatus.active);
    });
  });

  test('ogni categoria ha id univoco', () {
    final ids = Categories.all.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(Categories.byId('non-esiste').id, 'other');
  });
}
