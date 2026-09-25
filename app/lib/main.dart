import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

import 'app/app_controller.dart';
import 'data/sqlite_repository.dart';
import 'domain/tariff_reference.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  TariffDataset? reference;
  try {
    final raw = await rootBundle.loadString(
      'assets/data/gb_price_cap_electricity.json',
    );
    final ds = TariffDataset.parse(raw);
    // Invalid reference data is never used; the app works without it.
    reference = ds.validate().isEmpty ? ds : null;
  } catch (_) {
    reference = null;
  }

  final dir = await sqflite.getDatabasesPath();
  final repo = await SqliteRepository.open(
    sqflite.databaseFactory,
    p.join(dir, 'energylens.db'),
  );
  final controller = AppController(repository: repo, reference: reference);
  runApp(EnergyLensApp(controller: controller));
  await controller.load();
}
