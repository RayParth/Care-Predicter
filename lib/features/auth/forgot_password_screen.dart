import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/services/auth_service.dart';

// ── ForgotPasswordScreen ──────────────────────────────────────────────────────
//
// Two-step flow handled in a single screen using a step variable:
//
//   Step 1 — Enter email → send OTP
//   Step 2 — Enter OTP + new password + confirm → reset password
//
// On success: pops back to LoginScreen with a success SnackBar.
//
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  int    _step       = 1;          // 1 = enter email, 2 = enter OTP + new password
  bool   _loading    = false;
  String _email      = '';
  String? _error;

  // ── Step 1 controllers ────────────────────────────────────────────────────
  final _emailCtrl   = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  // ── Step 2 controllers ────────────────────────────────────────────────────
  final List<TextEditingController> _otpCtrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes =
  List.generate(6, (_) => FocusNode());
  final _newPassCtrl    = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  final _resetFormKey   = GlobalKey<FormState>();
  bool  _obscureNew     = true;
  bool  _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final n in _otpNodes) n.dispose();
    super.dispose();
  }

  String get _otp => _otpCtrls.map((c) => c.text).join();

  // ── Step 1: Send OTP ──────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await AuthService.forgotPassword(email: _emailCtrl.text.trim());
      setState(() {
        _email = _emailCtrl.text.trim();
        _step  = 2;
      });
    } catch (e) {
      setState(() =>
      _error = e.toString().replaceAll('Exception: ', ''));
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Step 2: Reset Password ────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    if (_otp.length < 6) {
      setState(() => _error = 'Please enter all 6 digits of the reset code');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await AuthService.resetPassword(
        email:       _email,
        otp:         _otp,
        newPassword: _newPassCtrl.text.trim(),
      );

      if (mounted) {
        // Go back to login screen and show success message
        Navigator.pop(context, 'Password reset successfully. Please login with your new password.');
      }
    } catch (e) {
      setState(() =>
      _error = e.toString().replaceAll('Exception: ', ''));
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  // ── Step 1 UI: Enter Email ─────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios_rounded,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text('Back',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 36),

          // Icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.lock_reset_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 20),

          const Text(
            'Forgot password?',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered email address.\nWe will send you a 6-digit reset code.',
            style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 32),

          // Email field
          TextFormField(
            controller:  _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText:  'Email address',
              prefixIcon: const Icon(Icons.email_outlined),
              filled:     true,
              fillColor:  AppColors.surface,
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
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: AppColors.danger)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF09595)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),

          // Send code button
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: AppColors.white, strokeWidth: 2.5))
                  : const Text('Send reset code',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),

          const SizedBox(height: 20),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_rounded,
                  color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check your spam folder if you don\'t see the email. The code expires in 10 minutes.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.primaryDark),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Step 2 UI: Enter OTP + New Password ───────────────────────────────────

  Widget _buildStep2() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to step 1
          GestureDetector(
            onTap: () => setState(() { _step = 1; _error = null; }),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios_rounded,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text('Back',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 36),

          // Icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.verified_user_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 20),

          const Text(
            'Enter reset code',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to\n$_email',
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 28),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => SizedBox(
              width: 46, height: 56,
              child: TextFormField(
                controller:  _otpCtrls[i],
                focusNode:   _otpNodes[i],
                textAlign:   TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength:   1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
                decoration: InputDecoration(
                  counterText: '',
                  filled:     true,
                  fillColor:  AppColors.primaryLight,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    _otpNodes[i + 1].requestFocus();
                  } else if (v.isEmpty && i > 0) {
                    _otpNodes[i - 1].requestFocus();
                  }
                },
              ),
            )),
          ),
          const SizedBox(height: 24),

          // New password field
          TextFormField(
            controller:  _newPassCtrl,
            obscureText: _obscureNew,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText:  'New password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscureNew = !_obscureNew),
                child: Icon(_obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
              ),
              filled:    true,
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
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: AppColors.danger)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Confirm password field
          TextFormField(
            controller:  _confirmCtrl,
            obscureText: _obscureConfirm,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText:  'Confirm new password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                child: Icon(_obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
              ),
              filled:    true,
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
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: AppColors.danger)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _newPassCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF09595)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),

          // Reset button
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: AppColors.white, strokeWidth: 2.5))
                  : const Text('Reset password',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 16),

          // Resend code link
          Center(
            child: GestureDetector(
              onTap: _loading
                  ? null
                  : () async {
                setState(() { _loading = true; _error = null; });
                try {
                  await AuthService.forgotPassword(email: _email);
                  // Clear OTP boxes
                  for (final c in _otpCtrls) c.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('New reset code sent'),
                        backgroundColor: AppColors.teal,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => _error =
                      e.toString().replaceAll('Exception: ', ''));
                }
                if (mounted) setState(() => _loading = false);
              },
              child: Text(
                'Resend code',
                style: TextStyle(
                    fontSize: 13,
                    color: _loading
                        ? AppColors.textHint
                        : AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}