import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/auth_service.dart';
import '../main_shell.dart';
import '../doctor/doctor_shell.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String role;

  const OtpScreen({super.key, required this.email, required this.role});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final data = await AuthService.verifyOtp(widget.email, _otp);
      final userData = data['user'];
      if (userData == null) {
        throw Exception(data['message'] ?? 'Invalid OTP');
      }

      if (userData != null && mounted) {
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


        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => widget.role == 'doctor'
                ? const DoctorShell()
                : const MainShell(),
          ),
              (_) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AuthService.sendOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent to your email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
    if (mounted) setState(() => _resending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 32),

              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 20),

              const Text('Verify your email',
                  style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to\n${widget.email}',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 46, height: 56,
                  child: TextFormField(
                    controller: _ctrls[i],
                    focusNode: _nodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.primaryLight,
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
                        _nodes[i + 1].requestFocus();
                      } else if (v.isEmpty && i > 0) {
                        _nodes[i - 1].requestFocus();
                      }

                    },
                  ),
                )),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.danger)),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
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
                      : const Text('Verify & continue',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: GestureDetector(
                  onTap: _resending ? null : _resend,
                  child: Text(
                    _resending ? 'Sending...' : 'Resend OTP',
                    style: TextStyle(
                        fontSize: 13,
                        color: _resending
                            ? AppColors.textHint
                            : AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(height: 20),
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
                      style: TextStyle(fontSize: 11, color: AppColors.primaryDark),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}