import 'package:flutter/material.dart';
import '../../theme.dart';

class MpBrandPhotoStrip extends StatelessWidget {
  final String imagePath;
  final String tagline;
  final double height;

  const MpBrandPhotoStrip({
    super.key,
    required this.imagePath,
    required this.tagline,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Container(color: AppColors.navy),
          ),
          // Gradient: subtle navy tint over photo → bleeds seamlessly into
          // scaffold background so the image dissolves into the form below.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  AppColors.navy.withValues(alpha: 0.30),
                  AppColors.navy.withValues(alpha: 0.52),
                  scaffoldBg,
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Text(
              tagline,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                letterSpacing: -0.3,
                shadows: [
                  Shadow(
                    color: AppColors.navy.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
