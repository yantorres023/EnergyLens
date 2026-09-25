import 'package:flutter/material.dart';

import '../app/analytics.dart';
import '../domain/direct_debit.dart';
import '../domain/fixed_point.dart';
import '../domain/models.dart';
import 'format.dart';
import 'widgets.dart';

class DirectDebitScreen extends StatefulWidget {
  const DirectDebitScreen({super.key});

  @override
  State<DirectDebitScreen> createState() => _DirectDebitScreenState();
}

class _DirectDebitScreenState extends State<DirectDebitScreen> {
  final _dd = TextEditingController();
  bool _logged = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final h = AppScope.read(context).household;
    if (_dd.text.isEmpty && h?.directDebitMonthlyPence != null) {
      final p = h!.directDebitMonthlyPence!;
      _dd.text = '${p ~/ 100}.${(p % 100).toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _dd.dispose();
    super.dispose();
  }

  Future<void> _saveDd() async {
    final app = AppScope.read(context);
    final p = parsePoundsToPence(_dd.text);
    if (p == null || p <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your monthly amount, e.g. 95.00')),
      );
      return;
    }
    await app.updateHousehold(
      app.household!.copyWith(directDebitMonthlyPence: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final check = app.directDebitCheck();
    if (check != null && !_logged) {
      _logged = true;
      app.analytics.log(Events.directDebitChecked, {
        'verdict': check.verdict.name,
        'confidence': check.confidence.name,
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Is my Direct Debit right?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('dd_amount'),
                  controller: _dd,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Direct Debit (electricity)',
                    prefixText: '£ ',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('dd_save'),
                onPressed: _saveDd,
                child: const Text('Update'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (app.bills.isEmpty)
            const InfoBanner(text: 'Add at least one bill to run the check.')
          else if (check == null)
            const InfoBanner(
              text: 'Enter your Direct Debit amount above to run the check.',
            )
          else
            _Result(check: check),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.check});
  final DirectDebitCheck check;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final verdict = switch (check.verdict) {
      DirectDebitVerdict.aboutRight => 'Looks about right',
      DirectDebitVerdict.likelyTooLow => 'May be too low',
      DirectDebitVerdict.likelyTooHigh => 'May be higher than needed',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    verdict,
                    key: const Key('dd_verdict'),
                    style: t.titleLarge,
                  ),
                ),
                const ProvenanceChip(Provenance.estimated),
              ],
            ),
            const SizedBox(height: 12),
            Text('You pay: ${money(check.currentMonthlyPence)} a month'),
            Text(
              'Estimate from your bills: ${money(check.suggestedMonthlyPence)} a month',
            ),
            const SizedBox(height: 12),
            Text(
              'How: ${kwh(check.kwhPerDayMilli)} a day on average over '
              '${check.daysOfData} days of bills, priced for a year at your latest '
              'prices = ${money(check.annualCostPence)}'
              '${check.balancePence != 0 ? ', minus your balance of ${money(check.balancePence)}' : ''}, '
              'divided by 12.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.warning_amber,
              text: check.confidence == DirectDebitConfidence.low
                  ? 'Low confidence: fewer than 6 months of bills. Winter usage is '
                        'usually higher than summer, so a summer-only estimate can be '
                        'too low.'
                  : 'Medium confidence. Prices change every quarter on variable '
                        'tariffs, so this estimate will move too.',
            ),
            const Text(
              'Your supplier sets your Direct Debit. If this looks off, you can '
              'ask them to review it and explain how they calculated it.',
            ),
          ],
        ),
      ),
    );
  }
}
