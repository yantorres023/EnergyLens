import 'package:flutter/material.dart';

import '../domain/calculator.dart';
import '../domain/fixed_point.dart';
import '../domain/models.dart';
import '../domain/tariff_reference.dart';
import 'bill_form_screen.dart';
import 'comparison_screen.dart';
import 'copy.dart';
import 'format.dart';
import 'insight_widgets.dart';
import 'what_if_screen.dart';
import 'widgets.dart';

class BillDetailScreen extends StatelessWidget {
  const BillDetailScreen({super.key, required this.billId});
  final String billId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final bill = app.billById(billId);
    if (bill == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This bill was deleted.')),
      );
    }
    final calc = app.calculationFor(bill);
    final comparison = app.comparisonFor(bill);
    final insights = app.insightsFor(bill);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(dateRange(bill.periodStart, bill.periodEnd)),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BillFormScreen(existing: bill)),
            ),
          ),
          IconButton(
            key: const Key('delete_bill'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete this bill?'),
                  content: const Text(
                    'It will be removed from this phone, along with any action '
                    'tracking that uses it. This can\'t be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: const Key('confirm_delete'),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.of(context).pop();
                await app.deleteBill(bill.id);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(calc.totalPence),
                  key: const Key('detail_total'),
                  style: t.displaySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${calc.days} days · ${kwh(calc.kwhMilli, decimals: 0)} · '
                  '${money(divRoundHalfAwayFromZero(calc.costPerDayMilliPence, 1000))} a day',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const ProvenanceChip(Provenance.calculated),
                    ProvenanceChip(
                      bill.usageIsEstimated
                          ? Provenance.estimated
                          : bill.readingType == ReadingType.unknown
                          ? Provenance.userEntered
                          : Provenance.measured,
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(Copy.readingType(bill.readingType)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Reconciliation(calc: calc, bill: bill),
          const SectionTitle('How your bill adds up'),
          for (final l in calc.lines)
            _LineRow(line: l, inclVat: bill.ratesIncludeVat),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Total', style: t.titleMedium),
                const Spacer(),
                Text(money(calc.totalPence), style: t.titleMedium),
              ],
            ),
          ),
          if (comparison != null) ...[
            const SectionTitle('Compared with your previous bill'),
            ListTile(
              key: const Key('open_comparison'),
              title: Text(
                '${money(comparison.differencePence.abs())} '
                '${comparison.differencePence >= 0 ? 'more' : 'less'}',
              ),
              subtitle: comparison.mainDriver == null
                  ? null
                  : Text(
                      'Main reason: ${Copy.effectLabel(comparison.mainDriver!.type, comparison)}',
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ComparisonScreen(comparison: comparison),
                ),
              ),
            ),
          ],
          if (insights.isNotEmpty) const SectionTitle('What this means'),
          for (final i in insights)
            InsightCard(insight: i, bill: bill, comparison: comparison),
          _ReferenceCard(
            bill: bill,
            reference: app.reference,
            today: app.clock(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              key: const Key('open_what_if'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WhatIfScreen(bill: bill)),
              ),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('What if I had a different tariff?'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reconciliation extends StatelessWidget {
  const _Reconciliation({required this.calc, required this.bill});
  final BillCalculation calc;
  final Bill bill;

  @override
  Widget build(BuildContext context) {
    switch (calc.reconciliation) {
      case ReconciliationStatus.matches:
        return InfoBanner(
          icon: Icons.check_circle_outline,
          text:
              'Matches the ${money(bill.statedTotalPence!)} printed on your bill.',
        );
      case ReconciliationStatus.mismatch:
        return InfoBanner(
          warning: true,
          icon: Icons.error_outline,
          text:
              'Doesn\'t match: your bill says ${money(bill.statedTotalPence!)}; we '
              'calculate ${money(calc.totalPence)} '
              '(${money(calc.reconciliationDifferencePence!, signed: true)}). Check the values.',
        );
      case ReconciliationStatus.noStatedTotal:
        return const InfoBanner(
          text: 'Add the total from your bill (Edit) so we can check our maths against it.',
        );
    }
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.inclVat});
  final CalcLine line;
  final bool inclVat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    String? detail;
    if (line.kind == LineKind.standingCharge) {
      detail =
          '${line.quantityMilli! ~/ 1000} days × ${pence(line.rateMilliPence!)}';
    } else if (line.kind == LineKind.energy) {
      detail = '${kwh(line.quantityMilli!)} × ${pence(line.rateMilliPence!)}';
    }
    final isInfoOnly = line.kind == LineKind.vat && inclVat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.label),
                if (detail != null) Text(detail, style: t.bodySmall),
              ],
            ),
          ),
          Text(
            isInfoOnly
                ? '(${money(line.amountPence)})'
                : money(line.amountPence),
            style: t.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Official GB-average cap for the bill's period, for context only.
class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.bill,
    required this.reference,
    required this.today,
  });
  final Bill bill;
  final TariffDataset? reference;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final ds = reference;
    if (ds == null || bill.isEconomy7) return const SizedBox.shrink();
    if (ds.isStale(today)) {
      return const InfoBanner(
        icon: Icons.update,
        text:
            'Our copy of the Ofgem price cap is out of date, so we\'re not '
            'showing it. Update the app for the latest figures.',
      );
    }
    final v = ds.versionFor(bill.periodEnd);
    if (v == null) return const SizedBox.shrink();
    final period = bill.ratePeriods.last;
    final userRate = period.registers.first.unitRateMilliPence;
    final comparableRef = bill.ratesIncludeVat
        ? v.singleRateMilliPence
        : v.unitRateExVatMilliPence;
    final comparableStanding = bill.ratesIncludeVat
        ? v.standingChargeMilliPencePerDay
        : v.standingExVatMilliPencePerDay;
    final diffPermille = comparableRef == 0
        ? 0
        : divRoundHalfAwayFromZero(
            (userRate - comparableRef) * 1000,
            comparableRef,
          );
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For context: the Ofgem price cap', style: t.titleMedium),
            const SizedBox(height: 6),
            Text(
              'GB average, Direct Debit, ${dateRange(v.effectiveFrom, v.effectiveTo)}: '
              '${pence(comparableRef)}/kWh and ${pence(comparableStanding)}/day '
              '${bill.ratesIncludeVat ? 'incl.' : 'excl.'} VAT.',
            ),
            const SizedBox(height: 6),
            Text(
              'Your unit rate is ${pence(userRate)} '
              '(${diffPermille == 0 ? 'the same' : '${percentFromPermille(diffPermille.abs())} ${diffPermille > 0 ? 'above' : 'below'}'}).',
            ),
            const SizedBox(height: 6),
            Text(
              'The cap is a limit on standard variable rates, and it differs by '
              'region and payment method, so a difference here isn\'t necessarily '
              'wrong. Source: ${v.sourceAuthority}${v.verificationStatus == VerificationStatus.searchExtract ? ' (awaiting line-by-line verification)' : ''}.',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
