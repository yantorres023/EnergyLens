import '../domain/models.dart';

class AnalyticsEvent {
  const AnalyticsEvent(this.name, this.at, this.properties);
  final String name;
  final DateTime at;
  final Map<String, Object?> properties;
}

/// Storage boundary. Everything stays on the device.
abstract class Repository {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);

  Future<Household?> getHousehold(String id);
  Future<void> saveHousehold(Household household);

  /// Sorted by period end, oldest first.
  Future<List<Bill>> listBills(String householdId);
  Future<void> saveBill(Bill bill);

  /// Deletes the bill and any experiment that used it as baseline or result.
  Future<void> deleteBill(String billId);

  Future<List<SavingsExperiment>> listExperiments(String householdId);
  Future<void> saveExperiment(SavingsExperiment experiment);
  Future<void> deleteExperiment(String id);

  Future<void> logEvent(AnalyticsEvent event);
  Future<List<AnalyticsEvent>> listEvents();
  Future<void> clearEvents();

  /// Erases every table. Used by "Delete all my data".
  Future<void> deleteAllData();
}

/// In-memory implementation for tests and previews.
class InMemoryRepository implements Repository {
  AppSettings _settings = const AppSettings();
  final Map<String, Household> _households = {};
  final Map<String, Bill> _bills = {};
  final Map<String, SavingsExperiment> _experiments = {};
  final List<AnalyticsEvent> _events = [];

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async => _settings = settings;

  @override
  Future<Household?> getHousehold(String id) async => _households[id];

  @override
  Future<void> saveHousehold(Household household) async =>
      _households[household.id] = household;

  @override
  Future<List<Bill>> listBills(String householdId) async =>
      _bills.values.where((b) => b.householdId == householdId).toList()
        ..sort((a, b) => a.periodEnd.compareTo(b.periodEnd));

  @override
  Future<void> saveBill(Bill bill) async => _bills[bill.id] = bill;

  @override
  Future<void> deleteBill(String billId) async {
    _bills.remove(billId);
    _experiments.removeWhere(
      (_, e) => e.baselineBillId == billId || e.resultBillId == billId,
    );
  }

  @override
  Future<List<SavingsExperiment>> listExperiments(String householdId) async =>
      _experiments.values.where((e) => e.householdId == householdId).toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  @override
  Future<void> saveExperiment(SavingsExperiment experiment) async =>
      _experiments[experiment.id] = experiment;

  @override
  Future<void> deleteExperiment(String id) async => _experiments.remove(id);

  @override
  Future<void> logEvent(AnalyticsEvent event) async => _events.add(event);

  @override
  Future<List<AnalyticsEvent>> listEvents() async => List.unmodifiable(_events);

  @override
  Future<void> clearEvents() async => _events.clear();

  @override
  Future<void> deleteAllData() async {
    _settings = const AppSettings();
    _households.clear();
    _bills.clear();
    _experiments.clear();
    _events.clear();
  }
}
