import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/fixed_point.dart';
import '../domain/models.dart';
import 'copy.dart';
import 'widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  MeterType _meter = MeterType.singleRate;
  TariffKind _tariff = TariffKind.unknown;
  PaymentMethod _payment = PaymentMethod.directDebit;
  GbRegion _region = GbRegion.unknown;
  bool _analytics = false;
  final _dd = TextEditingController();
  String? _ddError;

  @override
  void dispose() {
    _dd.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    int? ddPence;
    if (_payment == PaymentMethod.directDebit && _dd.text.trim().isNotEmpty) {
      ddPence = parsePoundsToPence(_dd.text);
      if (ddPence == null || ddPence <= 0) {
        setState(() => _ddError = 'Enter an amount like 95.00, or leave blank');
        return;
      }
    }
    await AppScope.read(context).completeOnboarding(
      Household(
        id: newId(),
        region: _region,
        meterType: _meter,
        tariffKind: _tariff,
        paymentMethod: _payment,
        directDebitMonthlyPence: ddPence,
      ),
      analyticsOptIn: _analytics,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_intro(context), _privacy(context), _household(context)];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / pages.length),
            Expanded(child: pages[_step]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('onboarding_next'),
                    onPressed: _step < pages.length - 1
                        ? () => setState(() => _step++)
                        : _finish,
                    child: Text(_step < pages.length - 1 ? 'Next' : 'Start'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.receipt_long,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text('Why did my electricity bill change?', style: t.headlineSmall),
        const SizedBox(height: 12),
        const Text(
          'Add two bills and EnergyLens splits the difference into plain '
          'reasons: more days, more use, higher prices, the standing charge, VAT '
          'or credits — with the pounds for each.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Then pick one thing to try, and your next bill shows whether it '
          'made a difference.',
        ),
        const SizedBox(height: 24),
        const InfoBanner(
          text:
              'For households in England, Scotland and Wales with an electricity '
              'bill (single-rate or Economy 7). Not for prepayment meters yet.',
        ),
        const InfoBanner(
          text:
              'EnergyLens is independent. It is not your supplier or Ofgem, it '
              'doesn\'t sell tariffs, and it can\'t guarantee savings.',
        ),
      ],
    );
  }

  Widget _privacy(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.lock_outline,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text('Your bills stay on this phone', style: t.headlineSmall),
        const SizedBox(height: 12),
        const Text(
          '• No account, no login to your supplier.\n'
          '• We never ask for your name, address, account number or MPAN.\n'
          '• Pasted bill text is read once and not saved.\n'
          '• You can delete everything in Settings at any time.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          key: const Key('analytics_switch'),
          value: _analytics,
          onChanged: (v) => setState(() => _analytics = v),
          title: const Text('Keep a private usage log on this device'),
          subtitle: const Text(
            'Off by default. Records which screens you used (no amounts, dates '
            'or text) so you can share it if you give feedback. Never sent '
            'anywhere automatically.',
          ),
        ),
      ],
    );
  }

  Widget _household(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('About your electricity', style: t.headlineSmall),
        const SizedBox(height: 4),
        const Text('You can change these later. "Not sure" is fine.'),
        const SizedBox(height: 16),
        _choice<MeterType>(
          'Meter',
          MeterType.values,
          _meter,
          Copy.meterType,
          (v) => setState(() => _meter = v),
        ),
        _choice<TariffKind>(
          'Tariff',
          TariffKind.values,
          _tariff,
          Copy.tariffKind,
          (v) => setState(() => _tariff = v),
        ),
        _choice<PaymentMethod>(
          'How you pay',
          PaymentMethod.values,
          _payment,
          Copy.paymentMethod,
          (v) => setState(() => _payment = v),
        ),
        if (_payment == PaymentMethod.directDebit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              key: const Key('dd_field'),
              controller: _dd,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monthly Direct Debit for electricity (optional)',
                prefixText: '£ ',
                errorText: _ddError,
                helperText:
                    'Used only for the "Is my Direct Debit right?" check.',
              ),
            ),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<GbRegion>(
          initialValue: _region,
          decoration: const InputDecoration(labelText: 'Region (optional)'),
          items: [
            for (final r in GbRegion.values)
              DropdownMenuItem(value: r, child: Text(r.label)),
          ],
          onChanged: (v) => setState(() => _region = v ?? GbRegion.unknown),
        ),
      ],
    );
  }

  Widget _choice<T>(
    String label,
    List<T> values,
    T selected,
    String Function(T) text,
    ValueChanged<T> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(text(v)),
                  selected: v == selected,
                  onSelected: (_) => onChanged(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
