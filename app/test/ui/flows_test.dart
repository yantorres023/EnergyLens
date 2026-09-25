import 'dart:io';

import 'package:energylens/app/app_controller.dart';
import 'package:energylens/data/repository.dart';
import 'package:energylens/domain/models.dart';
import 'package:energylens/domain/tariff_reference.dart';
import 'package:energylens/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../parsing/bill_text_parser_test.dart' show singleRateBill;

Future<AppController> pumpApp(
  WidgetTester tester, {
  InMemoryRepository? repo,
  bool onboarded = false,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);
  final r = repo ?? InMemoryRepository();
  if (onboarded) {
    await r.saveHousehold(
      const Household(
        id: 'h1',
        tariffKind: TariffKind.standardVariable,
        directDebitMonthlyPence: 9000,
      ),
    );
    await r.saveSettings(
      const AppSettings(onboardingCompleted: true, activeHouseholdId: 'h1'),
    );
  }
  final app = AppController(
    repository: r,
    reference: TariffDataset.parse(
      File('assets/data/gb_price_cap_electricity.json').readAsStringSync(),
    ),
    clock: () => DateTime.utc(2026, 11, 5),
  );
  await app.load();
  await tester.pumpWidget(EnergyLensApp(controller: app));
  await tester.pumpAndSettle();
  return app;
}

Future<void> enterBill(
  WidgetTester tester, {
  required String start,
  required String end,
  required String kwh,
  required String rate,
  required String standing,
  String? total,
}) async {
  await tester.tap(find.byKey(const Key('add_bill')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add_manual')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('start_date')), start);
  await tester.enterText(find.byKey(const Key('end_date')), end);
  await tester.enterText(find.byKey(const Key('kwh')), kwh);
  await tester.enterText(find.byKey(const Key('rate')), rate);
  await tester.enterText(find.byKey(const Key('standing')), standing);
  if (total != null) {
    await tester.enterText(find.byKey(const Key('stated_total')), total);
  }
  await tester.tap(find.byKey(const Key('save_bill')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding → empty home', (tester) async {
    final app = await pumpApp(tester);
    expect(find.text('Why did my electricity bill change?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Your bills stay on this phone'), findsOneWidget);
    // Analytics defaults to off.
    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('analytics_switch')),
    );
    expect(sw.value, isFalse);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('dd_field')), '90');
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Add your latest electricity bill'), findsOneWidget);
    expect(app.household!.directDebitMonthlyPence, 9000);
    expect(app.settings.analyticsOptIn, isFalse);
  });

  testWidgets('two manual bills → what changed and why', (tester) async {
    final app = await pumpApp(tester, onboarded: true);
    await enterBill(
      tester,
      start: '01/09/2026',
      end: '30/09/2026',
      kwh: '300',
      rate: '24.87',
      standing: '54.47',
      total: '95.50',
    );
    expect(app.bills.length, 1);
    expect(find.byKey(const Key('home_total')), findsOneWidget);
    expect(find.text('£95.50'), findsWidgets);
    expect(find.text('Matches your bill'), findsOneWidget);

    // October: VAT defaults to 0% because the bill starts on 1 Oct 2026.
    await enterBill(
      tester,
      start: '01/10/2026',
      end: '31/10/2026',
      kwh: '341',
      rate: '26.32',
      standing: '54.83',
    );
    expect(app.bills.length, 2);
    expect(app.bills.last.ratePeriods.single.vatBasisPoints, 0);
    expect(find.text('£106.75'), findsWidgets);
    expect(find.text('£11.25 more'), findsOneWidget);

    await tester.tap(find.byKey(const Key('change_card')));
    await tester.pumpAndSettle();
    expect(find.text('£11.25 more than last time'), findsOneWidget);
    expect(find.text('VAT rate changed (5% to 0%)'), findsOneWidget);
    expect(
      find.text('Higher price per kWh (24.87p to 26.32p before VAT)'),
      findsOneWidget,
    );
    expect(find.textContaining('These add up to +£11.25'), findsOneWidget);
  });

  testWidgets('choosing an action shows it as waiting for next bill', (
    tester,
  ) async {
    await pumpApp(tester, onboarded: true);
    await enterBill(
      tester,
      start: '01/09/2026',
      end: '30/09/2026',
      kwh: '300',
      rate: '24.87',
      standing: '54.47',
    );
    await enterBill(
      tester,
      start: '01/10/2026',
      end: '31/10/2026',
      kwh: '341',
      rate: '26.32',
      standing: '54.83',
    );
    await tester.tap(find.byKey(const Key('action_mainDriver')));
    await tester.pumpAndSettle();
    expect(find.text('Use less electricity per day'), findsWidgets);
    await tester.tap(find.byKey(const Key('start_experiment')));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for your next bill…'), findsOneWidget);

    await enterBill(
      tester,
      start: '01/11/2026',
      end: '30/11/2026',
      kwh: '300',
      rate: '26.32',
      standing: '54.83',
    );
    expect(find.text('Your action result is in'), findsOneWidget);
    expect(find.text('Result: Improved'), findsWidgets);
  });

  testWidgets('bad input is caught before saving', (tester) async {
    final app = await pumpApp(tester, onboarded: true);
    await enterBill(
      tester,
      start: '31/02/2026',
      end: '30/09/2026',
      kwh: 'abc',
      rate: '0.26',
      standing: '54',
    );
    expect(find.text('Enter a date as dd/mm/yyyy'), findsOneWidget);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(
      find.text('Looks like pounds — enter pence (e.g. 26.32)'),
      findsOneWidget,
    );
    expect(app.bills, isEmpty);
  });

  testWidgets('mismatch with the printed total asks before saving', (
    tester,
  ) async {
    final app = await pumpApp(tester, onboarded: true);
    await enterBill(
      tester,
      start: '01/09/2026',
      end: '30/09/2026',
      kwh: '300',
      rate: '24.87',
      standing: '54.47',
      total: '90.00',
    );
    expect(find.text('Doesn\'t match your bill'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(app.bills, isEmpty);
    await tester.tap(find.byKey(const Key('save_bill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();
    expect(app.bills.length, 1);
  });

  testWidgets('paste → review parsed values → correct one → save', (
    tester,
  ) async {
    final app = await pumpApp(tester, onboarded: true);
    await tester.tap(find.byKey(const Key('add_bill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_paste')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('paste_field')),
      singleRateBill,
    );
    await tester.tap(find.byKey(const Key('parse_button')));
    await tester.pumpAndSettle();
    expect(find.text('Check what we found'), findsOneWidget);
    expect(find.textContaining('Please check'), findsOneWidget);
    // The parsed values are prefilled for review.
    expect(find.widgetWithText(TextFormField, '24.87'), findsOneWidget);
    // User corrects kWh.
    await tester.enterText(find.byKey(const Key('kwh')), '301');
    await tester.tap(find.byKey(const Key('save_bill')));
    await tester.pumpAndSettle();
    // 301 kWh no longer matches the printed £95.50 → confirm.
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();
    final b = app.bills.single;
    expect(b.source, BillSource.pastedText);
    expect(b.fieldProvenance['rate'], Provenance.parsed);
    expect(b.fieldProvenance['kwh'], Provenance.userEntered);
    expect(b.corrections.single.field, 'kwh');
    expect(b.readingType, ReadingType.actual);
    // Personal details from the pasted text are nowhere in the stored bill.
    expect(b.toJson().toString(), isNot(contains('Example')));
    expect(b.toJson().toString(), isNot(contains('12345678')));
  });

  testWidgets('what-if re-prices a bill at a quote', (tester) async {
    await pumpApp(tester, onboarded: true);
    await enterBill(
      tester,
      start: '01/09/2026',
      end: '30/09/2026',
      kwh: '300',
      rate: '24.87',
      standing: '54.47',
    );
    await tester.tap(find.byKey(const Key('latest_bill_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_what_if')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('whatif_standing')), '60');
    await tester.enterText(find.byKey(const Key('whatif_rate')), '23');
    await tester.tap(find.byKey(const Key('whatif_calculate')));
    await tester.pumpAndSettle();
    expect(
      find.text('The quote would have been £4.15 cheaper for this bill.'),
      findsOneWidget,
    );
  });

  testWidgets('direct debit check shows an estimate', (tester) async {
    await pumpApp(tester, onboarded: true);
    await enterBill(
      tester,
      start: '01/09/2026',
      end: '30/09/2026',
      kwh: '300',
      rate: '24.87',
      standing: '54.47',
    );
    await enterBill(
      tester,
      start: '01/10/2026',
      end: '31/10/2026',
      kwh: '341',
      rate: '26.32',
      standing: '54.83',
    );
    await tester.tap(find.byKey(const Key('dd_card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dd_verdict')), findsOneWidget);
    expect(find.text('May be too low'), findsOneWidget);
    expect(find.text('Estimate'), findsWidgets);
  });

  testWidgets('delete a bill, then delete all data', (tester) async {
    final app = await pumpApp(tester, onboarded: true);
    await enterBill(
      tester,
      start: '01/09/2026',
      end: '30/09/2026',
      kwh: '300',
      rate: '24.87',
      standing: '54.47',
    );
    await tester.tap(find.byKey(const Key('latest_bill_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_bill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(app.bills, isEmpty);

    await tester.tap(find.byKey(const Key('open_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_all')));
    await tester.pumpAndSettle();
    expect(app.needsOnboarding, isTrue);
    expect(find.text('Why did my electricity bill change?'), findsOneWidget);
  });
}
