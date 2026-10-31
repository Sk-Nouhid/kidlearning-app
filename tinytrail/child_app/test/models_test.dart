import 'package:flutter_test/flutter_test.dart';
import 'package:tinytrail_child_app/models.dart';

void main() {
  test('published game prefers saved template key and infers otherwise', () {
    final saved = PublishedGame.fromJson({
      'id': 4,
      'title': 'Saved',
      'template_id': 1,
      'template_name': 'Matching',
      'template_key': 'multiple_choice',
    }, const {});
    expect(saved.templateKey, 'multiple_choice');

    final inferred = PublishedGame.fromJson({
      'id': 5,
      'title': 'Inferred',
      'template_id': 2,
      'template_name': 'Multiple Choice',
    }, const {});
    expect(inferred.templateKey, 'multiple_choice');

    final mapped = PublishedGame.fromJson({
      'id': 6,
      'title': 'Mapped',
      'template_id': 3,
      'template_name': 'Unknown',
    }, const {3: 'matching'});
    expect(mapped.templateKey, 'matching');
  });

  test('game bundle round trip preserves questions, assets and fingerprint', () {
    const bundle = GameBundle(
      game: PublishedGame(
        id: 9,
        title: 'Round trip',
        description: 'Test',
        templateId: 1,
        templateName: 'Matching',
        templateKey: 'matching',
        updatedAt: '2026-01-01',
      ),
      questions: [
        GameQuestion(
          id: 'q1',
          prompt: 'Match',
          data: {
            'type': 'matching',
            'pairs': [
              {'left': 'cat', 'right': 'meow'},
            ],
          },
          sortOrder: 1,
        ),
      ],
      fingerprint: 'abc',
      assets: {'/uploads/cat.png': 'data:image/png;base64,AA=='},
      downloadedAt: '2026-01-01T00:00:00.000',
    );

    final restored = GameBundle.fromJson(bundle.toJson());
    expect(restored.game.title, 'Round trip');
    expect(restored.game.templateKey, 'matching');
    expect(restored.questions.single.type, 'matching');
    expect(restored.assets['/uploads/cat.png'], startsWith('data:image/png'));
    expect(restored.fingerprint, 'abc');
  });

  test('supported questions and possible points count matching pairs', () {
    const questions = [
      GameQuestion(
        id: 'q1',
        prompt: 'Match',
        data: {
          'type': 'matching',
          'pairs': [
            {'left': 'a', 'right': '1'},
            {'left': 'b', 'right': '2'},
          ],
        },
        sortOrder: 1,
      ),
      GameQuestion(
        id: 'q2',
        prompt: 'Choice',
        data: {
          'type': 'multiple_choice',
          'options': ['a', 'b'],
          'answer': 'a',
        },
        sortOrder: 2,
      ),
      GameQuestion(
        id: 'q3',
        prompt: 'Unsupported',
        data: {'type': 'drawing'},
        sortOrder: 3,
      ),
    ];

    expect(isSupportedQuestion(questions[0]), isTrue);
    expect(isSupportedQuestion(questions[1]), isTrue);
    expect(isSupportedQuestion(questions[2]), isFalse);
    expect(possiblePoints(questions), 3);
  });
}
