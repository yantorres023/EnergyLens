import '../data/repository.dart';

/// Event names from docs/product/ANALYTICS.md. Properties must never contain
/// money amounts, dates of bills, supplier names or free text — only
/// counts, enums and booleans.
abstract final class Events {
  static const onboardingCompleted = 'onboarding_completed';
  static const billAdded = 'bill_added';
  static const billParsed = 'bill_parsed';
  static const billCorrected = 'bill_corrected';
  static const comparisonViewed = 'comparison_viewed';
  static const insightViewed = 'insight_viewed';
  static const actionSelected = 'action_selected';
  static const nextBillAdded = 'next_bill_added';
  static const savingsExperimentCompleted = 'savings_experiment_completed';
  static const whatIfCalculated = 'what_if_calculated';
  static const directDebitChecked = 'direct_debit_checked';
  static const dataDeleted = 'data_deleted';

  static const all = {
    onboardingCompleted,
    billAdded,
    billParsed,
    billCorrected,
    comparisonViewed,
    insightViewed,
    actionSelected,
    nextBillAdded,
    savingsExperimentCompleted,
    whatIfCalculated,
    directDebitChecked,
    dataDeleted,
  };
}

/// Local-only analytics. V1 has no network code at all: events are written
/// to the on-device database *only if the user opted in*, and can be viewed
/// and cleared in Settings. See docs/product/ANALYTICS.md.
class Analytics {
  Analytics(this._repo, this._clock);

  final Repository _repo;
  final DateTime Function() _clock;
  bool enabled = false;

  static final _allowedValue = RegExp(r'^[a-zA-Z0-9_]{0,40}$');

  Future<void> log(String name, [Map<String, Object?> props = const {}]) async {
    assert(Events.all.contains(name), 'Unknown event $name');
    if (!enabled) return;
    final safe = <String, Object?>{};
    props.forEach((k, v) {
      if (v is bool || v is int) {
        safe[k] = v;
      } else if (v is String && _allowedValue.hasMatch(v)) {
        safe[k] = v;
      }
      // Anything else (free text, doubles, maps) is dropped by design.
    });
    await _repo.logEvent(AnalyticsEvent(name, _clock(), safe));
  }
}
