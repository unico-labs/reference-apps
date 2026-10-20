// The heading of the result screen. It only names the result the API returned, in words:
// https://developer.unico.io/developers/api-reference/get-process. The JSON on screen stays as returned.

enum Tone { ok, bad, neutral }

String? short(Object? value) =>
    (value as String?)?.replaceFirst('PROCESS_RESULT_', '').replaceFirst('PROCESS_STATE_', '');

// The result values per flow: https://developer.unico.io/developers/start/flows
const _ok = {'APPROVED', 'AUTHENTICATED'};
const _bad = {
  'INVALID_IDENTITY',
  'ERROR',
  'NOT_APPROVED',
  'NOT_LIVE',
  'HIGH_RISK',
  'CRITICAL_RISK',
  'AUTHENTICATED_WITH_HIGH_RISK',
  'AUTHENTICATED_WITH_CRITICAL_RISK',
  'AUTHENTICATED_WITH_EXTREME_RISK',
};

// PROCESS_RESULT_OK reads "Success" in green, an approval in green, a rejection, a risk or an error in red,
// anything else in grey.
({String title, Tone tone}) verdict(Map<String, dynamic> process) {
  final result = short(process['result']);
  if (result == 'OK') return (title: 'Success', tone: Tone.ok);
  final tone = _ok.contains(result) ? Tone.ok : (_bad.contains(result) ? Tone.bad : Tone.neutral);
  final words = (result ?? short(process['state']) ?? '').replaceAll('_', ' ').toLowerCase();
  return (title: words.isEmpty ? 'Result' : words[0].toUpperCase() + words.substring(1), tone: tone);
}

// A timestamp that doesn't parse leaves the duration out.
int? durationSeconds(Map<String, dynamic> process) {
  final created = DateTime.tryParse(process['createdAt'] as String? ?? '');
  final finished = DateTime.tryParse(process['finishedAt'] as String? ?? '');
  if (created == null || finished == null) return null;
  return finished.difference(created).inSeconds;
}
