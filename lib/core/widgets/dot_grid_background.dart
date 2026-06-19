import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget vẽ lưới chấm bi trên nền tối, giống pattern dots trên dashboard premium.
/// Wrap bất kỳ widget nào bên trong để thêm hiệu ứng này.
class DotGridBackground extends StatelessWidget {
  const DotGridBackground({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFF111110),
    this.dotColor = const Color(0xFF2C2C2B),
    this.dotRadius = 1.2,
    this.spacing = 22.0,
  });

  final Widget child;
  final Color backgroundColor;
  final Color dotColor;
  final double dotRadius;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Lớp nền màu
        ColoredBox(color: backgroundColor),
        // Lớp lưới chấm
        RepaintBoundary(
          child: CustomPaint(
            painter: _DotGridPainter(
              dotColor: dotColor,
              dotRadius: dotRadius,
              spacing: spacing,
            ),
          ),
        ),
        // Nội dung bên trên
        child,
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({
    required this.dotColor,
    required this.dotRadius,
    required this.spacing,
  });

  final Color dotColor;
  final double dotRadius;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final x = col * spacing;
        final y = row * spacing;
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.spacing != spacing;

  @override
  bool hitTest(Offset position) => false;
}

/// Variant có vignette gradient mờ dần ở góc, trông premium hơn.
class DotGridBackgroundWithVignette extends StatelessWidget {
  const DotGridBackgroundWithVignette({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFF111110),
    this.dotColor = const Color(0xFF2A2A29),
    this.dotRadius = 1.2,
    this.spacing = 22.0,
  });

  final Widget child;
  final Color backgroundColor;
  final Color dotColor;
  final double dotRadius;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: backgroundColor),
        RepaintBoundary(
          child: CustomPaint(
            painter: _DotGridPainter(
              dotColor: dotColor,
              dotRadius: dotRadius,
              spacing: spacing,
            ),
          ),
        ),
        // Vignette: gradient trong suốt từ tâm ra các góc, tạo cảm giác depth
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: math.sqrt(2),
              colors: [
                Colors.transparent,
                backgroundColor.withValues(alpha: 0.7),
              ],
              stops: const [0.4, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
