import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/pet.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../core/widgets/tier_badge.dart';
import '../../../theme.dart';
import '../bloc/member_bloc.dart';
import 'pet_form_screen.dart';

/// The small uppercase group header ("MEMBERSHIP", "PET DETAILS", ...) shared
/// by every section on this screen — a single source so they can't drift
/// out of sync the way two separately hand-copied TextStyles eventually do.
TextStyle? _sectionLabelStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w600,
  );
}

class PetProfileScreen extends StatefulWidget {
  final Pet pet;
  const PetProfileScreen({super.key, required this.pet});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  late Pet _pet = widget.pet;
  // True only when verification is crossed live in this session (e.g. right
  // after the 8th photo upload) — not when the pet was already verified on
  // page load, so the badge only "arrives" for a moment that actually earns it.
  bool _justVerified = false;

  static const _heroExpandedHeight = 280.0;
  final ScrollController _scrollController = ScrollController();

  void _handlePetUpdated(Pet updated) {
    final crossedNow = !_pet.isProfileVerified && updated.isProfileVerified;
    setState(() {
      _pet = updated;
      if (crossedNow) _justVerified = true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: _heroExpandedHeight,
              pinned: true,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                Semantics(
                  label: 'Edit ${_pet.name}',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit pet',
                    onPressed: () {
                      final bloc = context.read<MemberBloc>();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: bloc,
                            child: PetFormScreen(pet: _pet),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                // FlexibleSpaceBar's built-in title fade starts appearing well
                // before the hero has actually collapsed, so the compact
                // white title was showing up alongside the still-visible gold
                // name in the photo — same information rendered twice at
                // once. Drive opacity from real scroll offset instead: stay
                // invisible until the last ~15% of the collapse range.
                title: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    final offset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0;
                    final collapseRange =
                        _heroExpandedHeight - kToolbarHeight;
                    final t = collapseRange > 0
                        ? (offset / collapseRange).clamp(0.0, 1.0)
                        : 1.0;
                    final opacity = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
                    return Opacity(opacity: opacity, child: child);
                  },
                  child: Text(
                    _pet.name,
                    // headlineSmall (20sp/w700) instead of a hand-copied
                    // literal — same value, one source of truth.
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                ),
                // FlexibleSpaceBar's collapsed title doesn't know the leading
                // back button reserves 56dp — start:16 put "Jelly" directly
                // under the arrow once the bar collapsed. Clear it properly.
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 56,
                  bottom: 16,
                ),
                background: _HeroSection(pet: _pet, animateBadgeIn: _justVerified),
              ),
            ),
            SliverToBoxAdapter(
              child: _ProfileBody(
                pet: _pet,
                onPetUpdated: _handlePetUpdated,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Pet pet;
  final bool animateBadgeIn;
  const _HeroSection({required this.pet, this.animateBadgeIn = false});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Decode at the hero's actual display resolution instead of whatever the
    // source photo was shot at — a phone-camera original can be 3000px+ wide
    // for a region that only ever renders at ~280 logical px tall.
    final cacheWidth = (media.size.width * media.devicePixelRatio).round();
    const heroHeight = 280.0;
    final cacheHeight = (heroHeight * media.devicePixelRatio).round();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (pet.photoUrl != null)
          Image.network(
            pet.photoUrl!,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            errorBuilder: (context, error, _) => _NavyFallback(pet: pet),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                );
              }
              return _NavyFallback(pet: pet);
            },
          )
        else
          _NavyFallback(pet: pet),
        // Bottom gradient for text legibility
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xCC000000)],
              stops: [0.4, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                pet.name.toUpperCase(),
                // displaySmall (28sp/w800) is the project's own mandated
                // size for a pet name in any context — was a hand-picked
                // 30sp that happened to clear the same minimum.
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (pet.species != null || pet.breed != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    [
                      if (pet.species != null) pet.species!,
                      if (pet.breed != null) pet.breed!,
                    ].join(' · '),
                    // labelLarge (14sp/w600) — was an arbitrary 13sp that
                    // didn't belong to the app's defined scale.
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
              if (pet.isProfileVerified) ...[
                const SizedBox(height: 10),
                animateBadgeIn
                    ? const _AnimatedBadgeEntrance(child: _VerifiedBadge())
                    : const _VerifiedBadge(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NavyFallback extends StatelessWidget {
  final Pet pet;
  const _NavyFallback({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      child: Align(
        alignment: const Alignment(0, -0.3),
        child: PetAvatar(photoUrl: null, size: 88, petName: pet.name),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final Pet pet;
  final ValueChanged<Pet> onPetUpdated;
  const _ProfileBody({required this.pet, required this.onPetUpdated});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDetails =
        (pet.birthMonth != null && pet.birthYear != null) ||
        pet.weightKg != null ||
        pet.sex != null ||
        (pet.notes != null && pet.notes!.isNotEmpty);

    final sectionLabelStyle = _sectionLabelStyle(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredReveal(index: 0, child: _PlanSection(pet: pet)),
          const SizedBox(height: 32),
          if (hasDetails) ...[
            StaggeredReveal(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PET DETAILS', style: sectionLabelStyle),
                  const SizedBox(height: 12),
                  _DetailsCard(pet: pet),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          StaggeredReveal(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('HEALTH RECORDS', style: sectionLabelStyle),
                const SizedBox(height: 12),
                _VaxSection(vaxCardUrl: pet.vaxCardUrl),
              ],
            ),
          ),
          if (pet.uploadedPhotos.isNotEmpty) ...[
            const SizedBox(height: 32),
            StaggeredReveal(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PET PHOTOS', style: sectionLabelStyle),
                  const SizedBox(height: 6),
                  Text(
                    'The identity photos on file for ${pet.name}. Tap one to view it larger.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  _PhotoGallery(pet: pet),
                ],
              ),
            ),
          ],
          if (pet.remainingPhotoSlots.isNotEmpty) ...[
            const SizedBox(height: 32),
            StaggeredReveal(
              index: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('COMPLETE YOUR PET\'S PROFILE', style: sectionLabelStyle),
                  const SizedBox(height: 6),
                  Text(
                    'Add the remaining photos to earn a Verified profile badge.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _PhotoProgress(remaining: pet.remainingPhotoSlots.length),
                  const SizedBox(height: 12),
                  _PhotoCompletionSection(pet: pet, onPetUpdated: onPetUpdated),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Pet pet;
  const _DetailsCard({required this.pet});

  // "0 years" reads as broken for a pet under a year old — show months
  // instead until there's at least one full year to report.
  String? _formatAge() {
    final months = pet.computedAgeMonths;
    if (months == null) return null;
    if (months < 12) return '$months ${months == 1 ? 'month' : 'months'}';
    final years = pet.computedAge!;
    return '$years ${years == 1 ? 'year' : 'years'}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_RowData>[];
    final age = _formatAge();
    if (age != null) {
      rows.add(_RowData('Age', age));
    }
    if (pet.weightKg != null) {
      rows.add(_RowData('Weight', '${pet.weightKg!.toStringAsFixed(1)} kg'));
    }
    if (pet.sex != null && pet.sex!.isNotEmpty) {
      final sexLabel = '${pet.sex![0].toUpperCase()}${pet.sex!.substring(1)}';
      rows.add(_RowData('Sex', sexLabel));
    }
    if (pet.notes != null && pet.notes!.isNotEmpty) {
      rows.add(_RowData('Notes', pet.notes!));
    }

    // Label prominent, value muted — matches the settings-row convention used
    // by _AccountRow elsewhere in the app, and gives label vs. value a real
    // weight contrast instead of relying on color alone (both were 14sp/w600).
    Widget buildRow(int i) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rows[i].label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              rows[i].value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );

    if (rows.length == 1) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: buildRow(0),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        // Theme-driven outline (not a hardcoded light-mode grey) so the
        // border resolves correctly in dark mode too.
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            buildRow(i),
            if (i < rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outline,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _RowData {
  final String label;
  final String value;
  const _RowData(this.label, this.value);
}

class _PlanSection extends StatelessWidget {
  final Pet pet;
  const _PlanSection({required this.pet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final hasActivePlan = pet.planType != null;
    // Same fix as _VaxSection: navy is fixed-brand (never lightens for dark
    // mode), so it's invisible as text on the dark elevated card below.
    final isDark = theme.brightness == Brightness.dark;
    final planTextColor = isDark ? cs.onSurface : AppColors.navy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MEMBERSHIP', style: _sectionLabelStyle(context)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            // goldLight is a fixed brand cream — swap to its dark-mode
            // counterpart or the card stays cream while its text follows the
            // theme to a light color, reading as washed-out gray-on-cream.
            color: hasActivePlan
                ? cs.surfaceContainerHighest
                : (isDark ? AppDarkColors.goldBg : AppColors.goldLight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasActivePlan
                  ? cs.outline
                  : AppColors.gold.withValues(alpha: 0.3),
            ),
          ),
          child: hasActivePlan
              ? Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pet.planType!,
                                style: tt.labelLarge?.copyWith(
                                  color: planTextColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TierBadge(planType: pet.planType!),
                            ],
                          ),
                          if (pet.planActivatedAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Active since ${_formatDate(pet.planActivatedAt!)}',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const Icon(Icons.workspace_premium_outlined,
                        color: AppColors.gold, size: 28),
                    const SizedBox(height: 10),
                    Text(
                      'No active plan',
                      style: tt.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a plan from the Home tab to unlock sessions and clinic access.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _VaxSection extends StatelessWidget {
  final String? vaxCardUrl;
  const _VaxSection({this.vaxCardUrl});

  Future<void> _openVaxCard(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the card. Contact your clinic.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (vaxCardUrl == null) {
      // goldLight is a fixed brand cream — never lightens/darkens itself, so
      // without this swap the card stayed cream in dark mode while its text
      // correctly followed the theme to a light color, reading as washed-out
      // gray-on-cream. Same fix as the badge/tier-card pattern elsewhere.
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppDarkColors.goldBg : AppColors.goldLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.gold, size: 32),
            const SizedBox(height: 12),
            Text(
              'No vaccination card yet',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Contact your clinic to upload your vaccination record',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: 'View vaccination card',
      button: true,
      child: InkWell(
        onTap: () => _openVaxCard(context, vaxCardUrl!),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              // AppColors.navy is a fixed brand color (colorScheme.primary
              // stays navy in both themes by design), so it never lightens
              // for dark mode — on the dark elevated card above it was
              // near-invisible (navy text on a near-navy background).
              // onSurface is the theme's guaranteed-contrast fallback there.
              final isDark = theme.brightness == Brightness.dark;
              final confirmedColor = isDark ? cs.onSurface : AppColors.navy;
              return Row(
                children: [
                  Icon(Icons.verified, color: confirmedColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vaccination card on file',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: confirmedColor,
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 16, color: AppColors.grey),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One-time pop + fade for the Verified badge when it's earned live in this
/// session (see [_PetProfileScreenState._handlePetUpdated]) — matches the
/// spring feel of [ScaleButton]'s tap feedback elsewhere in the app, since
/// this is the milestone payoff of the whole photo-completion feature.
class _AnimatedBadgeEntrance extends StatelessWidget {
  final Widget child;
  const _AnimatedBadgeEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: child),
      ),
      child: child,
    );
  }
}

/// Shown near a pet's name once all 8 identity photos (MP-FRM-PET-001) are on
/// file — signals a verified, fraud-checked profile. Reuses the gold-pill
/// pattern from the Founding Member badge (Account tab / Home dashboard).
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 13, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            'Verified Profile',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling row of every identity photo already on file —
/// the pet's hero only ever shows the front face, so this is the only place
/// a member can see the other required photos (full body, with owner) they
/// uploaded at registration, plus any optional ones added since.
class _PhotoGallery extends StatelessWidget {
  final Pet pet;
  const _PhotoGallery({required this.pet});

  @override
  Widget build(BuildContext context) {
    final photos = pet.uploadedPhotos;
    final media = MediaQuery.of(context);
    const thumbSize = 88.0;
    final cacheDim = (thumbSize * media.devicePixelRatio).round();

    // A horizontal ListView needs a bounded height, but the label below each
    // thumb grows with the system font scale. Derive the height from the
    // actual scaled label size (two lines, so longer names like "Pet with ID
    // card" wrap instead of truncating to "Pet with…") so it never overflows.
    final labelLine = media.textScaler.scale(12); // labelSmall base size
    final rowHeight = thumbSize + 4 + labelLine * 1.3 * 2;

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _PhotoThumb(
          photo: photos[i],
          size: thumbSize,
          cacheDim: cacheDim,
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final PetPhoto photo;
  final double size;
  final int cacheDim;
  const _PhotoThumb({
    required this.photo,
    required this.size,
    required this.cacheDim,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'View ${photo.label} photo',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _PhotoViewerScreen(photo: photo)),
        ),
        child: SizedBox(
          width: size,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  photo.url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth: cacheDim,
                  cacheHeight: cacheDim,
                  errorBuilder: (context, error, _) => Container(
                    width: size,
                    height: size,
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                photo.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom view of one uploaded identity photo.
class _PhotoViewerScreen extends StatelessWidget {
  final PetPhoto photo;
  const _PhotoViewerScreen({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(photo.label),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(photo.url),
        ),
      ),
    );
  }
}

/// Total identity-photo slots (MP-FRM-PET-001): front face, full body,
/// pet+owner, left/right profile, rear, top, pet+ID card.
const _kTotalIdentityPhotos = 8;

/// Gold fill on a neutral track, reusing the exact progress-bar idiom from
/// [WalletPetCard] so "earning toward a reward" reads consistently
/// across the app.
class _PhotoProgress extends StatelessWidget {
  final int remaining;
  const _PhotoProgress({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final completed = _kTotalIdentityPhotos - remaining;
    final pct = completed / _kTotalIdentityPhotos;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            // Animates from whatever value it last held to the new one —
            // without this the bar would jump-cut on every upload instead of
            // filling, which is the one moment on this screen most worth
            // seeing move.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.secondary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$completed of $_kTotalIdentityPhotos',
          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Lists the identity-photo slots not yet captured (MP-FRM-PET-001 slots 4-8)
/// so the member can complete their pet's verified profile after
/// registration. Each row uploads independently via [ApiService.uploadPetPhotoSlot]
/// and reports the refreshed pet back up through [onPetUpdated].
class _PhotoCompletionSection extends StatefulWidget {
  final Pet pet;
  final ValueChanged<Pet> onPetUpdated;
  const _PhotoCompletionSection({required this.pet, required this.onPetUpdated});

  @override
  State<_PhotoCompletionSection> createState() => _PhotoCompletionSectionState();
}

class _PhotoCompletionSectionState extends State<_PhotoCompletionSection> {
  String? _uploadingField;
  String? _justCompletedField;
  String? _exitingField;
  String? _collapsingField;

  Future<void> _addPhoto(PetPhotoSlot slot) async {
    // Re-entrancy guard: the picker sheet takes a moment to appear, and
    // onTap isn't disabled until _uploadingField is set below — without this,
    // a fast double-tap can open the OS picker twice.
    if (_uploadingField != null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > ApiService.maxUploadBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'That photo is over ${ApiService.maxUploadMb} MB. Please choose a smaller one.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    // picked.name (not .path) — on web, XFile.path is a blob: URL with no
    // real extension, which sends the wrong extension to the backend.
    final ext = picked.name.split('.').last.toLowerCase();

    setState(() => _uploadingField = slot.field);
    try {
      final updated = await ApiService.uploadPetPhotoSlot(
        widget.pet.id,
        slot.field,
        bytes,
        ext,
      );
      if (!mounted) return;
      // Register the success visually before the row leaves the list — an
      // instant vanish reads as "did that even work?" Sequence: hold the
      // gold "Added" state, fade out, then collapse the now-empty space.
      // Exit is faster than the entrance/hold, per the app's motion rules.
      setState(() {
        _uploadingField = null;
        _justCompletedField = slot.field;
      });
      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;
      setState(() {
        _justCompletedField = null;
        _exitingField = slot.field;
      });
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() {
        _exitingField = null;
        _collapsingField = slot.field;
      });
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) widget.onPetUpdated(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload that photo. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingField = null;
          _justCompletedField = null;
          _exitingField = null;
          _collapsingField = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.pet.remainingPhotoSlots;
    return Column(
      children: [
        for (int i = 0; i < slots.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i > 0 ? 8 : 0),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _collapsingField == slots[i].field
                  ? const SizedBox.shrink()
                  : AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _exitingField == slots[i].field ? 0.0 : 1.0,
                      child: _PhotoSlotRow(
                        slot: slots[i],
                        uploading: _uploadingField == slots[i].field,
                        justCompleted: _justCompletedField == slots[i].field,
                        locked:
                            _justCompletedField == slots[i].field ||
                            _exitingField == slots[i].field ||
                            _collapsingField == slots[i].field,
                        onTap: () => _addPhoto(slots[i]),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _PhotoSlotRow extends StatelessWidget {
  final PetPhotoSlot slot;
  final bool uploading;
  final bool justCompleted;
  // True for justCompleted plus the exiting/collapsing phases that follow it
  // — the row is on its way out and shouldn't accept a tap in that window.
  final bool locked;
  final VoidCallback onTap;
  const _PhotoSlotRow({
    required this.slot,
    required this.uploading,
    required this.justCompleted,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Gold marks "action available to earn a reward," matching the vax-card
    // empty state above it and the payout-setup row on the Account tab —
    // goldDark keeps it readable on the light Standard-tier surface.
    final goldText = isDark ? AppColors.gold : AppColors.goldDark;

    return Semantics(
      label: justCompleted ? '${slot.label} photo added' : 'Add ${slot.label} photo',
      button: true,
      child: InkWell(
        onTap: (uploading || locked) ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: justCompleted
                ? (isDark ? AppDarkColors.goldBg : AppColors.goldLight)
                : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: justCompleted
                  ? AppColors.gold.withValues(alpha: 0.4)
                  : cs.outline,
            ),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: justCompleted
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('done'),
                        size: 20,
                        color: AppColors.gold,
                      )
                    : Icon(
                        Icons.add_a_photo_outlined,
                        key: const ValueKey('add'),
                        size: 20,
                        color: goldText,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      justCompleted ? 'Added' : slot.hint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: justCompleted ? goldText : cs.onSurfaceVariant,
                        fontWeight: justCompleted ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (uploading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    // Same fix as the vax "on file" row: navy is fixed-brand
                    // and invisible against this card's dark-mode surface.
                    color: isDark ? cs.onSurface : AppColors.navy,
                  ),
                )
              else if (!justCompleted)
                Icon(Icons.chevron_right_rounded, size: 20, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}
