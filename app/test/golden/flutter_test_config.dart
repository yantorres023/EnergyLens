import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads real fonts (Roboto + Material Icons from the Flutter SDK cache) so
/// golden images are readable and can double as store-screenshot drafts.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = '$root/bin/cache/artifacts/material_fonts';
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        final file = File('$dir/$f');
        if (file.existsSync()) {
          loader.addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          );
        }
      }
      await loader.load();
    }

    await load('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  }
  await testMain();
}
