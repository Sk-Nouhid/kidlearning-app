import 'dart:math';

import 'models.dart';

enum MatchOutcome { none, matched, wrong, complete }

class MatchingState {
  MatchingState(this.pairCount, {Random? random})
    : rightOrder = List<int>.generate(pairCount, (index) => index)
        ..shuffle(random ?? Random());

  final int pairCount;
  final List<int> rightOrder;
  final Set<int> matchedPairs = <int>{};
  int? selectedLeft;
  int? selectedRight;

  bool get isComplete => matchedPairs.isNotEmpty && matchedPairs.length == pairCount;

  MatchOutcome pick({required bool left, required int index}) {
    if (isComplete ||
        index < 0 ||
        index >= pairCount ||
        matchedPairs.contains(index)) {
      return MatchOutcome.none;
    }
    if (left) {
      selectedLeft = index;
    } else {
      selectedRight = index;
    }
    if (selectedLeft == null || selectedRight == null) return MatchOutcome.none;

    final leftIndex = selectedLeft;
    final rightIndex = selectedRight;
    selectedLeft = null;
    selectedRight = null;

    if (leftIndex == rightIndex && !matchedPairs.contains(leftIndex)) {
      matchedPairs.add(leftIndex!);
      return isComplete ? MatchOutcome.complete : MatchOutcome.matched;
    }
    return MatchOutcome.wrong;
  }

  bool isMatched(int index) => matchedPairs.contains(index);
}

int clampLessonIndex(int current, int direction, int length) {
  if (length <= 0) return 0;
  return (current + direction).clamp(0, length - 1);
}

bool isLastLessonIndex(int index, int length) => length > 0 && index >= length - 1;

bool fingerprintsDiffer(String downloaded, String latest) => downloaded != latest;

bool isBuiltInBundle(GameBundle bundle) => bundle.fingerprint.isEmpty;

String progressKeyForBundle(GameBundle bundle) =>
    '${isBuiltInBundle(bundle) ? 'builtin' : 'teacher'}:${bundle.game.id}';

int correctAnswerScore({required String selected, required String answer}) =>
    selected == answer ? 1 : 0;
