import 'package:flutter/material.dart';

import '../app/analytics.dart';
import '../domain/comparison.dart';
import '../domain/experiments.dart';
import '../domain/insights.dart';
import '../domain/models.dart';
import 'copy.dart';
import 'direct_debit_screen.dart';
import 'format.dart';
import 'what_if_screen.dart';
import 'widgets.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.insight,
    required this.bill,
    this.comparison,
  });

  final Insight insight;
  final Bill bill;
  final BillComparison? comparison;

  @override
  Widget build(BuildContext context) {
    final (title, body) = Copy.insight(insight, comparison: comparison);
    final t = Theme.of(context).textTheme;
    final action = insight.suggestedAction;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 6),
            Text(body),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ProvenanceChip(insight.provenance),
                Text(Copy.confidence(insight.confidence), style: t.labelSmall),
                if (action != null)
                  TextButton(
                    key: Key('action_${insight.kind.name}'),
                    onPressed: () => showActionSheet(context, action, bill),
                    child: const Text('What can I do?'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showActionSheet(
  BuildContext context,
  ActionType type,
  Bill baseline,
) {
  final app = AppScope.read(context);
  app.analytics.log(Events.insightViewed, {'action': type.name});
  final def = actionCatalog[type]!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.title, style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(def.howTo),
            const SizedBox(height: 12),
            Text(
              'How we\'ll check: ${def.verification}',
              style: Theme.of(sheet).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (type == ActionType.checkTariffQuote)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WhatIfScreen(bill: baseline),
                        ),
                      );
                    },
                    child: const Text('Open What if?'),
                  ),
                if (type == ActionType.reviewDirectDebit)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DirectDebitScreen(),
                        ),
                      );
                    },
                    child: const Text('Open check'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('start_experiment'),
                  onPressed: () async {
                    await app.startExperiment(type, baseline);
                    if (sheet.mounted) Navigator.pop(sheet);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Added. Your next bill will show whether it changed.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('I\'ll try this'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ExperimentCard extends StatelessWidget {
  const ExperimentCard({super.key, required this.experiment});
  final SavingsExperiment experiment;

  String _metric(ActionType a, int v) => switch (a) {
    ActionType.reduceDailyUsage => '${kwh(v)}/day',
    ActionType.shiftToNight => '${percentFromPermille(v)} at night',
    ActionType.checkTariffQuote => money(v),
    ActionType.reviewDirectDebit => '${money(v)}/month',
    ActionType.submitMeterReading =>
      v == 1 ? 'actual reading' : 'estimated reading',
  };

  @override
  Widget build(BuildContext context) {
    final e = experiment;
    final def = actionCatalog[e.action]!;
    final t = Theme.of(context).textTheme;
    final app = AppScope.read(context);
    final active = e.status == ExperimentStatus.active;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(active ? Icons.hourglass_top : Icons.flag_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(def.title, style: t.titleMedium)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${def.metricLabel} before: ${_metric(e.action, e.baselineMetricMilli)}',
            ),
            if (active)
              const Text('Waiting for your next bill…')
            else ...[
              if (e.resultMetricMilli != null)
                Text('After: ${_metric(e.action, e.resultMetricMilli!)}'),
              Text(
                'Result: ${Copy.outcome(e.outcome ?? ExperimentOutcome.inconclusive)}',
                style: t.titleSmall,
              ),
              if (e.counterfactualSavingPence != null)
                Text(
                  e.action == ActionType.checkTariffQuote
                      ? 'The same usage at your old prices would have cost '
                            '${money(e.counterfactualSavingPence!.abs())} '
                            '${e.counterfactualSavingPence! >= 0 ? 'more' : 'less'}.'
                      : e.counterfactualSavingPence! >= 0
                      ? 'At your current prices, the lower daily use is worth about '
                            '${money(e.counterfactualSavingPence!)} over this bill.'
                      : 'At your current prices, the higher daily use cost about '
                            '${money(-e.counterfactualSavingPence!)} over this bill.',
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const ProvenanceChip(Provenance.calculated),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A change isn\'t proof of cause — weather and routines matter too.',
                      style: t.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (active)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => app.abandonExperiment(e),
                  child: const Text('Stop tracking'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
