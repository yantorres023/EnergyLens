import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../domain/calculator.dart';
import '../domain/comparison.dart';
import '../domain/direct_debit.dart';
import '../domain/experiments.dart';
import '../domain/insights.dart';
import '../domain/models.dart';
import '../domain/tariff_reference.dart';
import 'analytics.dart';

String newId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Holds app state and coordinates domain services with storage.
class AppController extends ChangeNotifier {
  AppController({
    required this.repository,
    this.reference,
    DateTime Function()? clock,
    this.calculator = const BillCalculator(),
  }) : clock = clock ?? DateTime.now {
    analytics = Analytics(repository, this.clock);
  }

  final Repository repository;
  final TariffDataset? reference;
  final DateTime Function() clock;
  final BillCalculator calculator;
  late final Analytics analytics;

  bool loading = true;
  AppSettings settings = const AppSettings();
  Household? household;
  List<Bill> bills = const [];
  List<SavingsExperiment> experiments = const [];

  /// Set when a new bill completes an experiment, so the UI can show it.
  SavingsExperiment? lastCompletedExperiment;

  Future<void> load() async {
    loading = true;
    settings = await repository.loadSettings();
    analytics.enabled = settings.analyticsOptIn;
    final id = settings.activeHouseholdId;
    household = id == null ? null : await repository.getHousehold(id);
    await _reloadCollections();
    loading = false;
    notifyListeners();
  }

  Future<void> _reloadCollections() async {
    final h = household;
    if (h == null) {
      bills = const [];
      experiments = const [];
      return;
    }
    bills = await repository.listBills(h.id);
    experiments = await repository.listExperiments(h.id);
  }

  bool get needsOnboarding => !settings.onboardingCompleted || household == null;

  bool get referenceIsStale => reference == null || reference!.isStale(clock());

  Future<void> completeOnboarding(Household h, {required bool analyticsOptIn}) async {
    household = h;
    await repository.saveHousehold(h);
    settings = settings.copyWith(
      onboardingCompleted: true,
      analyticsOptIn: analyticsOptIn,
      activeHouseholdId: h.id,
    );
    analytics.enabled = analyticsOptIn;
    await repository.saveSettings(settings);
    await analytics.log(Events.onboardingCompleted, {
      'meter': h.meterType.name,
      'tariff': h.tariffKind.name,
      'payment': h.paymentMethod.name,
    });
    await _reloadCollections();
    notifyListeners();
  }

  Future<void> updateHousehold(Household h) async {
    household = h;
    await repository.saveHousehold(h);
    notifyListeners();
  }

  Future<void> setAnalyticsOptIn(bool value) async {
    settings = settings.copyWith(analyticsOptIn: value);
    analytics.enabled = value;
    await repository.saveSettings(settings);
    if (!value) await repository.clearEvents();
    notifyListeners();
  }

  /// Saves a bill. Returns experiments completed by this bill.
  Future<List<SavingsExperiment>> saveBill(Bill bill, {bool isEdit = false}) async {
    // Validate before storing: throws ValidationError on impossible input.
    final calc = calculator.calculate(bill);
    final hadEarlier = bills.any(
      (b) => b.id != bill.id && b.periodEnd.isBefore(bill.periodEnd),
    );
    await repository.saveBill(bill);
    if (!isEdit) {
      await analytics.log(Events.billAdded, {
        'source': bill.source.name,
        'periods': bill.ratePeriods.length,
        'e7': bill.isEconomy7,
        'reconciles': calc.reconciliation.name,
        'reading': bill.readingType.name,
      });
      if (bill.corrections.isNotEmpty) {
        await analytics.log(Events.billCorrected, {
          'fields_corrected': bill.corrections.length,
        });
      }
      if (hadEarlier) await analytics.log(Events.nextBillAdded);
    }
    await _reloadCollections();
    final completed = await _evaluateExperiments(bill);
    lastCompletedExperiment = completed.isEmpty ? null : completed.last;
    notifyListeners();
    return completed;
  }

  Future<List<SavingsExperiment>> _evaluateExperiments(Bill newBill) async {
    final done = <SavingsExperiment>[];
    final engine = ExperimentEngine(calculator: calculator);
    for (final e in experiments.where((e) => e.status == ExperimentStatus.active)) {
      final baseline = billById(e.baselineBillId);
      if (baseline == null || !ExperimentEngine.isLaterBill(baseline, newBill)) {
        continue;
      }
      final eval = engine.evaluate(
        experiment: e,
        baseline: baseline,
        result: newBill,
        allBills: bills
            .where((b) => !b.periodEnd.isAfter(newBill.periodEnd))
            .toList(),
        directDebit: household?.directDebitMonthlyPence,
      );
      final updated = e.copyWith(
        status: ExperimentStatus.completed,
        resultBillId: newBill.id,
        outcome: eval.outcome,
        resultMetricMilli: eval.resultMetricMilli,
        counterfactualSavingPence: eval.counterfactualSavingPence,
        completedAt: clock(),
      );
      await repository.saveExperiment(updated);
      await analytics.log(Events.savingsExperimentCompleted, {
        'action': e.action.name,
        'outcome': eval.outcome.name,
      });
      done.add(updated);
    }
    if (done.isNotEmpty) await _reloadCollections();
    return done;
  }

  Future<void> deleteBill(String id) async {
    await repository.deleteBill(id);
    await _reloadCollections();
    notifyListeners();
  }

  Future<SavingsExperiment> startExperiment(ActionType action, Bill baseline) async {
    // One active experiment per action type keeps verification unambiguous.
    for (final e in experiments.where(
      (e) => e.status == ExperimentStatus.active && e.action == action,
    )) {
      await repository.saveExperiment(e.copyWith(status: ExperimentStatus.abandoned));
    }
    final exp = ExperimentEngine(calculator: calculator).start(
      id: newId(),
      action: action,
      baseline: baseline,
      now: clock(),
      directDebit: household?.directDebitMonthlyPence,
    );
    await repository.saveExperiment(exp);
    await analytics.log(Events.actionSelected, {'action': action.name});
    await _reloadCollections();
    notifyListeners();
    return exp;
  }

  Future<void> abandonExperiment(SavingsExperiment e) async {
    await repository.saveExperiment(e.copyWith(status: ExperimentStatus.abandoned));
    await _reloadCollections();
    notifyListeners();
  }

  Future<void> deleteAllData() async {
    await repository.deleteAllData();
    settings = const AppSettings();
    analytics.enabled = false;
    household = null;
    bills = const [];
    experiments = const [];
    lastCompletedExperiment = null;
    notifyListeners();
  }

  // ---- Derived views -------------------------------------------------------

  Bill? billById(String id) {
    for (final b in bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  Bill? get latestBill => bills.isEmpty ? null : bills.last;

  /// The bill immediately before [bill] (by period end).
  Bill? previousBillFor(Bill bill) {
    Bill? best;
    for (final b in bills) {
      if (b.id == bill.id) continue;
      if (b.periodEnd.isBefore(bill.periodEnd) &&
          (best == null || b.periodEnd.isAfter(best.periodEnd))) {
        best = b;
      }
    }
    return best;
  }

  BillCalculation calculationFor(Bill bill) => calculator.calculate(bill);

  BillComparison? comparisonFor(Bill bill) {
    final prev = previousBillFor(bill);
    if (prev == null) return null;
    return BillComparison.compare(prev, bill, calculator: calculator);
  }

  List<Insight> insightsFor(Bill bill) {
    final h = household;
    if (h == null) return const [];
    return InsightEngine(calculator: calculator).build(
      current: bill,
      previous: previousBillFor(bill),
      household: h,
      reference: reference,
      today: clock(),
    );
  }

  DirectDebitCheck? directDebitCheck() {
    final dd = household?.directDebitMonthlyPence;
    if (dd == null || bills.isEmpty) return null;
    // Use up to the last 12 months of bills.
    final latestEnd = bills.last.periodEnd;
    final recent = bills
        .where((b) => latestEnd.difference(b.periodEnd).inDays < 365)
        .toList();
    return DirectDebitCheck.run(
      bills: recent,
      currentMonthlyPence: dd,
      calculator: calculator,
    );
  }

  List<SavingsExperiment> get activeExperiments =>
      experiments.where((e) => e.status == ExperimentStatus.active).toList();

  List<SavingsExperiment> get completedExperiments =>
      experiments.where((e) => e.status == ExperimentStatus.completed).toList();
}
