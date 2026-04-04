import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/auth_service.dart';
import '../main_shell.dart';
import '../doctor/doctor_shell.dart';
import 'role_select_screen.dart';
import 'otp_screen.dart';
import 'email_register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _showEmailLogin = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign in failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loginWithEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await AuthService.loginWithEmail(email: email, password: password);
      final userData = data['user'];
      if (userData == null) {
        throw Exception(data['message'] ?? 'Invalid OTP');
      }

      if (userData != null && mounted) {
        // Save to local prefs
        final profile = UserProfile(
          name: userData['name'] ?? '',
          email: userData['email'] ?? '',
          gender: userData['gender'] ?? '',
          age: userData['age'] ?? 0,
          weight: (userData['weight'] as num?)?.toDouble() ?? 0,
          height: (userData['height'] as num?)?.toDouble() ?? 0,
          bloodGroup: userData['blood_group'] ?? '',
          role: userData['role'] ?? 'patient',
          backendUserId: userData['id'] ?? 0,
        );
        await ref.read(userProfileProvider.notifier).save(profile);

        // Navigate based on role
        final role = userData['role'] ?? 'patient';
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => role == 'doctor'
                  ? const DoctorShell()
                  : const MainShell(),
            ),
                (_) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Care Predicter',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('Monitor · Analyse · Stay healthy',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 32),

              if (!_showEmailLogin) ...[
                // Feature pills
                Wrap(
                  spacing: 8, runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: const [
                    _Pill('Health tracking'), _Pill('Lab OCR'),
                    _Pill('AI chat'), _Pill('Organ map'),
                    _Pill('Doctor consult'),
                  ],
                ),
                const SizedBox(height: 32),

                // Gmail button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2.5))
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Continue with Gmail',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Divider
                Row(children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(
                        fontSize: 12, color: AppColors.textHint)),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ]),
                const SizedBox(height: 12),

                // Email login button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showEmailLogin = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Login with Email & Password',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Register new account
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const EmailRegisterScreen())),
                  child: const Text(
                    "Don't have an account? Create one",
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ),

              ] else ...[
                // Email login form
                GestureDetector(
                  onTap: () => setState(() => _showEmailLogin = false),
                  child: Row(children: const [
                    Icon(Icons.arrow_back_ios_rounded,
                        size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                ),
                const SizedBox(height: 20),
                const Text('Login with email',
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 20),

                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),

                // Password field
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2.5))
                        : const Text('Login',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const EmailRegisterScreen())),
                  child: const Text(
                    "Don't have an account? Create one",
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text(
                'Secured by Firebase · Your data is private',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(fontSize: 12,
              color: AppColors.primaryDark, fontWeight: FontWeight.w500)),
    );
  }
}