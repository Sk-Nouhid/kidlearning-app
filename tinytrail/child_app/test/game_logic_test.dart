import 'package:flutter_test/flutter_test.dart';
import 'package:tinytrail_child_app/game_logic.dart';
import 'package:tinytrail_child_app/models.dart';

void main() {
  test('matching state only accepts correct pair indexes once', () {
    final state = MatchingState(2);

    expect(state.pick(left: true, index: 0), MatchOutcome.none);
    expect(state.pick(left: false, index: 1), MatchOutcome.wrong);
    expect(state.selectedLeft, isNull);
    expect(state.selectedRight, isNull);

    expect(state.pick(left: true, index: 0), MatchOutcome.none);
    expect(state.pick(left: false, index: 0), MatchOutcome.matched);
    expect(state.isMatched(0), isTrue);

    expect(state.pick(left: false, index: 0), MatchOutcome.none);
    expect(state.pick(left: true, index: 1), MatchOutcome.none);
    expect(state.pick(left: false, index: 1), MatchOutcome.complete);
    expect(state.isComplete, isTrue);
    expect(state.pick(left: true, index: 0), MatchOutcome.none);
  });

  test('lesson indexes clamp and identify the final step', () {
    expect(clampLessonIndex(0, -1, 26), 0);
    expect(clampLessonIndex(25, 1, 26), 25);
    expect(isLastLessonIndex(25, 26), isTrue);
    expect(isLastLessonIndex(24, 26), isFalse);
    expect(isLastLessonIndex(0, 0), isFalse);
  });

  test('progress keys and scores distinguish built-in from teacher games', () {
    const builtIn = GameBundle(
      game: PublishedGame(
        id: 7,
        title: 'Built in',
        description: '',
        templateId: 0,
        templateName: '',
        templateKey: 'matching',
        updatedAt: '',
      ),
      questions: [],
      fingerprint: '',
      assets: {},
      downloadedAt: '',
    );
    const teacher = GameBundle(
      game: PublishedGame(
        id: 7,
        title: 'Teacher',
        description: '',
        templateId: 1,
        templateName: 'Matching',
        templateKey: 'matching',
        updatedAt: '2026-01-01',
      ),
      questions: [],
      fingerprint: 'abc',
      assets: {},
      downloadedAt: '2026-01-01',
    );

    expect(progressKeyForBundle(builtIn), 'builtin:7');
    expect(progressKeyForBundle(teacher), 'teacher:7');
    expect(fingerprintsDiffer('a', 'b'), isTrue);
    expect(fingerprintsDiffer('a', 'a'), isFalse);
    expect(correctAnswerScore(selected: 'cat', answer: 'cat'), 1);
    expect(correctAnswerScore(selected: 'dog', answer: 'cat'), 0);
  });
}
