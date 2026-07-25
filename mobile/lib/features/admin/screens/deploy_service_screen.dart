import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/member.dart';
import '../../../core/models/service_type.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_dropdown_field.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../theme.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

/// Shown after a successful admin scan — lets staff log a service session
/// against the scanned member, optionally tied to one of their pets.
class DeployServiceScreen extends StatefulWidget {
  final Member member;
  final List<ServiceType> serviceTypes;

  const DeployServiceScreen({
    super.key,
    required this.member,
    required this.serviceTypes,
  });

  @override
  State<DeployServiceScreen> createState() => _DeployServiceScreenState();
}

class _DeployServiceScreenState extends State<DeployServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();

  String? _selectedServiceTypeId;
  String? _selectedPetId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-select when there's only one sensible option — one less tap for
    // the common case of a single-service, single-pet member.
    if (widget.serviceTypes.length == 1) {
      _selectedServiceTypeId = widget.serviceTypes.first.id;
    }
    if (widget.member.pets.length == 1) {
      _selectedPetId = widget.member.pets.first.id;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _deploy() {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    final serviceTypeId = _selectedServiceTypeId;
    if (serviceTypeId == null) return;
    setState(() => _submitting = true);
    final notes = _notesCtrl.text.trim();
    context.read<AdminBloc>().add(
      AdminDeployServiceRequested(
        memberId: widget.member.id,
        serviceTypeId: serviceTypeId,
        petId: _selectedPetId,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final member = widget.member;
    final pets = member.pets;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(
          'Deploy Service',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: BlocConsumer<AdminBloc, AdminState>(
        listenWhen: (_, state) =>
            state is AdminDeploySuccess || state is AdminDeployFailure,
        listener: (context, state) {
          if (state is AdminDeploySuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            Navigator.pop(context);
          } else if (state is AdminDeployFailure) {
            setState(() => _submitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final loading = state is AdminDeploying || _submitting;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemberSummaryCard(member: member, isDark: isDark),
                    const SizedBox(height: 24),
                    Text(
                      'Service details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose the service to log a session for this member.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    MpDropdownField<String>(
                      value: _selectedServiceTypeId,
                      label: 'Service type',
                      items: widget.serviceTypes
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: loading
                          ? null
                          : (v) => setState(() => _selectedServiceTypeId = v),
                      validator: (v) =>
                          v == null ? 'Choose a service type' : null,
                    ),
                    if (pets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      MpDropdownField<String>(
                        value: _selectedPetId,
                        label: 'Pet (optional)',
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No specific pet'),
                          ),
                          ...pets.map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: loading
                            ? null
                            : (v) => setState(() => _selectedPetId = v),
                      ),
                    ],
                    const SizedBox(height: 16),
                    MpTextField(
                      controller: _notesCtrl,
                      label: 'Notes (optional)',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 28),
                    MpButton(
                      label: 'Deploy Service',
                      gold: true,
                      loading: loading,
                      onPressed:
                          (_selectedServiceTypeId == null || loading)
                              ? null
                              : _deploy,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemberSummaryCard extends StatelessWidget {
  final Member member;
  final bool isDark;

  const _MemberSummaryCard({required this.member, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppDarkColors.surface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((member.planType ?? '').isNotEmpty) member.planType!,
                    '${member.pets.length} pet${member.pets.length == 1 ? '' : 's'}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
