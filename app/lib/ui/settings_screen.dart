import 'package:flutter/material.dart';

import '../app/analytics.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/tariff_reference.dart';
import 'copy.dart';
import 'format.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final h = app.household;
    final ref = app.reference;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings and privacy')),
      body: ListView(
        children: [
          if (h != null) ...[
            const SectionTitle('Your home'),
            ListTile(
              title: const Text('Meter'),
              subtitle: Text(Copy.meterType(h.meterType)),
              onTap: () => _pick<MeterType>(
                context,
                'Meter',
                MeterType.values,
                Copy.meterType,
                (v) => app.updateHousehold(h.copyWith(meterType: v)),
              ),
            ),
            ListTile(
              title: const Text('Tariff'),
              subtitle: Text(Copy.tariffKind(h.tariffKind)),
              onTap: () => _pick<TariffKind>(
                context,
                'Tariff',
                TariffKind.values,
                Copy.tariffKind,
                (v) => app.updateHousehold(h.copyWith(tariffKind: v)),
              ),
            ),
            ListTile(
              title: const Text('How you pay'),
              subtitle: Text(Copy.paymentMethod(h.paymentMethod)),
              onTap: () => _pick<PaymentMethod>(
                context,
                'How you pay',
                PaymentMethod.values,
                Copy.paymentMethod,
                (v) => app.updateHousehold(h.copyWith(paymentMethod: v)),
              ),
            ),
            ListTile(
              title: const Text('Region'),
              subtitle: Text(h.region.label),
              onTap: () => _pick<GbRegion>(
                context,
                'Region',
                GbRegion.values,
                (r) => r.label,
                (v) => app.updateHousehold(h.copyWith(region: v)),
              ),
            ),
          ],
          const SectionTitle('Privacy'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Everything you enter is stored only in this app on this phone. '
              'EnergyLens has no account, no server and no advertising or '
              'tracking code. Pasted bill text is not saved. Phone backups '
              'may include app data depending on your phone settings.',
            ),
          ),
          SwitchListTile(
            key: const Key('settings_analytics'),
            title: const Text('Private usage log on this device'),
            subtitle: const Text(
              'Which features you used — no amounts, dates or text. Never sent.',
            ),
            value: app.settings.analyticsOptIn,
            onChanged: (v) => app.setAnalyticsOptIn(v),
          ),
          if (app.settings.analyticsOptIn)
            ListTile(
              title: const Text('View usage log'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _EventLogScreen()),
              ),
            ),
          ListTile(
            key: const Key('delete_all'),
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Delete all my data'),
            subtitle: const Text('Bills, actions, settings and the usage log'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete everything?'),
                  content: const Text(
                    'All bills, actions and settings will be erased from this phone. '
                    'This can\'t be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: const Key('confirm_delete_all'),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete everything'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await app.analytics.log(Events.dataDeleted);
                await app.deleteAllData();
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              }
            },
          ),
          const SectionTitle('Where the numbers come from'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(Copy.methodology),
          ),
          const SizedBox(height: 8),
          if (ref != null)
            ListTile(
              title: const Text('Price cap reference data'),
              subtitle: Text(
                '${ref.versions.length} quarters, last checked '
                '${date(ref.versions.map((v) => v.lastVerifiedAt).reduce((a, b) => a.isAfter(b) ? a : b))}. '
                '${app.referenceIsStale ? 'Out of date — estimates using it are hidden.' : 'Up to date.'}'
                '${ref.versions.any((v) => v.verificationStatus == VerificationStatus.searchExtract) ? ' Some figures await line-by-line verification against Ofgem\'s tables.' : ''}',
              ),
            ),
          const SectionTitle('About'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Text(
              'EnergyLens (working name) is independent of energy suppliers and '
              'Ofgem. It explains bills using the figures you enter; it is not '
              'financial advice and cannot guarantee savings. For billing '
              'disputes contact your supplier, then the Energy Ombudsman. Free '
              'help: Citizens Advice consumer service.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick<T>(
    BuildContext context,
    String title,
    List<T> values,
    String Function(T) label,
    Future<void> Function(T) onPicked,
  ) async {
    final v = await showDialog<T>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(title),
        children: [
          for (final v in values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, v),
              child: Text(label(v)),
            ),
        ],
      ),
    );
    if (v != null) await onPicked(v);
  }
}

class _EventLogScreen extends StatelessWidget {
  const _EventLogScreen();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage log'),
        actions: [
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              await app.repository.clearEvents();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<AnalyticsEvent>>(
        future: app.repository.listEvents(),
        builder: (context, snap) {
          final events = snap.data ?? const [];
          if (events.isEmpty) {
            return const Center(child: Text('Nothing logged yet.'));
          }
          return ListView(
            children: [
              for (final e in events.reversed)
                ListTile(
                  dense: true,
                  title: Text(e.name),
                  subtitle: Text(
                    '${e.at.toLocal().toIso8601String().substring(0, 16)}  ${e.properties}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
