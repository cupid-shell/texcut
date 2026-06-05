import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The texcut brand mark — a chevron (a typed shortcut) expanding into lines of
/// text — drawn with strokes so it scales crisply at any size and any colour.
///
/// Set [compact] for a simplified double-chevron that stays legible at small
/// sizes (inline lists, badges).
class TexcutMark extends StatelessWidget {
  const TexcutMark({
    super.key,
    this.size = 44,
    this.color = Colors.white,
    this.compact = false,
  });

  final double size;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: TexcutMarkPainter(1, color, compact: compact)),
    );
  }
}

/// Paints the texcut mark on a 108×108 reference grid. [bars] (0..1) animates
/// the expanding text lines; pass 1 for the static logo. [compact] draws a
/// simplified double-chevron instead, for small sizes.
class TexcutMarkPainter extends CustomPainter {
  TexcutMarkPainter(this.bars, this.color, {this.compact = false});

  final double bars;
  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 108;
    double f(double v) => v * scale;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (compact) {
      // Double chevron "»" — reads well even when tiny.
      p.strokeWidth = f(11);
      canvas.drawPath(
        Path()
          ..moveTo(f(34), f(34))
          ..lineTo(f(54), f(54))
          ..lineTo(f(34), f(74)),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(f(56), f(34))
          ..lineTo(f(76), f(54))
          ..lineTo(f(56), f(74)),
        p,
      );
      return;
    }

    // Chevron ">".
    p.strokeWidth = f(8.5);
    final chevron = Path()
      ..moveTo(f(31), f(39))
      ..lineTo(f(46), f(54))
      ..lineTo(f(31), f(69));
    canvas.drawPath(chevron, p);

    // Expanding text lines (staggered when [bars] < 1).
    p.strokeWidth = f(7);
    const lines = [
      [55.0, 43.0, 74.0],
      [55.0, 54.0, 82.0],
      [55.0, 65.0, 69.0],
    ];
    const starts = [0.0, 0.18, 0.36];
    for (var i = 0; i < lines.length; i++) {
      final t = ((bars - starts[i]) / 0.55).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(t);
      if (e <= 0) continue;
      final x0 = lines[i][0], y = lines[i][1], x1 = lines[i][2];
      final cur = x0 + (x1 - x0) * e;
      canvas.drawLine(
          Offset(f(x0), f(y)), Offset(f(math.max(cur, x0 + 0.1)), f(y)), p);
    }
  }

  @override
  bool shouldRepaint(TexcutMarkPainter old) =>
      old.bars != bars || old.color != color || old.compact != compact;
}
