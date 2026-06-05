import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_screen.dart';

/// An animated splash: the texcut mark (a chevron expanding into lines of
/// text) draws itself in, then the wordmark appears, before handing off to the
/// home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _goHome();
    });
  }

  Future<void> _goHome() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, a, __) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _interval(double start, double end, [Curve curve = Curves.easeOut]) {
    final t = ((_c.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final enter = _interval(0.0, 0.45, Curves.easeOutBack);
          final fade = _interval(0.0, 0.3);
          final bars = _interval(0.2, 0.95, Curves.easeInOut);
          final title = _interval(0.5, 0.85);
          final tagline = _interval(0.66, 1.0);

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A6CF7), Color(0xFF6557EC), Color(0xFF8A45E0)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * enter,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: CustomPaint(painter: _MarkPainter(bars)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Opacity(
                    opacity: title,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - title)),
                      child: const Text(
                        'texcut',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Opacity(
                    opacity: tagline,
                    child: Text(
                      'type less · say more',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints the texcut mark within its box, with the text lines "expanding"
/// according to [bars] (0..1).
class _MarkPainter extends CustomPainter {
  _MarkPainter(this.bars);
  final double bars;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 108;
    double f(double v) => v * scale;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Chevron.
    p.strokeWidth = f(8.5);
    final chevron = Path()
      ..moveTo(f(31), f(39))
      ..lineTo(f(46), f(54))
      ..lineTo(f(31), f(69));
    canvas.drawPath(chevron, p);

    // Expanding text lines (staggered).
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
      canvas.drawLine(Offset(f(x0), f(y)), Offset(f(math.max(cur, x0 + 0.1)), f(y)), p);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.bars != bars;
}
