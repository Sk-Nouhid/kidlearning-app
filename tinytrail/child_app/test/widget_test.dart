import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tinytrail_child_app/local_store.dart';
import 'package:tinytrail_child_app/main.dart';

void main() {
  Future<LocalStore> openStore() => LocalStore.open(
    factory: databaseFactoryMemory,
    databaseName: 'widget-${DateTime.now().microsecondsSinceEpoch}.db',
  );

  Future<void> pumpApp(WidgetTester tester, LocalStore store) async {
    await tester.pumpWidget(
      TinyTrailApp(
        store: store,
        connectivityStream: const Stream<List<ConnectivityResult>>.empty(),
        onlineCheck: () async => false,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Welcome opens the child home screen', (tester) async {
    final store = await openStore();
    addTearDown(store.close);
    await pumpApp(tester, store);

    expect(find.text('Start Learning'), findsOneWidget);
    await tester.tap(find.text('Start Learning'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, little explorer!'), findsOneWidget);
  });

  testWidgets('A letter lesson shows both cases and a narrow trace card', (
    tester,
  ) async {
    final store = await openStore();
    addTearDown(store.close);
    await pumpApp(tester, store);

    await tester.tap(find.text('Start Learning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore lessons'));
    await tester.pumpAndSettle();
    expect(find.text('Learning trails'), findsOneWidget);

    await tester.tap(find.text('A').first);
    await tester.pumpAndSettle();

    expect(find.text('Trace the uppercase A'), findsOneWidget);
    expect(find.text('Uppercase'), findsOneWidget);
    expect(find.text('Lowercase'), findsOneWidget);
  });

  testWidgets('Progress screen shows lesson and question counts', (
    tester,
  ) async {
    final store = await openStore();
    addTearDown(store.close);
    await tester.runAsync(() async {
      await store.recordLesson('alphabet:A');
      await store.recordGame(
        key: 'builtin:1',
        title: 'Animal quiz',
        score: 2,
        total: 3,
        questions: 3,
        answered: 3,
      );
    });
    await pumpApp(tester, store);

    await tester.tap(find.text('Start Learning'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Progress'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My progress'), findsOneWidget);
    expect(find.text('Questions answered'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Animal quiz'), findsOneWidget);
  });
}
