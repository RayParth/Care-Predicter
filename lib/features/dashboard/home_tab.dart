import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/widgets/metric_card.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../main_shell.dart';
import '../alert/alert_screen.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, ref, profile),
              const SizedBox(height: 12),
              _buildMetricGrid(),
              const SizedBox(height: 12),
              _buildLabSection(context, ref),
              const SizedBox(height: 12),
              _buildAlertBanner(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Good morning',
              style: TextStyle(
                  fontSize: 13, color: AppColors.primaryMid)),
          const SizedBox(height: 2),
          Text(
            profile.name.isNotEmpty ? profile.name : 'Welcome',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.white),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: const [
                    Text('Health score',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryMid)),
                    SizedBox(height: 4),
                    Text('82',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            height: 1)),
                    SizedBox(height: 4),
                    Text('Good condition',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.tealMid)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (profile.bloodGroup.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius:
                            BorderRadius.circular(20)),
                        child: Text(
                            'Blood: ${profile.bloodGroup}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500)),
                      ),
                    const SizedBox(height: 6),
                    if (profile.bmi > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.teal
                                .withOpacity(0.2),
                            borderRadius:
                            BorderRadius.circular(20)),
                        child: Text(
                            'BMI: ${profile.bmi.toStringAsFixed(1)}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.tealMid,
                                fontWeight: FontWeight.w500)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: const [
          MetricCard(
            label: 'Heart rate',
            value: '76',
            unit: 'bpm',
            status: 'Normal',
            statusColor: AppColors.success,
            statusBg: AppColors.successLight,
            progress: 0.55,
            progressColor: AppColors.tealMid,
          ),
          MetricCard(
            label: 'SpO₂',
            value: '98',
            unit: '%',
            status: 'Excellent',
            statusColor: AppColors.success,
            statusBg: AppColors.successLight,
            progress: 0.90,
            progressColor: AppColors.tealMid,
          ),
          MetricCard(
            label: 'Steps today',
            value: '6,420',
            unit: '',
            status: '64% of goal',
            statusColor: AppColors.blue,
            statusBg: AppColors.blueLight,
            progress: 0.64,
            progressColor: AppColors.blue,
          ),
          MetricCard(
            label: 'Calories',
            value: '1,840',
            unit: 'kcal',
            status: 'Active day',
            statusColor: AppColors.warning,
            statusBg: AppColors.warningLight,
            progress: 0.73,
            progressColor: Color(0xFFEF9F27),
          ),
          MetricCard(
            label: 'Sleep',
            value: '7.2',
            unit: 'hrs',
            status: 'Good',
            statusColor: AppColors.primary,
            statusBg: AppColors.primaryLight,
            progress: 0.72,
            progressColor: AppColors.primary,
          ),
          MetricCard(
            label: 'Temperature',
            value: '36.8',
            unit: '°C',
            status: 'Normal',
            statusColor: AppColors.success,
            statusBg: AppColors.successLight,
            progress: 0.80,
            progressColor: AppColors.tealMid,
          ),
        ],
      ),
    );
  }

  Widget _buildLabSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Latest lab report',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  GestureDetector(
                    onTap: () => ref
                        .read(shellIndexProvider.notifier)
                        .state = 3,
                    child: const StatusBadge(
                        label: 'Upload new →',
                        type: BadgeType.info),
                  ),
                ],
              ),
            ),
            _labRow('Glucose', '94 mg/dL', false),
            _labRow('Hemoglobin', '13.2 g/dL', false),
            _labRow('Cholesterol', '178 mg/dL', false),
            _labRow('Triglycerides', '140 mg/dL', false,
                isBorderline: true),
            _labRow('Creatinine', '0.9 mg/dL', true),
          ],
        ),
      ),
    );
  }

  Widget _labRow(String name, String value, bool isLast,
      {bool isBorderline = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
            bottom: BorderSide(
                color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary)),
          Row(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            StatusBadge(
              label: isBorderline ? 'Borderline' : 'Normal',
              type: isBorderline
                  ? BadgeType.warning
                  : BadgeType.normal,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AlertScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFF09595)),
          ),
          child: Row(children: const [
            Icon(Icons.warning_rounded,
                color: AppColors.danger, size: 20),
            SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Test emergency alert',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF791F1F))),
                  Text('Tap to see alert screen',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFA32D2D))),
                ]),
          ]),
        ),
      ),
    );
  }
}
