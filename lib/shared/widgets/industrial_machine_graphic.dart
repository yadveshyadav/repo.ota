import 'package:flutter/material.dart';
import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';

/// Industrial drilling / heavy equipment background graphic.
/// Scales to match the exact full width of the mobile app screen.
class IndustrialMachineGraphic extends StatelessWidget {
  final double opacity;
  final double? height;
  final BoxFit fit;

  const IndustrialMachineGraphic({
    super.key,
    this.opacity = 0.95,
    this.height,
    this.fit = BoxFit.fitWidth,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Opacity(
      opacity: opacity,
      child: Image.asset(
        AssetPaths.heavyMachineBg,
        width: screenWidth,
        height: height,
        fit: fit,
        alignment: Alignment.bottomCenter,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          height: height ?? 280.0,
          width: screenWidth,
          child: CustomPaint(
            painter: _MachineVectorPainter(),
          ),
        ),
      ),
    );
  }
}

/// Custom vector painter representing horizontal directional drilling / excavator equipment
class _MachineVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.borderGray.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final darkPaint = Paint()
      ..color = AppColors.deepNavy.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final greenLinePaint = Paint()
      ..color = AppColors.darkHeroGreen.withValues(alpha: 0.25)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final groundY = size.height * 0.82;

    // Ground level line
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      linePaint,
    );

    // Drilling path trajectory
    final path = Path()
      ..moveTo(size.width * 0.15, groundY)
      ..quadraticBezierTo(
        size.width * 0.5,
        groundY + 40,
        size.width * 0.85,
        groundY + 15,
      );
    canvas.drawPath(path, greenLinePaint);

    // Track 1
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.1, groundY - 35, size.width * 0.35, 32),
      const Radius.circular(10),
    );
    canvas.drawRRect(trackRect, darkPaint);

    // Body Cabin
    final bodyPath = Path()
      ..moveTo(size.width * 0.15, groundY - 35)
      ..lineTo(size.width * 0.18, groundY - 95)
      ..lineTo(size.width * 0.38, groundY - 95)
      ..lineTo(size.width * 0.42, groundY - 35)
      ..close();
    canvas.drawPath(bodyPath, darkPaint);

    // Drill Mast
    canvas.drawLine(
      Offset(size.width * 0.35, groundY - 45),
      Offset(size.width * 0.72, groundY - 145),
      linePaint..strokeWidth = 10,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
