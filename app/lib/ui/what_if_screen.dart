import 'package:flutter/material.dart';

import '../app/analytics.dart';
import '../domain/calculator.dart';
import '../domain/fixed_point.dart';
import '../domain/models.dart';
import '../domain/what_if.dart';
import 'format.dart';
import 'widgets.dart';

/// Re-price one bill's real usage at prices the user types in (a quote).
/// No catalogue, no ranking, no referral links.
class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({super.key, required this.bill});
  final Bill bill;

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  final _standing = TextEditingController();
  final _rate = TextEditingController();
  final _dayRate = TextEditingController();
  final _nightRate = TextEditingController();
  bool _inclVat = false;
  bool _singleQuote = true;
  WhatIfResult? _result;
  String? _error;

  @override
  void dispose() {
    for (final c in [_standing, _rate, _dayRate, _nightRate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    final standing = parseMilli(_standing.text);
    final rates = <Register, int>{};
    if (!widget.bill.isEconomy7 || _singleQuote) {
      final r = parseMilli(_rate.text);
      if (r != null) rates[Register.single] = r;
    } else {
      final d = parseMilli(_dayRate.text);
      final n = parseMilli(_nightRate.text);
      if (d != null) rates[Register.day] = d;
      if (n != null) rates[Register.night] = n;
    }
    if (standing == null ||
        rates.isEmpty ||
        standing < 0 ||
        rates.values.any((v) => v < 0)) {
      setState(
        () => _error =
            'Enter the quote\'s standing charge and unit rate in pence.',
      );
      return;
    }
    try {
      final r = const WhatIfCalculator().reprice(
        widget.bill,
        AlternativeRates(
          standingChargeMilliPencePerDay: standing,
          unitRatesMilliPence: rates,
          ratesIncludeVat: _inclVat,
        ),
      );
      setState(() {
        _result = r;
        _error = null;
      });
      AppScope.read(context).analytics
          .log(Events.whatIfCalculated, {'cheaper': r.savingPence > 0});
    } on ValidationError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('What if?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Enter a tariff quote to see what your bill for ${dateRange(b.periodStart, b.periodEnd)} '
            'would have cost with the same usage.',
          ),
          const SizedBox(height: 8),
          const InfoBanner(
            text:
                'EnergyLens doesn\'t recommend or sell tariffs and earns nothing '
                'if you switch. Get quotes from your supplier or a comparison '
                'site; check exit fees and contract length before switching.',
          ),
          TextField(
            key: const Key('whatif_standing'),
            controller: _standing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Standing charge',
              suffixText: 'p/day',
            ),
          ),
          if (b.isEconomy7)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('The quote is single-rate'),
              value: _singleQuote,
              onChanged: (v) => setState(() => _singleQuote = v),
            ),
          if (!b.isEconomy7 || _singleQuote)
            TextField(
              key: const Key('whatif_rate'),
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Unit rate',
                suffixText: 'p/kWh',
              ),
            )
          else ...[
            TextField(
              controller: _dayRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Day unit rate',
                suffixText: 'p/kWh',
              ),
            ),
            TextField(
              controller: _nightRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Night unit rate',
                suffixText: 'p/kWh',
              ),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quote prices include VAT'),
            subtitle: const Text(
              'Comparison sites usually show prices including VAT.',
            ),
            value: _inclVat,
            onChanged: (v) => setState(() => _inclVat = v),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('whatif_calculate'),
            onPressed: _calculate,
            child: const Text('Calculate'),
          ),
          if (r != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Result',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        const ProvenanceChip(Provenance.calculated),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Your bill: ${money(r.actual.totalPence)}'),
                    Text('With the quote: ${money(r.alternative.totalPence)}'),
                    const SizedBox(height: 8),
                    Text(
                      r.savingPence > 0
                          ? 'The quote would have been ${money(r.savingPence)} cheaper for this bill.'
                          : r.savingPence < 0
                          ? 'The quote would have cost ${money(-r.savingPence)} more for this bill.'
                          : 'The quote would have cost the same for this bill.',
                      key: const Key('whatif_result'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This uses one bill\'s usage. A year includes winter and '
                      'summer, so the yearly difference can be different. It '
                      'excludes credits that belong to your current account.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
