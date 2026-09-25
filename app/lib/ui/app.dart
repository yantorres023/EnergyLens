import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app/app_controller.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'widgets.dart';

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B6E5A),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(isDense: true),
    cardTheme: const CardThemeData(elevation: 0.5),
  );
}

class EnergyLensApp extends StatelessWidget {
  const EnergyLensApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'EnergyLens',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('en', 'GB'),
        supportedLocales: const [Locale('en', 'GB')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return app.needsOnboarding ? const OnboardingScreen() : const HomeScreen();
  }
}
