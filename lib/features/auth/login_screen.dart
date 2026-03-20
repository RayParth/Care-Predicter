import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/colors.dart';
import 'role_select_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn() async {
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
          MaterialPageRoute(
              builder: (context) => const RoleSelectScreen()),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.07),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Care Predicter',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text('Monitor · Analyse · Stay healthy',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary)),
              const Spacer(flex: 2),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  _Pill('Health tracking'),
                  _Pill('Lab OCR'),
                  _Pill('AI chat'),
                  _Pill('Organ map'),
                  _Pill('Doctor consult'),
                ],
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5))
                      : const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Continue with Gmail',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                              FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Secured by Firebase · Your data is private',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
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
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w500)),
    );
  }
}