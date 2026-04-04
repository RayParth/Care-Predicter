import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../main_shell.dart';


class AlertScreen extends StatefulWidget {
  final String parameter;
  final String value;
  final String message;

  const AlertScreen({
    super.key,
    this.parameter = 'SpO₂',
    this.value = '88%',
    this.message = 'SpO₂ dropped critically below safe threshold.',
  });

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _smsSent = true;
  bool _notificationSent = true;
  bool _dataSynced = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildAlertCard(),
                    const SizedBox(height: 14),
                    _buildFallbackCard(),
                    const SizedBox(height: 14),
                    _buildActionsCard(),
                    const SizedBox(height: 14),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      color: const Color(0xFFA32D2D),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Color(0xFFF09595),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.warning_rounded,
            color: Color(0xFFFCEBEB),
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text(
            'Emergency alert',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFCEBEB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF09595),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // Alert icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFFCEBEB),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Critical: ${widget.parameter} ${widget.value}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF791F1F),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFA32D2D),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dhara Patel · 10:34 AM · 16 Mar 2026',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFA32D2D),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFAC775)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_rounded,
            color: Color(0xFF854F0B),
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rule-based fallback active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF633806),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'AI model is temporarily offline. Threshold-based rules triggered this alert automatically to ensure your safety.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF854F0B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC0DD97)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions taken automatically',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF27500A),
            ),
          ),
          const SizedBox(height: 10),
          _buildActionRow(
            Icons.sms_rounded,
            'SMS sent to +91 98765 XXXXX',
            _smsSent,
          ),
          const SizedBox(height: 8),
          _buildActionRow(
            Icons.notifications_rounded,
            'In-app push notification sent',
            _notificationSent,
          ),
          const SizedBox(height: 8),
          _buildActionRow(
            Icons.cloud_upload_rounded,
            'Data synced to cloud backend',
            _dataSynced,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String text, bool done) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: done ? AppColors.success : AppColors.textHint,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: done
                ? const Color(0xFF3B6D11)
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Dismiss and Call row
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calling emergency services 108...'),
                      backgroundColor: Color(0xFFE24B4A),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text(
                  'Call 108',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Request consultation button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Switch to Consult tab (index 4) in MainShell
              Future.delayed(Duration.zero, () {
                final container = ProviderScope.containerOf(context, listen: false);
                container.read(shellIndexProvider.notifier).state = 4;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.people_rounded, size: 18),
            label: const Text(
              'Request doctor consultation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
