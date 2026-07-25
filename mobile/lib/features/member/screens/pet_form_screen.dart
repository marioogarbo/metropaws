import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/pet.dart';
import '../../../core/widgets/mp_button.dart';
import '../../../core/widgets/mp_dropdown_field.dart';
import '../../../core/widgets/mp_text_field.dart';
import '../../../theme.dart';
import '../bloc/member_bloc.dart';
import '../bloc/member_event.dart';
import '../bloc/member_state.dart';

const _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Edits an existing pet's details and front-face photo. Adding a new pet
/// goes through the AddPetScreen wizard instead, which also captures the
/// 3 required identity photos (MP-FRM-PET-001).
class PetFormScreen extends StatefulWidget {
  final Pet pet;

  const PetFormScreen({super.key, required this.pet});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _notesCtrl;
  String? _selectedSpecies;
  String? _selectedSex;
  int? _selectedBirthMonth;
  int? _selectedBirthYear;
  int? _selectedBirthDay;
  Uint8List? _photoBytes;
  String? _photoExt;

  final _picker = ImagePicker();

  static const _sexOptions = ['Male', 'Female'];
  static const _speciesOptions = ['Dog', 'Cat'];

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    _nameCtrl = TextEditingController(text: p.name);
    _breedCtrl = TextEditingController(text: p.breed ?? '');
    _weightCtrl = TextEditingController(
      text: p.weightKg != null ? p.weightKg!.toString() : '',
    );
    _notesCtrl = TextEditingController(text: p.notes ?? '');
    _selectedSpecies = p.species != null
        ? '${p.species![0].toUpperCase()}${p.species!.substring(1).toLowerCase()}'
        : null;
    _selectedSex = p.sex != null
        ? '${p.sex![0].toUpperCase()}${p.sex!.substring(1)}'
        : null;
    _selectedBirthMonth = p.birthMonth;
    _selectedBirthYear = p.birthYear;
    _selectedBirthDay = p.birthDay;
  }

  static const _maxPhotoBytes = 5 * 1024 * 1024; // 5 MB
  static const _allowedExts = {'jpg', 'jpeg', 'png'};

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    if (!_allowedExts.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPG and PNG files are allowed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo must be under 5 MB.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _photoBytes = bytes;
      _photoExt = ext;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecies == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pet type'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_selectedSex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sex'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final rawName = _nameCtrl.text.trim();
    final name = rawName.isNotEmpty
        ? rawName[0].toUpperCase() + rawName.substring(1)
        : rawName;
    final breed = _breedCtrl.text.trim();
    final weightKg = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final sexValue = _selectedSex?.toLowerCase();
    final speciesValue = _selectedSpecies?.toLowerCase();

    context.read<MemberBloc>().add(
      PetUpdateRequested(
        petId: widget.pet.id,
        name: name,
        species: speciesValue,
        breed: breed,
        birthMonth: _selectedBirthMonth,
        birthYear: _selectedBirthYear,
        birthDay: _selectedBirthDay,
        weightKg: weightKg,
        sex: sexValue,
        notes: notes,
        photoBytes: _photoBytes,
        photoExt: _photoExt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return BlocListener<MemberBloc, MemberState>(
      listener: (context, state) {
        if (state is PetOperationSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state is PetOperationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Pet')),
        body: SafeArea(
          child: BlocBuilder<MemberBloc, MemberState>(
            builder: (context, state) {
              final isLoading = state is PetOperationLoading;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PhotoPicker(
                        bytes: _photoBytes,
                        existingUrl: widget.pet.photoUrl,
                        onTap: isLoading ? null : _pickPhoto,
                      ),
                      const SizedBox(height: 20),
                      MpTextField(
                        controller: _nameCtrl,
                        label: 'Pet name *',
                        hint: 'e.g. Luna',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Name is required';
                          if (v.trim().length > 60) return 'Name must be 60 characters or fewer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      MpDropdownField<String>(
                        value: _selectedSpecies,
                        label: 'Pet type *',
                        items: _speciesOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSpecies = v),
                      ),
                      const SizedBox(height: 16),
                      MpDropdownField<String>(
                        value: _selectedSex,
                        label: 'Sex *',
                        items: _sexOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSex = v),
                      ),
                      const SizedBox(height: 16),
                      MpTextField(
                        controller: _breedCtrl,
                        label: 'Breed *',
                        hint: 'e.g. Golden Retriever',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'HEALTH & VITALS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: MpDropdownField<int>(
                              value: _selectedBirthMonth,
                              label: 'Birth month *',
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(_kMonthNames[i]),
                                ),
                              ),
                              onChanged: (v) => setState(() => _selectedBirthMonth = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MpDropdownField<int>(
                              value: _selectedBirthYear,
                              label: 'Birth year *',
                              items: List.generate(
                                currentYear - 1989,
                                (i) => DropdownMenuItem(
                                  value: currentYear - i,
                                  child: Text('${currentYear - i}'),
                                ),
                              ),
                              onChanged: (v) => setState(() => _selectedBirthYear = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      MpDropdownField<int?>(
                        value: _selectedBirthDay,
                        label: 'Birth day (optional)',
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('—')),
                          ...List.generate(
                            31,
                            (i) => DropdownMenuItem<int?>(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedBirthDay = v),
                      ),
                      const SizedBox(height: 16),
                      MpTextField(
                        controller: _weightCtrl,
                        label: 'Weight (kg) *',
                        hint: 'e.g. 5.2',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0 || val > 200) return 'Enter a valid weight';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      MpTextField(
                        controller: _notesCtrl,
                        label: 'Notes',
                        hint: 'Allergies, conditions, special care…',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),
                      MpButton(
                        label: 'Save Changes',
                        loading: isLoading,
                        onPressed: isLoading ? null : _submit,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback? onTap;

  const _PhotoPicker({this.bytes, this.existingUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget avatar;
    if (bytes != null) {
      avatar = CircleAvatar(radius: 52, backgroundImage: MemoryImage(bytes!));
    } else if (existingUrl != null) {
      avatar = CircleAvatar(
        radius: 52,
        backgroundImage: NetworkImage(existingUrl!),
      );
    } else {
      avatar = CircleAvatar(
        radius: 52,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(Icons.pets, size: 40, color: cs.primary),
      );
    }

    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                bottom: -4,
                right: -4,
                child: Semantics(
                  label: 'Change pet photo',
                  button: true,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          (bytes != null || existingUrl != null) ? 'Tap to change photo' : 'Tap to add photo',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
