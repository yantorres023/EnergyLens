@Tags(['golden'])
library;

import 'dart:io';

import 'package:energylens/app/app_controller.dart';
import 'package:energylens/data/repository.dart';
import 'package:energylens/domain/comparison.dart';
import 'package:energylens/domain/insights.dart';
import 'package:energylens/domain/models.dart';
import 'package:energylens/domain/tariff_reference.dart';
import 'package:energylens/ui/app.dart';
import 'package:energylens/ui/bill_detail_screen.dart';
import 'package:energylens/ui/comparison_screen.dart';
import 'package:energylens/ui/insight_widgets.dart';
import 'package:energylens/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Goldens are generated on Linux (CI: ubuntu). Regenerate with
/// `flutter test --update-goldens test/golden`.
void main() {
  late AppController app;

  Future<void> setUpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final repo = InMemoryRepository();
    await repo.saveHousehold(
      const Household(
        id: 'h1',
        tariffKind: TariffKind.standardVariable,
        directDebitMonthlyPence: 9000,
      ),
    );
    await repo.saveSettings(
      const AppSettings(onboardingCompleted: true, activeHouseholdId: 'h1'),
    );
    await repo.saveBill(septemberBill(stated: 9550));
    await repo.saveBill(octoberBill());
    app = AppController(
      repository: repo,
      reference: TariffDataset.parse(
        File('assets/data/gb_price_cap_electricity.json').readAsStringSync(),
      ),
      clock: () => DateTime.utc(2026, 11, 5),
    );
    await app.load();
  }

  Widget wrap(Widget child) => AppScope(
    controller: app,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: child,
    ),
  );

  testWidgets('home', (tester) async {
    await setUpApp(tester);
    await tester.pumpWidget(EnergyLensApp(controller: app));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('bill detail', (tester) async {
    await setUpApp(tester);
    await tester.pumpWidget(wrap(const BillDetailScreen(billId: 'oct')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/bill_detail.png'),
    );
  });

  testWidgets('comparison', (tester) async {
    await setUpApp(tester);
    final c = BillComparison.compare(septemberBill(), octoberBill());
    await tester.pumpWidget(wrap(ComparisonScreen(comparison: c)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/comparison.png'),
    );
  });

  testWidgets('insight', (tester) async {
    await setUpApp(tester);
    final c = BillComparison.compare(septemberBill(), octoberBill());
    final insight = app
        .insightsFor(app.latestBill!)
        .firstWhere((i) => i.kind == InsightKind.mainDriver);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: ListView(
            children: [
              InsightCard(
                insight: insight,
                bill: app.latestBill!,
                comparison: c,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/insight.png'),
    );
  });

  testWidgets('action', (tester) async {
    await setUpApp(tester);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showActionSheet(
                  context,
                  ActionType.reduceDailyUsage,
                  app.latestBill!,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/action.png'),
    );
  });
}
