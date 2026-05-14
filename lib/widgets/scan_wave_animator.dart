import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated radar / sonar scan visualization.
/// Shows expanding concentric rings with a rotating sweep line.
class ScanWaveAnimator extends StatefulWidget {
  final bool isActive;
  final double size;

  const ScanWaveAnimator({super.key, required this.isActive, this.size = 240});

  @override
  State<ScanWaveAnimator> createState() => _ScanWaveAnimatorState();
}

class _ScanWaveAnimatorState extends State<ScanWaveAnimator>
    with TickerProviderStateMixin {
  late AnimationController _sweep;
  late AnimationController _pulse;
  late Animation<double> _sweepAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _sweepAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_sweep);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
    if (widget.isActive) {
      _sweep.repeat();
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(ScanWaveAnimator old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_sweep.isAnimating) {
      _sweep.repeat();
      _pulse.repeat();
    } else if (!widget.isActive && _sweep.isAnimating) {
      _sweep.stop();
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sweepAnim, _pulseAnim]),
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RadarPainter(
          sweepAngle: _sweepAnim.value,
          pulseValue: _pulseAnim.value,
          isActive: widget.isActive,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseValue;
  final bool isActive;

  _RadarPainter({
    required this.sweepAngle,
    required this.pulseValue,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2;

    // ── Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      maxR,
      Paint()..color = AppColors.surface,
    );

    // ── Concentric grid rings
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), maxR * i / 4, gridPaint);
    }

    // ── Cross-hair lines
    final crossPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), crossPaint);
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), crossPaint);

    if (!isActive) {
      canvas.drawCircle(
        Offset(cx, cy),
        maxR * 0.6,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }

    // ── Sweep gradient fill
    final sweepRect = Rect.fromCircle(center: Offset(cx, cy), radius: maxR);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - math.pi / 2,
        endAngle: sweepAngle,
        colors: [
          AppColors.primary.withValues(alpha: 0.0),
          AppColors.primary.withValues(alpha: 0.25),
        ],
        stops: const [0.0, 1.0],
      ).createShader(sweepRect);
    canvas.drawArc(
      sweepRect,
      sweepAngle - math.pi / 2 - math.pi / 3,
      math.pi / 3,
      true,
      sweepPaint,
    );

    // ── Sweep leading line
    final lineEnd = Offset(
      cx + maxR * math.cos(sweepAngle),
      cy + maxR * math.sin(sweepAngle),
    );
    canvas.drawLine(
      Offset(cx, cy),
      lineEnd,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // ── Pulsing ring
    final pR = maxR * pulseValue;
    canvas.drawCircle(
      Offset(cx, cy),
      pR,
      Paint()
        ..color = AppColors.primary.withValues(alpha: (1 - pulseValue) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ── Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      5,
      Paint()..color = AppColors.primary,
    );

    // ── Outer ring border
    canvas.drawCircle(
      Offset(cx, cy),
      maxR,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweepAngle != sweepAngle ||
      old.pulseValue != pulseValue ||
      old.isActive != isActive;
}
