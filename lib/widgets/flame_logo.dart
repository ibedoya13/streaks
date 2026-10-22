import 'package:flutter/material.dart';

/// The Streaks mark: a flowing "S" with two flame tongues, painted with the
/// same geometry as the launcher icon (see tool/generate_icon.py) so the app
/// and the icon stay in sync.
class FlameLogo extends StatelessWidget {
  const FlameLogo({super.key, this.size = 32, this.color});

  final double size;

  /// When null the logo uses the yellow -> orange -> red fire ramp.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FlameLogoPainter(color)),
    );
  }
}

class _FlameLogoPainter extends CustomPainter {
  const _FlameLogoPainter(this.color);

  final Color? color;

  // The S centreline, in the icon's 1024x1024 space.
  static final _sPath = Path()
    ..moveTo(700, 392)
    ..cubicTo(700, 302, 630, 255, 520, 255)
    ..cubicTo(410, 255, 340, 305, 340, 395)
    ..cubicTo(340, 500, 440, 545, 520, 560)
    ..cubicTo(605, 576, 684, 615, 684, 720)
    ..cubicTo(684, 810, 605, 870, 500, 870)
    ..cubicTo(395, 870, 330, 820, 330, 735);

  // Flame tongue rising from the top-right terminal.
  static final _topTongue = Path()
    ..moveTo(694, 330)
    ..cubicTo(700, 240, 726, 180, 768, 120)
    ..cubicTo(812, 200, 806, 300, 772, 360)
    ..cubicTo(752, 396, 712, 386, 694, 330)
    ..close();

  // Flame tongue dropping from the bottom-left terminal.
  static final _bottomTongue = Path()
    ..moveTo(300, 700)
    ..cubicTo(258, 760, 216, 826, 220, 900)
    ..cubicTo(266, 880, 296, 826, 308, 766)
    ..cubicTo(314, 726, 310, 706, 300, 700)
    ..close();

  static const _strokeWidth = 132.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1024;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (color != null) {
      paint.color = color!;
      paint.style = PaintingStyle.fill;
      canvas.drawPath(_topTongue, paint);
      canvas.drawPath(_bottomTongue, paint);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color!;
      canvas.drawPath(_sPath, stroke);
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD54A), Color(0xFFF79009), Color(0xFFD92D20)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 1024, 1024));
      canvas.drawPath(_topTongue, paint);
      canvas.drawPath(_bottomTongue, paint);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = paint.shader;
      canvas.drawPath(_sPath, stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlameLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
