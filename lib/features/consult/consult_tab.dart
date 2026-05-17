import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/consult_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_endpoints.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

// Fetches all registered doctors from the backend
final doctorsListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final res = await ApiClient.get('${ApiEndpoints.profile.replaceAll('/auth/profile', '')}/auth/doctors');
    return res.data as List;
  } catch (_) {
    // Fallback: call directly
    try {
      final res = await ApiClient.get('/auth/doctors');
      return res.data as List;
    } catch (_) {
      return [];
    }
  }
});

// Fetches patient's own consultation history
final patientConsultHistoryProvider =
FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final userId = ref.watch(backendUserIdProvider) ?? 0;
  if (userId == 0) return [];
  return await ConsultService.getConsultationsForPatient(userId);
});

// ── State providers ───────────────────────────────────────────────────────────

final _selectedDoctorProvider =
StateProvider<Map<String, dynamic>?>((ref) => null);
final _requestSentProvider = StateProvider<bool>((ref) => false);

// ── ConsultTab ────────────────────────────────────────────────────────────────

class ConsultTab extends ConsumerWidget {
  const ConsultTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile     = ref.watch(userProfileProvider);
    final selected    = ref.watch(_selectedDoctorProvider);
    final sent        = ref.watch(_requestSentProvider);
    final doctorsAsync = ref.watch(doctorsListProvider);
    final historyAsync = ref.watch(patientConsultHistoryProvider);

    // Build AI summary from real profile data
    final summary = _buildSummary(profile);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(doctorsListProvider);
            ref.invalidate(patientConsultHistoryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 12),

                // AI summary card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AppCard(
                    color: AppColors.primaryLight,
                    borderColor: AppColors.primaryMid,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.auto_awesome_rounded,
                              color: AppColors.primary, size: 16),
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
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.primaryMid)),
                          child: const Text(
                            'This summary will be sent with your request',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryDark,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Doctor list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available doctors',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),

                      doctorsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        ),
                        error: (_, __) => _noDoctorsCard(),
                        data: (doctors) {
                          if (doctors.isEmpty) return _noDoctorsCard();
                          return _doctorListCard(
                              context, ref, doctors, selected, sent);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Send request section
                if (selected != null && !sent)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      AppCard(
                        color: AppColors.surface,
                        child: Row(children: [
                          const Icon(Icons.person_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Sending to: ${selected['name']}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Send request + AI summary',
                        icon:  Icons.send_rounded,
                        onTap: () async {
                          final userId =
                              ref.read(backendUserIdProvider) ?? 0;
                          await ConsultService.createConsultation(
                            patientId:  userId,
                            doctorName: selected['name'] as String,
                            aiSummary:  summary,
                          );
                          ref.read(_requestSentProvider.notifier).state =
                          true;
                          ref.invalidate(patientConsultHistoryProvider);
                        },
                      ),
                    ]),
                  ),

                // Success state
                if (sent)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                    child: AppCard(
                      color: AppColors.successLight,
                      borderColor: const Color(0xFFC0DD97),
                      child: Column(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 48),
                        const SizedBox(height: 12),
                        const Text('Request sent successfully',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF27500A))),
                        const SizedBox(height: 6),
                        Text(
                          'Your request has been sent to ${selected?['name']} with your AI health summary.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3B6D11),
                              height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        AppButton(
                          label:      'Send another request',
                          isOutlined: true,
                          color:      AppColors.success,
                          onTap: () {
                            ref
                                .read(_requestSentProvider.notifier)
                                .state = false;
                            ref
                                .read(_selectedDoctorProvider.notifier)
                                .state = null;
                          },
                        ),
                      ]),
                    ),
                  ),

                // Past consultation history
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your consultation history',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      historyAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2),
                          ),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (history) {
                          if (history.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.border),
                              ),
                              child: const Center(
                                child: Text(
                                  'No consultation requests sent yet.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            );
                          }
                          return AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: history
                                  .asMap()
                                  .entries
                                  .map((e) {
                                final isLast =
                                    e.key == history.length - 1;
                                final c = e.value
                                as Map<String, dynamic>;
                                final status =
                                c['status'] as String;
                                final createdAt =
                                c['created_at'] as String?;
                                String dateStr = '';
                                if (createdAt != null) {
                                  try {
                                    final dt = DateTime.parse(createdAt);
                                    dateStr =
                                    '${dt.day}/${dt.month}/${dt.year}';
                                  } catch (_) {}
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: isLast
                                        ? null
                                        : Border(
                                        bottom: BorderSide(
                                            color: AppColors.border,
                                            width: 0.5)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 38, height: 38,
                                      decoration: BoxDecoration(
                                          color: AppColors.blueLight,
                                          shape: BoxShape.circle),
                                      child: Center(
                                        child: Text(
                                          _initials(c['doctor_name']
                                          as String? ??
                                              '?'),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight.w600,
                                              color: AppColors.blue),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['doctor_name'] ?? 'Doctor',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                FontWeight.w600,
                                                color: AppColors
                                                    .textPrimary),
                                          ),
                                          if (dateStr.isNotEmpty)
                                            Text(dateStr,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textHint)),
                                        ],
                                      ),
                                    ),
                                    // Status badge
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'accepted'
                                            ? AppColors.successLight
                                            : status == 'rejected'
                                            ? AppColors.dangerLight
                                            : AppColors.warningLight,
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status == 'accepted'
                                            ? 'Accepted'
                                            : status == 'rejected'
                                            ? 'Rejected'
                                            : 'Pending',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: status == 'accepted'
                                                ? AppColors.success
                                                : status == 'rejected'
                                                ? AppColors.danger
                                                : AppColors.warning,
                                            fontWeight:
                                            FontWeight.w500),
                                      ),
                                    ),
                                  ]),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Doctor list card ──────────────────────────────────────────────────────

  Widget _doctorListCard(
      BuildContext context,
      WidgetRef ref,
      List<dynamic> doctors,
      Map<String, dynamic>? selected,
      bool sent,
      ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: doctors.asMap().entries.map((e) {
          final isLast = e.key == doctors.length - 1;
          final d      = e.value as Map<String, dynamic>;
          final isSel  = selected?['id'] == d['id'];
          final name   = d['name'] as String? ?? 'Doctor';
          final initials = d['initials'] as String? ?? _initials(name);

          return GestureDetector(
            onTap: () {
              ref.read(_selectedDoctorProvider.notifier).state = d;
              ref.read(_requestSentProvider.notifier).state    = false;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSel ? AppColors.primaryLight : AppColors.white,
                borderRadius: isLast
                    ? const BorderRadius.only(
                    bottomLeft:  Radius.circular(14),
                    bottomRight: Radius.circular(14))
                    : BorderRadius.zero,
                border: isLast
                    ? null
                    : Border(
                    bottom: BorderSide(
                        color: AppColors.border, width: 0.5)),
              ),
              child: Row(children: [
                // Avatar with initials
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.primary
                          : AppColors.blueLight,
                      shape: BoxShape.circle),
                  child: Center(
                    child: Text(initials,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? AppColors.white
                                : AppColors.blue)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary)),
                      Text('Registered doctor',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                // Available badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Available',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500)),
                ),
                if (isSel) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 18),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── No doctors state ──────────────────────────────────────────────────────

  Widget _noDoctorsCard() {
    return AppCard(
      child: Column(children: const [
        Icon(Icons.medical_services_outlined,
            color: AppColors.textHint, size: 40),
        SizedBox(height: 10),
        Text('No doctors registered yet',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        SizedBox(height: 4),
        Text(
          'Doctors need to create an account with the Doctor role first.',
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

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
          Text('Select a real registered doctor and send your request',
              style: TextStyle(
                  fontSize: 12, color: AppColors.primaryMid)),
        ],
      ),
    );
  }

  // ── Build AI summary from real profile ───────────────────────────────────

  String _buildSummary(UserProfile profile) {
    final parts = <String>[];

    if (profile.name.isNotEmpty) parts.add(profile.name);
    if (profile.age > 0) {
      parts.add(
          '${profile.age}y${profile.gender.isNotEmpty ? ' ${profile.gender[0]}' : ''}');
    }
    if (profile.bloodGroup.isNotEmpty) {
      parts.add('Blood: ${profile.bloodGroup}');
    }
    if (profile.weight > 0) {
      parts.add('${profile.weight.toStringAsFixed(0)} kg');
    }
    if (profile.height > 0) {
      parts.add('${profile.height.toStringAsFixed(0)} cm');
    }
    if (profile.bmi > 0) {
      parts.add('BMI: ${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})');
    }

    if (parts.isEmpty) {
      return 'Patient profile not complete. Please update your profile for a full summary.';
    }

    return '${parts.join(' · ')}. Requesting doctor consultation. Please review and respond.';
  }

  // ── Initials helper ───────────────────────────────────────────────────────

  String _initials(String name) {
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}