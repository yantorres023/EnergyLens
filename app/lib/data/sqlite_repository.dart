import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../domain/dates.dart';
import '../domain/models.dart';
import 'repository.dart';

/// SQLite-backed [Repository]. Rows hold a JSON document plus the columns
/// needed for filtering and ordering; the schema is versioned via
/// [schemaVersion] and [_migrate].
class SqliteRepository implements Repository {
  SqliteRepository(this._db);

  final Database _db;

  static const int schemaVersion = 1;

  static Future<SqliteRepository> open(
    DatabaseFactory factory,
    String path,
  ) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          // Overwrite deleted content instead of leaving it in free pages.
          await db.execute('PRAGMA secure_delete = ON');
        },
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return SqliteRepository(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 1) {
      await db.execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE households (id TEXT PRIMARY KEY, json TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE bills ('
        'id TEXT PRIMARY KEY, '
        'household_id TEXT NOT NULL, '
        'period_end TEXT NOT NULL, '
        'json TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE INDEX bills_household ON bills (household_id, period_end)',
      );
      await db.execute(
        'CREATE TABLE experiments ('
        'id TEXT PRIMARY KEY, '
        'household_id TEXT NOT NULL, '
        'baseline_bill_id TEXT NOT NULL, '
        'result_bill_id TEXT, '
        'json TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE events ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, '
        'at TEXT NOT NULL, '
        'props TEXT NOT NULL)',
      );
    }
  }

  Future<void> close() => _db.close();

  Map<String, Object?> _decode(Object? json) =>
      (jsonDecode(json! as String) as Map).cast<String, Object?>();

  @override
  Future<AppSettings> loadSettings() async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['app'],
    );
    if (rows.isEmpty) return const AppSettings();
    return AppSettings.fromJson(_decode(rows.first['value']));
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _db.insert('settings', {
      'key': 'app',
      'value': jsonEncode(settings.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Household?> getHousehold(String id) async {
    final rows = await _db.query(
      'households',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Household.fromJson(_decode(rows.first['json']));
  }

  @override
  Future<void> saveHousehold(Household household) async {
    await _db.insert('households', {
      'id': household.id,
      'json': jsonEncode(household.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Bill>> listBills(String householdId) async {
    final rows = await _db.query(
      'bills',
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'period_end ASC',
    );
    return rows.map((r) => Bill.fromJson(_decode(r['json']))).toList();
  }

  @override
  Future<void> saveBill(Bill bill) async {
    await _db.insert('bills', {
      'id': bill.id,
      'household_id': bill.householdId,
      'period_end': isoDate(bill.periodEnd),
      'json': jsonEncode(bill.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteBill(String billId) async {
    await _db.transaction((txn) async {
      await txn.delete('bills', where: 'id = ?', whereArgs: [billId]);
      await txn.delete(
        'experiments',
        where: 'baseline_bill_id = ? OR result_bill_id = ?',
        whereArgs: [billId, billId],
      );
    });
  }

  @override
  Future<List<SavingsExperiment>> listExperiments(String householdId) async {
    final rows = await _db.query(
      'experiments',
      where: 'household_id = ?',
      whereArgs: [householdId],
    );
    return rows
        .map((r) => SavingsExperiment.fromJson(_decode(r['json'])))
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }

  @override
  Future<void> saveExperiment(SavingsExperiment experiment) async {
    await _db.insert('experiments', {
      'id': experiment.id,
      'household_id': experiment.householdId,
      'baseline_bill_id': experiment.baselineBillId,
      'result_bill_id': experiment.resultBillId,
      'json': jsonEncode(experiment.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteExperiment(String id) async {
    await _db.delete('experiments', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    await _db.insert('events', {
      'name': event.name,
      'at': event.at.toUtc().toIso8601String(),
      'props': jsonEncode(event.properties),
    });
  }

  @override
  Future<List<AnalyticsEvent>> listEvents() async {
    final rows = await _db.query('events', orderBy: 'id ASC');
    return rows
        .map(
          (r) => AnalyticsEvent(
            r['name']! as String,
            DateTime.parse(r['at']! as String),
            _decode(r['props']),
          ),
        )
        .toList();
  }

  @override
  Future<void> clearEvents() async {
    await _db.delete('events');
  }

  @override
  Future<void> deleteAllData() async {
    await _db.transaction((txn) async {
      for (final t in ['settings', 'households', 'bills', 'experiments', 'events']) {
        await txn.delete(t);
      }
    });
    // Reclaim the pages so deleted rows don't linger in the file.
    await _db.execute('VACUUM');
  }
}
