import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigoself/core/l10n/app_l10n.dart';
import 'package:frigoself/core/theme/app_theme.dart';
import 'package:frigoself/domain/models/food_item.dart';
import 'package:frigoself/presentation/widgets/common.dart';
import 'package:integration_test/integration_test.dart';

/// Test di integrazione sui componenti grafici principali (non richiedono il backend).
/// Esegui con: flutter test integration_test
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {Locale locale = const Locale('it')}) => MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppL10n.supported,
        localizationsDelegates: AppL10n.delegates,
        home: Scaffold(body: child),
      );

  FoodItem make(int days) {
    final t = DateTime.now();
    return FoodItem(
      id: 'x',
      name: 'Latte intero',
      category: 'milk',
      location: StorageLocation.fridge,
      expiryDate: DateTime(t.year, t.month, t.day + days),
      brand: 'Granarolo',
    );
  }

  testWidgets('la riga alimento mostra nome, marca e scadenza', (tester) async {
    await tester.pumpWidget(wrap(FoodTile(item: make(2), onTap: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Latte intero'), findsOneWidget);
    expect(find.textContaining('Granarolo'), findsOneWidget);
    expect(find.text('tra 2 giorni'), findsOneWidget);
  });

  testWidgets('alimento scaduto mostra il testo "scaduto da"', (tester) async {
    await tester.pumpWidget(wrap(FoodTile(item: make(-3), onTap: () {})));
    await tester.pumpAndSettle();
    expect(find.text('scaduto da 3 giorni'), findsOneWidget);
  });

  testWidgets('traduzione in inglese', (tester) async {
    await tester.pumpWidget(wrap(FoodTile(item: make(1), onTap: () {}), locale: const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Expires tomorrow'), findsOneWidget);
  });

  testWidgets('il tap sulla riga viene notificato', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(FoodTile(item: make(10), onTap: () => tapped = true)));
    await tester.tap(find.text('Latte intero'));
    expect(tapped, isTrue);
  });

  testWidgets('stato vuoto', (tester) async {
    await tester.pumpWidget(wrap(const EmptyState(icon: Icons.kitchen, title: 'Vuoto', hint: 'Aggiungi')));
    expect(find.text('Vuoto'), findsOneWidget);
    expect(find.text('Aggiungi'), findsOneWidget);
  });
}
