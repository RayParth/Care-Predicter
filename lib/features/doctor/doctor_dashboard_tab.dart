import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/consult_service.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/login_screen.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
//
// Fetches all consultations sent to this doctor from the backend.
// Each item includes: patient profile + vitals + lab values.
//
final doctorConsultationsProvider =
FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final profile = ref.watch(userProfileProvider);
  if (profile.name.isEmpty) return [];
  return await ConsultService.getConsultationsForDoctor(profile.name);
});

// ── DoctorDashboardTab ────────────────────────────────────────────────────────

class DoctorDashboardTab extends ConsumerWidget {
  const DoctorDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile      = ref.watch(userProfileProvider);
    final consultAsync = ref.watch(doctorConsultationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () async =>
              ref.invalidate(doctorConsultationsProvider),
          child: consultAsync.when(
            loading: () => _buildLoading(context, ref, profile),
            error:   (_, __) => _buildContent(context, ref, profile, []),
            data:    (list) => _buildContent(context, ref, profile, list),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(
      BuildContext context, WidgetRef ref, UserProfile profile) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(children: [
        _buildHeader(context, ref, profile, 0, 0, 0),
        const SizedBox(height: 40),
        const Center(
            child: CircularProgressIndicator(color: AppColors.blue)),
      ]),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      UserProfile profile, List<dynamic> consultations) {

    // Real counts from actual data
    final total    = consultations.length;
    final pending  = consultations
        .where((c) => c['status'] == 'pending')
        .length;
    final accepted = consultations
        .where((c) => c['status'] == 'accepted')
        .length;

    // Count critical: patient vitals where spo2 < 90 or hr > 130
    final critical = consultations.where((c) {
      final v = c['vitals'];
      if (v == null) return false;
      final spo2 = (v['spo2'] as num?)?.toDouble() ?? 0;
      final hr   = (v['heart_rate'] as num?)?.toDouble() ?? 0;
      return (spo2 > 0 && spo2 < 90) || (hr > 0 && hr > 130);
    }).length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(children: [
        _buildHeader(context, ref, profile, total, pending, critical),
        const SizedBox(height: 12),
        _buildStatsRow(total, accepted, critical),
        const SizedBox(height: 12),
        _buildConsultationList(context, ref, consultations),
        const SizedBox(height: 12),
        _buildAiSummary(consultations),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, WidgetRef ref,
      UserProfile profile, int total, int pending, int critical) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF85B7EB))),
                const SizedBox(height: 2),
                Text(
                  profile.name.isNotEmpty
                      ? 'Dr. ${profile.name}'
                      : 'Dr. Welcome',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const Text('Care Predicter · Doctor Dashboard',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF85B7EB))),
              ]),
              GestureDetector(
                onTap: () async {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                  await AuthService.logout();
                  await ref.read(userProfileProvider.notifier).clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                          (_) => false,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C447C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(children: [
                    Icon(Icons.logout_rounded,
                        color: Color(0xFF85B7EB), size: 14),
                    SizedBox(width: 4),
                    Text('Logout',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF85B7EB))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stats row — real numbers
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0C447C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('$total',   'Total requests'),
                _divider(),
                _statChip('$pending', 'Pending'),
                _divider(),
                _statChip('$critical', critical > 0 ? 'Critical ⚠' : 'Critical'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: Color(0xFF85B7EB))),
    ]);
  }

  Widget _divider() {
    return Container(
        width: 1, height: 36,
        color: const Color(0xFF185FA5).withOpacity(0.5));
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(int total, int accepted, int critical) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(child: _StatCard(
            icon:  Icons.people_rounded,
            label: 'Total patients',
            value: '$total',
            color: AppColors.blue,
            bg:    AppColors.blueLight)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
            icon:  Icons.check_circle_rounded,
            label: 'Accepted',
            value: '$accepted',
            color: AppColors.success,
            bg:    AppColors.successLight)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
            icon:  Icons.warning_rounded,
            label: 'Critical',
            value: '$critical',
            color: AppColors.danger,
            bg:    AppColors.dangerLight)),
      ]),
    );
  }

  // ── Consultation List ─────────────────────────────────────────────────────

  Widget _buildConsultationList(
      BuildContext context, WidgetRef ref, List<dynamic> consultations) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Patient requests',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text('${consultations.length} total',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),

          if (consultations.isEmpty)
            AppCard(
              child: Column(children: const [
                Icon(Icons.inbox_rounded,
                    color: AppColors.textHint, size: 40),
                SizedBox(height: 10),
                Text('No consultation requests yet',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                SizedBox(height: 4),
                Text(
                  'When patients send you a request it will appear here.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ]),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: consultations.asMap().entries.map((e) {
                  final isLast = e.key == consultations.length - 1;
                  final c      = e.value as Map<String, dynamic>;
                  final p      = c['patient'] as Map<String, dynamic>?;
                  final v      = c['vitals']  as Map<String, dynamic>?;

                  final name   = p?['name']   ?? 'Unknown Patient';
                  final age    = p?['age'];
                  final gender = p?['gender'];
                  final status = c['status']  as String;

                  // Calculate score from real vitals
                  final score  = _scoreFromVitals(v);

                  final statusColor = status == 'accepted'
                      ? AppColors.success
                      : status == 'rejected'
                      ? AppColors.danger
                      : AppColors.warning;
                  final statusBg = status == 'accepted'
                      ? AppColors.successLight
                      : status == 'rejected'
                      ? AppColors.dangerLight
                      : AppColors.warningLight;
                  final statusLabel = status == 'accepted'
                      ? 'Accepted'
                      : status == 'rejected'
                      ? 'Rejected'
                      : 'Pending';

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
                      // Avatar
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                              name.isNotEmpty
                                  ? name.substring(0, 1).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blue)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text(
                              [
                                if (age != null) '${age}y',
                                if (gender != null) gender.toString().substring(0, 1),
                                if (v != null && (v['heart_rate'] as num?) != null)
                                  'HR: ${(v['heart_rate'] as num).toStringAsFixed(0)} bpm',
                              ].join(' · '),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (score > 0)
                              Text('$score/100',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: score >= 70
                                          ? AppColors.success
                                          : AppColors.warning)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(statusLabel,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: statusColor,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ]),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── AI Daily Summary ──────────────────────────────────────────────────────

  Widget _buildAiSummary(List<dynamic> consultations) {
    final pending  = consultations.where((c) => c['status'] == 'pending').length;
    final critical = consultations.where((c) {
      final v = c['vitals'];
      if (v == null) return false;
      final spo2 = (v['spo2'] as num?)?.toDouble() ?? 0;
      final hr   = (v['heart_rate'] as num?)?.toDouble() ?? 0;
      return (spo2 > 0 && spo2 < 90) || (hr > 0 && hr > 130);
    }).length;

    String summary;
    if (consultations.isEmpty) {
      summary = 'No consultation requests yet. When patients send you requests, their health summaries will appear here.';
    } else {
      summary = '${consultations.length} patient request${consultations.length == 1 ? '' : 's'} in total. '
          '$pending pending review${pending == 1 ? '' : 's'}. '
          '${critical > 0 ? '$critical patient${critical == 1 ? '' : 's'} with critical vitals — review immediately.' : 'No critical vitals detected.'} '
          'Check the Patients tab for full lab and vitals data.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        color: AppColors.blueLight,
        borderColor: const Color(0xFF85B7EB),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.blue, size: 16),
              SizedBox(width: 6),
              Text('AI daily summary',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0C447C))),
            ]),
            const SizedBox(height: 8),
            Text(summary,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.blue,
                    height: 1.6)),
          ],
        ),
      ),
    );
  }

  // ── Score calculation from real vitals ────────────────────────────────────

  int _scoreFromVitals(Map<String, dynamic>? v) {
    if (v == null) return 0;
    int score = 100;
    final hr   = (v['heart_rate'] as num?)?.toDouble() ?? 0;
    final spo2 = (v['spo2']       as num?)?.toDouble() ?? 0;

    int points = 0;
    if (hr   > 0) points++;
    if (spo2 > 0) points++;
    if (points == 0) return 0;

    if (hr > 0) {
      if (hr > 120 || hr < 50)      score -= 20;
      else if (hr > 100 || hr < 60) score -= 10;
    }
    if (spo2 > 0) {
      if (spo2 < 90)      score -= 30;
      else if (spo2 < 95) score -= 15;
      else if (spo2 < 97) score -= 5;
    }
    return score.clamp(0, 100);
  }
}

// ── Stat Card Widget ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  final Color    bg;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
}