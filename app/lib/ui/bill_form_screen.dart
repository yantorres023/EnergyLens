import 'package:flutter/material.dart';

import '../app/analytics.dart';
import '../app/app_controller.dart';
import '../domain/calculator.dart';
import '../domain/dates.dart';
import '../domain/fixed_point.dart';
import '../domain/models.dart';
import '../parsing/bill_text_parser.dart';
import 'copy.dart';
import 'format.dart';
import 'widgets.dart';

/// GB VAT on domestic electricity: 0% from 1 Oct 2026 to 31 Mar 2027,
/// otherwise 5%. Only a default — the user can change it per rate period.
int defaultVatFor(DateTime day) {
  return isWithin(day, DateTime.utc(2026, 10, 1), DateTime.utc(2027, 3, 31))
      ? 0
      : 500;
}

DateTime? parseUkDate(String s) {
  final m = RegExp(r'^\s*(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})\s*$')
      .firstMatch(s);
  if (m == null) return null;
  var y = int.parse(m.group(3)!);
  if (y < 100) y += 2000;
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(1)!);
  final dt = DateTime.utc(y, mo, d);
  if (dt.month != mo || dt.day != d) return null;
  return dt;
}

String ukDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _PeriodDraft {
  _PeriodDraft({required this.vatBp});
  final standing = TextEditingController();
  final kwh = TextEditingController();
  final rate = TextEditingController();
  final dayKwh = TextEditingController();
  final dayRate = TextEditingController();
  final nightKwh = TextEditingController();
  final nightRate = TextEditingController();
  int vatBp;
  bool vatTouched = false;

  void dispose() {
    for (final c in [
      standing,
      kwh,
      rate,
      dayKwh,
      dayRate,
      nightKwh,
      nightRate,
    ]) {
      c.dispose();
    }
  }
}

class _AdjustmentDraft {
  final label = TextEditingController();
  final amount = TextEditingController();
  bool isCredit = true;
  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

/// Enter, confirm (after paste) or edit a bill.
///
/// When [parsed] is given, every proposed value is shown with its source
/// snippet and must be reviewed before saving; changed values are recorded as
/// [UserCorrection]s.
class BillFormScreen extends StatefulWidget {
  const BillFormScreen({super.key, this.existing, this.parsed});
  final Bill? existing;
  final ParseResult? parsed;

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _change = TextEditingController();
  final _total = TextEditingController();
  final _balance = TextEditingController();
  final _supplier = TextEditingController();
  late _PeriodDraft _p1;
  late _PeriodDraft _p2;
  bool _split = false;
  bool _e7 = false;
  bool _ratesIncludeVat = false;
  bool _balanceInCredit = true;
  ReadingType _reading = ReadingType.unknown;
  final List<_AdjustmentDraft> _adjustments = [];

  /// field name → value proposed by the parser (for corrections/provenance).
  final Map<String, String> _parsedValues = {};
  final Map<String, String> _parsedSnippets = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _p1 = _PeriodDraft(vatBp: 500);
    _p2 = _PeriodDraft(vatBp: 0);
    final existing = widget.existing;
    if (existing != null) {
      _loadExisting(existing);
    } else if (widget.parsed != null) {
      _loadParsed(widget.parsed!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing == null &&
        widget.parsed?.fields.containsKey(ParsedFieldKey.kwhDay) != true) {
      _e7 =
          _e7 ||
          AppScope.read(context).household?.meterType == MeterType.economy7;
    }
  }

  void _loadExisting(Bill b) {
    _start.text = ukDate(b.periodStart);
    _end.text = ukDate(b.periodEnd);
    _ratesIncludeVat = b.ratesIncludeVat;
    _reading = b.readingType;
    _supplier.text = b.supplierName ?? '';
    if (b.statedTotalPence != null) {
      _total.text = _poundsText(b.statedTotalPence!);
    }
    if (b.closingBalancePence != null) {
      _balance.text = _poundsText(b.closingBalancePence!.abs());
      _balanceInCredit = b.closingBalancePence! >= 0;
    }
    _e7 = b.isEconomy7;
    void fill(_PeriodDraft d, RatePeriod p) {
      d.standing.text = formatMilli(p.standingChargeMilliPencePerDay);
      d.vatBp = p.vatBasisPoints;
      d.vatTouched = true;
      for (final r in p.registers) {
        switch (r.register) {
          case Register.single:
            d.kwh.text = formatMilli(r.kwhMilli);
            d.rate.text = formatMilli(r.unitRateMilliPence);
          case Register.day:
            d.dayKwh.text = formatMilli(r.kwhMilli);
            d.dayRate.text = formatMilli(r.unitRateMilliPence);
          case Register.night:
            d.nightKwh.text = formatMilli(r.kwhMilli);
            d.nightRate.text = formatMilli(r.unitRateMilliPence);
        }
      }
    }

    fill(_p1, b.ratePeriods.first);
    if (b.ratePeriods.length > 1) {
      _split = true;
      fill(_p2, b.ratePeriods[1]);
      _change.text = ukDate(b.ratePeriods[1].start);
    }
    for (final a in b.adjustments) {
      final d = _AdjustmentDraft()
        ..label.text = a.label
        ..amount.text = _poundsText(a.amountPence.abs())
        ..isCredit = a.amountPence < 0;
      _adjustments.add(d);
    }
  }

  void _loadParsed(ParseResult r) {
    void set(
      ParsedFieldKey k,
      TextEditingController c,
      String name, {
      String Function(String)? map,
    }) {
      final f = r.fields[k];
      if (f == null) return;
      final v = map == null ? f.value : map(f.value);
      c.text = v;
      _parsedValues[name] = v;
      _parsedSnippets[name] = f.sourceSnippet;
    }

    set(
      ParsedFieldKey.periodStart,
      _start,
      'start',
      map: (v) => ukDate(parseIsoDate(v)),
    );
    set(
      ParsedFieldKey.periodEnd,
      _end,
      'end',
      map: (v) => ukDate(parseIsoDate(v)),
    );
    set(ParsedFieldKey.standingCharge, _p1.standing, 'standing');
    set(ParsedFieldKey.kwhSingle, _p1.kwh, 'kwh');
    set(ParsedFieldKey.unitRateSingle, _p1.rate, 'rate');
    set(ParsedFieldKey.kwhDay, _p1.dayKwh, 'dayKwh');
    set(ParsedFieldKey.unitRateDay, _p1.dayRate, 'dayRate');
    set(ParsedFieldKey.kwhNight, _p1.nightKwh, 'nightKwh');
    set(ParsedFieldKey.unitRateNight, _p1.nightRate, 'nightRate');
    set(
      ParsedFieldKey.statedTotal,
      _total,
      'total',
      map: (v) => _poundsText(int.parse(v)),
    );
    _e7 = r.fields.containsKey(ParsedFieldKey.kwhDay);
    final vat = r.fields[ParsedFieldKey.vatPercent];
    if (vat != null) {
      final bp = parseMilli(vat.value);
      if (bp != null) {
        _p1.vatBp = bp ~/ 10;
        _p1.vatTouched = true;
        _parsedValues['vat'] = '${_p1.vatBp}';
        _parsedSnippets['vat'] = vat.sourceSnippet;
      }
    }
    final rt = r.fields[ParsedFieldKey.readingType];
    if (rt != null) {
      _reading = ReadingType.values.firstWhere(
        (e) => e.name == rt.value,
        orElse: () => ReadingType.unknown,
      );
      _parsedValues['reading'] = _reading.name;
      _parsedSnippets['reading'] = rt.sourceSnippet;
    }
  }

  static String _poundsText(int pence) =>
      '${pence ~/ 100}.${(pence % 100).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    for (final c in [_start, _end, _change, _total, _balance, _supplier]) {
      c.dispose();
    }
    _p1.dispose();
    _p2.dispose();
    for (final a in _adjustments) {
      a.dispose();
    }
    super.dispose();
  }

  // ---- Validation helpers --------------------------------------------------

  String? _dateValidator(String? v) =>
      parseUkDate(v ?? '') == null ? 'Enter a date as dd/mm/yyyy' : null;

  String? _numberValidator(String? v, {bool allowZero = true}) {
    final n = parseMilli(v ?? '');
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Can\'t be negative';
    if (!allowZero && n == 0) return 'Must be more than 0';
    return null;
  }

  String? _rateValidator(String? v) {
    final basic = _numberValidator(v);
    if (basic != null) return basic;
    final n = parseMilli(v!)!;
    // Guard the most common unit slip: typing pounds (0.26) instead of pence.
    if (n > 0 && n < 1000) {
      return 'Looks like pounds — enter pence (e.g. 26.32)';
    }
    if (n > 150 * milli) return 'That\'s over £1.50 — check the unit (pence)';
    return null;
  }

  RatePeriod _buildPeriod(_PeriodDraft d, DateTime start, DateTime end) {
    final regs = _e7
        ? [
            RegisterUsage(
              register: Register.day,
              kwhMilli: parseMilli(d.dayKwh.text)!,
              unitRateMilliPence: parseMilli(d.dayRate.text)!,
            ),
            RegisterUsage(
              register: Register.night,
              kwhMilli: parseMilli(d.nightKwh.text)!,
              unitRateMilliPence: parseMilli(d.nightRate.text)!,
            ),
          ]
        : [
            RegisterUsage(
              register: Register.single,
              kwhMilli: parseMilli(d.kwh.text)!,
              unitRateMilliPence: parseMilli(d.rate.text)!,
            ),
          ];
    return RatePeriod(
      start: start,
      end: end,
      standingChargeMilliPencePerDay: parseMilli(d.standing.text)!,
      registers: regs,
      vatBasisPoints: d.vatBp,
    );
  }

  Bill? _buildBill(AppController app) {
    if (!_formKey.currentState!.validate()) return null;
    final start = parseUkDate(_start.text)!;
    final end = parseUkDate(_end.text)!;
    if (end.isBefore(start)) {
      _snack('The end date is before the start date.');
      return null;
    }
    if (inclusiveDays(start, end) > 400) {
      _snack('That period is over 400 days. Enter one bill at a time.');
      return null;
    }
    final periods = <RatePeriod>[];
    if (_split) {
      final change = parseUkDate(_change.text);
      if (change == null || !change.isAfter(start) || change.isAfter(end)) {
        _snack(
          'The date new prices started must be inside the billing period.',
        );
        return null;
      }
      periods.add(
        _buildPeriod(_p1, start, change.subtract(const Duration(days: 1))),
      );
      periods.add(_buildPeriod(_p2, change, end));
    } else {
      periods.add(_buildPeriod(_p1, start, end));
    }

    final adjustments = <Adjustment>[];
    for (final a in _adjustments) {
      final p = parsePoundsToPence(a.amount.text);
      if (p == null || a.label.text.trim().isEmpty) {
        _snack('Each credit or charge needs a name and an amount.');
        return null;
      }
      adjustments.add(
        Adjustment(
          label: a.label.text.trim(),
          amountPence: a.isCredit ? -p.abs() : p.abs(),
          kind: a.isCredit ? AdjustmentKind.credit : AdjustmentKind.fee,
        ),
      );
    }

    int? stated;
    if (_total.text.trim().isNotEmpty) {
      stated = parsePoundsToPence(_total.text);
      if (stated == null) {
        _snack('The bill total isn\'t a valid amount.');
        return null;
      }
    }
    int? balance;
    if (_balance.text.trim().isNotEmpty) {
      final b = parsePoundsToPence(_balance.text);
      if (b == null) {
        _snack('The balance isn\'t a valid amount.');
        return null;
      }
      balance = _balanceInCredit ? b.abs() : -b.abs();
    }

    // Provenance and corrections for parsed values.
    final current = <String, String>{
      'start': _start.text.trim(),
      'end': _end.text.trim(),
      'standing': _p1.standing.text.trim(),
      'kwh': _p1.kwh.text.trim(),
      'rate': _p1.rate.text.trim(),
      'dayKwh': _p1.dayKwh.text.trim(),
      'dayRate': _p1.dayRate.text.trim(),
      'nightKwh': _p1.nightKwh.text.trim(),
      'nightRate': _p1.nightRate.text.trim(),
      'total': _total.text.trim(),
      'vat': '${_p1.vatBp}',
      'reading': _reading.name,
    };
    final provenance = <String, Provenance>{};
    final corrections = <UserCorrection>[...?widget.existing?.corrections];
    current.forEach((k, v) {
      if (v.isEmpty) return;
      final parsed = _parsedValues[k];
      if (parsed == null) {
        provenance[k] =
            widget.existing?.fieldProvenance[k] ?? Provenance.userEntered;
      } else if (parsed == v) {
        provenance[k] = Provenance.parsed;
      } else {
        provenance[k] = Provenance.userEntered;
        corrections.add(
          UserCorrection(field: k, parsedValue: parsed, correctedValue: v),
        );
      }
    });
    if (_reading == ReadingType.actual || _reading == ReadingType.smart) {
      provenance['usage'] = Provenance.measured;
    } else if (_reading == ReadingType.estimated) {
      provenance['usage'] = Provenance.estimated;
    }

    final e = widget.existing;
    return Bill(
      id: e?.id ?? newId(),
      householdId: app.household!.id,
      ratePeriods: periods,
      adjustments: adjustments,
      ratesIncludeVat: _ratesIncludeVat,
      statedTotalPence: stated,
      readingType: _reading,
      supplierName: _supplier.text.trim().isEmpty
          ? null
          : _supplier.text.trim(),
      source:
          e?.source ??
          (widget.parsed != null ? BillSource.pastedText : BillSource.manual),
      fieldProvenance: provenance,
      corrections: corrections,
      closingBalancePence: balance,
      createdAt: e?.createdAt ?? app.clock(),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final bill = _buildBill(app);
    if (bill == null) return;
    final BillCalculation calc;
    try {
      calc = app.calculator.calculate(bill);
    } on ValidationError catch (e) {
      _snack(e.message);
      return;
    }
    if (calc.reconciliation == ReconciliationStatus.mismatch) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Doesn\'t match your bill'),
          content: Text(
            'From these values we calculate ${money(calc.totalPence)}, but the '
            'bill total you entered is ${money(bill.statedTotalPence!)}.\n\n'
            'Common causes: a mistyped rate or kWh, prices shown including VAT, '
            'a missing credit, or prices that changed during the bill.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Check again'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    setState(() => _saving = true);
    if (widget.parsed != null && widget.existing == null) {
      await app.analytics.log(Events.billParsed, {
        'fields_found': widget.parsed!.fields.length,
      });
    }
    await app.saveBill(bill, isEdit: widget.existing != null);
    if (!mounted) return;
    Navigator.of(context).pop(bill.id);
  }

  Future<void> _pickDate(TextEditingController c) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseUkDate(c.text) ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(
        () => c.text = ukDate(
          DateTime.utc(picked.year, picked.month, picked.day),
        ),
      );
      _applyVatDefaults();
    }
  }

  void _applyVatDefaults() {
    final start = parseUkDate(_start.text);
    if (start != null && !_p1.vatTouched) _p1.vatBp = defaultVatFor(start);
    final change = parseUkDate(_change.text);
    if (change != null && !_p2.vatTouched) _p2.vatBp = defaultVatFor(change);
  }

  Future<void> _readingsHelper(TextEditingController target) async {
    final open = TextEditingController();
    final close = TextEditingController();
    var rolled = false;
    String? error;
    final result = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Work out kWh from meter readings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('reading_open'),
                controller: open,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Opening reading'),
              ),
              TextField(
                key: const Key('reading_close'),
                controller: close,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Closing reading'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: rolled,
                onChanged: (v) => set(() => rolled = v ?? false),
                title: const Text(
                  'The meter went past 99999 and restarted at 0',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(c).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final a = parseMilli(open.text);
                final b = parseMilli(close.text);
                if (a == null || b == null) {
                  set(() => error = 'Enter both readings.');
                  return;
                }
                try {
                  final digits = open.text
                      .split('.')
                      .first
                      .replaceAll(',', '')
                      .length;
                  Navigator.pop(
                    c,
                    MeterConsumption.fromReadings(
                      startMilli: a,
                      endMilli: b,
                      rolloverDigits: rolled ? (digits < 5 ? 5 : digits) : null,
                    ),
                  );
                } on ValidationError catch (e) {
                  set(() => error = e.message);
                }
              },
              child: const Text('Use'),
            ),
          ],
        ),
      ),
    );
    open.dispose();
    close.dispose();
    if (result != null) setState(() => target.text = formatMilli(result));
  }

  // ---- Build ----------------------------------------------------------------

  Widget _parsedHint(String field) {
    final snippet = _parsedSnippets[field];
    if (snippet == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Row(
        children: [
          const ProvenanceChip(Provenance.parsed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '“$snippet”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(
    TextEditingController c,
    String label, {
    required Key key,
    String? suffix,
    String? helper,
    String? parsedField,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: key,
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            helperText: helper,
            suffixIcon: suffixIcon,
          ),
          validator: validator ?? _numberValidator,
        ),
        if (parsedField != null) _parsedHint(parsedField),
      ],
    );
  }

  Widget _periodFields(_PeriodDraft d, {required bool first}) {
    final k = first ? '' : '2';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_e7) ...[
          _numField(
            d.dayKwh,
            'Day units used',
            key: Key('dayKwh$k'),
            suffix: 'kWh',
            parsedField: first ? 'dayKwh' : null,
          ),
          _numField(
            d.dayRate,
            'Day unit rate',
            key: Key('dayRate$k'),
            suffix: 'p/kWh',
            parsedField: first ? 'dayRate' : null,
            validator: _rateValidator,
          ),
          _numField(
            d.nightKwh,
            'Night units used',
            key: Key('nightKwh$k'),
            suffix: 'kWh',
            parsedField: first ? 'nightKwh' : null,
          ),
          _numField(
            d.nightRate,
            'Night unit rate',
            key: Key('nightRate$k'),
            suffix: 'p/kWh',
            parsedField: first ? 'nightRate' : null,
            validator: _rateValidator,
          ),
        ] else ...[
          _numField(
            d.kwh,
            'Electricity used',
            key: Key('kwh$k'),
            suffix: 'kWh',
            parsedField: first ? 'kwh' : null,
            suffixIcon: IconButton(
              tooltip: 'Work out from meter readings',
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () => _readingsHelper(d.kwh),
            ),
          ),
          _numField(
            d.rate,
            'Unit rate',
            key: Key('rate$k'),
            suffix: 'p/kWh',
            helper: 'Price per kWh in pence, e.g. 26.32',
            parsedField: first ? 'rate' : null,
            validator: _rateValidator,
          ),
        ],
        _numField(
          d.standing,
          'Standing charge',
          key: Key('standing$k'),
          suffix: 'p/day',
          helper: 'Daily charge in pence, e.g. 54.83',
          parsedField: first ? 'standing' : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('VAT'),
            const SizedBox(width: 12),
            SegmentedButton<int>(
              key: Key('vat$k'),
              segments: const [
                ButtonSegment(value: 500, label: Text('5%')),
                ButtonSegment(value: 0, label: Text('0%')),
              ],
              selected: {d.vatBp == 0 ? 0 : 500},
              onSelectionChanged: (s) => setState(() {
                d.vatBp = s.first;
                d.vatTouched = true;
              }),
            ),
          ],
        ),
        if (first) _parsedHint('vat'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = widget.parsed;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? 'Edit bill'
              : parsed != null
              ? 'Check what we found'
              : 'Add a bill',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (parsed != null) ...[
              const InfoBanner(
                icon: Icons.fact_check_outlined,
                text:
                    'We read these values from the text you pasted. Please check '
                    'each one against your bill before saving — nothing is '
                    'calculated until you confirm.',
              ),
              for (final n in parsed.notes) InfoBanner(text: n),
            ],
            const SectionTitle('Billing period'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('start_date'),
                    controller: _start,
                    decoration: InputDecoration(
                      labelText: 'From',
                      hintText: 'dd/mm/yyyy',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.event),
                        tooltip: 'Pick start date',
                        onPressed: () => _pickDate(_start),
                      ),
                    ),
                    validator: _dateValidator,
                    onChanged: (_) => _applyVatDefaults(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('end_date'),
                    controller: _end,
                    decoration: InputDecoration(
                      labelText: 'To (inclusive)',
                      hintText: 'dd/mm/yyyy',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.event),
                        tooltip: 'Pick end date',
                        onPressed: () => _pickDate(_end),
                      ),
                    ),
                    validator: _dateValidator,
                  ),
                ),
              ],
            ),
            _parsedHint('start'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Economy 7 (day and night rates)'),
              value: _e7,
              onChanged: (v) => setState(() => _e7 = v),
            ),
            SwitchListTile(
              key: const Key('split_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Prices changed during this bill'),
              subtitle: const Text(
                'e.g. your bill shows two unit rates, before and after 1 October',
              ),
              value: _split,
              onChanged: (v) => setState(() => _split = v),
            ),
            SectionTitle(
              _split ? 'Before the price change' : 'Usage and prices',
            ),
            _periodFields(_p1, first: true),
            if (_split) ...[
              const SectionTitle('After the price change'),
              TextFormField(
                key: const Key('change_date'),
                controller: _change,
                decoration: InputDecoration(
                  labelText: 'New prices started on',
                  hintText: 'dd/mm/yyyy',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.event),
                    onPressed: () => _pickDate(_change),
                  ),
                ),
                validator: _split ? _dateValidator : null,
                onChanged: (_) => _applyVatDefaults(),
              ),
              _periodFields(_p2, first: false),
            ],
            SwitchListTile(
              key: const Key('incl_vat_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('The prices above already include VAT'),
              subtitle: const Text(
                'Most bills show prices before VAT with a separate VAT line.',
              ),
              value: _ratesIncludeVat,
              onChanged: (v) => setState(() => _ratesIncludeVat = v),
            ),
            const SectionTitle('Meter reading'),
            DropdownButtonFormField<ReadingType>(
              key: const Key('reading_type'),
              initialValue: _reading,
              decoration: const InputDecoration(
                labelText: 'Closing reading was',
                helperText: 'Bills mark estimates with "E" or "estimated".',
              ),
              items: [
                for (final r in ReadingType.values)
                  DropdownMenuItem(value: r, child: Text(Copy.readingType(r))),
              ],
              onChanged: (v) =>
                  setState(() => _reading = v ?? ReadingType.unknown),
            ),
            _parsedHint('reading'),
            const SectionTitle('Credits and extra charges'),
            for (final a in _adjustments)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: a.label,
                      decoration: const InputDecoration(
                        labelText: 'What it is',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: a.amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '£',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: a.isCredit
                        ? 'Credit (reduces bill)'
                        : 'Charge (adds to bill)',
                    icon: Icon(
                      a.isCredit
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline,
                    ),
                    onPressed: () => setState(() => a.isCredit = !a.isCredit),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _adjustments.remove(a);
                      a.dispose();
                    }),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _adjustments.add(_AdjustmentDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add a credit or charge'),
              ),
            ),
            const SectionTitle('To check our maths (optional)'),
            TextFormField(
              key: const Key('stated_total'),
              controller: _total,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Total electricity charges on the bill',
                prefixText: '£ ',
                helperText:
                    'Charges for this period, not your account balance.',
              ),
            ),
            _parsedHint('total'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _balance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Account balance after this bill',
                      prefixText: '£ ',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<bool>(
                  value: _balanceInCredit,
                  items: const [
                    DropdownMenuItem(value: true, child: Text('in credit')),
                    DropdownMenuItem(value: false, child: Text('owed')),
                  ],
                  onChanged: (v) =>
                      setState(() => _balanceInCredit = v ?? true),
                ),
              ],
            ),
            TextFormField(
              controller: _supplier,
              decoration: const InputDecoration(
                labelText: 'Supplier (optional)',
                helperText:
                    'Just the company name. Don\'t enter account numbers.',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('save_bill'),
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.check),
        label: Text(parsed != null ? 'Confirm and save' : 'Save bill'),
      ),
    );
  }
}
