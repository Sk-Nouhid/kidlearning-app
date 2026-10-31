import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tinytrail_child_app/local_store.dart';
import 'package:tinytrail_child_app/models.dart';

void main() {
  late Database database;
  late LocalStore store;
  var counter = 0;

  setUp(() async {
    counter++;
    database = await databaseFactoryMemory.openDatabase('store-$counter.db');
    store = LocalStore.fromDatabase(database);
  });

  tearDown(() => store.close());

  GameBundle bundle(int id, String title, String downloadedAt) => GameBundle(
    game: PublishedGame(
      id: id,
      title: title,
      description: '',
      templateId: 1,
      templateName: 'Matching',
      templateKey: 'matching',
      updatedAt: '2026-01-01',
    ),
    questions: const [],
    fingerprint: 'fp-$id',
    assets: const {},
    downloadedAt: downloadedAt,
  );

  test('saved games round trip and sort newest first', () async {
    await store.saveDownloadedGame(bundle(1, 'Older', '2026-01-01'));
    await store.saveDownloadedGame(bundle(2, 'Newer', '2026-02-01'));

    final games = await store.downloadedGames();
    expect(games.map((item) => item.game.id), [2, 1]);
    expect((await store.downloadedGame(1))?.game.title, 'Older');
    expect(await store.downloadedGame(3), isNull);
  });

  test('one damaged record does not hide valid downloads', () async {
    await store.saveDownloadedGame(bundle(1, 'Good', '2026-01-01'));
    await StoreRef<String, Map<String, Object?>>.main()
        .record('game:2')
        .put(database, {'broken': true});

    final games = await store.downloadedGames();
    expect(games, hasLength(1));
    expect(games.single.game.title, 'Good');
  });

  test('lessons de-duplicate and game history records counts', () async {
    await store.recordLesson('alphabet:A');
    await store.recordLesson('alphabet:A');
    await store.recordGame(
      key: 'teacher:4',
      title: 'Match the Animals',
      score: 3,
      total: 4,
      questions: 4,
      answered: 4,
    );

    final progress = await store.progress();
    expect(progress['lessons'], ['alphabet:A']);
    final games = List<Map<String, dynamic>>.from(progress['games'] as List);
    expect(games.single['title'], 'Match the Animals');
    expect(games.single['questions'], 4);
    expect(games.single['answered'], 4);
  });

  test('removing a download leaves progress intact', () async {
    await store.saveDownloadedGame(bundle(5, 'Temporary', '2026-01-01'));
    await store.recordLesson('number:5');
    await store.removeDownloadedGame(5);

    expect(await store.downloadedGame(5), isNull);
    expect((await store.progress())['lessons'], ['number:5']);
  });
}
