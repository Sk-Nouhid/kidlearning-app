import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tinytrail_child_app/api_service.dart';
import 'package:tinytrail_child_app/models.dart';

http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

PublishedGame game({int id = 4}) => PublishedGame(
  id: id,
  title: 'Match the Animals',
  description: 'Demo',
  templateId: 1,
  templateName: 'Matching',
  templateKey: 'matching',
  updatedAt: '2026-01-01',
);

void main() {
  test('published games use template keys and ignore unsupported types', () async {
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path == '/api/games/published') {
          return jsonResponse({
            'games': [
              {
                'id': 4,
                'title': 'Match the Animals',
                'template_id': 1,
                'template_name': 'Matching',
              },
              {
                'id': 6,
                'title': 'Voice drawing',
                'template_id': 3,
                'template_name': 'Voice to Drawing',
              },
            ],
          });
        }
        if (request.url.path == '/api/templates') {
          return jsonResponse({
            'templates': [
              {'id': 1, 'template_key': 'matching'},
              {'id': 3, 'template_key': 'voice_to_drawing'},
            ],
          });
        }
        return jsonResponse({'message': 'Unexpected path'}, status: 404);
      }),
    );

    final games = await api.publishedGames();
    expect(games, hasLength(1));
    expect(games.single.id, 4);
    expect(games.single.templateKey, 'matching');
  });

  test('fetchBundle embeds images as data URLs and supports cancellation', () async {
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path == '/api/games/4/questions') {
          return jsonResponse({
            'questions': [
              {
                'id': 1,
                'prompt': 'Which picture shows a cat?',
                'question_data': {
                  'type': 'multiple_choice',
                  'options': ['Cat', 'Dog'],
                  'answer': 'Cat',
                  'image': '/uploads/cat.png',
                },
                'sort_order': 1,
              },
            ],
          });
        }
        if (request.url.path == '/uploads/cat.png') {
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: const {'content-type': 'image/png'},
          );
        }
        return jsonResponse({'message': 'Unexpected path'}, status: 404);
      }),
    );

    final bundle = await api.fetchBundle(game());
    expect(bundle.questions, hasLength(1));
    expect(
      bundle.assets['/uploads/cat.png'],
      startsWith('data:image/png;base64,'),
    );
    expect(
      bundle.questions.single.data['image'],
      startsWith('data:image/png;base64,'),
    );

    await expectLater(
      api.fetchBundle(game(), isCancelled: () => true),
      throwsA(isA<DownloadCancelled>()),
    );
  });

  test('server and network failures become readable ApiExceptions', () async {
    final serverError = ApiService(
      client: MockClient(
        (request) async =>
            jsonResponse({'message': 'Game not found'}, status: 404),
      ),
    );
    await expectLater(
      serverError.fetchSnapshot(game()),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Game not found',
        ),
      ),
    );

    final offline = ApiService(
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );
    await expectLater(
      offline.fetchSnapshot(game()),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Could not reach TinyTrail'),
        ),
      ),
    );
  });
}
