typedef JsonMap = Map<String, dynamic>;

int parseId(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class PublishedGame {
  const PublishedGame({
    required this.id,
    required this.title,
    required this.description,
    required this.templateId,
    required this.templateName,
    required this.templateKey,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final int templateId;
  final String templateName;
  final String templateKey;
  final String updatedAt;

  factory PublishedGame.fromJson(JsonMap json, Map<int, String> templateKeys) {
    final templateId = parseId(json['template_id']);
    final templateName = json['template_name']?.toString() ?? '';
    final inferredKey = templateName.toLowerCase().contains('match')
        ? 'matching'
        : templateName.toLowerCase().contains('choice')
        ? 'multiple_choice'
        : '';
    final savedKey = json['template_key']?.toString() ?? '';
    return PublishedGame(
      id: parseId(json['id']),
      title: json['title']?.toString() ?? 'Untitled game',
      description: json['description']?.toString() ?? '',
      templateId: templateId,
      templateName: templateName,
      templateKey: savedKey.isNotEmpty
          ? savedKey
          : templateKeys[templateId] ?? inferredKey,
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'template_id': templateId,
    'template_name': templateName,
    'template_key': templateKey,
    'updated_at': updatedAt,
  };
}

class GameQuestion {
  const GameQuestion({
    required this.id,
    required this.prompt,
    required this.data,
    required this.sortOrder,
  });

  final String id;
  final String prompt;
  final JsonMap data;
  final int sortOrder;
  String get type => data['type']?.toString() ?? '';

  factory GameQuestion.fromJson(JsonMap json) => GameQuestion(
    id: json['id']?.toString() ?? '',
    prompt: json['prompt']?.toString() ?? '',
    data: json['question_data'] is Map
        ? Map<String, dynamic>.from(json['question_data'] as Map)
        : <String, dynamic>{},
    sortOrder: parseId(json['sort_order']),
  );

  JsonMap toJson() => {
    'id': id,
    'prompt': prompt,
    'question_data': data,
    'sort_order': sortOrder,
  };
}

class GameBundle {
  const GameBundle({
    required this.game,
    required this.questions,
    required this.fingerprint,
    required this.assets,
    required this.downloadedAt,
  });

  final PublishedGame game;
  final List<GameQuestion> questions;
  final String fingerprint;
  final Map<String, String> assets;
  final String downloadedAt;

  JsonMap toJson() => {
    'game': game.toJson(),
    'questions': questions.map((question) => question.toJson()).toList(),
    'fingerprint': fingerprint,
    'assets': assets,
    'downloaded_at': downloadedAt,
  };

  factory GameBundle.fromJson(JsonMap json) => GameBundle(
    game: PublishedGame.fromJson(
      Map<String, dynamic>.from(json['game'] as Map),
      const {},
    ),
    questions: (json['questions'] as List)
        .map(
          (item) =>
              GameQuestion.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    fingerprint: json['fingerprint']?.toString() ?? '',
    assets: Map<String, String>.from(json['assets'] as Map? ?? const {}),
    downloadedAt: json['downloaded_at']?.toString() ?? '',
  );
}

class GameSnapshot {
  const GameSnapshot({
    required this.game,
    required this.questions,
    required this.fingerprint,
  });

  final PublishedGame game;
  final List<GameQuestion> questions;
  final String fingerprint;
}

bool isSupportedQuestion(GameQuestion question) =>
    question.type == 'matching' || question.type == 'multiple_choice';

int possiblePoints(List<GameQuestion> questions) => questions.fold<int>(0, (
  total,
  question,
) {
  if (question.type == 'matching') {
    return total + (question.data['pairs'] as List? ?? const []).length;
  }
  if (question.type == 'multiple_choice') return total + 1;
  return total;
});
