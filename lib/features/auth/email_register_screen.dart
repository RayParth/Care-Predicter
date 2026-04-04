import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/services/auth_service.dart';
import 'otp_screen.dart';

class EmailRegisterScreen extends ConsumerStatefulWidget {
  const EmailRegisterScreen({super.key});

  @override
  ConsumerState<EmailRegisterScreen> createState() =>
      _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends ConsumerState<EmailRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _gender = 'Female';
  String _bloodGroup = 'B+';
  String _role = 'patient';

  final _genders = ['Male', 'Female', 'Other'];
  final _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final _roles = ['patient', 'doctor'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // Register in backend
      await AuthService.registerWithEmail(
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        role: _role,
        gender: _gender,
        age: int.tryParse(_ageCtrl.text),
        weight: double.tryParse(_weightCtrl.text),
        height: double.tryParse(_heightCtrl.text),
        bloodGroup: _bloodGroup,
      );

      // Send OTP
      await AuthService.sendOtp(_emailCtrl.text.trim());

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              email: _emailCtrl.text.trim(),
              role: _role,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _dropdown(String label, String value, List<String> items,
      void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
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
              value: value,
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              items: items
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? type,
        List<TextInputFormatter>? formatters,
        bool obscure = false,
        String? Function(String?)? validator,
        Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          inputFormatters: formatters,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: suffix,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Row(children: [
                    Icon(Icons.arrow_back_ios_rounded,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                ),
                const SizedBox(height: 20),
                const Text('Create account',
                    style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Fill in your details to get started',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 24),

                _field('Full name', _nameCtrl,
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null),
                const SizedBox(height: 14),

                _field('Email address', _emailCtrl,
                    type: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid email'
                        : null),
                const SizedBox(height: 14),

                _field('Password', _passCtrl,
                    obscure: _obscure,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          color: AppColors.textHint),
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'Password must be at least 6 characters'
                        : null),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(
                    child: _field('Age', _ageCtrl,
                        type: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final a = int.tryParse(v);
                          if (a == null || a < 1 || a > 120) return 'Invalid';
                          return null;
                        }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _dropdown('Gender', _gender, _genders,
                              (v) => setState(() => _gender = v!))),
                ]),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(
                    child: _field('Weight (kg)', _weightCtrl,
                        type: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Height (cm)', _heightCtrl,
                        type: TextInputType.number,
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null),
                  ),
                ]),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(
                      child: _dropdown('Blood group', _bloodGroup, _bloodGroups,
                              (v) => setState(() => _bloodGroup = v!))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _dropdown('Role', _role, _roles,
                              (v) => setState(() => _role = v!))),
                ]),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2.5))
                        : const Text('Create account & verify email',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}