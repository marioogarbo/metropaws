import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/app_notification.dart';
import '../../../core/widgets/mp_empty_state.dart';
import '../../../core/widgets/mp_skeleton.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';
import 'reimbursement_screen.dart';

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = dt.toLocal();
  return '${months[d.month - 1]} ${d.day}';
}

/// The bell icon's inbox: in-app notifications, newest first. Tapping a
/// reimbursement notification marks it read and opens My Claims.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;

  @override
  void initState() {
    super.initState();
    context.read<MemberBloc>().add(NotificationsLoadRequested());
  }

  void _open(AppNotification n) {
    if (!n.isRead) {
      context.read<MemberBloc>().add(NotificationReadRequested(n.id));
    }
    if (n.type == 'reimbursement') {
      final bloc = context.read<MemberBloc>();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: const ReimbursementScreen(initialTab: 0), // My Claims
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasUnread = _items?.any((n) => !n.isRead) ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge!
              .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => context
                  .read<MemberBloc>()
                  .add(NotificationsReadAllRequested()),
              child: Text(
                'Mark all read',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: BlocConsumer<MemberBloc, MemberState>(
        listenWhen: (_, c) => c is NotificationsLoaded,
        listener: (context, state) {
          if (state is NotificationsLoaded) {
            setState(() => _items = state.notifications);
          }
        },
        buildWhen: (_, c) =>
            c is NotificationsLoaded || c is NotificationsFailure,
        builder: (context, state) {
          if (state is NotificationsFailure && _items == null) {
            return _Empty(
              icon: '😕',
              title: 'Could not load notifications',
              subtitle: state.message,
            );
          }
          final items = _items ??
              (state is NotificationsLoaded ? state.notifications : null);
          if (items == null) {
            return const MpSkeleton(items: 5);
          }
          if (items.isEmpty) {
            return const MpEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message:
                  'Updates about your claims and benefits will land here.',
            );
          }
          return RefreshIndicator(
            color: cs.primary,
            onRefresh: () async =>
                context.read<MemberBloc>().add(NotificationsLoadRequested()),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                return InkWell(
                  onTap: () => _open(n),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead ? cs.surface : cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isRead
                            ? cs.outline
                            : cs.secondary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          n.type == 'reimbursement'
                              ? Icons.receipt_long_outlined
                              : Icons.notifications_outlined,
                          size: 20,
                          color: n.isRead ? cs.onSurfaceVariant : cs.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: theme.textTheme.labelLarge!
                                          .copyWith(
                                        fontWeight: n.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(n.createdAt),
                                    style: theme.textTheme.labelSmall!
                                        .copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              if ((n.body ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  n.body!,
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cs.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge!
                  .copyWith(fontWeight: FontWeight.w800, color: cs.primary),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!
                  .copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
