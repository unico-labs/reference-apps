import 'package:flutter_test/flutter_test.dart';

import '../result/verdict.dart';

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
