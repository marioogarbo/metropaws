import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/member.dart';
import '../../../core/models/reimbursement.dart';
import '../../../core/models/reimbursement_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_dropdown_field.dart';
import '../../../core/widgets/mp_empty_state.dart';
import '../../../core/widgets/mp_skeleton.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../core/widgets/staggered_reveal.dart';
import '../../../core/widgets/tier_badge.dart';
import '../../../theme.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';
import 'payout_details_screen.dart';

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Parses a peso amount tolerating thousands separators ("1,500.00" — a
/// common PH formatting habit that plain [double.tryParse] rejects).
double? _parseAmount(String? raw) =>
    double.tryParse((raw ?? '').replaceAll(',', '').trim());

class ReimbursementScreen extends StatefulWidget {
  /// Tab to open on: 0 = My Claims, 1 = Submit. The Wallet balances already
  /// live on the Benefits hub, so this screen doesn't repeat them.
  final int initialTab;
  const ReimbursementScreen({super.key, this.initialTab = 0});

  @override
  State<ReimbursementScreen> createState() => _ReimbursementScreenState();
}

class _ReimbursementScreenState extends State<ReimbursementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedPetId;
  String? _selectedServiceTypeId;
  DateTime _serviceDate = DateTime.now();
  Uint8List? _receiptBytes;
  String? _receiptExt;
  bool _receiptMissing = false; // inline error under the attach tile
  bool _submitting = false;
  Member? _member;

  // Cached reimbursement data, held in State so the static Submit form + tab
  // chrome render immediately and transient bloc states (submitting, silent
  // refresh) don't blank the screen. The skeleton shows only in the tab that's
  // actually waiting on the first network load.
  Wallet _wallet = const Wallet();
  List<Reimbursement> _claims = const [];
  List<ReimbursementProvider> _providers = const [];
  bool _reimbLoaded = false; // first successful load has landed
  String? _reimbError; // last load failure (drives the in-tab error state)

  // 'member' (default, reimburse the member — existing flow) or 'provider'
  // (MetroPaws pays the selected provider directly). Only offered when the
  // backend flag is on AND the chosen category is non-emergency.
  String _payoutTarget = 'member';
  String? _selectedProviderId;
  String? _selectedProviderName;
  // Effective availability for THIS member — never read the global flag
  // directly at a UI site. An admin can restrict one member while the feature
  // stays on for everyone else, and only the wallet payload knows that.
  bool _directProviderPaymentEnabled = false;
  // Last-known global switch, kept so the effective value can be recomputed
  // when either input changes, and as the fallback for a backend too old to
  // send the member-scoped value.
  bool _globalDirectPayEnabled = false;

  /// Recompute [_directProviderPaymentEnabled] from the member-scoped wallet
  /// value, falling back to the global switch, and revert an in-progress
  /// provider selection if the option just went away — otherwise the form could
  /// submit a target the server will now refuse. Call from inside setState.
  void _applyDirectPayAvailability() {
    final effective = _wallet.directPayAvailable ?? _globalDirectPayEnabled;
    if (effective == _directProviderPaymentEnabled) return;
    _directProviderPaymentEnabled = effective;
    if (!effective && _payoutTarget == 'provider') {
      _payoutTarget = 'member';
      _selectedProviderId = null;
      _selectedProviderName = null;
      _serviceDate = DateTime.now();
    }
  }

  // The selected pet's plan tier, shown as a badge on the Submit form so the
  // member sees which plan their reimbursement cap comes from. Null when no pet
  // is selected, the member isn't loaded, or the pet has no active plan.
  String? _planTypeFor(String? petId) {
    if (petId == null) return null;
    final pets = _member?.pets;
    if (pets == null) return null;
    for (final p in pets) {
      if (p.id == petId) return p.planType;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    // Catch the member if it loaded before this screen mounted (it usually
    // did — MemberBloc is created at the dashboard shell).
    final bloc = context.read<MemberBloc>();
    final current = bloc.state;
    if (current is MemberLoaded) _member = current.member;
    // If claims were already loaded on a previous visit, seed from them so the
    // list/form show instantly instead of flashing a skeleton on re-entry.
    if (current is ReimbursementLoaded) {
      _wallet = current.wallet;
      _claims = current.claims;
      _providers = current.providers;
      _reimbLoaded = true;
      // Seeded before _globalDirectPayEnabled is read below; the call after it
      // resolves the effective value from both.
      if (current.wallet.pets.isNotEmpty) {
        _selectedPetId = current.wallet.pets.first.petId;
      }
    }
    // The shell's MobileConfigRequested fetch usually already completed by the
    // time a member navigates here — read the bloc's last-known value directly
    // rather than the current MemberState, which has likely moved on by now.
    _globalDirectPayEnabled = bloc.directProviderPaymentEnabled;
    _applyDirectPayAvailability();
    bloc.add(ReimbursementsLoadRequested());
    // Refresh the direct-to-provider flag on open so the "Pay the provider
    // directly" option reflects the current admin setting, not a value cached
    // at app launch. The listener below applies the result (and reverts any
    // in-progress provider selection if it turns out to be off).
    bloc.add(MobileConfigRequested());
  }

  void _openPayoutSetup() {
    final member = _member;
    if (member == null) return;
    final bloc = context.read<MemberBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: PayoutDetailsScreen(member: member),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _amountCtrl.dispose();
    _providerCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    _amountCtrl.clear();
    _providerCtrl.clear();
    _referenceCtrl.clear();
    _notesCtrl.clear();
    _selectedServiceTypeId = null;
    _serviceDate = DateTime.now();
    _receiptBytes = null;
    _receiptExt = null;
    _payoutTarget = 'member';
    _selectedProviderId = null;
    _selectedProviderName = null;
  }

  /// True when the Submit form holds an unsaved draft worth confirming before
  /// the member leaves — mirrors the fields [_resetForm] clears. The
  /// pre-selected pet and default date don't count as a draft on their own.
  bool get _submitDraftDirty =>
      !_submitting &&
      (_amountCtrl.text.trim().isNotEmpty ||
          _providerCtrl.text.trim().isNotEmpty ||
          _referenceCtrl.text.trim().isNotEmpty ||
          _notesCtrl.text.trim().isNotEmpty ||
          _selectedServiceTypeId != null ||
          _receiptBytes != null ||
          _selectedProviderId != null);

  Future<bool> _confirmDiscardDraft() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this claim?'),
        content: const Text(
          "You've started a claim but haven't submitted it. Leaving now "
          'discards what you entered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // ── Receipt picking (photo via image_picker, PDF via file_picker) ──────────

  /// Shows the source sheet and returns the picked file, or null. Pure — no
  /// state writes — so the resubmit sheet can reuse it.
  Future<(Uint8List, String)?> _pickReceiptData() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiptSourceSheet(),
    );
    if (choice == null || !mounted) return null;

    try {
      final (Uint8List, String)? result;
      if (choice == 'pdf') {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
        if (picked == null || picked.files.isEmpty) return null;
        final bytes = picked.files.first.bytes;
        if (bytes == null) return null;
        result = (bytes, 'pdf');
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
        );
        if (picked == null) return null;
        final bytes = await picked.readAsBytes();
        // picked.name (not .path) — on web, XFile.path is a blob: URL with no
        // real extension, which would mislabel the upload's content type.
        final ext = picked.name.split('.').last.toLowerCase();
        result = (bytes, ext == 'png' ? 'png' : 'jpg');
      }
      // Reject oversized files immediately, before the member fills out the
      // rest of the claim form only to have submission fail at the end.
      if (result.$1.length > ApiService.maxUploadBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'That file is over ${ApiService.maxUploadMb} MB. Please choose a smaller one.',
              ),
            ),
          );
        }
        return null;
      }
      return result;
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that file. Please try another.')),
      );
      return null;
    }
  }

  Future<void> _pickReceipt() async {
    final picked = await _pickReceiptData();
    if (picked == null || !mounted) return;
    setState(() {
      _receiptBytes = picked.$1;
      _receiptExt = picked.$2;
      _receiptMissing = false;
    });
  }

  void _submit() {
    if (_submitting) return;
    // Validate the form AND the receipt together so the member sees every
    // problem at once — dropdowns and text fields inline via the Form,
    // the receipt via its own inline error under the attach tile.
    final formOk = _formKey.currentState!.validate();
    final receiptOk = _receiptBytes != null && _receiptExt != null;
    if (!receiptOk) setState(() => _receiptMissing = true);
    if (!formOk || !receiptOk) return;

    final pesos = _parseAmount(_amountCtrl.text) ?? 0;
    final centavos = (pesos * 100).round();

    final isProviderTarget = _payoutTarget == 'provider';

    setState(() => _submitting = true);
    context.read<MemberBloc>().add(
          ReimbursementSubmitted(
            petId: _selectedPetId!,
            serviceTypeId: _selectedServiceTypeId!,
            providerName: isProviderTarget
                ? (_selectedProviderName ?? '')
                : _providerCtrl.text.trim(),
            serviceDate: _serviceDate,
            claimedAmountCentavos: centavos,
            receiptReference: _referenceCtrl.text.trim().isEmpty
                ? null
                : _referenceCtrl.text.trim(),
            memberNotes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            receiptBytes: _receiptBytes!,
            receiptExt: _receiptExt!,
            payoutTarget: _payoutTarget,
            providerId: isProviderTarget ? _selectedProviderId : null,
          ),
        );
  }

  Future<void> _resubmit(Reimbursement claim) async {
    if (_submitting) return;
    // Full-edit resubmit: the admin's complaint may be about the amount,
    // provider, or date — not just the photo — so everything is correctable.
    final result = await showModalBottomSheet<_ResubmitResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResubmitSheet(claim: claim, pickReceipt: _pickReceiptData),
    );
    if (result == null || !mounted) return;
    setState(() => _submitting = true);
    context.read<MemberBloc>().add(
          ReimbursementResubmitted(
            id: claim.id,
            claimedAmountCentavos: result.amountCentavos,
            providerName: result.providerName,
            serviceDate: result.serviceDate,
            memberNotes: result.memberNotes,
            receiptBytes: result.receiptBytes,
            receiptExt: result.receiptExt,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final navy = cs.primary;
    final gold = cs.secondary;

    // Only the FIRST load shows a skeleton; refreshes keep the cached content.
    final loading = !_reimbLoaded && _reimbError == null;

    final scaffold = Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 64,
        // Screen title at display size per the typography mandate ("never use
        // titleLarge as a screen heading") — matches the Benefits hub register.
        // FittedBox guards the long word on narrow (360dp) screens.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 24, color: AppColors.gold),
              const SizedBox(width: 10),
              Text(
                'Reimbursements',
                style: theme.textTheme.displaySmall!.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: gold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle: theme.textTheme.labelLarge!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          tabs: const [
            Tab(text: 'My Claims'),
            Tab(text: 'Submit'),
          ],
        ),
      ),
      body: BlocListener<MemberBloc, MemberState>(
        listenWhen: (_, c) =>
            c is ReimbursementSubmitSuccess ||
            c is ReimbursementSubmitFailure ||
            c is ReimbursementLoaded ||
            c is ReimbursementLoading ||
            c is ReimbursementFailure ||
            c is MemberLoaded ||
            c is PetOperationSuccess ||
            c is PayoutSaveSuccess ||
            c is MobileConfigLoaded,
        listener: (context, state) {
          if (state is MobileConfigLoaded) {
            // Applies both the on-open refresh and any config load that lands
            // while the form is open (e.g. the shell's fetch was still in
            // flight when this screen mounted).
            if (state.directProviderPaymentEnabled !=
                _globalDirectPayEnabled) {
              setState(() {
                _globalDirectPayEnabled = state.directProviderPaymentEnabled;
                // Only takes effect when the wallet hasn't supplied a
                // member-scoped value — a restricted member stays restricted
                // however the global switch moves.
                _applyDirectPayAvailability();
              });
            }
          } else if (state is MemberLoaded) {
            setState(() => _member = state.member);
          } else if (state is PetOperationSuccess) {
            setState(() => _member = state.member);
          } else if (state is PayoutSaveSuccess) {
            setState(() => _member = state.member);
          } else if (state is ReimbursementSubmitSuccess) {
            setState(() {
              _submitting = false;
              _resetForm();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: gold,
              ),
            );
            _tabs.animateTo(0); // jump to My Claims
          } else if (state is ReimbursementSubmitFailure) {
            setState(() => _submitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: cs.error,
              ),
            );
          } else if (state is ReimbursementLoading) {
            // Silent refresh when we already have data (loading stays false via
            // _reimbLoaded); just clear any stale error.
            if (_reimbError != null) setState(() => _reimbError = null);
          } else if (state is ReimbursementFailure) {
            setState(() => _reimbError = state.message);
          } else if (state is ReimbursementLoaded) {
            // Cache so transient states don't blank the form/list, and preselect
            // the first pet. The service category is a deliberate choice
            // (grooming has its own 90-day rule), left to the member.
            setState(() {
              _wallet = state.wallet;
              _claims = state.claims;
              _providers = state.providers;
              _reimbLoaded = true;
              _reimbError = null;
              // The wallet is where per-member availability arrives, so this is
              // the load that can restrict a member mid-session.
              _applyDirectPayAvailability();
              if (_selectedPetId == null && state.wallet.pets.isNotEmpty) {
                _selectedPetId = state.wallet.pets.first.petId;
              }
            });
          }
        },
        // Static form + tab chrome render immediately; only the parts that need
        // the network (claims list, wallet balances) show a skeleton in-place.
        // Cached data (updated in the listener above) survives transient states
        // instead of blanking the whole screen behind one skeleton.
        child: TabBarView(
          controller: _tabs,
          children: [
            _ClaimsTab(
              claims: _claims,
              loading: loading,
              error: _reimbError,
              onRetry: () =>
                  context.read<MemberBloc>().add(ReimbursementsLoadRequested()),
              onResubmit: _resubmit,
            ),
            _buildSubmitTab(_wallet, _providers, loading),
          ],
        ),
      ),
    );

    // Guard against losing an in-progress claim: intercept both the app-bar
    // back and the system/gesture back. canPop:false routes every attempt
    // here; leave immediately when the draft is empty, confirm otherwise.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (!_submitDraftDirty) {
          nav.pop();
          return;
        }
        if (await _confirmDiscardDraft() && mounted) nav.pop();
      },
      child: scaffold,
    );
  }

  // ── Submit tab ──────────────────────────────────────────────────────────
  Widget _buildSubmitTab(
      Wallet wallet, List<ReimbursementProvider> providers, bool loading) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Gate: a payout destination must be on file before claiming — the
    // backend enforces this too, but blocking it here avoids a member
    // filling out the whole form only to hit a rejection at the end.
    // Skipped when direct-to-provider payments are available: the member can
    // still use that path with no payout method of their own on file (the
    // inline "Reimburse me" warning below covers that path specifically).
    if (_member != null &&
        !_member!.hasPayoutMethod &&
        !_directProviderPaymentEnabled) {
      return MpEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Set up your payout method first',
        message: 'Tell us where to send approved reimbursements: GCash, '
            'bank, or cash pickup. Do this before submitting a claim.',
        action: SizedBox(
          width: 240,
          child: MpButton(
            label: 'Set up payout method',
            gold: true,
            onPressed: _openPayoutSetup,
          ),
        ),
      );
    }

    // While the wallet is still loading, fall through and render the form's
    // static fields immediately — the pet/category dropdowns populate when data
    // arrives. Only show the "no benefits" empty state once loading is done.
    if (!loading && wallet.pets.isEmpty) {
      return const MpEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No reimbursable benefits yet',
        message: "Your active plan doesn't include reimbursement, or no plan "
            'is active. Ask clinic staff for details.',
      );
    }

    // The selected pet's wallet has TWO pools. The chosen service category picks
    // which pool the claim draws from: "Emergency" → Emergency Wallet, anything
    // else → Preventive Wellness Wallet (grooming carries its own 90-day rule).
    WalletPet? selectedWallet;
    for (final p in wallet.pets) {
      if (p.petId == _selectedPetId) {
        selectedWallet = p;
        break;
      }
    }
    String? selectedServiceName;
    for (final st in wallet.serviceTypes) {
      if (st.id == _selectedServiceTypeId) {
        selectedServiceName = st.name;
        break;
      }
    }
    final isEmergencyCategory =
        (selectedServiceName ?? '').trim().toLowerCase() == 'emergency';
    final poolLabel =
        isEmergencyCategory ? 'Emergency Wallet' : 'Preventive Wellness Wallet';
    final remaining = selectedWallet == null
        ? 0
        : (isEmergencyCategory
            ? selectedWallet.emergencyRemainingCentavos
            : selectedWallet.remainingCentavos);
    final walletExhausted = selectedWallet != null && remaining <= 0;
    // Expired plan: the server 400s new claims; gate here too so the member
    // sees why instead of a failed round-trip.
    final planExpired = selectedWallet?.planExpired ?? false;
    final isDark = theme.brightness == Brightness.dark;
    final walletGold = isDark ? AppColors.gold : AppColors.goldDark;

    // Direct-to-provider is only offered once a category is chosen and it's
    // not Emergency — emergency claims always stay on pay-then-reimburse.
    final showTargetChooser = _directProviderPaymentEnabled &&
        _selectedServiceTypeId != null &&
        !isEmergencyCategory;
    final isProviderTarget = showTargetChooser && _payoutTarget == 'provider';
    final memberNeedsPayoutMethod = !isProviderTarget &&
        _member != null &&
        !_member!.hasPayoutMethod;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1: what happened ─────────────────────────────
            const _SectionHeader('What happened'),
            const SizedBox(height: 12),
            MpDropdownField<String>(
              value: _selectedPetId,
              label: 'Pet',
              items: wallet.pets
                  .map((p) => DropdownMenuItem(
                      value: p.petId, child: Text(p.petName)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPetId = v),
              validator: (v) => v == null ? 'Choose a pet' : null,
            ),
            if (selectedWallet != null) ...[
              const SizedBox(height: 8),
              // Wrap (not Row) so the label, amount and tier badge flow onto a
              // second line instead of overflowing when the amount is large or
              // the font scale is high on a narrow screen.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    poolLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '${pesoFromCentavos(remaining)} left',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: walletExhausted ? cs.error : walletGold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_planTypeFor(_selectedPetId) case final plan?
                      when plan.isNotEmpty)
                    TierBadge(planType: plan, small: true),
                ],
              ),
            ],
            if (planExpired) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.event_busy_rounded, size: 18, color: cs.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${selectedWallet!.petName}'s plan year has ended — "
                        'renew the plan from the Home tab to keep claiming.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            MpDropdownField<String>(
              value: _selectedServiceTypeId,
              label: 'Service category',
              items: wallet.serviceTypes
                  .map((st) => DropdownMenuItem(
                        value: st.id,
                        child: Text(st.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedServiceTypeId = v;
                // Emergency claims always stay on the pay-then-reimburse
                // flow — drop the provider selection if one was made under a
                // different, eligible category.
                String? name;
                for (final st in wallet.serviceTypes) {
                  if (st.id == v) {
                    name = st.name;
                    break;
                  }
                }
                if ((name ?? '').trim().toLowerCase() == 'emergency' &&
                    _payoutTarget == 'provider') {
                  _payoutTarget = 'member';
                  _selectedProviderId = null;
                  _selectedProviderName = null;
                  _serviceDate = DateTime.now();
                }
              }),
              validator: (v) => v == null ? 'Choose a service category' : null,
            ),
            const SizedBox(height: 16),
            if (showTargetChooser) ...[
              MpDropdownField<String>(
                value: _payoutTarget,
                label: 'How should this be paid?',
                items: const [
                  DropdownMenuItem(
                    value: 'member',
                    child: Text('Reimburse me'),
                  ),
                  DropdownMenuItem(
                    value: 'provider',
                    child: Text('Pay the provider directly'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _payoutTarget = v ?? 'member';
                  _selectedProviderId = null;
                  _selectedProviderName = null;
                  // The two paths have opposite date ranges (already-happened
                  // vs. upcoming), so the current pick likely falls outside
                  // the new range — reset it rather than risk an out-of-range
                  // date crashing the picker.
                  _serviceDate = DateTime.now();
                }),
                validator: (v) => null,
              ),
              const SizedBox(height: 16),
            ],
            MpTextField(
              controller: _amountCtrl,
              label: 'Amount paid',
              prefixText: '₱ ',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // Digits, one decimal point, and thousands separators only.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              // Tabular figures — digits hold a fixed width so the amount
              // doesn't visually jiggle as the member types.
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              validator: (v) {
                // Tolerates "1,500.00" — commas stripped before parsing.
                final value = _parseAmount(v);
                if (value == null || value <= 0) {
                  return 'Enter the amount on the receipt';
                }
                // A claim can't exceed what's left in the pool its category
                // draws from (the backend enforces this too).
                if (selectedWallet != null &&
                    (value * 100).round() > remaining) {
                  return 'Insufficient $poolLabel balance — '
                      '${pesoFromCentavos(remaining)} left';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (isProviderTarget)
              providers.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Text(
                        'No verified providers are available yet. Choose '
                        '"Reimburse me" above instead, or check back later.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    )
                  : MpDropdownField<String>(
                      value: _selectedProviderId,
                      label: 'Provider / clinic',
                      items: providers
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedProviderId = v;
                        _selectedProviderName = null;
                        for (final p in providers) {
                          if (p.id == v) {
                            _selectedProviderName = p.name;
                            break;
                          }
                        }
                      }),
                      validator: (v) => v == null ? 'Choose a provider' : null,
                    )
            else
              MpTextField(
                controller: _providerCtrl,
                label: 'Provider / clinic name',
                maxLength: 60,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Enter the provider name'
                    : null,
              ),
            const SizedBox(height: 16),
            _DateField(
              date: _serviceDate,
              label: isProviderTarget ? 'Appointment date' : 'Service date',
              onTap: () async {
                final now = DateTime.now();
                final firstDate =
                    isProviderTarget ? now : DateTime(now.year - 2);
                final lastDate = isProviderTarget
                    ? now.add(const Duration(days: 60))
                    : now;
                final initial =
                    _serviceDate.isBefore(firstDate) || _serviceDate.isAfter(lastDate)
                        ? now
                        : _serviceDate;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                if (picked != null) setState(() => _serviceDate = picked);
              },
            ),
            const SizedBox(height: 28),

            // ── Section 2: proof ─────────────────────────────────────
            _SectionHeader(isProviderTarget ? 'Proof of appointment' : 'Proof'),
            const SizedBox(height: 12),
            _ReceiptAttachment(
              hasFile: _receiptBytes != null,
              ext: _receiptExt,
              onTap: _pickReceipt,
              attachedLabel: isProviderTarget ? 'File attached' : 'Receipt attached',
              emptyLabel: isProviderTarget
                  ? 'Attach a quote, estimate, or booking confirmation (photo or PDF)'
                  : 'Attach receipt (photo or PDF)',
            ),
            if (_receiptMissing && _receiptBytes == null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  isProviderTarget
                      ? 'Attach a quote, estimate, or booking confirmation'
                      : 'Attach the official receipt',
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: cs.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            MpTextField(
              controller: _referenceCtrl,
              label: 'Receipt / reference no. (optional)',
            ),
            const SizedBox(height: 16),
            MpTextField(
              controller: _notesCtrl,
              label: 'Notes (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (walletExhausted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedWallet.petName}\'s $poolLabel is used up for '
                  'this plan year, so a new claim can\'t be submitted.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onErrorContainer, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (memberNeedsPayoutMethod) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set up your payout method to get reimbursed — GCash, '
                      'bank, or cash pickup.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.gold
                            : AppColors.goldDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _openPayoutSetup,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text('Set up payout method'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            MpButton(
              label: 'Submit claim',
              gold: true,
              loading: _submitting,
              onPressed: (_submitting ||
                      loading ||
                      walletExhausted ||
                      planExpired ||
                      memberNeedsPayoutMethod)
                  ? null
                  : _submit,
            ),
            const SizedBox(height: 12),
            Text(
              'MetroPaws will review your claim against your plan benefits. '
              'You\'ll be notified in the app and by email when the status changes.',
              style: theme.textTheme.bodySmall!
                  .copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Claims tab ────────────────────────────────────────────────────────────────

class _ClaimsTab extends StatelessWidget {
  const _ClaimsTab({
    required this.claims,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onResubmit,
  });
  final List<Reimbursement> claims;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final void Function(Reimbursement) onResubmit;

  @override
  Widget build(BuildContext context) {
    // Failure / loading / empty all render inside the tab, under the tab bar —
    // the screen chrome (and the Submit tab) stay usable throughout.
    if (error != null) {
      return _ErrorState(message: error!, onRetry: onRetry);
    }
    if (loading) {
      return const _LoadingState();
    }
    if (claims.isEmpty) {
      return const MpEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No claims yet',
        message: 'Submit a receipt from the Submit tab to request a '
            'reimbursement.',
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: claims.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = claims[i];
        final colors = _statusColors(c.status, context);

        final card = Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.serviceType.name,
                      // titleMedium(16)+w800 vs the badge's labelSmall(12) —
                      // a clear size+weight gap so the card's identity reads
                      // as the dominant element, not a peer of its status.
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.$1,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      c.statusLabel,
                      style: theme.textTheme.labelSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.$2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ClaimLine(label: 'Provider', value: c.providerName),
              _ClaimLine(label: 'Service date', value: _formatDate(c.serviceDate)),
              _ClaimLine(
                label: 'Claimed',
                value: pesoFromCentavos(c.claimedAmountCentavos),
                numeric: true,
              ),
              if (c.approvedAmountCentavos != null)
                _ClaimLine(
                  label: 'Approved',
                  value: pesoFromCentavos(c.approvedAmountCentavos!),
                  numeric: true,
                ),
              const SizedBox(height: 10),
              _ReceiptLink(url: c.receiptUrl),
              if (c.adminNotes != null && c.adminNotes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Note: ${c.adminNotes!}',
                    style: theme.textTheme.bodySmall!
                        .copyWith(color: cs.onSurface, height: 1.4),
                  ),
                ),
              ],
              if (c.needsInfo) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: MpButton(
                    label: 'Fix and resubmit',
                    gold: true,
                    onPressed: () => onResubmit(c),
                  ),
                ),
              ],
            ],
          ),
        );
        return StaggeredReveal(index: i, child: card);
      },
    );
  }
}

class _ClaimLine extends StatelessWidget {
  const _ClaimLine({required this.label, required this.value, this.numeric = false});
  final String label;
  final String value;
  /// True for peso amounts — applies tabular figures so digits hold a fixed
  /// width, keeping the "Claimed"/"Approved" columns visually aligned across
  /// claim cards while scanning the list.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text('$label  ',
              style: theme.textTheme.bodySmall!
                  .copyWith(color: cs.onSurfaceVariant)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontFeatures:
                      numeric ? const [FontFeature.tabularFigures()] : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// (background, foreground) for a claim status badge.
(Color, Color) _statusColors(String status, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (status) {
    case 'approved':
    case 'paid':
      return (
        isDark ? AppDarkColors.successBg : AppColors.successLight,
        isDark ? AppColors.success : AppColors.successDark,
      );
    case 'rejected':
      return (
        isDark ? AppDarkColors.errorBg : AppColors.errorLight,
        AppColors.error,
      );
    case 'needs_info':
      // goldDark is tuned for light-gold surfaces; on darkGoldBg it fails
      // WCAG contrast for this small badge text — use raw gold in dark mode.
      return (
        Theme.of(context).colorScheme.secondaryContainer,
        isDark ? AppColors.gold : AppColors.goldDark,
      );
    default: // pending, under_review
      return (
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
  }
}

// ── Submit form helpers ───────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.onTap,
    this.label = 'Service date',
  });
  final DateTime date;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDate(date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Icon(Icons.calendar_today_outlined,
                size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ReceiptAttachment extends StatelessWidget {
  const _ReceiptAttachment({
    required this.hasFile,
    required this.ext,
    required this.onTap,
    this.attachedLabel = 'Receipt attached',
    this.emptyLabel = 'Attach receipt (photo or PDF)',
  });
  final bool hasFile;
  final String? ext;
  final VoidCallback onTap;
  final String attachedLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold = cs.secondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: hasFile ? cs.secondaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? gold.withValues(alpha: 0.5) : cs.outline,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              child: Icon(
                hasFile
                    ? (ext == 'pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined)
                    : Icons.upload_file_outlined,
                key: ValueKey('${hasFile}_$ext'),
                color: hasFile
                    ? (theme.brightness == Brightness.dark
                        ? AppColors.gold
                        : AppColors.goldDark)
                    : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                child: Text(
                  hasFile
                      ? '$attachedLabel (${ext == 'pdf' ? 'PDF' : 'photo'}) · tap to change'
                      : emptyLabel,
                  key: ValueKey('${hasFile}_$ext'),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: hasFile ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: hasFile ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF file'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Submit form section header ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

// ── Receipt preview link (claim cards) ───────────────────────────────────────
//
// The stored receipt was previously invisible in My Claims, which made the
// needs_info resubmission a blind replacement. A thumbnail + viewer lets the
// member judge what they sent against the admin's note.

class _ReceiptLink extends StatelessWidget {
  const _ReceiptLink({required this.url});
  final String url;

  bool get _isPdf => url.toLowerCase().split('?').first.endsWith('.pdf');

  Future<void> _open(BuildContext context) async {
    if (_isPdf) {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the receipt.')),
        );
      }
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(
                              color: AppColors.gold),
                        ),
                  errorBuilder: (c, _, _) => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Text('Could not load the receipt.',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 36,
              height: 36,
              child: _isPdf
                  ? ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.picture_as_pdf_outlined,
                          size: 20, color: cs.onSurfaceVariant),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (c, _, _) => ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.image_outlined,
                            size: 20, color: cs.onSurfaceVariant),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'View receipt',
            style: theme.textTheme.labelMedium!.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ── Full-edit resubmit sheet (needs_info) ───────────────────────────────────

class _ResubmitResult {
  const _ResubmitResult({
    required this.amountCentavos,
    required this.providerName,
    required this.serviceDate,
    this.memberNotes,
    this.receiptBytes,
    this.receiptExt,
  });
  final int amountCentavos;
  final String providerName;
  final DateTime serviceDate;
  final String? memberNotes;
  final Uint8List? receiptBytes;
  final String? receiptExt;
}

class _ResubmitSheet extends StatefulWidget {
  const _ResubmitSheet({required this.claim, required this.pickReceipt});
  final Reimbursement claim;
  final Future<(Uint8List, String)?> Function() pickReceipt;

  @override
  State<_ResubmitSheet> createState() => _ResubmitSheetState();
}

class _ResubmitSheetState extends State<_ResubmitSheet> {
  final _sheetFormKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _providerCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;
  Uint8List? _newBytes;
  String? _newExt;

  @override
  void initState() {
    super.initState();
    final c = widget.claim;
    _amountCtrl = TextEditingController(
        text: (c.claimedAmountCentavos / 100).toStringAsFixed(2));
    _providerCtrl = TextEditingController(text: c.providerName);
    _notesCtrl = TextEditingController(text: c.memberNotes ?? '');
    _date = c.serviceDate;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _providerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _replaceReceipt() async {
    final picked = await widget.pickReceipt();
    if (picked == null || !mounted) return;
    setState(() {
      _newBytes = picked.$1;
      _newExt = picked.$2;
    });
  }

  void _confirm() {
    if (!_sheetFormKey.currentState!.validate()) return;
    final pesos = _parseAmount(_amountCtrl.text) ?? 0;
    Navigator.pop(
      context,
      _ResubmitResult(
        amountCentavos: (pesos * 100).round(),
        providerName: _providerCtrl.text.trim(),
        serviceDate: _date,
        memberNotes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        receiptBytes: _newBytes,
        receiptExt: _newExt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasNewReceipt = _newBytes != null;
    final iconGold = theme.brightness == Brightness.dark
        ? AppColors.gold
        : AppColors.goldDark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          // Keeps the sheet's fields above the keyboard.
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Form(
              key: _sheetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Resubmit claim',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Correct anything that was wrong, then resubmit for review.',
                    style: theme.textTheme.bodySmall!
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                  if ((widget.claim.adminNotes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'MetroPaws: ${widget.claim.adminNotes!}',
                        style: theme.textTheme.bodySmall!
                            .copyWith(color: cs.onSurface, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  MpTextField(
                    controller: _amountCtrl,
                    label: 'Amount paid',
                    prefixText: '₱ ',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()]),
                    validator: (v) {
                      final value = _parseAmount(v);
                      if (value == null || value <= 0) {
                        return 'Enter the amount on the receipt';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  MpTextField(
                    controller: _providerCtrl,
                    label: 'Provider / clinic name',
                    maxLength: 60,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter the provider name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _DateField(
                    date: _date,
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(now.year - 2),
                        lastDate: now,
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  const SizedBox(height: 14),
                  MpTextField(
                    controller: _notesCtrl,
                    label: 'Notes (optional)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _replaceReceipt,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: hasNewReceipt
                            ? cs.secondaryContainer
                            : cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasNewReceipt
                              ? cs.secondary.withValues(alpha: 0.5)
                              : cs.outline,
                          width: hasNewReceipt ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasNewReceipt
                                ? (_newExt == 'pdf'
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.image_outlined)
                                : Icons.autorenew_rounded,
                            color: hasNewReceipt
                                ? iconGold
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hasNewReceipt
                                  ? 'New receipt attached (${_newExt == 'pdf' ? 'PDF' : 'photo'}) · tap to change'
                                  : 'Keep current receipt · tap to replace',
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: hasNewReceipt
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                                fontWeight: hasNewReceipt
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  MpButton(
                    label: 'Resubmit claim',
                    gold: true,
                    onPressed: _confirm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared loading / error / empty states ───────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const MpSkeleton(items: 3, itemHeight: 96);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final navy = cs.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!
                  .copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: navy, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Try again',
                  style: TextStyle(color: navy, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

