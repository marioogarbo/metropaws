import 'package:flutter/material.dart';

import '../../theme.dart';

/// The shared shell for the "how this works" sheets reached from the help icon
/// in a screen's AppBar: a draggable, scrollable surface with a grab handle, a
/// display-size title, an optional intro line, and the support address pinned
/// at the end. Screens supply only their own body, so two sheets can't drift
/// apart on padding, corner radius or drag extents.
class MpHelpSheet extends StatelessWidget {
  const MpHelpSheet({
    super.key,
    required this.title,
    required this.children,
    this.intro,
  });

  final String title;

  /// One line under the title setting up what the sheet covers. Omit it when
  /// the first section speaks for itself.
  final String? intro;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? AppColors.gold : AppColors.goldDark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(title, style: theme.textTheme.displaySmall),
                  if (intro != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      intro!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Questions? csr@metropaws.ph',
                      style: theme.textTheme.bodyMedium?.copyWith(color: gold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section heading inside an [MpHelpSheet] body. The gap above it belongs to
/// the caller, so the first heading can sit tight under the intro while later
/// ones get room to breathe.
class MpHelpHeading extends StatelessWidget {
  const MpHelpHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// A bullet line inside an [MpHelpSheet] body.
class MpHelpBullet extends StatelessWidget {
  const MpHelpBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
