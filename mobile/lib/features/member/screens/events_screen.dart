import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/promo.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_empty_state.dart';
import '../../../core/widgets/mp_skeleton.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../theme.dart';
import 'member_dashboard_screen.dart' show kNavClearance;
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';

const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The "Events" bottom-tab hub — the Book tab's stand-in while booking is on
/// standby (no partner clinics yet). Surfaces club events and member promos,
/// delivering the "member promos and event access" plan features.
class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  List<Promo>? _promos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _load() => context.read<MemberBloc>().add(PromosLoadRequested());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocConsumer<MemberBloc, MemberState>(
      // Single-stream bloc: every consumer MUST filter, or the 60s notification
      // poll and unrelated states rebuild this tab.
      listenWhen: (_, s) => s is PromosLoaded,
      buildWhen: (_, s) =>
          s is PromosLoading || s is PromosLoaded || s is PromosFailure,
      listener: (context, state) {
        if (state is PromosLoaded) _promos = state.promos;
      },
      builder: (context, state) {
        if (state is PromosLoaded) _promos = state.promos;

        return RefreshIndicator(
          color: cs.primary,
          onRefresh: () async => _load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 40 + kNavClearance),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Events', style: theme.textTheme.displaySmall),
                ),
                const SizedBox(height: 6),
                Text(
                  'Club events and member promos',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildContent(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildContent(BuildContext context, MemberState state) {
    final promos = _promos;
    if (promos == null) {
      if (state is PromosFailure) {
        return [_ErrorState(message: state.message, onRetry: _load)];
      }
      return const [
        MpSkeleton(
          items: 3,
          itemHeight: 96,
          padding: EdgeInsets.only(top: 8),
        ),
      ];
    }
    if (promos.isEmpty) {
      return const [
        MpEmptyState(
          icon: Icons.celebration_outlined,
          title: 'Nothing on the calendar yet',
          message: 'Club events and member promos will show up here. '
              'Watch this space.',
          padding: EdgeInsets.only(top: 40),
        ),
      ];
    }

    final events = promos.where((p) => p.isEvent).toList()
      // Soonest event first; undated events keep their admin order at the end.
      ..sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });
    final offers = promos.where((p) => !p.isEvent).toList();

    var revealIndex = 0;
    return [
      if (events.isNotEmpty) ...[
        _SectionHeader(title: 'Upcoming events'),
        const SizedBox(height: 12),
        for (final e in events) ...[
          StaggeredReveal(
            index: revealIndex++,
            child: _EventCard(promo: e),
          ),
          const SizedBox(height: 12),
        ],
      ],
      if (offers.isNotEmpty) ...[
        if (events.isNotEmpty) const SizedBox(height: 16),
        _SectionHeader(title: 'Member promos'),
        const SizedBox(height: 12),
        for (final p in offers) ...[
          StaggeredReveal(
            index: revealIndex++,
            child: _PromoCard(promo: p),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.headlineSmall);
  }
}

void _openLink(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Shared card shell: surface fill, 16px radius, outline border, optional tap.
class _PromoShell extends StatelessWidget {
  final Widget child;
  final String? linkUrl;
  const _PromoShell({required this.child, this.linkUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: child,
    );

    final url = linkUrl;
    if (url == null || url.isEmpty) return card;
    return ScaleButton(onTap: () => _openLink(url), child: card);
  }
}

class _EventCard extends StatelessWidget {
  final Promo promo;
  const _EventCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = promo.eventDate?.toLocal();
    final body = promo.body;

    return _PromoShell(
      linkUrl: promo.linkUrl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventDateBlock(date: date),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (promo.location != null && promo.location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          promo.location!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (promo.linkUrl != null && promo.linkUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _LearnMoreLink(label: 'View details'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calendar-leaf date block: big day number over the month, navy-tinted fill.
class _EventDateBlock extends StatelessWidget {
  final DateTime? date;
  const _EventDateBlock({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final d = date;

    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: d == null
          ? Icon(
              Icons.celebration_outlined,
              color: isDark ? AppColors.gold : cs.primary,
            )
          : Column(
              children: [
                Text(
                  '${d.day}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.gold : cs.primary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _kShortMonths[d.month - 1].toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Promo promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final goldInk = isDark ? AppColors.gold : AppColors.goldDark;
    final body = promo.body;

    return _PromoShell(
      linkUrl: promo.linkUrl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_offer_outlined, size: 20, color: goldInk),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (promo.linkUrl != null && promo.linkUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _LearnMoreLink(label: 'Learn more'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnMoreLink extends StatelessWidget {
  final String label;
  const _LearnMoreLink({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? AppColors.gold : theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Icon(Icons.chevron_right_rounded, size: 18, color: color),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text("Couldn't load events", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: MpButton(label: 'Try again', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
