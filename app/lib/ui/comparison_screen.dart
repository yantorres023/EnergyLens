import 'package:flutter/material.dart';

import '../app/analytics.dart';
import '../domain/comparison.dart';
import '../domain/fixed_point.dart';
import '../domain/models.dart';
import 'copy.dart';
import 'format.dart';
import 'widgets.dart';

/// Shows WHAT CHANGED and WHY between two bills.
class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key, required this.comparison});
  final BillComparison comparison;

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.read(context).analytics.log(Events.comparisonViewed, {
        'effects': widget.comparison.effects.length,
        'caveats': widget.comparison.caveats.length,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What changed')),
      body: ComparisonBody(comparison: widget.comparison),
    );
  }
}

class ComparisonBody extends StatelessWidget {
  const ComparisonBody({super.key, required this.comparison});
  final BillComparison comparison;

  @override
  Widget build(BuildContext context) {
    final c = comparison;
    final t = Theme.of(context).textTheme;
    final maxAbs = c.effects.fold<int>(
      0,
      (m, e) => e.amountPence.abs() > m ? e.amountPence.abs() : m,
    );
    final pct = c.differencePerMille;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.differencePence == 0
                    ? 'Same total as last time'
                    : '${money(c.differencePence.abs())} ${c.differencePence > 0 ? 'more' : 'less'} than last time',
                key: const Key('comparison_headline'),
                style: t.headlineSmall,
              ),
              if (pct != null && c.differencePence != 0)
                Text(
                  '${c.differencePence > 0 ? '+' : ''}${percentFromPermille(pct)}',
                ),
              const SizedBox(height: 12),
              _TwoBills(comparison: c),
            ],
          ),
        ),
        const SectionTitle('Why'),
        if (c.effects.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nothing changed between these bills.'),
          ),
        for (final e in c.effects)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Copy.effectLabel(e.type, c),
                        style: t.bodyLarge,
                      ),
                    ),
                    Text(
                      money(e.amountPence, signed: true),
                      style: t.titleMedium?.copyWith(
                        color: e.amountPence > 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                EffectBar(value: e.amountPence, maxAbs: maxAbs),
                const SizedBox(height: 4),
                Text(Copy.effectExplanation(e.type), style: t.bodySmall),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const ProvenanceChip(Provenance.calculated),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These add up to ${money(c.differencePence, signed: true)}.',
                  style: t.bodySmall,
                ),
              ),
            ],
          ),
        ),
        if (c.caveats.isNotEmpty) ...[
          const SectionTitle('Keep in mind'),
          for (final cv in c.caveats)
            InfoBanner(text: Copy.caveat(cv), icon: Icons.warning_amber),
        ],
        const SectionTitle('How we worked this out'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(Copy.methodology),
        ),
      ],
    );
  }
}

class _TwoBills extends StatelessWidget {
  const _TwoBills({required this.comparison});
  final BillComparison comparison;

  @override
  Widget build(BuildContext context) {
    final c = comparison;
    Widget col(String label, Bill b, int total, int perDay, int kwhDay) =>
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  Text(
                    money(total),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    dateRange(b.periodStart, b.periodEnd),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text('${b.days} days · ${kwh(kwhDay)}/day'),
                  Text('${money(divRoundHalfAwayFromZero(perDay, 1000))}/day'),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        col(
          'Previous',
          c.previous,
          c.previousCalc.totalPence,
          c.previousCalc.costPerDayMilliPence,
          c.previousCalc.kwhPerDayMilli,
        ),
        col(
          'This bill',
          c.current,
          c.currentCalc.totalPence,
          c.currentCalc.costPerDayMilliPence,
          c.currentCalc.kwhPerDayMilli,
        ),
      ],
    );
  }
}
