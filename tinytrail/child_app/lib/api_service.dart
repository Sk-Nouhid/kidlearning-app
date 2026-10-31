import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Uri get _base => Uri.parse(apiBaseUrl);

  Uri resolveMedia(String value) => value.startsWith('http')
      ? Uri.parse(value)
      : _base.resolve(value.startsWith('/') ? value : '/$value');

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw ApiException(
        'Could not reach TinyTrail at $apiBaseUrl. Check that the server is running.',
      );
    } catch (error) {
      if (error is ApiException || error is DownloadCancelled) rethrow;
      throw ApiException(
        'Could not reach TinyTrail at $apiBaseUrl. Check your connection.',
      );
    }
  }

  Future<JsonMap> _get(String path) async {
    final response = await _send(() => _client.get(_base.resolve(path)));
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['message']?.toString() ?? 'The server could not be reached.',
      );
    }
    return body;
  }

  JsonMap _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // The backend may return a plain-text error for unexpected failures.
    }
    return {'message': 'The server returned an unexpected response.'};
  }

  Future<List<PublishedGame>> publishedGames() async {
    final gamesResponse = await _get('/api/games/published');

    final templateKeys = <int, String>{};
    try {
      final templates = await _get('/api/templates');
      for (final value in templates['templates'] as List? ?? const []) {
        if (value is Map) {
          final item = Map<String, dynamic>.from(value);
          templateKeys[parseId(item['id'])] =
              item['template_key']?.toString() ?? '';
        }
      }
    } catch (_) {
      // The template list is only used to name game types. Published games can
      // still be shown by inferring the type from their template name.
    }

    return (gamesResponse['games'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => PublishedGame.fromJson(
            Map<String, dynamic>.from(item),
            templateKeys,
          ),
        )
        .where(
          (game) =>
              game.id > 0 &&
              (game.templateKey == 'matching' ||
                  game.templateKey == 'multiple_choice'),
        )
        .toList();
  }

  Future<GameSnapshot> fetchSnapshot(PublishedGame game) async {
    final payload = await _fetchQuestionData(game);
    return GameSnapshot(
      game: game,
      questions: payload.questions,
      fingerprint: payload.fingerprint,
    );
  }

  Future<GameBundle> fetchBundle(
    PublishedGame game, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) throw const DownloadCancelled();
    final payload = await _fetchQuestionData(game);
    final urls = <String>{};
    for (final question in payload.questions) {
      _collectImageUrls(question.data, urls);
    }

    final assets = <String, String>{};
    var done = 0;
    onProgress?.call(done, urls.length);
    for (final value in urls) {
      if (isCancelled?.call() ?? false) throw const DownloadCancelled();
      final response = await _send(
        () => _client.get(resolveMedia(value)),
        timeout: const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ApiException(
          'An image needed by this game could not be saved.',
        );
      }
      final mime =
          response.headers['content-type']?.split(';').first ?? 'image/png';
      assets[value] = 'data:$mime;base64,${base64Encode(response.bodyBytes)}';
      done++;
      onProgress?.call(done, urls.length);
    }
    if (isCancelled?.call() ?? false) throw const DownloadCancelled();

    final localQuestions = payload.questions
        .map(
          (question) => GameQuestion(
            id: question.id,
            prompt: question.prompt,
            sortOrder: question.sortOrder,
            data: _replaceImageUrls(question.data, assets),
          ),
        )
        .toList();
    return GameBundle(
      game: game,
      questions: localQuestions,
      fingerprint: payload.fingerprint,
      assets: assets,
      downloadedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<_QuestionData> _fetchQuestionData(PublishedGame game) async {
    final response = await _get('/api/games/${game.id}/questions');
    final rawQuestions = (response['questions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final questions = rawQuestions
        .map(GameQuestion.fromJson)
        .where(isSupportedQuestion)
        .toList();
    if (questions.isEmpty) {
      throw const ApiException(
        'This game has no supported Matching or Multiple Choice questions yet.',
      );
    }

    final fingerprintSource = jsonEncode({
      'game': game.toJson(),
      'questions': rawQuestions,
    });
    return _QuestionData(
      questions: questions,
      fingerprint: sha256
          .convert(utf8.encode(fingerprintSource))
          .toString(),
    );
  }

  void _collectImageUrls(Object? value, Set<String> urls, [String key = '']) {
    if (value is Map) {
      for (final entry in value.entries) {
        _collectImageUrls(entry.value, urls, entry.key.toString());
      }
    } else if (value is List) {
      for (final item in value) {
        _collectImageUrls(item, urls, key);
      }
    } else if (value is String &&
        (key.toLowerCase().contains('image') ||
            key.toLowerCase().contains('photo')) &&
        (value.startsWith('/uploads/') ||
            value.startsWith('http://') ||
            value.startsWith('https://'))) {
      urls.add(value);
    }
  }

  dynamic _replaceImageUrls(dynamic value, Map<String, String> assets) {
    if (value is Map) {
      return value.map(
        (key, item) =>
            MapEntry(key.toString(), _replaceImageUrls(item, assets)),
      );
    }
    if (value is List) {
      return value.map((item) => _replaceImageUrls(item, assets)).toList();
    }
    if (value is String) {
      return assets[value] ?? value;
    }
    return value;
  }
}

class _QuestionData {
  const _QuestionData({required this.questions, required this.fingerprint});

  final List<GameQuestion> questions;
  final String fingerprint;
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}
