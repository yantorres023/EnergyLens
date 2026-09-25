import 'dart:io';

import 'package:energylens/data/repository.dart';
import 'package:energylens/data/sqlite_repository.dart';
import 'package:energylens/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers.dart';

void main() {
  sqfliteFfiInit();
  late SqliteRepository repo;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('energylens_test');
    repo = await SqliteRepository.open(databaseFactoryFfi, '${tmp.path}/t.db');
  });

  tearDown(() async {
    await repo.close();
    await tmp.delete(recursive: true);
  });

  test('settings round trip with defaults', () async {
    expect((await repo.loadSettings()).onboardingCompleted, isFalse);
    await repo.saveSettings(
      const AppSettings(onboardingCompleted: true, activeHouseholdId: 'h1'),
    );
    final s = await repo.loadSettings();
    expect(s.onboardingCompleted, isTrue);
    expect(s.activeHouseholdId, 'h1');
    expect(s.analyticsOptIn, isFalse);
  });

  test('household round trip holds no personal identifiers', () async {
    const h = Household(
      id: 'h1',
      region: GbRegion.london,
      meterType: MeterType.economy7,
      tariffKind: TariffKind.fixed,
      directDebitMonthlyPence: 9500,
    );
    await repo.saveHousehold(h);
    final back = (await repo.getHousehold('h1'))!;
    expect(back.region, GbRegion.london);
    expect(back.meterType, MeterType.economy7);
    expect(back.directDebitMonthlyPence, 9500);
    expect(
      h.toJson().keys,
      isNot(anyOf(contains('name'), contains('address'), contains('mpan'))),
    );
  });

  test(
    'bills are stored, ordered by period end and fully round-tripped',
    () async {
      final split =
          bill(
            'split',
            [
              period(
                d(2026, 9, 15),
                d(2026, 9, 30),
                kwh: '160',
                rate: '24.87',
                standing: '54.47',
              ),
              period(
                d(2026, 10, 1),
                d(2026, 10, 14),
                kwh: '150',
                rate: '26.32',
                standing: '54.83',
                vatBp: 0,
              ),
            ],
            adjustments: const [
              Adjustment(
                label: 'WHD',
                amountPence: -15000,
                kind: AdjustmentKind.credit,
              ),
            ],
            statedTotalPence: 9810,
            closingBalancePence: -1234,
            readingType: ReadingType.estimated,
          ).copyWith(
            fieldProvenance: {'kwh': Provenance.parsed},
            corrections: const [
              UserCorrection(
                field: 'rate',
                parsedValue: '24.8',
                correctedValue: '24.87',
              ),
            ],
          );
      await repo.saveBill(octoberBill());
      await repo.saveBill(septemberBill());
      await repo.saveBill(split);
      final list = await repo.listBills('h1');
      expect(list.map((b) => b.id), ['sep', 'split', 'oct']);
      final back = list[1];
      expect(back.ratePeriods.length, 2);
      expect(back.ratePeriods[1].vatBasisPoints, 0);
      expect(back.adjustments.single.amountPence, -15000);
      expect(back.statedTotalPence, 9810);
      expect(back.closingBalancePence, -1234);
      expect(back.readingType, ReadingType.estimated);
      expect(back.fieldProvenance['kwh'], Provenance.parsed);
      expect(back.corrections.single.correctedValue, '24.87');
      expect(await repo.listBills('other'), isEmpty);
    },
  );

  test('saving the same id updates rather than duplicates', () async {
    await repo.saveBill(septemberBill());
    await repo.saveBill(septemberBill(stated: 9550));
    final list = await repo.listBills('h1');
    expect(list.length, 1);
    expect(list.single.statedTotalPence, 9550);
  });

  test('deleting a bill deletes experiments that depend on it', () async {
    await repo.saveBill(septemberBill());
    await repo.saveBill(octoberBill());
    await repo.saveExperiment(
      SavingsExperiment(
        id: 'e1',
        householdId: 'h1',
        action: ActionType.reduceDailyUsage,
        baselineBillId: 'sep',
        startedAt: d(2026, 10, 1),
        baselineMetricMilli: 10000,
      ),
    );
    await repo.saveExperiment(
      SavingsExperiment(
        id: 'e2',
        householdId: 'h1',
        action: ActionType.checkTariffQuote,
        baselineBillId: 'oct',
        startedAt: d(2026, 11, 1),
        baselineMetricMilli: 1,
      ),
    );
    await repo.deleteBill('sep');
    expect((await repo.listBills('h1')).map((b) => b.id), ['oct']);
    expect((await repo.listExperiments('h1')).map((e) => e.id), ['e2']);
  });

  test('experiment round trip including outcome', () async {
    final e =
        SavingsExperiment(
          id: 'e1',
          householdId: 'h1',
          action: ActionType.shiftToNight,
          baselineBillId: 'a',
          startedAt: d(2026, 10, 1),
          baselineMetricMilli: 333,
        ).copyWith(
          status: ExperimentStatus.completed,
          resultBillId: 'b',
          outcome: ExperimentOutcome.improved,
          resultMetricMilli: 412,
          counterfactualSavingPence: -5,
          completedAt: d(2026, 11, 1),
        );
    await repo.saveExperiment(e);
    final back = (await repo.listExperiments('h1')).single;
    expect(back.outcome, ExperimentOutcome.improved);
    expect(back.resultMetricMilli, 412);
    expect(back.counterfactualSavingPence, -5);
    expect(back.completedAt, d(2026, 11, 1));
  });

  test('events log and clear', () async {
    await repo.logEvent(
      AnalyticsEvent('bill_added', d(2026, 1, 1), {'e7': false}),
    );
    expect((await repo.listEvents()).single.properties['e7'], isFalse);
    await repo.clearEvents();
    expect(await repo.listEvents(), isEmpty);
  });

  test(
    'delete all data wipes every table and leaves no bill text in the file',
    () async {
      await repo.saveSettings(const AppSettings(onboardingCompleted: true));
      await repo.saveHousehold(const Household(id: 'h1'));
      await repo.saveBill(
        septemberBill().copyWith(supplierName: 'UniqueSupplierMarker'),
      );
      await repo.logEvent(
        AnalyticsEvent('bill_added', d(2026, 1, 1), const {}),
      );
      await repo.deleteAllData();
      expect((await repo.loadSettings()).onboardingCompleted, isFalse);
      expect(await repo.getHousehold('h1'), isNull);
      expect(await repo.listBills('h1'), isEmpty);
      expect(await repo.listEvents(), isEmpty);
      await repo.close();
      final bytes = await File('${tmp.path}/t.db').readAsBytes();
      expect(
        String.fromCharCodes(bytes).contains('UniqueSupplierMarker'),
        isFalse,
      );
      repo = await SqliteRepository.open(
        databaseFactoryFfi,
        '${tmp.path}/t.db',
      );
    },
  );

  test('data survives reopening the database', () async {
    await repo.saveBill(septemberBill());
    await repo.close();
    repo = await SqliteRepository.open(databaseFactoryFfi, '${tmp.path}/t.db');
    expect((await repo.listBills('h1')).single.id, 'sep');
  });
}
