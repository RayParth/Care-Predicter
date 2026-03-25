import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../auth/login_screen.dart';

class DoctorDashboardTab extends ConsumerWidget {
  const DoctorDashboardTab({super.key});

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
              _buildStatsRow(),
              const SizedBox(height: 12),
              _buildRecentConsultations(),
              const SizedBox(height: 12),
              _buildAiSummaryPanel(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, UserProfile profile) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Good morning, Doctor',
                      style: TextStyle(fontSize: 13, color: Color(0xFF85B7EB))),
                  const SizedBox(height: 2),
                  Text(
                    profile.name.isNotEmpty ? 'Dr. ${profile.name}' : 'Dr. Welcome',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const Text('General Physician · Care Predicter',
                      style: TextStyle(fontSize: 11, color: Color(0xFF85B7EB))),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                  await ref.read(userProfileProvider.notifier).clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C447C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(children: [
                    Icon(Icons.logout_rounded, color: Color(0xFF85B7EB), size: 14),
                    SizedBox(width: 4),
                    Text('Logout', style: TextStyle(fontSize: 11, color: Color(0xFF85B7EB))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0C447C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('4', 'Patients today'),
                _divider(),
                _statChip('2', 'Pending reviews'),
                _divider(),
                _statChip('1', 'Critical alert'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF85B7EB))),
    ]);
  }

  Widget _divider() {
    return Container(width: 1, height: 36,
        color: const Color(0xFF185FA5).withOpacity(0.5));
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(child: _StatCard(
            icon: Icons.people_rounded, label: 'Total patients',
            value: '12', color: AppColors.blue, bg: AppColors.blueLight)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
            icon: Icons.check_circle_rounded, label: 'Consultations done',
            value: '38', color: AppColors.success, bg: AppColors.successLight)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
            icon: Icons.warning_rounded, label: 'Active alerts',
            value: '1', color: AppColors.danger, bg: AppColors.dangerLight)),
      ]),
    );
  }

  Widget _buildRecentConsultations() {
    final patients = [
      {'name': 'Dhara Patel', 'age': '24F', 'score': '82', 'status': 'Good', 'time': '10:30 AM'},
      {'name': 'Ravi Sharma', 'age': '45M', 'score': '61', 'status': 'Caution', 'time': '11:00 AM'},
      {'name': 'Priya Modi', 'age': '32F', 'score': '91', 'status': 'Excellent', 'time': '2:00 PM'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today\'s consultations',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: patients.asMap().entries.map((e) {
                final isLast = e.key == patients.length - 1;
                final p = e.value;
                final score = int.parse(p['score']!);
                final statusColor = score >= 80 ? AppColors.success
                    : score >= 60 ? AppColors.warning : AppColors.danger;
                final statusBg = score >= 80 ? AppColors.successLight
                    : score >= 60 ? AppColors.warningLight : AppColors.dangerLight;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                        bottom: BorderSide(color: AppColors.border, width: 0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: AppColors.blueLight, shape: BoxShape.circle),
                      child: Center(child: Text(
                          p['name']!.substring(0, 1),
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w600, color: AppColors.blue))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name']!, style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                        Text('${p['age']} · ${p['time']}',
                            style: const TextStyle(fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    )),
                    Column(children: [
                      Text('${p['score']}/100',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: statusColor)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: statusBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(p['status']!,
                            style: TextStyle(fontSize: 10, color: statusColor,
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

  Widget _buildAiSummaryPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        color: AppColors.blueLight,
        borderColor: const Color(0xFF85B7EB),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.auto_awesome_rounded, color: AppColors.blue, size: 16),
              SizedBox(width: 6),
              Text('AI daily summary',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: Color(0xFF0C447C))),
            ]),
            const SizedBox(height: 8),
            const Text(
              '2 patients have stable readings today. Ravi Sharma (45M) shows borderline triglycerides at 148 mg/dL — recommend dietary review. No critical anomalies detected in last 24 hours.',
              style: TextStyle(fontSize: 12, color: AppColors.blue, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _StatCard({required this.icon, required this.label,
    required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 10,
            color: AppColors.textSecondary)),
      ]),
    );
  }
}