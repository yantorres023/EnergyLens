import 'package:flutter/material.dart';

import '../domain/calculator.dart';
import '../domain/direct_debit.dart';
import '../domain/fixed_point.dart';
import '../domain/models.dart';
import 'bill_detail_screen.dart';
import 'bill_form_screen.dart';
import 'comparison_screen.dart';
import 'copy.dart';
import 'direct_debit_screen.dart';
import 'format.dart';
import 'insight_widgets.dart';
import 'paste_import_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// HOW MUCH? → WHAT CHANGED? → WHY? → WHAT CAN I DO? → HOW CONFIDENT?
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static Future<void> addBill(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('add_manual'),
              leading: const Icon(Icons.edit_note),
              title: const Text('Type in the figures'),
              subtitle: const Text(
                'About 2 minutes with your bill in front of you',
              ),
              onTap: () => Navigator.pop(c, 'manual'),
            ),
            ListTile(
              key: const Key('add_paste'),
              leading: const Icon(Icons.content_paste),
              title: const Text('Paste text from a PDF or website'),
              subtitle: const Text('We find the figures; you check them'),
              onTap: () => Navigator.pop(c, 'paste'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => choice == 'paste'
            ? const PasteImportScreen()
            : const BillFormScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final latest = app.latestBill;
    return Scaffold(
      appBar: AppBar(
        title: const Text('EnergyLens'),
        actions: [
          IconButton(
            key: const Key('open_settings'),
            tooltip: 'Settings and privacy',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_bill'),
        onPressed: () => addBill(context),
        icon: const Icon(Icons.add),
        label: const Text('Add bill'),
      ),
      body: latest == null ? const _Empty() : _Dashboard(latest: latest),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.receipt_long_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Add your latest electricity bill',
          style: t.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'You\'ll need: the dates it covers, kWh used, unit rate, standing charge '
          'and the total. Then add the bill before it to see what changed.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('empty_add'),
          onPressed: () => HomeScreen.addBill(context),
          icon: const Icon(Icons.add),
          label: const Text('Add a bill'),
        ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.latest});
  final Bill latest;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final calc = app.calculationFor(latest);
    final comparison = app.comparisonFor(latest);
    final insights = app.insightsFor(latest);
    final t = Theme.of(context).textTheme;
    final completed = app.lastCompletedExperiment;
    final dd = app.directDebitCheck();
    final household = app.household!;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (completed != null) ...[
          const SectionTitle('Your action result is in'),
          ExperimentCard(experiment: completed),
        ],
        // HOW MUCH?
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: InkWell(
            key: const Key('latest_bill_card'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BillDetailScreen(billId: latest.id),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest bill', style: t.labelLarge),
                  Text(
                    money(calc.totalPence),
                    key: const Key('home_total'),
                    style: t.displaySmall,
                  ),
                  Text(
                    '${dateRange(latest.periodStart, latest.periodEnd)} · ${calc.days} days · '
                    '${kwh(calc.kwhPerDayMilli)}/day',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      const ProvenanceChip(Provenance.calculated),
                      if (latest.usageIsEstimated)
                        const ProvenanceChip(Provenance.estimated),
                      if (calc.reconciliation == ReconciliationStatus.matches)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(Icons.check, size: 16),
                          label: Text('Matches your bill'),
                        ),
                      if (calc.reconciliation == ReconciliationStatus.mismatch)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(Icons.error_outline, size: 16),
                          label: Text('Doesn\'t match — check'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // WHAT CHANGED? WHY?
        if (comparison != null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: InkWell(
              key: const Key('change_card'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ComparisonScreen(comparison: comparison),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change vs previous bill', style: t.labelLarge),
                    Text(
                      comparison.differencePence == 0
                          ? 'No change'
                          : '${money(comparison.differencePence.abs())} ${comparison.differencePence > 0 ? 'more' : 'less'}',
                      style: t.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final e in comparison.effects.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(Copy.effectLabel(e.type, comparison)),
                            ),
                            Text(money(e.amountPence, signed: true)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'See the full breakdown ›',
                      style: t.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          InfoBanner(
            icon: Icons.compare,
            text:
                'Add your previous bill too (the one before '
                '${date(latest.periodStart)}) to see what changed and why.',
          ),
        // WHAT CAN I DO?
        if (insights.isNotEmpty) const SectionTitle('What this means for you'),
        for (final i in insights.take(3))
          InsightCard(insight: i, bill: latest, comparison: comparison),
        if (insights.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BillDetailScreen(billId: latest.id),
                  ),
                ),
                child: Text('${insights.length - 3} more on the bill page'),
              ),
            ),
          ),
        if (app.activeExperiments.isNotEmpty) ...[
          const SectionTitle('Trying now'),
          for (final e in app.activeExperiments) ExperimentCard(experiment: e),
        ],
        if (household.paymentMethod == PaymentMethod.directDebit)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: ListTile(
              key: const Key('dd_card'),
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Is my Direct Debit right?'),
              subtitle: Text(
                dd == null
                    ? 'Add your monthly amount to check it'
                    : switch (dd.verdict) {
                        DirectDebitVerdict.aboutRight =>
                          'Looks about right (estimate)',
                        DirectDebitVerdict.likelyTooLow =>
                          'May be too low: ~${money(dd.suggestedMonthlyPence)} a month (estimate)',
                        DirectDebitVerdict.likelyTooHigh =>
                          'May be higher than needed: ~${money(dd.suggestedMonthlyPence)} (estimate)',
                      },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DirectDebitScreen()),
              ),
            ),
          ),
        if (app.referenceIsStale)
          const InfoBanner(
            icon: Icons.update,
            text:
                'Price-cap reference figures in this version are out of date. Your '
                'own bills are unaffected; estimates that rely on the cap are hidden.',
          ),
        const SectionTitle('Your bills'),
        for (final b in app.bills.reversed) _BillTile(bill: b),
        if (app.completedExperiments.isNotEmpty) ...[
          const SectionTitle('Past actions'),
          for (final e in app.completedExperiments.reversed)
            ExperimentCard(experiment: e),
        ],
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill});
  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = app.calculationFor(bill);
    return ListTile(
      title: Text(dateRange(bill.periodStart, bill.periodEnd)),
      subtitle: Text(
        '${kwh(c.kwhMilli, decimals: 0)} · ${money(divRoundHalfAwayFromZero(c.costPerDayMilliPence, 1000))}/day'
        '${bill.usageIsEstimated ? ' · estimated' : ''}',
      ),
      trailing: Text(
        money(c.totalPence),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)),
      ),
    );
  }
}
