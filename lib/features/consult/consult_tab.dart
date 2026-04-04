import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/consult_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';

final _selectedDoctorProvider =
StateProvider<String?>((ref) => null);
final _requestSentProvider = StateProvider<bool>((ref) => false);

class ConsultTab extends ConsumerWidget {
  const ConsultTab({super.key});

  static const _doctors = [
    {
      'name': 'Dr. Priya Sharma',
      'spec': 'Cardiologist',
      'exp': '5 yrs',
      'initials': 'PS',
      'available': true,
    },
    {
      'name': 'Dr. Rohan Mehta',
      'spec': 'General Physician',
      'exp': '8 yrs',
      'initials': 'RM',
      'available': true,
    },
    {
      'name': 'Dr. Anita Joshi',
      'spec': 'Pulmonologist',
      'exp': '6 yrs',
      'initials': 'AJ',
      'available': false,
    },
    {
      'name': 'Dr. Vikram Patel',
      'spec': 'Endocrinologist',
      'exp': '10 yrs',
      'initials': 'VP',
      'available': true,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final selected = ref.watch(_selectedDoctorProvider);
    final sent = ref.watch(_requestSentProvider);

    final summary =
        '${profile.name} · ${profile.age}${profile.gender.isNotEmpty ? profile.gender[0] : ''} · '
        'HR 76 bpm · SpO₂ 98% · BP 118/76 · '
        'Glucose 94 mg/dL · Triglycerides 140 mg/dL (borderline) · '
        'Sleep 7.2 hrs · Health score 82. Routine follow-up recommended.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12),
                child: AppCard(
                  color: AppColors.primaryLight,
                  borderColor: AppColors.primaryMid,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Icon(Icons.auto_awesome_rounded,
                            color: AppColors.primary,
                            size: 16),
                        SizedBox(width: 6),
                        Text('AI patient summary',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark)),
                      ]),
                      const SizedBox(height: 8),
                      Text(summary,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              height: 1.6)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius:
                            BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primaryMid)),
                        child: const Text(
                            'This summary will be sent with your request',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryDark,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('Available doctors',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: _doctors
                            .asMap()
                            .entries
                            .map((e) {
                          final isLast =
                              e.key == _doctors.length - 1;
                          final d = e.value;
                          final isSel =
                              selected == d['name'];
                          final avail =
                          d['available'] as bool;
                          return GestureDetector(
                            onTap: avail
                                ? () {
                              ref
                                  .read(
                                  _selectedDoctorProvider
                                      .notifier)
                                  .state = d['name']
                              as String;
                              ref
                                  .read(
                                  _requestSentProvider
                                      .notifier)
                                  .state = false;
                            }
                                : null,
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.primaryLight
                                    : AppColors.white,
                                borderRadius: isLast
                                    ? const BorderRadius.only(
                                    bottomLeft:
                                    Radius.circular(
                                        14),
                                    bottomRight:
                                    Radius.circular(
                                        14))
                                    : BorderRadius.zero,
                                border: isLast
                                    ? null
                                    : Border(
                                    bottom: BorderSide(
                                        color:
                                        AppColors.border,
                                        width: 0.5)),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                      color: isSel
                                          ? AppColors.primary
                                          : AppColors.blueLight,
                                      shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                        d['initials']
                                        as String,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                            FontWeight.w600,
                                            color: isSel
                                                ? AppColors.white
                                                : AppColors
                                                .blue)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                          d['name'] as String,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight.w600,
                                              color: isSel
                                                  ? AppColors
                                                  .primaryDark
                                                  : AppColors
                                                  .textPrimary)),
                                      Text(
                                          '${d['spec']} · ${d['exp']}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors
                                                  .textSecondary)),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: avail
                                      ? 'Available'
                                      : 'Busy',
                                  type: avail
                                      ? BadgeType.normal
                                      : BadgeType.warning,
                                ),
                                if (isSel) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                      Icons
                                          .check_circle_rounded,
                                      color: AppColors.primary,
                                      size: 18),
                                ],
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (selected != null && !sent)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  child: Column(children: [
                    AppCard(
                      color: AppColors.surface,
                      child: Row(children: [
                        const Icon(Icons.person_rounded,
                            color: AppColors.primary,
                            size: 18),
                        const SizedBox(width: 8),
                        Text('Sending to: $selected',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label:
                      'Send request + AI summary',
                      icon: Icons.send_rounded,
                      onTap: () async {
                        final userId =
                            ref.read(backendUserIdProvider) ??
                                1;
                        await ConsultService.createConsultation(
                          patientId: userId,
                          doctorName: selected,
                          aiSummary: summary,
                        );
                        ref
                            .read(
                            _requestSentProvider.notifier)
                            .state = true;
                      },
                    ),
                  ]),
                ),
              if (sent)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  child: AppCard(
                    color: AppColors.successLight,
                    borderColor:
                    const Color(0xFFC0DD97),
                    child: Column(
                      children: [
                        const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 48),
                        const SizedBox(height: 12),
                        const Text(
                            'Request sent successfully',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF27500A))),
                        const SizedBox(height: 6),
                        Text(
                            'Your request has been sent to $selected with your AI health summary.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3B6D11),
                                height: 1.5),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        AppButton(
                          label: 'Send another request',
                          isOutlined: true,
                          color: AppColors.success,
                          onTap: () {
                            ref
                                .read(_requestSentProvider
                                .notifier)
                                .state = false;
                            ref
                                .read(_selectedDoctorProvider
                                .notifier)
                                .state = null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.primary,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Doctor consultation',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white)),
          SizedBox(height: 4),
          Text('AI summary sent with your request',
              style: TextStyle(
                  fontSize: 12, color: AppColors.primaryMid)),
        ],
      ),
    );
  }
}
