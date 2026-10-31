import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart'
    if (dart.library.html) 'database_factory_web.dart'
    as database;
import 'models.dart';

class LocalStoreException implements Exception {
  const LocalStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalStore {
  LocalStore._(this._database);

  factory LocalStore.fromDatabase(Database database) =>
      LocalStore._(database);

  final Database _database;
  static final StoreRef<String, Map<String, Object?>> _records =
      StoreRef<String, Map<String, Object?>>.main();

  static Future<LocalStore> open({
    DatabaseFactory? factory,
    String databaseName = 'tinytrail.db',
  }) async {
    if (factory != null) {
      return LocalStore._(await factory.openDatabase(databaseName));
    }
    return LocalStore._(await database.openTinyTrailDatabase());
  }

  Future<List<GameBundle>> downloadedGames() async {
    final snapshots = await _records.find(_database);
    final games = <GameBundle>[];
    for (final snapshot in snapshots) {
      if (!snapshot.key.startsWith('game:')) continue;
      try {
        games.add(
          GameBundle.fromJson(Map<String, dynamic>.from(snapshot.value)),
        );
      } catch (_) {
        // Ignore one damaged record instead of hiding every saved game.
      }
    }
    games.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return games;
  }

  Future<GameBundle?> downloadedGame(int id) async {
    final record = await _records.record('game:$id').get(_database);
    if (record == null) return null;
    try {
      return GameBundle.fromJson(Map<String, dynamic>.from(record));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDownloadedGame(GameBundle bundle) async {
    try {
      await _records
          .record('game:${bundle.game.id}')
          .put(_database, Map<String, Object?>.from(bundle.toJson()));
    } catch (error) {
      throw const LocalStoreException(
        'This game could not be saved. The device may be out of storage space.',
      );
    }
  }

  Future<void> removeDownloadedGame(int id) async {
    try {
      await _records.record('game:$id').delete(_database);
    } catch (error) {
      throw const LocalStoreException(
        'This download could not be removed. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> progress() async {
    final record = await _records.record('progress').get(_database);
    return record == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(record);
  }

  Future<void> recordLesson(String key) async {
    final current = await progress();
    final lessons = List<String>.from(current['lessons'] as List? ?? const []);
    if (!lessons.contains(key)) lessons.add(key);
    current['lessons'] = lessons;
    try {
      await _records.record('progress').put(_database, current);
    } catch (error) {
      throw const LocalStoreException(
        'Your lesson progress could not be saved on this device.',
      );
    }
  }

  Future<void> recordGame({
    required String key,
    required String title,
    required int score,
    required int total,
    required int questions,
    required int answered,
  }) async {
    final current = await progress();
    final history = List<Map<String, dynamic>>.from(
      (current['games'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    history.insert(0, {
      'key': key,
      'title': title,
      'score': score,
      'total': total,
      'questions': questions,
      'answered': answered,
      'date': DateTime.now().toIso8601String(),
    });
    current['games'] = history.take(100).toList();
    try {
      await _records.record('progress').put(_database, current);
    } catch (error) {
      throw const LocalStoreException(
        'Your game score could not be saved on this device.',
      );
    }
  }

  Future<void> close() => _database.close();

  static String encodeJson(Object value) => jsonEncode(value);

  static bool get isBrowserStorage => kIsWeb;
}
