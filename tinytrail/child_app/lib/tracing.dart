import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef TraceStroke = List<Offset>;

const Map<String, List<List<Offset>>> _glyphs = {
  'A': [
    [Offset(.05, 1), Offset(.5, 0), Offset(.95, 1)],
    [Offset(.24, .62), Offset(.76, .62)],
  ],
  'B': [
    [Offset(.12, 0), Offset(.12, 1)],
    [
      Offset(.12, 0),
      Offset(.62, 0),
      Offset(.86, .16),
      Offset(.86, .34),
      Offset(.62, .49),
      Offset(.12, .49),
    ],
    [
      Offset(.12, .49),
      Offset(.66, .49),
      Offset(.9, .65),
      Offset(.9, .82),
      Offset(.68, 1),
      Offset(.12, 1),
    ],
  ],
  'C': [
    [
      Offset(.88, .15),
      Offset(.68, 0),
      Offset(.34, 0),
      Offset(.12, .2),
      Offset(.08, .78),
      Offset(.3, 1),
      Offset(.7, 1),
      Offset(.9, .82),
    ],
  ],
  'D': [
    [Offset(.12, 0), Offset(.12, 1)],
    [
      Offset(.12, 0),
      Offset(.54, 0),
      Offset(.84, .2),
      Offset(.9, .5),
      Offset(.84, .8),
      Offset(.54, 1),
      Offset(.12, 1),
    ],
  ],
  'E': [
    [Offset(.88, 0), Offset(.12, 0), Offset(.12, 1), Offset(.9, 1)],
    [Offset(.12, .5), Offset(.72, .5)],
  ],
  'F': [
    [Offset(.12, 1), Offset(.12, 0), Offset(.9, 0)],
    [Offset(.12, .48), Offset(.72, .48)],
  ],
  'G': [
    [
      Offset(.9, .18),
      Offset(.7, 0),
      Offset(.3, 0),
      Offset(.1, .22),
      Offset(.1, .78),
      Offset(.3, 1),
      Offset(.72, 1),
      Offset(.9, .78),
      Offset(.9, .54),
      Offset(.58, .54),
    ],
  ],
  'H': [
    [Offset(.1, 0), Offset(.1, 1)],
    [Offset(.9, 0), Offset(.9, 1)],
    [Offset(.1, .5), Offset(.9, .5)],
  ],
  'I': [
    [Offset(.18, 0), Offset(.82, 0)],
    [Offset(.5, 0), Offset(.5, 1)],
    [Offset(.18, 1), Offset(.82, 1)],
  ],
  'J': [
    [
      Offset(.85, 0),
      Offset(.85, .75),
      Offset(.68, 1),
      Offset(.32, 1),
      Offset(.12, .78),
    ],
  ],
  'K': [
    [Offset(.12, 0), Offset(.12, 1)],
    [Offset(.88, 0), Offset(.16, .52), Offset(.9, 1)],
  ],
  'L': [
    [Offset(.14, 0), Offset(.14, 1), Offset(.9, 1)],
  ],
  'M': [
    [
      Offset(.08, 1),
      Offset(.08, 0),
      Offset(.5, .5),
      Offset(.92, 0),
      Offset(.92, 1),
    ],
  ],
  'N': [
    [Offset(.12, 1), Offset(.12, 0), Offset(.88, 1), Offset(.88, 0)],
  ],
  'O': [
    [
      Offset(.5, 0),
      Offset(.2, .05),
      Offset(.08, .28),
      Offset(.08, .72),
      Offset(.2, .95),
      Offset(.5, 1),
      Offset(.8, .95),
      Offset(.92, .72),
      Offset(.92, .28),
      Offset(.8, .05),
      Offset(.5, 0),
    ],
  ],
  'P': [
    [
      Offset(.12, 1),
      Offset(.12, 0),
      Offset(.6, 0),
      Offset(.9, .18),
      Offset(.9, .34),
      Offset(.68, .5),
      Offset(.12, .5),
    ],
  ],
  'Q': [
    [
      Offset(.5, 0),
      Offset(.2, .05),
      Offset(.08, .28),
      Offset(.08, .72),
      Offset(.2, .95),
      Offset(.5, 1),
      Offset(.8, .95),
      Offset(.92, .72),
      Offset(.92, .28),
      Offset(.8, .05),
      Offset(.5, 0),
    ],
    [Offset(.62, .7), Offset(.98, 1)],
  ],
  'R': [
    [
      Offset(.12, 1),
      Offset(.12, 0),
      Offset(.6, 0),
      Offset(.9, .17),
      Offset(.9, .34),
      Offset(.68, .5),
      Offset(.12, .5),
    ],
    [Offset(.52, .5), Offset(.92, 1)],
  ],
  'S': [
    [
      Offset(.88, .14),
      Offset(.68, 0),
      Offset(.3, 0),
      Offset(.1, .18),
      Offset(.18, .4),
      Offset(.78, .6),
      Offset(.9, .82),
      Offset(.7, 1),
      Offset(.3, 1),
      Offset(.1, .84),
    ],
  ],
  'T': [
    [Offset(.05, 0), Offset(.95, 0)],
    [Offset(.5, 0), Offset(.5, 1)],
  ],
  'U': [
    [
      Offset(.1, 0),
      Offset(.1, .72),
      Offset(.28, 1),
      Offset(.72, 1),
      Offset(.9, .72),
      Offset(.9, 0),
    ],
  ],
  'V': [
    [Offset(.08, 0), Offset(.5, 1), Offset(.92, 0)],
  ],
  'W': [
    [
      Offset(.06, 0),
      Offset(.26, 1),
      Offset(.5, .5),
      Offset(.74, 1),
      Offset(.94, 0),
    ],
  ],
  'X': [
    [Offset(.1, 0), Offset(.9, 1)],
    [Offset(.9, 0), Offset(.1, 1)],
  ],
  'Y': [
    [Offset(.08, 0), Offset(.5, .48), Offset(.92, 0)],
    [Offset(.5, .48), Offset(.5, 1)],
  ],
  'Z': [
    [Offset(.1, 0), Offset(.9, 0), Offset(.1, 1), Offset(.9, 1)],
  ],
  '0': [
    [
      Offset(.5, 0),
      Offset(.2, .08),
      Offset(.08, .3),
      Offset(.08, .7),
      Offset(.22, .94),
      Offset(.5, 1),
      Offset(.78, .92),
      Offset(.92, .7),
      Offset(.92, .3),
      Offset(.78, .08),
      Offset(.5, 0),
    ],
  ],
  '1': [
    [Offset(.24, .22), Offset(.5, 0), Offset(.5, 1)],
    [Offset(.2, 1), Offset(.82, 1)],
  ],
  '2': [
    [
      Offset(.12, .2),
      Offset(.28, 0),
      Offset(.72, 0),
      Offset(.9, .2),
      Offset(.86, .38),
      Offset(.12, 1),
      Offset(.9, 1),
    ],
  ],
  '3': [
    [
      Offset(.12, .12),
      Offset(.34, 0),
      Offset(.72, 0),
      Offset(.9, .2),
      Offset(.7, .46),
      Offset(.44, .5),
    ],
    [
      Offset(.54, .5),
      Offset(.8, .54),
      Offset(.92, .78),
      Offset(.76, 1),
      Offset(.34, 1),
      Offset(.12, .88),
    ],
  ],
  '4': [
    [Offset(.68, 1), Offset(.68, 0), Offset(.1, .68), Offset(.92, .68)],
  ],
  '5': [
    [
      Offset(.86, 0),
      Offset(.2, 0),
      Offset(.16, .46),
      Offset(.66, .46),
      Offset(.9, .64),
      Offset(.88, .82),
      Offset(.68, 1),
      Offset(.28, 1),
      Offset(.1, .84),
    ],
  ],
  '6': [
    [
      Offset(.8, 0),
      Offset(.42, .08),
      Offset(.16, .42),
      Offset(.1, .72),
      Offset(.28, .96),
      Offset(.68, 1),
      Offset(.9, .78),
      Offset(.86, .6),
      Offset(.68, .48),
      Offset(.16, .5),
    ],
  ],
  '7': [
    [Offset(.08, 0), Offset(.92, 0), Offset(.34, 1)],
  ],
  '8': [
    [
      Offset(.5, .48),
      Offset(.22, .42),
      Offset(.12, .22),
      Offset(.28, .02),
      Offset(.7, .02),
      Offset(.88, .22),
      Offset(.78, .42),
      Offset(.5, .48),
      Offset(.22, .56),
      Offset(.1, .78),
      Offset(.28, .98),
      Offset(.7, .98),
      Offset(.9, .78),
      Offset(.78, .56),
      Offset(.5, .48),
    ],
  ],
  '9': [
    [
      Offset(.84, .5),
      Offset(.32, .5),
      Offset(.12, .34),
      Offset(.14, .16),
      Offset(.34, 0),
      Offset(.72, .04),
      Offset(.9, .26),
      Offset(.86, .58),
      Offset(.58, .9),
      Offset(.24, 1),
    ],
  ],
};

List<TraceStroke> tracePaths(String text) {
  final symbols = text.toUpperCase().split('');
  final count = symbols.length;
  final margin = .08;
  final gap = count > 1 ? .08 : 0.0;
  final width = (1 - margin * 2 - gap * (count - 1)) / count;
  final paths = <TraceStroke>[];
  for (var index = 0; index < count; index++) {
    final glyph = _glyphs[symbols[index]];
    if (glyph == null) continue;
    final left = margin + index * (width + gap);
    for (final stroke in glyph) {
      paths.add(
        stroke
            .map(
              (point) => Offset(left + point.dx * width, .12 + point.dy * .76),
            )
            .toList(),
      );
    }
  }
  return paths;
}

double traceCoverage(
  List<TraceStroke> target,
  List<TraceStroke> drawn, {
  double tolerance = .065,
}) {
  if (target.isEmpty || drawn.isEmpty) return 0;
  final drawnLength = drawn.fold<double>(0, (sum, stroke) {
    for (var i = 1; i < stroke.length; i++) {
      sum += (stroke[i] - stroke[i - 1]).distance;
    }
    return sum;
  });
  if (drawnLength < .12) return 0;

  var expectedCount = 0;
  var coveredCount = 0;
  for (final stroke in target) {
    for (var segment = 1; segment < stroke.length; segment++) {
      final start = stroke[segment - 1];
      final end = stroke[segment];
      final distance = (end - start).distance;
      final steps = math.max(1, (distance / .025).ceil());
      for (var i = 0; i <= steps; i++) {
        expectedCount++;
        final sample = Offset.lerp(start, end, i / steps)!;
        if (drawn.any((path) => _nearStroke(sample, path, tolerance))) {
          coveredCount++;
        }
      }
    }
  }
  return expectedCount == 0 ? 0 : coveredCount / expectedCount;
}

bool _nearStroke(Offset point, TraceStroke path, double tolerance) {
  if (path.length == 1) return (path.single - point).distance <= tolerance;
  for (var i = 1; i < path.length; i++) {
    if (_distanceToSegment(point, path[i - 1], path[i]) <= tolerance) {
      return true;
    }
  }
  return false;
}

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) return (point - start).distance;
  final projection =
      ((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
      lengthSquared;
  final t = projection.clamp(0.0, 1.0);
  return (point - (start + segment * t)).distance;
}

class TracePainter extends CustomPainter {
  const TracePainter({required this.target, required this.drawn});

  final List<TraceStroke> target;
  final List<TraceStroke> drawn;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = const Color(0xffb5c6d7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final stroke in target) {
      for (var segment = 1; segment < stroke.length; segment++) {
        final from = _scale(stroke[segment - 1], size);
        final to = _scale(stroke[segment], size);
        final distance = (to - from).distance;
        for (var offset = 0.0; offset < distance; offset += 12) {
          final t = offset / distance;
          final point = Offset.lerp(from, to, t)!;
          canvas.drawCircle(point, 2.2, guide);
        }
      }
    }
    final ink = Paint()
      ..color = const Color(0xff3978bd)
      ..strokeWidth = math.max(5, size.shortestSide * .035)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in drawn) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, ink);
    }
  }

  Offset _scale(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

  @override
  bool shouldRepaint(covariant TracePainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.drawn != drawn;
}
