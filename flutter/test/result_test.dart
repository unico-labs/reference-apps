import 'package:flutter_test/flutter_test.dart';

import 'package:unico_reference/result/verdict.dart';

void main() {
  test('PROCESS_RESULT_OK reads Success in green', () {
    expect(verdict({'state': 'PROCESS_STATE_FINISHED', 'result': 'PROCESS_RESULT_OK'}), (
      title: 'Success',
      tone: Tone.ok,
    ));
  });

  test('a definitive negative or an error reads in red, named as the API returns it', () {
    expect(verdict({'result': 'PROCESS_RESULT_INVALID_IDENTITY'}), (title: 'Invalid identity', tone: Tone.bad));
    expect(verdict({'result': 'PROCESS_RESULT_ERROR'}), (title: 'Error', tone: Tone.bad));
  });

  test('an approved or authenticated result reads in green', () {
    expect(verdict({'result': 'PROCESS_RESULT_APPROVED'}), (title: 'Approved', tone: Tone.ok));
    expect(verdict({'result': 'PROCESS_RESULT_AUTHENTICATED'}), (title: 'Authenticated', tone: Tone.ok));
  });

  test('a rejection or a risk reads in red', () {
    for (final result in [
      'PROCESS_RESULT_NOT_APPROVED',
      'PROCESS_RESULT_NOT_LIVE',
      'PROCESS_RESULT_HIGH_RISK',
      'PROCESS_RESULT_CRITICAL_RISK',
      'PROCESS_RESULT_AUTHENTICATED_WITH_HIGH_RISK',
      'PROCESS_RESULT_AUTHENTICATED_WITH_CRITICAL_RISK',
      'PROCESS_RESULT_AUTHENTICATED_WITH_EXTREME_RISK',
    ]) {
      expect(verdict({'result': result}).tone, Tone.bad, reason: result);
    }
  });

  test('an inconclusive or retry result reads in grey', () {
    expect(verdict({'result': 'PROCESS_RESULT_INCONCLUSIVE'}).tone, Tone.neutral);
    expect(verdict({'result': 'PROCESS_RESULT_RETRY'}).tone, Tone.neutral);
  });

  test('any other result reads in grey, and the state stands in when there is no result', () {
    expect(verdict({'result': 'PROCESS_RESULT_EXPIRED'}), (title: 'Expired', tone: Tone.neutral));
    expect(verdict({'state': 'PROCESS_STATE_CREATED'}), (title: 'Created', tone: Tone.neutral));
  });

  test('measures how long the journey took from createdAt to finishedAt', () {
    expect(durationSeconds({'createdAt': '2026-10-19T12:00:00Z', 'finishedAt': '2026-10-19T12:00:38Z'}), 38);
    expect(durationSeconds({'createdAt': '2026-10-19T12:00:00Z'}), isNull);
  });

  test("leaves the duration out when a timestamp doesn't parse", () {
    expect(durationSeconds({'createdAt': 'yesterday', 'finishedAt': '2026-10-19T12:00:38Z'}), isNull);
  });
}
