import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/metric_card.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/services/health_connect.dart';
import '../main_shell.dart';
import '../alert/alert_screen.dart';
import '../auth/login_screen.dart';
import '../../shared/services/vitals_service.dart';
import '../../shared/services/lab_service.dart';

// Provider to load latest lab report from backend
final latestLabProvider =
FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(backendUserIdProvider) ?? 0;
  if (userId == 0) return {};
  final result = await LabService.getLatestLabReport(userId);
  if (result == null || result['status'] == 'no_data') return {};
  return result;
});

// Real health data provider
final healthDataProvider =
FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return await healthService.fetchTodayData();
});

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final healthAsync = ref.watch(healthDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(healthDataProvider);
          },
          child: healthAsync.when(
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Fetching health data...',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            error: (e, _) =>
                _buildContent(context, ref, profile, {}, error: e.toString()),
            data: (data) => _buildContent(context, ref, profile, data),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      UserProfile profile, Map<String, dynamic> data,
      {String? error}) {
    final steps = (data['steps'] as int?) ?? 0;
    final hr = (data['heartRate'] as double?) ?? 0.0;
    final spo2 = (data['spo2'] as double?) ?? 0.0;
    final cal = (data['calories'] as double?) ?? 0.0;
    final sleep = (data['sleepHours'] as double?) ?? 0.0;
    final temp = (data['temperature'] as double?) ?? 0.0;
    final sys = (data['systolic'] as double?) ?? 0.0;
    final dia = (data['diastolic'] as double?) ?? 0.0;
    final score = healthService.calculateHealthScore(data);

    _saveToBackend(ref, data);
    final criticalAlert = _getCriticalAlert(hr, spo2, temp);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildHeader(context, ref, profile, score, sys, dia),
          if (criticalAlert != null) _criticalBanner(context, criticalAlert),
          if (error != null) _errorBanner(error),
          const SizedBox(height: 12),
          _metricGrid(hr, spo2, steps, cal, sleep, temp),
          const SizedBox(height: 12),
          _labSection(context, ref),
          const SizedBox(height: 12),
          _alertTestBanner(context),
          const SizedBox(height: 8),
          _refreshHint(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Map<String, String>? _getCriticalAlert(
      double hr, double spo2, double temp) {
    if (spo2 > 0 && spo2 < 90) {
      return {
        'parameter': 'SpO₂',
        'value': '${spo2.toStringAsFixed(0)}%',
        'message': 'SpO₂ critically low — immediate attention needed.',
      };
    }
    if (hr > 0 && hr > 130) {
      return {
        'parameter': 'Heart rate',
        'value': '${hr.toStringAsFixed(0)} bpm',
        'message': 'Heart rate critically high.',
      };
    }
    if (temp > 0 && temp > 39) {
      return {
        'parameter': 'Temperature',
        'value': '${temp.toStringAsFixed(1)}°C',
        'message': 'High fever detected.',
      };
    }
    return null;
  }

  Future<void> _saveToBackend(
      WidgetRef ref, Map<String, dynamic> data) async {
    try {
      final userId = ref.read(backendUserIdProvider) ?? 0;
      if (userId == 0) return;
      final hr = (data['heartRate'] as double?) ?? 0;
      final spo2 = (data['spo2'] as double?) ?? 0;
      if (hr == 0 && spo2 == 0) return;
      await VitalsService.saveVitals(
        userId: userId,
        heartRate: hr,
        spo2: spo2,
        steps: (data['steps'] as int?) ?? 0,
        calories: (data['calories'] as double?) ?? 0,
        sleepHours: (data['sleepHours'] as double?) ?? 0,
        temperature: (data['temperature'] as double?) ?? 0,
      );
    } catch (e) {
      print('Backend save error: $e');
    }
  }

  // ── HEADER WITH LOGOUT ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, WidgetRef ref,
      UserProfile profile, int score, double sys, double dia) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row — greeting + logout button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.primaryMid),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.name.isNotEmpty ? profile.name : 'Welcome',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white),
                  ),
                  if (profile.age > 0)
                    Text(
                      '${profile.age}y · ${profile.gender} · ${profile.bloodGroup}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primaryMid),
                    ),
                ],
              ),
              // Logout button
              GestureDetector(
                onTap: () async {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                  await AuthService.logout();  // this clears JWT token too
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
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppColors.primaryMid, size: 14),
                      SizedBox(width: 4),
                      Text('Logout',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryMid)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Health score card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Health score',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.primaryMid)),
                    const SizedBox(height: 4),
                    Text('$score',
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            height: 1)),
                    const SizedBox(height: 4),
                    Text(
                      score >= 85
                          ? 'Excellent'
                          : score >= 70
                          ? 'Good condition'
                          : score >= 55
                          ? 'Fair — monitor closely'
                          : 'Needs attention',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.tealMid),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Health Connect: Live',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.tealMid,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 6),
                    if (sys > 0 && dia > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            'BP: ${sys.toStringAsFixed(0)}/${dia.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Pull to refresh',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primaryMid)),
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _criticalBanner(
      BuildContext context, Map<String, String> alert) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlertScreen(
            parameter: alert['parameter']!,
            value: alert['value']!,
            message: alert['message']!,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF09595), width: 2),
        ),
        child: Row(children: [
          const Icon(Icons.warning_rounded,
              color: AppColors.danger, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Critical: ${alert['parameter']} ${alert['value']}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF791F1F))),
                Text(alert['message']!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFA32D2D))),
              ],
            ),
          ),
          const Text('View →',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _errorBanner(String error) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFAC775)),
      ),
      child: const Row(children: [
        Icon(Icons.info_rounded, color: AppColors.warning, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Health Connect data unavailable. Make sure Health Connect app is installed and permissions are granted.',
            style: TextStyle(fontSize: 11, color: AppColors.warning),
          ),
        ),
      ]),
    );
  }

  Widget _metricGrid(double hr, double spo2, int steps,
      double cal, double sleep, double temp) {
    String fmt(double v, {int decimals = 0}) =>
        v > 0 ? v.toStringAsFixed(decimals) : '--';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: [
          MetricCard(
            label: 'Heart rate',
            value: fmt(hr),
            unit: hr > 0 ? 'bpm' : '',
            status: hr <= 0 ? 'No data' : hr > 100 || hr < 60 ? 'Abnormal' : 'Normal',
            statusColor: hr <= 0 ? AppColors.textHint : hr > 100 || hr < 60 ? AppColors.danger : AppColors.success,
            statusBg: hr <= 0 ? AppColors.surface : hr > 100 || hr < 60 ? AppColors.dangerLight : AppColors.successLight,
            progress: hr > 0 ? (hr / 180).clamp(0.0, 1.0) : 0,
            progressColor: AppColors.tealMid,
          ),
          MetricCard(
            label: 'SpO₂',
            value: fmt(spo2),
            unit: spo2 > 0 ? '%' : '',
            status: spo2 <= 0 ? 'No data' : spo2 < 90 ? 'Critical' : spo2 < 95 ? 'Low' : 'Excellent',
            statusColor: spo2 <= 0 ? AppColors.textHint : spo2 < 90 ? AppColors.danger : spo2 < 95 ? AppColors.warning : AppColors.success,
            statusBg: spo2 <= 0 ? AppColors.surface : spo2 < 90 ? AppColors.dangerLight : spo2 < 95 ? AppColors.warningLight : AppColors.successLight,
            progress: spo2 > 0 ? (spo2 / 100).clamp(0.0, 1.0) : 0,
            progressColor: AppColors.tealMid,
          ),
          MetricCard(
            label: 'Steps today',
            value: steps > 0 ? steps.toString() : '--',
            unit: '',
            status: steps <= 0 ? 'No data' : steps >= 10000 ? 'Goal reached!' : '${((steps / 10000) * 100).toStringAsFixed(0)}% of goal',
            statusColor: steps <= 0 ? AppColors.textHint : AppColors.blue,
            statusBg: steps <= 0 ? AppColors.surface : AppColors.blueLight,
            progress: steps > 0 ? (steps / 10000).clamp(0.0, 1.0) : 0,
            progressColor: AppColors.blue,
          ),
          MetricCard(
            label: 'Calories',
            value: cal > 0 ? cal.toStringAsFixed(0) : '--',
            unit: cal > 0 ? 'kcal' : '',
            status: cal <= 0 ? 'No data' : cal > 1500 ? 'Active day' : 'Keep moving',
            statusColor: cal <= 0 ? AppColors.textHint : AppColors.warning,
            statusBg: cal <= 0 ? AppColors.surface : AppColors.warningLight,
            progress: cal > 0 ? (cal / 2500).clamp(0.0, 1.0) : 0,
            progressColor: const Color(0xFFEF9F27),
          ),
          MetricCard(
            label: 'Sleep',
            value: fmt(sleep, decimals: 1),
            unit: sleep > 0 ? 'hrs' : '',
            status: sleep <= 0 ? 'No data' : sleep >= 7 ? 'Good' : sleep >= 6 ? 'Fair' : 'Low',
            statusColor: sleep <= 0 ? AppColors.textHint : sleep >= 7 ? AppColors.success : AppColors.warning,
            statusBg: sleep <= 0 ? AppColors.surface : sleep >= 7 ? AppColors.successLight : AppColors.warningLight,
            progress: sleep > 0 ? (sleep / 9).clamp(0.0, 1.0) : 0,
            progressColor: AppColors.primary,
          ),
          MetricCard(
            label: 'Temperature',
            value: fmt(temp, decimals: 1),
            unit: temp > 0 ? '°C' : '',
            status: temp <= 0 ? 'No data' : temp > 38.5 ? 'Fever' : temp > 37.5 ? 'Elevated' : 'Normal',
            statusColor: temp <= 0 ? AppColors.textHint : temp > 38.5 ? AppColors.danger : temp > 37.5 ? AppColors.warning : AppColors.success,
            statusBg: temp <= 0 ? AppColors.surface : temp > 38.5 ? AppColors.dangerLight : temp > 37.5 ? AppColors.warningLight : AppColors.successLight,
            progress: temp > 0 ? ((temp - 35) / 6).clamp(0.0, 1.0) : 0,
            progressColor: AppColors.tealMid,
          ),
        ],
      ),
    );
  }

  Widget _labSection(BuildContext context, WidgetRef ref) {
    final labAsync = ref.watch(latestLabProvider);

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
            labAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2)),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Could not load lab data',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ),
              data: (lab) {
                if (lab.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      const Icon(Icons.science_outlined,
                          color: AppColors.textHint, size: 32),
                      const SizedBox(height: 8),
                      const Text('No lab reports yet',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => ref
                            .read(shellIndexProvider.notifier)
                            .state = 3,
                        child: const Text('Upload your first report →',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  );
                }

                // Build rows from real DB data
                final rows = <Map<String, dynamic>>[];
                void addRow(String key, String label, String? unit) {
                  final val = lab[key];
                  if (val != null && val is num && val > 0) {
                    rows.add({
                      'label': label,
                      'value':
                      '${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)}${unit != null ? ' $unit' : ''}',
                    });
                  }
                }

                addRow('hemoglobin', 'Hemoglobin', 'g%');
                addRow('rbc', 'RBC', 'mil/cmm');
                addRow('wbc', 'WBC', '/cumm');
                addRow('platelets', 'Platelets', '/cumm');
                addRow('glucose', 'Glucose', 'mg/dL');
                addRow('cholesterol', 'Cholesterol', 'mg/dL');
                addRow('triglycerides', 'Triglycerides', 'mg/dL');
                addRow('creatinine', 'Creatinine', 'mg/dL');
                addRow('uric_acid', 'Uric acid', 'mg/dL');
                addRow('sgpt', 'SGPT', 'U/L');
                addRow('sgot', 'SGOT', 'U/L');
                addRow('hba1c', 'HbA1c', '%');
                addRow('tsh', 'TSH', 'mIU/L');
                addRow('vitamin_d', 'Vitamin D', 'ng/mL');
                addRow('vitamin_b12', 'Vitamin B12', 'pg/mL');

                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No values in latest report',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  );
                }

                return Column(
                  children: rows.asMap().entries.map((e) {
                    final isLast = e.key == rows.length - 1;
                    final row = e.value;
                    return _labRow(
                        row['label'], row['value'], isLast);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _labRow(String name, String value, bool isLast,
      {bool isBorderline = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Row(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            StatusBadge(
              label: isBorderline ? 'Borderline' : 'Normal',
              type: isBorderline ? BadgeType.warning : BadgeType.normal,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _alertTestBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AlertScreen())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF09595)),
          ),
          child: Row(children: const [
            Icon(Icons.warning_rounded, color: AppColors.danger, size: 20),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency alert demo',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF791F1F))),
                Text('Tap to see alert screen',
                    style: TextStyle(fontSize: 11, color: Color(0xFFA32D2D))),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _refreshHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.refresh_rounded, size: 14, color: AppColors.textHint),
          SizedBox(width: 4),
          Text('Pull down to refresh health data',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }
}