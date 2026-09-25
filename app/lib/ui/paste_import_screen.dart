import 'package:flutter/material.dart';

import '../parsing/bill_text_parser.dart';
import 'bill_form_screen.dart';
import 'widgets.dart';

/// IMPORT step: the user pastes text copied from a PDF bill or their
/// supplier's website. The text lives only in this screen's memory; it is
/// parsed, then discarded — it is never written to storage.
class PasteImportScreen extends StatefulWidget {
  const PasteImportScreen({super.key});

  @override
  State<PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends State<PasteImportScreen> {
  final _text = TextEditingController();
  static const maxChars = 50000;

  @override
  void dispose() {
    _text.clear();
    _text.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final input = _text.text;
    if (input.trim().isEmpty) return;
    final result = const BillTextParser().parse(
      input.length > maxChars ? input.substring(0, maxChars) : input,
    );
    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We couldn\'t find bill figures in that text. You can enter them by hand instead.',
          ),
        ),
      );
      return;
    }
    // Drop the pasted text as soon as it has been parsed.
    _text.clear();
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => BillFormScreen(parsed: result)),
    );
    if (!mounted) return;
    if (saved != null) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paste bill text')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Open your bill (PDF or your supplier\'s website), select all the '
            'text, copy it, and paste it below. We look for the billing '
            'period, kWh, unit rate, standing charge, VAT and total.',
          ),
          const SizedBox(height: 8),
          const InfoBanner(
            icon: Icons.privacy_tip_outlined,
            text:
                'The text is read on this phone and then discarded. We never '
                'keep your name, address, account number or MPAN.',
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('paste_field'),
            controller: _text,
            maxLines: 12,
            maxLength: maxChars,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste here…',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('parse_button'),
            onPressed: _parse,
            icon: const Icon(Icons.search),
            label: const Text('Find the figures'),
          ),
        ],
      ),
    );
  }
}
