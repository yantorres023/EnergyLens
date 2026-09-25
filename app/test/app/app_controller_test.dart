import 'dart:io';

import 'package:energylens/app/analytics.dart';
import 'package:energylens/app/app_controller.dart';
import 'package:energylens/data/repository.dart';
import 'package:energylens/domain/models.dart';
import 'package:energylens/domain/tariff_reference.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late InMemoryRepository repo;
  late AppController app;
  final reference = TariffDataset.parse(
    File('assets/data/gb_price_cap_electricity.json').readAsStringSync(),
  );

  setUp(() async {
    repo = InMemoryRepository();
    app = AppController(
      repository: repo,
      reference: reference,
      clock: () => DateTime.utc(2026, 11, 5),
    );
    await app.load();
  });

  Future<void> onboard({bool analytics = true, int? dd}) =>
      app.completeOnboarding(
        Household(
          id: 'h1',
          tariffKind: TariffKind.standardVariable,
          directDebitMonthlyPence: dd,
        ),
        analyticsOptIn: analytics,
      );

  test('starts in onboarding, then persists household', () async {
    expect(app.needsOnboarding, isTrue);
    await onboard();
    expect(app.needsOnboarding, isFalse);
    final reloaded = AppController(repository: repo);
    await reloaded.load();
    expect(reloaded.household!.tariffKind, TariffKind.standardVariable);
  });

  test('core loop: bill → compare → action → next bill verifies', () async {
    await onboard();
    await app.saveBill(septemberBill());
    expect(app.comparisonFor(app.latestBill!), isNull);
    await app.saveBill(octoberBill());
    final cmp = app.comparisonFor(app.latestBill!)!;
    expect(cmp.differencePence, 1125);

    final exp = await app.startExperiment(
      ActionType.reduceDailyUsage,
      app.latestBill!,
    );
    expect(app.activeExperiments.single.id, exp.id);

    final completed = await app.saveBill(
      bill('nov', [
        period(
          d(2026, 11, 1),
          d(2026, 11, 30),
          kwh: '300',
          rate: '26.32',
          standing: '54.83',
          vatBp: 0,
        ),
      ]),
    );
    expect(completed.single.outcome, ExperimentOutcome.improved);
    expect(app.activeExperiments, isEmpty);
    expect(app.completedExperiments.single.resultBillId, 'nov');
    expect(app.lastCompletedExperiment, isNotNull);

    final events = (await repo.listEvents()).map((e) => e.name).toList();
    expect(
      events,
      containsAll([
        Events.onboardingCompleted,
        Events.billAdded,
        Events.nextBillAdded,
        Events.actionSelected,
        Events.savingsExperimentCompleted,
      ]),
    );
  });

  test('an earlier bill does not complete an experiment', () async {
    await onboard();
    await app.saveBill(octoberBill());
    await app.startExperiment(ActionType.reduceDailyUsage, app.latestBill!);
    final done = await app.saveBill(septemberBill());
    expect(done, isEmpty);
    expect(app.activeExperiments.length, 1);
  });

  test('starting the same action again replaces the old one', () async {
    await onboard();
    await app.saveBill(octoberBill());
    await app.startExperiment(ActionType.reduceDailyUsage, app.latestBill!);
    await app.startExperiment(ActionType.reduceDailyUsage, app.latestBill!);
    expect(app.activeExperiments.length, 1);
  });

  test('invalid bills are rejected before storage', () async {
    await onboard();
    await expectLater(
      app.saveBill(bill('bad', [period(d(2026, 9, 30), d(2026, 9, 1))])),
      throwsA(anything),
    );
    expect(app.bills, isEmpty);
  });

  test(
    'analytics is off unless opted in, and drops unsafe properties',
    () async {
      await onboard(analytics: false);
      await app.saveBill(septemberBill());
      expect(await repo.listEvents(), isEmpty);
      await app.setAnalyticsOptIn(true);
      await app.analytics.log(Events.billAdded, {
        'ok': 1,
        'text': 'free text with spaces',
        'amount': 12.5,
        'flag': true,
      });
      final props = (await repo.listEvents()).single.properties;
      expect(props.keys, containsAll(['ok', 'flag']));
      expect(props.containsKey('text'), isFalse);
      expect(props.containsKey('amount'), isFalse);
      await app.setAnalyticsOptIn(false);
      expect(await repo.listEvents(), isEmpty);
    },
  );

  test('delete all data returns to onboarding with nothing left', () async {
    await onboard(dd: 9000);
    await app.saveBill(septemberBill());
    await app.deleteAllData();
    expect(app.needsOnboarding, isTrue);
    expect(app.bills, isEmpty);
    final fresh = AppController(repository: repo);
    await fresh.load();
    expect(fresh.household, isNull);
  });

  test('direct debit check uses stored DD and recent bills', () async {
    await onboard(dd: 9000);
    await app.saveBill(septemberBill());
    await app.saveBill(octoberBill());
    expect(app.directDebitCheck()!.suggestedMonthlyPence, 10080);
  });

  test('deleting a bill removes it and its experiments', () async {
    await onboard();
    await app.saveBill(octoberBill());
    await app.startExperiment(ActionType.checkTariffQuote, app.latestBill!);
    await app.deleteBill('oct');
    expect(app.bills, isEmpty);
    expect(app.experiments, isEmpty);
  });

  test('reference data staleness is reported', () async {
    expect(app.referenceIsStale, isFalse);
    final later = AppController(
      repository: repo,
      reference: reference,
      clock: () => DateTime.utc(2027, 2, 1),
    );
    expect(later.referenceIsStale, isTrue);
  });
}
