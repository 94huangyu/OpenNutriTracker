import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';

/// Original C artwork with two brief record-dot pulses, then the diary.
class SplashScreen extends StatefulWidget {
  /// Legacy call-site compatibility; a body profile no longer gates entry.
  final bool userInitialized;

  const SplashScreen({super.key, required this.userInitialized});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _startTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _goNext();
        });

    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduceMotion) {
      _startTimer = Timer(const Duration(milliseconds: 600), _goNext);
    } else {
      _controller.forward();
    }
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(NavigationOptions.mainRoute);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Android's launch resources follow the system theme, before app preferences.
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF131C18)
          : const Color(0xFFFDF1DA),
      body: Center(
        child: CustomPaint(
          size: const Size.square(168),
          painter: _ShijiSplashPainter(_controller),
        ),
      ),
    );
  }
}

class _ShijiSplashPainter extends CustomPainter {
  _ShijiSplashPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  double _pulse(double start) {
    final t = ((animation.value * 800 - start) / 300).clamp(0.0, 1.0);
    return 1 + 0.18 * math.pow(math.sin(math.pi * t), 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 440, size.height / 440);
    final paint = Paint()..color = const Color(0xFF336A73);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(219.6105, 225.1673),
        width: 340.6512,
        height: 341.2182,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(219.9998, 225.5270),
        width: 243.4604,
        height: 244.4672,
      ),
      paint..color = const Color(0xFFFDF5E7),
    );
    paint.color = const Color(0xFF336A73);
    canvas.drawRRect(
      RRect.fromLTRBR(149, 187, 256, 215, const Radius.circular(14)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(149, 246, 226, 273, const Radius.circular(13.5)),
      paint,
    );
    paint.color = const Color(0xFFC48639);
    canvas.drawCircle(const Offset(285, 201), 14.2 * _pulse(0), paint);
    canvas.drawCircle(const Offset(255.5, 259), 14.2 * _pulse(350), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShijiSplashPainter oldDelegate) =>
      animation != oldDelegate.animation;
}
