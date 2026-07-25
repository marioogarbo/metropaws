import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/member.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_dropdown_field.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';

/// Where approved reimbursements are sent. Payout is settled offline by staff;
/// these details tell them where to send the money (shown on the admin claim).
class PayoutDetailsScreen extends StatefulWidget {
  final Member member;
  const PayoutDetailsScreen({super.key, required this.member});

  @override
  State<PayoutDetailsScreen> createState() => _PayoutDetailsScreenState();
}

class _PayoutDetailsScreenState extends State<PayoutDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late String? _method = _initialMethod();
  late final _nameCtrl =
      TextEditingController(text: widget.member.payoutAccountName ?? '');
  late final _numberCtrl =
      TextEditingController(text: widget.member.payoutAccountNumber ?? '');
  late final _bankCtrl =
      TextEditingController(text: widget.member.payoutBankName ?? '');
  bool _saving = false;

  String? _initialMethod() {
    final m = widget.member.payoutMethod;
    return (m == 'gcash' || m == 'bank' || m == 'cash') ? m : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_method == null) return;
    setState(() => _saving = true);
    context.read<MemberBloc>().add(
          PayoutDetailsSubmitted(
            method: _method!,
            accountName: _nameCtrl.text.trim(),
            accountNumber: _method == 'cash' ? '' : _numberCtrl.text.trim(),
            bankName: _method == 'bank' ? _bankCtrl.text.trim() : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBank = _method == 'bank';
    final isCash = _method == 'cash';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Payout method',
          style: theme.textTheme.titleLarge!
              .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocListener<MemberBloc, MemberState>(
        listenWhen: (_, c) => c is PayoutSaveSuccess || c is PayoutSaveFailure,
        listener: (context, state) {
          if (state is PayoutSaveSuccess) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Payout method saved.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: cs.secondary,
              ),
            );
          } else if (state is PayoutSaveFailure) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
                backgroundColor: cs.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approved reimbursements are sent here. MetroPaws releases '
                    'payment to this account and marks your claim as paid. '
                    'You can change this anytime before a claim is paid out.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  MpDropdownField<String>(
                    value: _method,
                    label: 'Payout method',
                    items: const [
                      DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                      DropdownMenuItem(
                          value: 'cash', child: Text('Cash pickup at clinic')),
                    ],
                    onChanged: (v) => setState(() => _method = v),
                    validator: (v) => v == null ? 'Choose a payout method' : null,
                  ),
                  const SizedBox(height: 16),
                  MpTextField(
                    controller: _nameCtrl,
                    label: isCash ? 'Name of who will pick up' : 'Account name',
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter the name' : null,
                  ),
                  if (!isCash) ...[
                    const SizedBox(height: 16),
                    MpTextField(
                      controller: _numberCtrl,
                      label: isBank ? 'Account number' : 'GCash number',
                      keyboardType: TextInputType.number,
                      validator: (v) => isCash || (v ?? '').trim().isNotEmpty
                          ? null
                          : 'Enter the ${isBank ? 'account' : 'GCash'} number',
                    ),
                  ],
                  if (isBank) ...[
                    const SizedBox(height: 16),
                    MpTextField(
                      controller: _bankCtrl,
                      label: 'Bank name',
                      validator: (v) => isBank && (v ?? '').trim().isEmpty
                          ? 'Enter the bank name'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  MpButton(
                    label: 'Save payout method',
                    gold: true,
                    loading: _saving,
                    onPressed: _saving ? null : _save,
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
