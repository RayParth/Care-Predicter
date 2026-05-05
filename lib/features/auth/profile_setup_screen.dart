import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../doctor/doctor_shell.dart';
import '../main_shell.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final String  role;
  // Filled when coming from Google login (new Google user)
  // Null when coming from email registration flow
  final String? googleEmail;
  final String? googleName;

  const ProfileSetupScreen({
    super.key,
    required this.role,
    this.googleEmail,
    this.googleName,
  });

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _ageCtrl      = TextEditingController();
  final _weightCtrl   = TextEditingController();
  final _heightCtrl   = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  String _gender      = 'Female';
  String _bloodGroup  = 'B+';
  bool   _saving      = false;
  bool   _obscurePass = true;
  bool   _obscureConf = true;

  final _genders     = ['Male', 'Female', 'Other'];
  final _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  // True when this screen is reached from Google sign-in
  bool get _isGoogleUser =>
      widget.googleEmail != null && widget.googleEmail!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isGoogleUser) {
      _nameCtrl.text = widget.googleName ?? '';
    } else {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser?.displayName != null) {
        _nameCtrl.text = firebaseUser!.displayName!;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final email = _isGoogleUser
        ? widget.googleEmail!
        : FirebaseAuth.instance.currentUser?.email ?? '';

    final profile = UserProfile(
      name:       _nameCtrl.text.trim(),
      email:      email,
      gender:     _gender,
      age:        int.tryParse(_ageCtrl.text)    ?? 0,
      weight:     double.tryParse(_weightCtrl.text) ?? 0,
      height:     double.tryParse(_heightCtrl.text) ?? 0,
      bloodGroup: _bloodGroup,
      role:       widget.role,
    );

    // Save to local SharedPreferences first
    await ref.read(userProfileProvider.notifier).save(profile);

    // Save full profile to PostgreSQL backend
    // If user filled the password field, it gets saved too — allowing
    // them to also login with email+password from now on
    final password = _passCtrl.text.trim();
    final result = await AuthService.registerGoogle(
      email:      profile.email,
      name:       profile.name,
      role:       profile.role,
      gender:     profile.gender,
      age:        profile.age,
      weight:     profile.weight,
      height:     profile.height,
      bloodGroup: profile.bloodGroup,
      password:   password.isNotEmpty ? password : null,
    );

    final backendId = result?['id'] ?? 0;

    // Save again now that we have the backend DB id
    await ref.read(userProfileProvider.notifier).save(
      profile.copyWith(backendUserId: backendId),
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.role == 'doctor'
              ? const DoctorShell()
              : const MainShell(),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                // Icon
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Set up your profile',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This helps us personalise your health insights',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),

                // ── Full name ──────────────────────────────────────────────
                AppTextField(
                  label:      'Full name',
                  hint:       'Enter your full name',
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline_rounded,
                  validator:  (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                // ── Age + Gender ───────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: AppTextField(
                      label:        'Age',
                      hint:         'e.g. 24',
                      controller:   _ageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      prefixIcon: Icons.cake_outlined,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final a = int.tryParse(v);
                        if (a == null || a < 1 || a > 120) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _genderDropdown()),
                ]),
                const SizedBox(height: 16),

                // ── Weight + Height ────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: AppTextField(
                      label:        'Weight (kg)',
                      hint:         'e.g. 58',
                      controller:   _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixIcon: Icons.monitor_weight_outlined,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label:        'Height (cm)',
                      hint:         'e.g. 162',
                      controller:   _heightCtrl,
                      keyboardType: TextInputType.number,
                      prefixIcon:   Icons.height_rounded,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Blood group ────────────────────────────────────────────
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
                      onTap: () => setState(() => _bloodGroup = bg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
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

                // ── Password fields (Google users only) ───────────────────
                // These are OPTIONAL. Google users can skip them and still
                // register. If they fill them, they can also use
                // email+password login from now on.
                if (_isGoogleUser) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryMid),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.lock_outline_rounded,
                              color: AppColors.primary, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Set a password (optional)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        const Text(
                          'If you set a password here, you can also login with email and password — not just Google.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              height: 1.5),
                        ),
                        const SizedBox(height: 14),

                        // Password field
                        TextFormField(
                          controller:  _passCtrl,
                          obscureText: _obscurePass,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText:  'Password (min 6 characters)',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                      () => _obscurePass = !_obscurePass),
                              child: Icon(_obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                            ),
                            filled:    true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5)),
                          ),
                          // Validation only runs if something was typed
                          validator: (v) {
                            if (v == null || v.isEmpty) return null; // optional
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Confirm password field
                        TextFormField(
                          controller:  _confirmCtrl,
                          obscureText: _obscureConf,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText:  'Confirm password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                      () => _obscureConf = !_obscureConf),
                              child: Icon(_obscureConf
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                            ),
                            filled:    true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5)),
                          ),
                          validator: (v) {
                            if (_passCtrl.text.isEmpty) return null; // both optional
                            if (v != _passCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                AppButton(
                  label:     'Save and continue',
                  onTap:     _save,
                  isLoading: _saving,
                  icon:      Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Gender Dropdown ───────────────────────────────────────────────────────

  Widget _genderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:      _gender,
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              items: _genders
                  .map((g) =>
                  DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v!),
            ),
          ),
        ),
      ],
    );
  }
}