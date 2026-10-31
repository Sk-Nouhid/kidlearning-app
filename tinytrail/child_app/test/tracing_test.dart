import 'package:flutter_test/flutter_test.dart';
import 'package:tinytrail_child_app/tracing.dart';

void main() {
  test(
    'trace evaluation accepts a matching path and rejects unrelated marks',
    () {
      final target = tracePaths('A');
      final correct = target.map((stroke) => List.of(stroke)).toList();
      final unrelated = [
        [
          const Offset(.02, .05),
          const Offset(.98, .05),
          const Offset(.98, .95),
          const Offset(.02, .95),
          const Offset(.02, .05),
        ],
      ];

      expect(traceCoverage(target, correct), greaterThanOrEqualTo(.58));
      expect(traceCoverage(target, unrelated), lessThan(.58));
    },
  );

  test('multi-digit numbers have guides and empty input fails', () {
    expect(tracePaths('20'), isNotEmpty);
    expect(traceCoverage(tracePaths('20'), const []), 0);
  });
}
