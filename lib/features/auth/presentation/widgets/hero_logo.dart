import 'package:flutter/material.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/theme/app_colors.dart';

/// Reusable HERO APP Brand Logo Widget loading official PNG logo asset with vector fallback
class HeroLogo extends StatelessWidget {
  final double width;
  final bool showTagline;
  final bool useShieldLogo;

  const HeroLogo({
    super.key,
    this.width = 120.0,
    this.showTagline = false,
    this.useShieldLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AssetPaths.logo,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => useShieldLogo
          ? _ShieldHeroLogo(width: width)
          : _VectorHeroLogo(width: width),
    );
  }
}

/// Official Shield Badge Logo matching reference mockup
class _ShieldHeroLogo extends StatelessWidget {
  final double width;

  const _ShieldHeroLogo({required this.width});

  @override
  Widget build(BuildContext context) {
    final height = width * 1.25;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ShieldBorderPainter(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            Icon(
              Icons.precision_manufacturing_rounded,
              color: const Color(0xFF1B4332),
              size: width * 0.28,
            ),
            const SizedBox(height: 2),
            Text(
              'HERO',
              style: TextStyle(
                fontSize: width * 0.22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1B4332),
                letterSpacing: 1.0,
                height: 1.0,
              ),
            ),
            Text(
              'APP',
              style: TextStyle(
                fontSize: width * 0.18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF7CB342),
                letterSpacing: 1.0,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShieldBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B4332)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.08, h * 0.14);
    path.lineTo(w * 0.5, h * 0.04);
    path.lineTo(w * 0.92, h * 0.14);
    path.lineTo(w * 0.92, h * 0.58);
    path.cubicTo(w * 0.92, h * 0.85, w * 0.5, h * 0.98, w * 0.5, h * 0.98);
    path.cubicTo(w * 0.5, h * 0.85, w * 0.08, h * 0.58, w * 0.08, h * 0.58);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vector logo representation for HERO APP
class _VectorHeroLogo extends StatelessWidget {
  final double width;

  const _VectorHeroLogo({required this.width});

  @override
  Widget build(BuildContext context) {
    final height = width * 0.3;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Hex Badge with Heavy Machine / Drill Icon
            Container(
              width: height * 0.8,
              height: height * 0.8,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(height * 0.22),
              ),
              child: Center(
                child: Icon(
                  Icons.precision_manufacturing_rounded,
                  color: AppColors.white,
                  size: height * 0.48,
                ),
              ),
            ),
            SizedBox(width: width * 0.04),
            // HERO APP Text
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HERO',
                  style: TextStyle(
                    fontSize: height * 0.48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepNavy,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'APP',
                    style: TextStyle(
                      fontSize: height * 0.36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
