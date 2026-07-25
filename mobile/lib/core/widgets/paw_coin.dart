import 'package:flutter/material.dart';

import '../../theme.dart';

/// The PawPoints brand mark: a gold coin with a paw punched into it, matching
/// the "paw coin" identity used across MetroPaws marketing material. Use this
/// wherever PawPoints needs an icon — never a star (stars are reserved for
/// "featured/bonus" meanings like the Founding Member badge).
///
/// Built from brand tokens only (gold fill, goldDark rim, dark-navy paw — the
/// same dark-on-gold pairing as the gold CTA buttons), so it stays crisp at
/// any size and needs no image asset. If a production coin graphic arrives
/// later, swap the internals here and every usage updates.
class PawCoin extends StatelessWidget {
  final double size;
  const PawCoin({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
        border: Border.all(
          color: AppColors.goldDark.withValues(alpha: 0.6),
          // Rim scales with the coin; floor keeps it visible at small sizes.
          width: (size * 0.06).clamp(1.0, 2.0),
        ),
      ),
      child: Center(
        child: Icon(Icons.pets, size: size * 0.56, color: AppColors.text),
      ),
    );
  }
}
