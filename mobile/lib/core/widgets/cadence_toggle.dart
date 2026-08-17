import 'package:flutter/material.dart';

import 'scale_button.dart';

/// Annual / monthly choice, shared by the two places a plan can be bought:
/// `PlanSelectionScreen` (an existing pet) and `AddPetScreen` (registration).
///
/// It lives here rather than in either screen because those two surfaces have
/// drifted apart before — the Pack Discount had to be taught to both
/// separately — and a member who signs up through registration must see the
/// same options as one upgrading later.
///
/// Two segments rather than a switch: neither option is the "off" state. Paying
/// monthly is a different arrangement, not a disabled version of paying yearly.
class CadenceToggle extends StatelessWidget {
  /// 'annual' or 'monthly'.
  final String cadence;
  final ValueChanged<String> onChanged;

  const CadenceToggle({
    super.key,
    required this.cadence,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget segment(String value, String label) {
      final selected = cadence == value;
      return Expanded(
        child: ScaleButton(
          onTap: () => onChanged(value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: tt.labelLarge?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              segment('annual', 'Pay yearly'),
              segment('monthly', 'Pay monthly'),
            ],
          ),
        ),
        if (cadence == 'monthly') ...[
          const SizedBox(height: 8),
          Text(
            'Monthly memberships start with app access, and benefits open up '
            'as your payments continue.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
