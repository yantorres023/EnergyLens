import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/models.dart';
import 'copy.dart';

/// Makes the [AppController] available to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }

  static AppController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

/// Small label telling the user where a number came from.
class ProvenanceChip extends StatelessWidget {
  const ProvenanceChip(this.provenance, {super.key});
  final Provenance provenance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (provenance) {
      Provenance.estimated => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.help_outline,
      ),
      Provenance.calculated => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.calculate_outlined,
      ),
      Provenance.parsed => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.content_paste,
      ),
      Provenance.measured => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.speed,
      ),
      Provenance.userEntered => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.edit_outlined,
      ),
    };
    return Semantics(
      label: 'Source: ${Copy.provenance(provenance)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              Copy.provenance(provenance),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.warning = false,
  });
  final String text;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: warning ? scheme.errorContainer : scheme.surfaceContainerHigh,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: warning
                  ? scheme.onErrorContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: warning ? scheme.onErrorContainer : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal bar used for change drivers; positive grows right (red-ish),
/// negative grows left (green-ish). Width is relative to [maxAbs].
class EffectBar extends StatelessWidget {
  const EffectBar({super.key, required this.value, required this.maxAbs});
  final int value;
  final int maxAbs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = maxAbs == 0
        ? 0.0
        : (value.abs() / maxAbs).clamp(0.02, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final half = c.maxWidth / 2;
        final w = half * fraction;
        return SizedBox(
          height: 10,
          child: Stack(
            children: [
              Positioned(
                left: half - 0.5,
                top: 0,
                bottom: 0,
                child: Container(width: 1, color: scheme.outlineVariant),
              ),
              Positioned(
                left: value >= 0 ? half : half - w,
                top: 1,
                bottom: 1,
                child: Container(
                  width: w,
                  decoration: BoxDecoration(
                    color: value >= 0 ? scheme.error : scheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
