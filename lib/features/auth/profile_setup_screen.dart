import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/services/api_service.dart';
import '../main_shell.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final String role;
  const ProfileSetupScreen({super.key, required this.role});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState
    extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  String _gender = 'Female';
  String _bloodGroup = 'B+';
  bool _saving = false;

  final _genders = ['Male', 'Female', 'Other'];
  final _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null) {
      _nameCtrl.text = user!.displayName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser;
    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      email: user?.email ?? '',
      gender: _gender,
      age: int.tryParse(_ageCtrl.text) ?? 0,
      weight: double.tryParse(_weightCtrl.text) ?? 0,
      height: double.tryParse(_heightCtrl.text) ?? 0,
      bloodGroup: _bloodGroup,
      role: widget.role,
    );

    await ref.read(userProfileProvider.notifier).save(profile);

    final result = await apiService.registerUser(
      email: profile.email,
      name: profile.name,
      role: profile.role,
    );
    if (result != null) {
      ref.read(backendUserIdProvider.notifier).state = result['id'];
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.06, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(height: 16),
                const Text('Set up your profile',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                    'This helps us personalise your health insights',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 28),

                AppTextField(
                  label: 'Full name',
                  hint: 'Enter your full name',
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                Row(children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Age',
                      hint: 'e.g. 24',
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      prefixIcon: Icons.cake_outlined,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Required';
                        }
                        final a = int.tryParse(v);
                        if (a == null || a < 1 || a > 120) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text('Gender',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                              BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.border)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _gender,
                              isExpanded: true,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              items: _genders
                                  .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g)))
                                  .toList(),
                              onChanged: (v) => setState(
                                      () => _gender = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                Row(children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Weight (kg)',
                      hint: 'e.g. 58',
                      controller: _weightCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixIcon:
                      Icons.monitor_weight_outlined,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(v) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'Height (cm)',
                      hint: 'e.g. 162',
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.height_rounded,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(v) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                const Text('Blood group',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bloodGroups.map((bg) {
                    final sel = _bloodGroup == bg;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _bloodGroup = bg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius:
                          BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: Text(bg,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: sel
                                    ? AppColors.white
                                    : AppColors.textPrimary)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                AppButton(
                  label: 'Save and continue',
                  onTap: _save,
                  isLoading: _saving,
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}