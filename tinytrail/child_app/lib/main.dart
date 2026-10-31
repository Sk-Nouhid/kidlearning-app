import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'config.dart';
import 'game_logic.dart';
import 'local_store.dart';
import 'models.dart';
import 'tracing.dart';

const _ink = Color(0xff28445c);
const _blue = Color(0xff6aa9dc);
const _cream = Color(0xfffffbf3);
const _mint = Color(0xffdff2e7);
const _coral = Color(0xffffd6c8);
const _lavender = Color(0xffe9e3fa);

void main() => runApp(const TinyTrailApp());

class TinyTrailApp extends StatelessWidget {
  const TinyTrailApp({
    super.key,
    this.api,
    this.store,
    this.connectivityStream,
    this.onlineCheck,
  });

  final ApiService? api;
  final LocalStore? store;
  final Stream<List<ConnectivityResult>>? connectivityStream;
  final Future<bool> Function()? onlineCheck;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TinyTrail',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _cream,
      colorScheme: ColorScheme.fromSeed(seedColor: _blue).copyWith(
        primary: _blue,
        secondary: const Color(0xffef9578),
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: _ink, height: 1.45),
        bodyMedium: TextStyle(color: Color(0xff617385), height: 1.4),
      ),
    ),
    home: TinyTrailShell(
      api: api,
      store: store,
      connectivityStream: connectivityStream,
      onlineCheck: onlineCheck,
    ),
  );
}

enum ChildScreen { welcome, home, learn, lesson, games, game, progress }

enum LessonKind { alphabet, number }

class TinyTrailShell extends StatefulWidget {
  const TinyTrailShell({
    super.key,
    this.api,
    this.store,
    this.connectivityStream,
    this.onlineCheck,
  });

  final ApiService? api;
  final LocalStore? store;
  final Stream<List<ConnectivityResult>>? connectivityStream;
  final Future<bool> Function()? onlineCheck;

  @override
  State<TinyTrailShell> createState() => _TinyTrailShellState();
}

class _TinyTrailShellState extends State<TinyTrailShell> {
  late final ApiService _api = widget.api ?? ApiService();
  LocalStore? _store;
  bool _ownsStore = false;
  ChildScreen _screen = ChildScreen.welcome;
  LessonKind _lessonKind = LessonKind.alphabet;
  int _lessonIndex = 0;
  bool _lessonPassed = false;
  String _lessonMessage = 'Follow the dotted trail with your finger.';
  List<TraceStroke> _drawn = [];
  Size _traceSize = Size.zero;
  bool _loadingStore = true;
  bool _loadingGames = false;
  String? _gamesError;
  List<PublishedGame> _published = [];
  List<GameBundle> _downloads = [];
  Map<String, dynamic> _progress = {};
  final Set<int> _updatesAvailable = {};
  final Map<int, String> _downloadStatus = {};
  final Set<int> _cancelDownloads = {};
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;

  GameBundle? _playing;
  bool _isPlayingOffline = false;
  int _questionIndex = 0;
  int _score = 0;
  bool _answered = false;
  String _feedback = '';
  bool _correctFeedback = false;
  MatchingState? _matchingState;
  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _initialize();
    try {
      final stream =
          widget.connectivityStream ?? Connectivity().onConnectivityChanged;
      _connectivitySub = stream.listen((results) {
        final online = results.any(
          (result) => result != ConnectivityResult.none,
        );
        if (!mounted) return;
        setState(() => _isOnline = online);
        if (online) unawaited(_loadPublishedGames());
      });
    } catch (_) {
      // The app still works with saved content when connectivity is unknown.
    }
  }

  Future<bool> _readOnline() async {
    if (widget.onlineCheck != null) return widget.onlineCheck!();
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<void> _initialize() async {
    try {
      final store = widget.store ?? await LocalStore.open();
      final results = await Future.wait([
        store.downloadedGames(),
        store.progress(),
      ]);
      final online = await _readOnline();
      if (!mounted) return;
      setState(() {
        _store = store;
        _ownsStore = widget.store == null;
        _downloads = results[0] as List<GameBundle>;
        _progress = results[1] as Map<String, dynamic>;
        _isOnline = online;
        _loadingStore = false;
      });
      if (online) unawaited(_loadPublishedGames());
    } on LocalStoreException catch (error) {
      final online = await _readOnline();
      if (!mounted) return;
      setState(() {
        _loadingStore = false;
        _isOnline = online;
        _gamesError = error.message;
      });
      if (online) unawaited(_loadPublishedGames());
    } catch (error) {
      final online = await _readOnline();
      if (!mounted) return;
      setState(() {
        _loadingStore = false;
        _isOnline = online;
        _gamesError =
            'Local storage is unavailable. Progress and downloads cannot be saved on this device.';
      });
      if (online) unawaited(_loadPublishedGames());
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    if (_ownsStore) _store?.close();
    super.dispose();
  }

  Future<void> _loadPublishedGames() async {
    if (!_isOnline) {
      if (mounted) setState(() => _loadingGames = false);
      return;
    }
    setState(() {
      _loadingGames = true;
      _gamesError = null;
    });
    try {
      final games = await _api.publishedGames();
      if (!mounted) return;
      setState(() {
        _published = games;
        _loadingGames = false;
      });
      await _checkDownloadedUpdates();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingGames = false;
        _gamesError = error.toString();
      });
    }
  }

  Future<void> _checkDownloadedUpdates() async {
    final store = _store;
    if (store == null || !_isOnline) return;
    final publishedById = {for (final game in _published) game.id: game};
    for (final download in _downloads) {
      final latest = publishedById[download.game.id];
      if (latest == null) continue;
      try {
        final current = await _api.fetchSnapshot(latest);
        if (!mounted) return;
        setState(() {
          if (fingerprintsDiffer(download.fingerprint, current.fingerprint)) {
            _updatesAvailable.add(latest.id);
          } else {
            _updatesAvailable.remove(latest.id);
          }
        });
      } catch (_) {
        // A temporary network failure never invalidates the last complete copy.
      }
    }
  }

  Future<void> _downloadGame(PublishedGame game) async {
    final store = _store;
    if (store == null) {
      _toast('Downloads are unavailable because local storage could not open.');
      return;
    }
    setState(() {
      _downloadStatus[game.id] = 'Preparing game…';
      _cancelDownloads.remove(game.id);
    });
    try {
      final bundle = await _api.fetchBundle(
        game,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _downloadStatus[game.id] = total == 0
                ? 'Saving game…'
                : 'Saving pictures $done of $total…';
          });
        },
        isCancelled: () => _cancelDownloads.contains(game.id),
      );
      if (_cancelDownloads.contains(game.id)) throw const DownloadCancelled();
      await store.saveDownloadedGame(bundle);
      final fresh = await store.downloadedGames();
      if (!mounted) return;
      setState(() {
        _downloads = fresh;
        _updatesAvailable.remove(game.id);
        _downloadStatus.remove(game.id);
      });
      _toast('Saved for an offline adventure!');
    } on DownloadCancelled {
      if (!mounted) return;
      setState(() => _downloadStatus.remove(game.id));
      _toast('Download cancelled.');
    } on LocalStoreException catch (error) {
      if (!mounted) return;
      setState(() => _downloadStatus[game.id] = 'Could not save. Tap Retry.');
      _toast(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _downloadStatus[game.id] = 'Could not save. Tap Retry.');
      _toast(error.toString());
    }
  }

  Future<void> _removeDownload(GameBundle bundle) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove offline game?'),
            content: Text(
              '“${bundle.game.title}” will be removed from this device. Your scores and learning progress will stay. (If offline, the game stays in this screen until you reconnect.)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep it'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await _store?.removeDownloadedGame(bundle.game.id);
    } on LocalStoreException catch (error) {
      if (mounted) _toast(error.message);
      return;
    }
    if (!mounted) return;
    setState(() {
      _downloads.removeWhere((item) => item.game.id == bundle.game.id);
      _updatesAvailable.remove(bundle.game.id);
    });
  }

  void _openLesson(LessonKind kind, int index) {
    setState(() {
      _lessonKind = kind;
      _lessonIndex = index;
      _lessonPassed = false;
      _lessonMessage = 'Follow the dotted trail with your finger.';
      _drawn = [];
      _screen = ChildScreen.lesson;
    });
  }

  String get _currentGlyph => _lessonKind == LessonKind.alphabet
      ? String.fromCharCode(65 + _lessonIndex)
      : (_lessonIndex + 1).toString();

  String get _lessonKey => '${_lessonKind.name}:$_currentGlyph';

  Future<void> _finishTrace() async {
    final ratio = traceCoverage(tracePaths(_currentGlyph), _drawn);
    final passed = ratio >= .58;
    setState(() {
      _lessonPassed = passed;
      _lessonMessage = passed
          ? 'Wonderful tracing! You did it!'
          : 'Stay close to the dotted trail. Try that one more time!';
    });
    if (!passed) return;
    try {
      await _store?.recordLesson(_lessonKey);
      await _refreshProgress();
    } on LocalStoreException catch (error) {
      if (mounted) _toast(error.message);
    }
  }

  Future<void> _refreshProgress() async {
    final value = await _store?.progress();
    if (mounted && value != null) setState(() => _progress = value);
  }

  int get _lessonLength => _lessonKind == LessonKind.alphabet ? 26 : 20;

  bool get _isLastLesson => isLastLessonIndex(_lessonIndex, _lessonLength);

  void _advanceLesson(int direction) {
    if (direction > 0 && _isLastLesson) {
      if (!_lessonPassed) {
        _toast('Trace this last one before finishing the trail!');
        return;
      }
      setState(() => _screen = ChildScreen.learn);
      _toast(
        'You finished the ${_lessonKind == LessonKind.alphabet ? 'alphabet' : 'number'} trail!',
      );
      return;
    }
    _openLesson(
      _lessonKind,
      clampLessonIndex(_lessonIndex, direction, _lessonLength),
    );
  }

  Future<void> _openTeacherPortal() async {
    final uri = Uri.parse(teacherPortalUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _toast('Could not open the teacher portal.');
    }
  }

  void _startGame(GameBundle bundle, {required bool offline}) {
    final questions = bundle.questions.where(isSupportedQuestion).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (questions.isEmpty) {
      _toast('This game has no playable questions yet.');
      return;
    }
    setState(() {
      _playing = GameBundle(
        game: bundle.game,
        questions: questions,
        fingerprint: bundle.fingerprint,
        assets: bundle.assets,
        downloadedAt: bundle.downloadedAt,
      );
      _isPlayingOffline = offline;
      _questionIndex = 0;
      _score = 0;
      _answered = false;
      _feedback = '';
      _correctFeedback = false;
      _matchingState = MatchingState(_pairCount(questions.first));
      _screen = ChildScreen.game;
    });
  }

  int _pairCount(GameQuestion? question) =>
      (question?.data['pairs'] as List? ?? const []).length;

  void _prepareMatching() {
    _matchingState = MatchingState(_pairCount(_currentQuestionOrNull));
  }

  GameQuestion? get _currentQuestionOrNull {
    final questions = _playing?.questions ?? const <GameQuestion>[];
    return _questionIndex < questions.length ? questions[_questionIndex] : null;
  }

  bool get _gameComplete =>
      _playing != null && _questionIndex >= _playing!.questions.length;

  int get _gameTotal => possiblePoints(_playing?.questions ?? const []);

  void _answerChoice(String choice) {
    if (_answered) return;
    final question = _currentQuestionOrNull;
    if (question == null) return;
    final correct =
        correctAnswerScore(
          selected: choice,
          answer: question.data['answer']?.toString() ?? '',
        ) ==
        1;
    setState(() {
      _answered = true;
      _correctFeedback = correct;
      _feedback = correct
          ? 'That’s right! Great thinking!'
          : 'Good try! The answer is ${question.data['answer']}.';
      if (correct) _score++;
    });
  }

  void _selectPairItem({required bool left, required int index}) {
    final state = _matchingState;
    if (_answered || state == null) return;
    setState(() {
      final outcome = state.pick(left: left, index: index);
      switch (outcome) {
        case MatchOutcome.matched:
          _score++;
          _feedback = 'A perfect pair!';
          _correctFeedback = true;
        case MatchOutcome.complete:
          _score++;
          _answered = true;
          _feedback = 'You matched them all!';
          _correctFeedback = true;
        case MatchOutcome.wrong:
          _feedback = 'Not quite. Give it another try!';
          _correctFeedback = false;
        case MatchOutcome.none:
          break;
      }
    });
  }

  void _nextQuestion() {
    if (_playing == null) return;
    setState(() {
      _questionIndex++;
      _answered = false;
      _feedback = '';
      _correctFeedback = false;
      _prepareMatching();
    });
    if (_gameComplete) _saveGameScore();
  }

  Future<void> _saveGameScore() async {
    final game = _playing;
    if (game == null) return;
    final answered = _gameComplete
        ? game.questions.length
        : _questionIndex + (_answered ? 1 : 0);
    try {
      await _store?.recordGame(
        key: progressKeyForBundle(game),
        title: game.game.title,
        score: _score,
        total: _gameTotal,
        questions: game.questions.length,
        answered: answered,
      );
      await _refreshProgress();
    } on LocalStoreException catch (error) {
      if (mounted) _toast(error.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStore) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final width = MediaQuery.sizeOf(context).width;
    final desktop =
        width >= 880 &&
        _screen != ChildScreen.welcome &&
        _screen != ChildScreen.lesson &&
        _screen != ChildScreen.game;
    return Scaffold(
      body: SafeArea(
        child: _screen == ChildScreen.welcome
            ? _welcome()
            : desktop
            ? Row(
                children: [
                  SizedBox(width: 232, child: _sideNavigation()),
                  Expanded(child: _page()),
                ],
              )
            : _page(),
      ),
      bottomNavigationBar: !desktop && _hasMainNavigation
          ? NavigationBar(
              selectedIndex: _navigationIndex,
              onDestinationSelected: (index) => _navigateTo(index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_rounded),
                  label: 'Learn',
                ),
                NavigationDestination(
                  icon: Icon(Icons.videogame_asset_rounded),
                  label: 'Games',
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events_rounded),
                  label: 'Progress',
                ),
              ],
            )
          : null,
    );
  }

  bool get _hasMainNavigation =>
      _screen == ChildScreen.home ||
      _screen == ChildScreen.learn ||
      _screen == ChildScreen.games ||
      _screen == ChildScreen.progress;

  int get _navigationIndex => switch (_screen) {
    ChildScreen.learn || ChildScreen.lesson => 1,
    ChildScreen.games || ChildScreen.game => 2,
    ChildScreen.progress => 3,
    _ => 0,
  };

  void _navigateTo(int index) => setState(() {
    _screen = switch (index) {
      1 => ChildScreen.learn,
      2 => ChildScreen.games,
      3 => ChildScreen.progress,
      _ => ChildScreen.home,
    };
  });

  Widget _page() => switch (_screen) {
    ChildScreen.home => _homePage(),
    ChildScreen.learn => _learnPage(),
    ChildScreen.lesson => _lessonPage(),
    ChildScreen.games => _gamesPage(),
    ChildScreen.game => _gamePage(),
    ChildScreen.progress => _progressPage(),
    ChildScreen.welcome => _welcome(),
  };

  Widget _welcome() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth > 720;
      return Stack(
        children: [
          Positioned(top: -70, left: -35, child: _bubble(230, _mint)),
          Positioned(right: -60, bottom: -85, child: _bubble(260, _lavender)),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: TextButton.icon(
                onPressed: _openTeacherPortal,
                icon: const Icon(Icons.lock_outline_rounded, size: 17),
                label: const Text('Teacher Login'),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 70, 28, 36),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: _welcomeCopy()),
                          const SizedBox(width: 30),
                          _mascotHero(),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _mascotHero(compact: true),
                          _welcomeCopy(compact: true),
                        ],
                      ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _welcomeCopy({bool compact = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _brandMark(58),
          const SizedBox(width: 13),
          const Text(
            'TinyTrail',
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: _ink,
              letterSpacing: -.8,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        'Little Steps,\nBig Dreams',
        textAlign: compact ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontSize: compact ? 38 : 54,
          fontWeight: FontWeight.w900,
          height: 1.05,
          color: _ink,
          letterSpacing: -1.8,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'A happy little place to learn, play, and grow.',
        textAlign: compact ? TextAlign.center : TextAlign.left,
        style: const TextStyle(fontSize: 17, color: Color(0xff6b7d8e)),
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: () => setState(() => _screen = ChildScreen.home),
        icon: const Icon(Icons.play_arrow_rounded, size: 26),
        label: const Text('Start Learning'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xffee977c),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 18),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _mascotHero({bool compact = false}) => Container(
    width: compact ? 170 : 310,
    height: compact ? 170 : 310,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xffffead7),
      boxShadow: [
        BoxShadow(
          color: const Color(0xffd7c6ac).withValues(alpha: .22),
          blurRadius: 32,
          offset: const Offset(0, 18),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text('🦊', style: TextStyle(fontSize: compact ? 100 : 188)),
        Positioned(
          top: compact ? 8 : 20,
          right: compact ? 6 : 28,
          child: Text(
            '✦',
            style: TextStyle(
              fontSize: compact ? 28 : 40,
              color: const Color(0xffedb36c),
            ),
          ),
        ),
        Positioned(
          bottom: compact ? 8 : 25,
          left: compact ? 2 : 18,
          child: Text(
            '✦',
            style: TextStyle(
              fontSize: compact ? 22 : 34,
              color: const Color(0xff8bbfa2),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _homePage() => _content(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar('Hello, little explorer!', trailing: _onlineBadge()),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xffe6f3e9),
            borderRadius: BorderRadius.circular(28),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ready for today’s adventure?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Pick a trail and let’s discover something new.',
                        style: TextStyle(color: Color(0xff627c70)),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _screen = ChildScreen.learn),
                        child: const Text('Explore lessons'),
                      ),
                    ],
                  ),
                ),
                if (constraints.maxWidth > 460)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('🐻', style: TextStyle(fontSize: 82)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Choose your trail',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth > 760
                ? 3
                : constraints.maxWidth > 500
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: count,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: count == 1 ? 2.5 : 1.15,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: [
                _homeCard(
                  'Learn',
                  'Letters and numbers',
                  '📚',
                  _mint,
                  () => setState(() => _screen = ChildScreen.learn),
                ),
                _homeCard('Games', 'Play and find out', '🧩', _coral, () {
                  setState(() => _screen = ChildScreen.games);
                  unawaited(_loadPublishedGames());
                }),
                _homeCard(
                  'Progress',
                  'See how far you’ve come',
                  '🌟',
                  _lavender,
                  () {
                    setState(() => _screen = ChildScreen.progress);
                    _refreshProgress();
                  },
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _homeCard(
    String title,
    String subtitle,
    String emoji,
    Color color,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 35)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xff6a7e8d)),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: _blue),
        ],
      ),
    ),
  );

  Widget _learnPage() => _content(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(
          'Learning trails',
          trailing: const Text('🌱', style: TextStyle(fontSize: 27)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Take one little step at a time.',
          style: TextStyle(color: Color(0xff6a7e8d)),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Alphabets A–Z'),
              selected: _lessonKind == LessonKind.alphabet,
              onSelected: (_) =>
                  setState(() => _lessonKind = LessonKind.alphabet),
            ),
            ChoiceChip(
              label: const Text('Numbers 1–20'),
              selected: _lessonKind == LessonKind.number,
              onSelected: (_) =>
                  setState(() => _lessonKind = LessonKind.number),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 850
                ? 7
                : constraints.maxWidth > 540
                ? 5
                : 4;
            final count = _lessonKind == LessonKind.alphabet ? 26 : 20;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 11,
                mainAxisSpacing: 11,
                childAspectRatio: 1,
              ),
              itemCount: count,
              itemBuilder: (context, index) {
                final glyph = _lessonKind == LessonKind.alphabet
                    ? String.fromCharCode(65 + index)
                    : '${index + 1}';
                final completed = List<String>.from(
                  _progress['lessons'] as List? ?? const [],
                ).contains('${_lessonKind.name}:$glyph');
                return InkWell(
                  onTap: () => _openLesson(_lessonKind, index),
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? Colors.white
                          : const Color(0xfffff1e8),
                      borderRadius: BorderRadius.circular(19),
                      boxShadow: _shadow,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          glyph,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                        if (completed)
                          const Positioned(
                            right: 8,
                            top: 7,
                            child: Icon(
                              Icons.check_circle,
                              size: 17,
                              color: Color(0xff59a879),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
  );

  Widget _lessonPage() {
    final examples = _lessonKind == LessonKind.alphabet
        ? _alphabetExamples[_currentGlyph] ?? const [('🌟', 'Wonderful')]
        : [('🍓', 'Count them!'), ('🍊', 'One for each')];
    final number = _lessonKind == LessonKind.number ? _lessonIndex + 1 : 0;

    final traceCard = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _lessonPassed ? const Color(0xffe2f3e8) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lessonKind == LessonKind.alphabet) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _caseTile(_currentGlyph, 'Uppercase'),
                    const SizedBox(width: 9),
                    _caseTile(_currentGlyph.toLowerCase(), 'Lowercase'),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _lessonKind == LessonKind.alphabet
                    ? 'Trace the uppercase $_currentGlyph'
                    : 'Trace the number $_currentGlyph',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff738495),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 245,
                child: LayoutBuilder(
                  builder: (context, box) {
                    _traceSize = Size(box.maxWidth, box.maxHeight);
                    return Semantics(
                      label:
                          'Tracing canvas. Trace the $_currentGlyph with your finger.',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _lessonPassed
                            ? null
                            : (details) => setState(
                                () => _drawn = [
                                  ..._drawn,
                                  [_normalized(details.localPosition)],
                                ],
                              ),
                        onPanUpdate: _lessonPassed
                            ? null
                            : (details) => setState(() {
                                if (_drawn.isNotEmpty) {
                                  _drawn.last.add(
                                    _normalized(details.localPosition),
                                  );
                                }
                              }),
                        onPanEnd: _lessonPassed
                            ? null
                            : (_) => _finishTrace(),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: TracePainter(
                            target: tracePaths(_currentGlyph),
                            drawn: _drawn,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _drawn = [];
                      _lessonPassed = false;
                      _lessonMessage =
                          'Follow the dotted trail with your finger.';
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  const Spacer(),
                  if (_lessonPassed)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xff4caa70),
                      size: 28,
                    ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _lessonMessage,
                  key: ValueKey(
                    _lessonPassed.toString() + _drawn.length.toString(),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _lessonPassed
                        ? const Color(0xff43875f)
                        : const Color(0xff788797),
                  ),
                ),
              ),
              if (_lessonPassed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    onPressed: () => _advanceLesson(1),
                    icon: Icon(
                      _isLastLesson
                          ? Icons.celebration_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _isLastLesson ? 'Finish trail' : 'Next lesson',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final exampleCard = GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 250) {
          _advanceLesson(-1);
        } else if (velocity < -250) {
          _advanceLesson(1);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xfffff0e5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _lessonKind == LessonKind.alphabet
                  ? 'Words that begin with $_currentGlyph'
                  : 'Count to $_currentGlyph',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: _ink,
              ),
            ),
            const SizedBox(height: 14),
            if (_lessonKind == LessonKind.alphabet)
              ...examples.map((example) => _exampleRow(example.$1, example.$2))
            else ...[
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: List.generate(
                  number,
                  (index) => const Text(
                    '🍎',
                    style: TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                '$number ${number == 1 ? 'apple' : 'apples'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Every try helps your brain grow. Keep going, explorer!',
              style: TextStyle(color: Color(0xff728493)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Swipe this card left or right to change lessons.',
              style: TextStyle(color: Color(0xff94a3b0), fontSize: 12),
            ),
          ],
        ),
      ),
    );

    return _content(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(
            'Little lesson',
            trailing: TextButton.icon(
              onPressed: () => setState(() => _screen = ChildScreen.learn),
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('All lessons'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _lessonIndex > 0 ? () => _advanceLesson(-1) : null,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lessonKind == LessonKind.alphabet
                          ? 'Letter ${_lessonIndex + 1} of $_lessonLength'
                          : 'Number $number of $_lessonLength',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xff708394),
                      ),
                    ),
                    Text(
                      _lessonKind == LessonKind.alphabet
                          ? '$_currentGlyph is for adventure!'
                          : 'Let’s count together!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _isLastLesson && !_lessonPassed
                    ? null
                    : () => _advanceLesson(1),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 690;
              if (!wide) {
                return Column(
                  children: [
                    traceCard,
                    const SizedBox(height: 14),
                    exampleCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: traceCard),
                  const SizedBox(width: 18),
                  Expanded(flex: 3, child: exampleCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _caseTile(String value, String label) => Container(
    width: 82,
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xfffff4e8),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: _ink,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xff8a9aa8)),
        ),
      ],
    ),
  );

  Offset _normalized(Offset point) => Offset(
    (_traceSize.width == 0 ? 0.0 : point.dx / _traceSize.width)
        .clamp(0, 1)
        .toDouble(),
    (_traceSize.height == 0 ? 0.0 : point.dy / _traceSize.height)
        .clamp(0, 1)
        .toDouble(),
  );

  Widget _exampleRow(String emoji, String word) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 27)),
        ),
        const SizedBox(width: 12),
        Text(
          word,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    ),
  );

  Widget _gamesPage() => _content(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(
          'Games & adventures',
          trailing: IconButton(
            onPressed: _isOnline ? _loadPublishedGames : null,
            tooltip: 'Refresh games',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _isOnline
              ? 'Pick a game to play right away or save for offline.'
              : 'You’re offline. Saved games are ready when you are.',
          style: const TextStyle(color: Color(0xff708394)),
        ),
        const SizedBox(height: 17),
        if (_gamesError != null)
          _notice(
            _gamesError!,
            icon: Icons.cloud_off_rounded,
            color: const Color(0xfffff0df),
            action: _isOnline
                ? TextButton(
                    onPressed: _loadPublishedGames,
                    child: const Text('Try again'),
                  )
                : null,
          ),
        if (_loadingGames) const LinearProgressIndicator(),
        if (_loadingGames && _published.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          ),
        _sectionLabel('Play anywhere', '✨'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 520
                ? 2
                : 1;
            final builtins = _builtInGames;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: builtins.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: columns == 1 ? 2.1 : 1.45,
              ),
              itemBuilder: (context, index) =>
                  _builtInGameCard(builtins[index]),
            );
          },
        ),
        const SizedBox(height: 25),
        _sectionLabel('Teacher games', '🧑‍🏫'),
        if (_published.isEmpty &&
            _downloads.isEmpty &&
            !_loadingGames &&
            _gamesError == null)
          _notice(
            'No published games yet. Your saved learning games are always here!',
            icon: Icons.toys_rounded,
            color: const Color(0xffeef4fa),
          ),
        ..._teacherGameCards(),
      ],
    ),
  );

  List<Widget> _teacherGameCards() {
    final games = <int, PublishedGame>{
      for (final game in _published) game.id: game,
    };
    for (final saved in _downloads) {
      games.putIfAbsent(saved.game.id, () => saved.game);
    }
    return games.values.map((game) {
      final saved = _downloads
          .where((item) => item.game.id == game.id)
          .firstOrNull;
      final status = _downloadStatus[game.id];
      final available = _published.any((item) => item.id == game.id);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _teacherGameCard(game, saved, status, available),
      );
    }).toList();
  }

  Widget _teacherGameCard(
    PublishedGame game,
    GameBundle? saved,
    String? status,
    bool onlineAvailable,
  ) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: _shadow,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 530;
        final info = Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffe9f3fc),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                game.templateKey == 'matching'
                    ? Icons.extension_rounded
                    : Icons.lightbulb_rounded,
                color: _blue,
                size: 28,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  Text(
                    '${game.templateName.isEmpty ? game.templateKey : game.templateName}${saved != null ? ' · Saved offline' : ''}',
                    style: const TextStyle(
                      color: Color(0xff728393),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final controls = Wrap(
          spacing: 8,
          runSpacing: 7,
          alignment: WrapAlignment.end,
          children: [
            if (onlineAvailable)
              OutlinedButton.icon(
                onPressed: _loadingGames ? null : () => _playOnline(game),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play online'),
              ),
            if (saved != null)
              FilledButton.tonalIcon(
                onPressed: () => _startGame(saved, offline: true),
                icon: const Icon(Icons.offline_pin_rounded),
                label: const Text('Play offline'),
              ),
            if (status != null && !_cancelDownloads.contains(game.id))
              TextButton(
                onPressed: () {
                  setState(() => _cancelDownloads.add(game.id));
                },
                child: const Text('Cancel'),
              ),
            if (status == null && onlineAvailable && saved == null)
              TextButton.icon(
                onPressed: () => _downloadGame(game),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download'),
              ),
            if (status == null &&
                onlineAvailable &&
                saved != null &&
                _updatesAvailable.contains(game.id))
              TextButton.icon(
                onPressed: () => _downloadGame(game),
                icon: const Icon(Icons.system_update_alt_rounded),
                label: const Text('Update'),
              ),
            if (status == null && saved != null)
              IconButton(
                onPressed: () => _removeDownload(saved),
                tooltip: 'Remove download',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact)
              info
            else
              Row(
                children: [
                  Expanded(child: info),
                  controls,
                ],
              ),
            if (compact)
              Padding(padding: const EdgeInsets.only(top: 12), child: controls),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (_cancelDownloads.contains(game.id))
                      const Icon(Icons.info_outline, size: 17)
                    else
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(color: Color(0xff708394)),
                      ),
                    ),
                    if (status.startsWith('Could not') && onlineAvailable)
                      TextButton(
                        onPressed: () => _downloadGame(game),
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );

  Future<void> _playOnline(PublishedGame game) async {
    setState(() => _downloadStatus[game.id] = 'Loading questions…');
    try {
      final bundle = await _api.fetchBundle(game);
      if (!mounted) return;
      setState(() => _downloadStatus.remove(game.id));
      _startGame(bundle, offline: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _downloadStatus.remove(game.id));
      _toast(error.toString());
    }
  }

  Widget _builtInGameCard(_BuiltInGame game) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: game.tint,
      borderRadius: BorderRadius.circular(23),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(game.emoji, style: const TextStyle(fontSize: 39)),
            const Spacer(),
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xff718492),
              size: 18,
            ),
          ],
        ),
        const Spacer(),
        Text(
          game.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        Text(game.subtitle, style: const TextStyle(color: Color(0xff627687))),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => _startGame(game.bundle, offline: true),
            child: const Text('Play now'),
          ),
        ),
      ],
    ),
  );

  Widget _gamePage() {
    final game = _playing;
    if (game == null) {
      return _emptyState(
        'No game selected.',
        onBack: () => setState(() => _screen = ChildScreen.games),
      );
    }
    if (_gameComplete) {
      final percentage = _gameTotal == 0
          ? 0
          : (_score / _gameTotal * 100).round();
      return _content(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 530),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: _shadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 76)),
                  const SizedBox(height: 7),
                  const Text(
                    'Trail complete!',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  Text(
                    game.game.title,
                    style: const TextStyle(color: Color(0xff718391)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$_score / $_gameTotal',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _blue,
                    ),
                  ),
                  Text(
                    '$percentage%  ·  ${percentage >= 80 ? 'Amazing work!' : 'Keep practicing!'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xff5d886e),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _screen = ChildScreen.games;
                          _playing = null;
                        }),
                        icon: const Icon(Icons.grid_view_rounded),
                        label: const Text('Back to games'),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            _startGame(game, offline: _isPlayingOffline),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Play again'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final question = _currentQuestionOrNull!;
    return _content(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(
            game.game.title,
            trailing: TextButton(
              onPressed: () => setState(() => _screen = ChildScreen.games),
              child: const Text('Exit'),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_questionIndex + 1) / game.questions.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(width: 11),
              Text(
                '${_questionIndex + 1}/${game.questions.length}',
                style: const TextStyle(
                  color: Color(0xff718391),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _questionImage(question),
                Text(
                  question.prompt,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 18),
                if (question.type == 'multiple_choice')
                  _multipleChoice(question)
                else
                  _matching(question),
                if (_feedback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _feedback,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _correctFeedback
                            ? const Color(0xff499267)
                            : const Color(0xffcc8067),
                      ),
                    ),
                  ),
                if (_answered)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: FilledButton.icon(
                        onPressed: _nextQuestion,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          _questionIndex + 1 == game.questions.length
                              ? 'See my score'
                              : 'Next question',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Stars earned  $_score',
              style: const TextStyle(
                color: Color(0xff758493),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multipleChoice(GameQuestion question) {
    final options = (question.data['options'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    return Column(
      children: options.map((option) {
        final isAnswer = option == question.data['answer'];
        final color = !_answered
            ? Colors.white
            : isAnswer
            ? const Color(0xffe3f4e8)
            : const Color(0xfff6f6f5);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _answered ? null : () => _answerChoice(option),
              style: OutlinedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: _ink,
                side: BorderSide(
                  color: _answered && isAnswer
                      ? const Color(0xff68b17f)
                      : const Color(0xffe1e9ed),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 15,
                ),
                alignment: Alignment.centerLeft,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_answered && isAnswer)
                    const Icon(Icons.check_circle, color: Color(0xff55a672)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _matching(GameQuestion question) {
    final pairs = (question.data['pairs'] as List? ?? const [])
        .whereType<Map>()
        .map((pair) => Map<String, dynamic>.from(pair))
        .toList();
    final state = _matchingState ?? MatchingState(pairs.length);
    return Column(
      children: [
        const Text(
          'Tap a friend on each side to make a pair.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff748391)),
        ),
        const SizedBox(height: 13),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: List.generate(
                  pairs.length,
                  (index) => _matchingTile(
                    pairs[index]['left']?.toString() ?? '',
                    left: true,
                    index: index,
                    state: state,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: state.rightOrder
                    .map(
                      (index) => _matchingTile(
                        pairs[index]['right']?.toString() ?? '',
                        left: false,
                        index: index,
                        state: state,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _matchingTile(
    String label, {
    required bool left,
    required int index,
    required MatchingState state,
  }) {
    final isMatched = state.isMatched(index);
    final selected = left
        ? state.selectedLeft == index
        : state.selectedRight == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isMatched
              ? null
              : () => _selectPairItem(left: left, index: index),
          style: OutlinedButton.styleFrom(
            backgroundColor: isMatched
                ? const Color(0xffe5f3e8)
                : selected
                ? const Color(0xffe7f1fa)
                : Colors.white,
            foregroundColor: _ink,
            side: BorderSide(
              color: isMatched
                  ? const Color(0xff75b888)
                  : selected
                  ? _blue
                  : const Color(0xffdce5ea),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (isMatched)
                const Padding(
                  padding: EdgeInsets.only(left: 5),
                  child: Icon(Icons.check, size: 17, color: Color(0xff54a46f)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionImage(GameQuestion question) {
    final value = _findImage(question.data);
    if (value == null) return const SizedBox.shrink();
    final Widget image;
    if (value.startsWith('data:')) {
      final encoded = value.split(',').last;
      try {
        final bytes = _imageCache.putIfAbsent(
          value,
          () => base64Decode(encoded),
        );
        image = Image.memory(bytes, height: 175, fit: BoxFit.contain);
      } catch (_) {
        return const SizedBox.shrink();
      }
    } else {
      image = Image.network(
        _api.resolveMedia(value).toString(),
        height: 175,
        fit: BoxFit.contain,
        cacheWidth: 700,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Center(child: image),
    );
  }

  String? _findImage(Object? value, [String key = '']) {
    if (value is Map) {
      for (final entry in value.entries) {
        final found = _findImage(entry.value, entry.key.toString());
        if (found != null) return found;
      }
    }
    if ((key.toLowerCase().contains('image') ||
            key.toLowerCase().contains('photo')) &&
        value is String) {
      return value;
    }
    return null;
  }

  int _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  Widget _progressPage() {
    final games = List<Map<String, dynamic>>.from(
      (_progress['games'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final lessons = List<String>.from(
      _progress['lessons'] as List? ?? const [],
    );
    final builtInGames = games
        .where((game) => game['key']?.toString().startsWith('builtin:') ?? false)
        .toList();
    final teacherGames = games
        .where(
          (game) => !(game['key']?.toString().startsWith('builtin:') ?? false),
        )
        .toList();
    final answered = games.fold<int>(
      0,
      (sum, game) => sum + _asInt(game['answered'] ?? game['questions']),
    );
    return _content(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(
            'My progress',
            trailing: const Text('🌈', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  'Lessons explored',
                  '${lessons.length}',
                  '📖',
                  _mint,
                  constraints.maxWidth,
                ),
                _statCard(
                  'Games played',
                  '${games.length}',
                  '🏅',
                  _lavender,
                  constraints.maxWidth,
                ),
                _statCard(
                  'Questions answered',
                  '$answered',
                  '💡',
                  const Color(0xffe3f1fa),
                  constraints.maxWidth,
                ),
                _statCard(
                  'Saved offline',
                  '${_downloads.length}',
                  '📥',
                  _coral,
                  constraints.maxWidth,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Teacher adventures',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          if (teacherGames.isEmpty)
            _notice(
              'Games from your teacher will appear here after you play them.',
              icon: Icons.school_rounded,
              color: const Color(0xfffff1e5),
            )
          else
            ..._gameHistory(teacherGames),
          const SizedBox(height: 20),
          const Text(
            'Built-in adventures',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          if (builtInGames.isEmpty)
            _notice(
              'Your finished built-in games will appear here. Go earn some stars!',
              icon: Icons.star_outline_rounded,
              color: const Color(0xfffff1e5),
            )
          else
            ..._gameHistory(builtInGames),
          const SizedBox(height: 20),
          const Text(
            'Learning trail',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          if (lessons.isEmpty)
            _notice(
              'Every letter and number you finish will light up here.',
              icon: Icons.eco_rounded,
              color: const Color(0xffeaf4ec),
            ),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: lessons
                .map(
                  (item) => Chip(
                    avatar: const Icon(
                      Icons.check_circle,
                      size: 17,
                      color: Color(0xff5ba774),
                    ),
                    label: Text(item.replaceAll(':', ' ')),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _gameHistory(List<Map<String, dynamic>> games) => games
      .map((game) {
        final date = game['date']?.toString().split('T').first ?? '';
        final questionTotal = _asInt(game['questions']);
        final subtitle = questionTotal > 0
            ? '$date · ${_asInt(game['answered'])}/$questionTotal questions'
            : date;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            tileColor: Colors.white,
            leading: const CircleAvatar(
              backgroundColor: _lavender,
              child: Text('🎯'),
            ),
            title: Text(
              game['title']?.toString() ?? 'Game',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            subtitle: Text(subtitle),
            trailing: Text(
              '${_asInt(game['score'])}/${_asInt(game['total'])}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _blue,
              ),
            ),
          ),
        );
      })
      .toList();

  Widget _statCard(
    String label,
    String value,
    String emoji,
    Color color,
    double width,
  ) => SizedBox(
    width: width > 760
        ? (width - 24) / 3
        : (width > 460 ? (width - 12) / 2 : width),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 31)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              Text(label, style: const TextStyle(color: Color(0xff617486))),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _sideNavigation() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(18, 24, 14, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _brandMark(44),
            const SizedBox(width: 10),
            const Text(
              'TinyTrail',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        for (final entry in [
          (Icons.home_rounded, 'Home'),
          (Icons.auto_stories_rounded, 'Learn'),
          (Icons.videogame_asset_rounded, 'Games'),
          (Icons.emoji_events_rounded, 'Progress'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              selected:
                  _navigationIndex ==
                  ['Home', 'Learn', 'Games', 'Progress'].indexOf(entry.$2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              leading: Icon(entry.$1),
              title: Text(
                entry.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => _navigateTo(
                ['Home', 'Learn', 'Games', 'Progress'].indexOf(entry.$2),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xfffff1e6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Text('🦊', style: TextStyle(fontSize: 27)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You’re doing great!',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _content({required Widget child}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        child: SingleChildScrollView(child: child),
      ),
    ),
  );

  Widget _topBar(String title, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: _ink,
            letterSpacing: -.5,
          ),
        ),
      ),
      ?trailing,
    ],
  );

  Widget _onlineBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: _isOnline ? const Color(0xffe4f3e8) : const Color(0xffffeee8),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          size: 16,
          color: _isOnline ? const Color(0xff4d9565) : const Color(0xffce8065),
        ),
        const SizedBox(width: 6),
        Text(
          _isOnline ? 'Online' : 'Offline',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String text, String emoji) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(width: 8),
        Text(emoji),
      ],
    ),
  );

  Widget _notice(
    String text, {
    required IconData icon,
    required Color color,
    Widget? action,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Icon(icon, color: _ink),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: _ink)),
        ),
        ?action,
      ],
    ),
  );

  Widget _emptyState(String message, {VoidCallback? onBack}) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(message),
        if (onBack != null)
          TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    ),
  );

  Widget _brandMark(double size) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xffffe3ce),
      shape: BoxShape.circle,
    ),
    child: Text('🌱', style: TextStyle(fontSize: size * .56)),
  );

  Widget _bubble(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .75),
      shape: BoxShape.circle,
    ),
  );

  List<BoxShadow> get _shadow => [
    BoxShadow(
      color: const Color(0xff526c82).withValues(alpha: .08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  List<_BuiltInGame> get _builtInGames => [
    _BuiltInGame(
      title: 'Animal friends',
      subtitle: 'Match a friend to its name',
      emoji: '🦁',
      tint: _mint,
      bundle: _builtInBundle('builtin:animals', 'Animal friends', 'matching', [
        _question('Match each animal to its name', 'matching', {
          'pairs': [
            {'left': '🐱', 'right': 'Cat'},
            {'left': '🐶', 'right': 'Dog'},
            {'left': '🐸', 'right': 'Frog'},
            {'left': '🦁', 'right': 'Lion'},
          ],
        }),
      ]),
    ),
    _BuiltInGame(
      title: 'Letter explorers',
      subtitle: 'Choose the first letter',
      emoji: '🔤',
      tint: _coral,
      bundle: _builtInBundle(
        'builtin:letters',
        'Letter explorers',
        'multiple_choice',
        [
          _question('Which letter starts Apple?', 'multiple_choice', {
            'options': ['A', 'B', 'C'],
            'answer': 'A',
          }),
          _question('Which letter starts Moon?', 'multiple_choice', {
            'options': ['M', 'S', 'T'],
            'answer': 'M',
          }),
          _question('Which letter starts Sun?', 'multiple_choice', {
            'options': ['P', 'S', 'R'],
            'answer': 'S',
          }),
        ],
      ),
    ),
    _BuiltInGame(
      title: 'Little nature quiz',
      subtitle: 'Pick the right answer',
      emoji: '🌈',
      tint: _lavender,
      bundle: _builtInBundle(
        'builtin:nature',
        'Little nature quiz',
        'multiple_choice',
        [
          _question('What color is a ripe banana?', 'multiple_choice', {
            'options': ['Purple', 'Yellow', 'Blue'],
            'answer': 'Yellow',
          }),
          _question('Which animal says “moo”?', 'multiple_choice', {
            'options': ['Cow', 'Duck', 'Sheep'],
            'answer': 'Cow',
          }),
          _question('How many legs does a spider have?', 'multiple_choice', {
            'options': ['Six', 'Eight', 'Ten'],
            'answer': 'Eight',
          }),
        ],
      ),
    ),
  ];

  GameBundle _builtInBundle(
    String id,
    String title,
    String type,
    List<GameQuestion> questions,
  ) => GameBundle(
    game: PublishedGame(
      id: id.hashCode.abs(),
      title: title,
      description: 'Built-in offline game',
      templateId: 0,
      templateName: type == 'matching' ? 'Matching' : 'Multiple Choice',
      templateKey: type,
      updatedAt: '',
    ),
    questions: questions,
    fingerprint: '',
    assets: const {},
    downloadedAt: '',
  );

  GameQuestion _question(String prompt, String type, JsonMap data) =>
      GameQuestion(
        id: prompt,
        prompt: prompt,
        data: {'type': type, ...data},
        sortOrder: 0,
      );
}

class _BuiltInGame {
  const _BuiltInGame({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.tint,
    required this.bundle,
  });
  final String title;
  final String subtitle;
  final String emoji;
  final Color tint;
  final GameBundle bundle;
}

GameBundle makeBuiltInBundle({
  required String key,
  required String title,
  required List<GameQuestion> questions,
}) => GameBundle(
  game: PublishedGame(
    id: key.hashCode.abs(),
    title: title,
    description: '',
    templateId: 0,
    templateName: '',
    templateKey: '',
    updatedAt: '',
  ),
  questions: questions,
  fingerprint: '',
  assets: const {},
  downloadedAt: '',
);

const Map<String, List<(String, String)>> _alphabetExamples = {
  'A': [('🐜', 'Ant'), ('🍎', 'Apple'), ('✈️', 'Aeroplane')],
  'B': [('🐻', 'Bear'), ('🦋', 'Butterfly'), ('⚽', 'Ball')],
  'C': [('🐱', 'Cat'), ('🚗', 'Car'), ('🎂', 'Cake')],
  'D': [('🐶', 'Dog'), ('🦆', 'Duck'), ('🥁', 'Drum')],
  'E': [('🐘', 'Elephant'), ('🥚', 'Egg'), ('🦅', 'Eagle')],
  'F': [('🐸', 'Frog'), ('🦊', 'Fox'), ('🌸', 'Flower')],
  'G': [('🦒', 'Giraffe'), ('🍇', 'Grapes'), ('🎁', 'Gift')],
  'H': [('🐴', 'Horse'), ('🏠', 'House'), ('❤️', 'Heart')],
  'I': [('🍦', 'Ice cream'), ('🧊', 'Ice'), ('🐛', 'Insect')],
  'J': [('🧃', 'Juice'), ('🪼', 'Jellyfish'), ('🧥', 'Jacket')],
  'K': [('🪁', 'Kite'), ('🔑', 'Key'), ('🥝', 'Kiwi')],
  'L': [('🦁', 'Lion'), ('🍋', 'Lemon'), ('🍃', 'Leaf')],
  'M': [('🐒', 'Monkey'), ('🌙', 'Moon'), ('🥭', 'Mango')],
  'N': [('🪺', 'Nest'), ('👃', 'Nose'), ('🌰', 'Nut')],
  'O': [('🐙', 'Octopus'), ('🍊', 'Orange'), ('🦉', 'Owl')],
  'P': [('🐼', 'Panda'), ('🍐', 'Pear'), ('🐧', 'Penguin')],
  'Q': [('👸', 'Queen'), ('🪶', 'Quill'), ('🧵', 'Quilt')],
  'R': [('🐰', 'Rabbit'), ('🌈', 'Rainbow'), ('🤖', 'Robot')],
  'S': [('☀️', 'Sun'), ('⭐', 'Star'), ('🐍', 'Snake')],
  'T': [('🐯', 'Tiger'), ('🌳', 'Tree'), ('🚂', 'Train')],
  'U': [('☂️', 'Umbrella'), ('🦄', 'Unicorn'), ('🧥', 'Uniform')],
  'V': [('🎻', 'Violin'), ('🌋', 'Volcano'), ('🚐', 'Van')],
  'W': [('🐳', 'Whale'), ('🍉', 'Watermelon'), ('⌚', 'Watch')],
  'X': [('🩻', 'X-ray'), ('🎼', 'Xylophone'), ('❌', 'X marks')],
  'Y': [('🪀', 'Yo-yo'), ('🧶', 'Yarn'), ('🛥️', 'Yacht')],
  'Z': [('🦓', 'Zebra'), ('🤐', 'Zipper'), ('0️⃣', 'Zero')],
};
