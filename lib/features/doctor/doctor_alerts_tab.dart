import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import 'doctor_dashboard_tab.dart'; // reuse doctorConsultationsProvider

// ── DoctorAlertsTab ───────────────────────────────────────────────────────────
//
// Generates alerts from REAL consultation vitals pulled from the backend.
// No hardcoded patient names or values.
//
// Alert rules:
//   Critical: SpO2 < 90  OR  HR > 130  OR  Temperature > 39
//   Warning:  SpO2 < 95  OR  HR > 100  OR  HR < 60  OR  Temperature > 38.5
//

class DoctorAlertsTab extends ConsumerStatefulWidget {
  const DoctorAlertsTab({super.key});

  @override
  ConsumerState<DoctorAlertsTab> createState() => _DoctorAlertsTabState();
}

class _DoctorAlertsTabState extends ConsumerState<DoctorAlertsTab> {
  // Track acknowledged alerts locally by consultation id + parameter
  final Set<String> _acknowledged = {};

  @override
  Widget build(BuildContext context) {
    final consultAsync = ref.watch(doctorConsultationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            color: AppColors.blue,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient alerts',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text('Critical and warning vitals from your patients',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF85B7EB))),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.blue,
              onRefresh: () async =>
                  ref.invalidate(doctorConsultationsProvider),
              child: consultAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.blue)),
                error: (_, __) => _buildEmpty('Could not load alerts'),
                data: (list) {
                  final alerts = _buildAlerts(list);
                  if (alerts.isEmpty) return _buildEmpty(null);
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: alerts.length,
                    itemBuilder: (_, i) => _alertCard(alerts[i]),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Generate alerts from real vitals ─────────────────────────────────────

  List<Map<String, dynamic>> _buildAlerts(List<dynamic> consultations) {
    final alerts = <Map<String, dynamic>>[];

    for (final c in consultations) {
      final consult = c as Map<String, dynamic>;
      final v       = consult['vitals'] as Map<String, dynamic>?;
      final p       = consult['patient'] as Map<String, dynamic>?;
      final consultId = consult['id'] as int;

      if (v == null || p == null) continue;

      final name = p['name'] ?? 'Unknown Patient';
      final hr   = (v['heart_rate']  as num?)?.toDouble() ?? 0;
      final spo2 = (v['spo2']        as num?)?.toDouble() ?? 0;
      final temp = (v['temperature'] as num?)?.toDouble() ?? 0;

      // SpO2 alerts
      if (spo2 > 0 && spo2 < 90) {
        alerts.add({
          'key':       '$consultId-spo2',
          'patient':   name,
          'parameter': 'SpO₂',
          'value':     '${spo2.toStringAsFixed(0)}%',
          'severity':  'Critical',
          'message':   'SpO₂ critically low — below 90%. Immediate attention required.',
        });
      } else if (spo2 > 0 && spo2 < 95) {
        alerts.add({
          'key':       '$consultId-spo2-warn',
          'patient':   name,
          'parameter': 'SpO₂',
          'value':     '${spo2.toStringAsFixed(0)}%',
          'severity':  'Warning',
          'message':   'SpO₂ below safe threshold of 95%.',
        });
      }

      // Heart rate alerts
      if (hr > 0 && hr > 130) {
        alerts.add({
          'key':       '$consultId-hr-high',
          'patient':   name,
          'parameter': 'Heart rate',
          'value':     '${hr.toStringAsFixed(0)} bpm',
          'severity':  'Critical',
          'message':   'Heart rate critically high. Risk of arrhythmia.',
        });
      } else if (hr > 0 && hr > 100) {
        alerts.add({
          'key':       '$consultId-hr-warn',
          'patient':   name,
          'parameter': 'Heart rate',
          'value':     '${hr.toStringAsFixed(0)} bpm',
          'severity':  'Warning',
          'message':   'Heart rate elevated above normal range.',
        });
      } else if (hr > 0 && hr < 50) {
        alerts.add({
          'key':       '$consultId-hr-low',
          'patient':   name,
          'parameter': 'Heart rate',
          'value':     '${hr.toStringAsFixed(0)} bpm',
          'severity':  'Warning',
          'message':   'Heart rate critically low — bradycardia.',
        });
      }

      // Temperature alerts
      if (temp > 0 && temp > 39) {
        alerts.add({
          'key':       '$consultId-temp',
          'patient':   name,
          'parameter': 'Temperature',
          'value':     '${temp.toStringAsFixed(1)}°C',
          'severity':  'Critical',
          'message':   'High fever detected. Immediate evaluation recommended.',
        });
      } else if (temp > 0 && temp > 38.5) {
        alerts.add({
          'key':       '$consultId-temp-warn',
          'patient':   name,
          'parameter': 'Temperature',
          'value':     '${temp.toStringAsFixed(1)}°C',
          'severity':  'Warning',
          'message':   'Elevated body temperature.',
        });
      }
    }

    // Sort: critical first, then warning
    alerts.sort((a, b) {
      if (a['severity'] == 'Critical' && b['severity'] != 'Critical') return -1;
      if (b['severity'] == 'Critical' && a['severity'] != 'Critical') return 1;
      return 0;
    });

    return alerts;
  }

  // ── Alert Card ────────────────────────────────────────────────────────────

  Widget _alertCard(Map<String, dynamic> alert) {
    final key        = alert['key'] as String;
    final isCritical = alert['severity'] == 'Critical';
    final acked      = _acknowledged.contains(key);
    final color      = isCritical ? AppColors.danger : AppColors.warning;
    final bg         = isCritical ? AppColors.dangerLight : AppColors.warningLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: acked ? AppColors.white : bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: acked ? AppColors.border : color.withOpacity(0.4),
            width: acked ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              isCritical
                  ? Icons.warning_rounded
                  : Icons.info_rounded,
              color: acked ? AppColors.textHint : color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${alert['patient']} — ${alert['parameter']}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: acked ? AppColors.textSecondary : color),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: acked ? AppColors.surface : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                acked ? 'Acknowledged' : alert['severity'],
                style: TextStyle(
                    fontSize: 10,
                    color: acked ? AppColors.textHint : color,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Value: ${alert['value']}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: acked ? AppColors.textHint : color),
          ),
          const SizedBox(height: 2),
          Text(
            alert['message'],
            style: TextStyle(
                fontSize: 11,
                color: acked ? AppColors.textHint : color,
                height: 1.4),
          ),
          if (!acked) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _acknowledged.add(key)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Acknowledge',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(String? message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const Icon(Icons.notifications_none_rounded,
              color: AppColors.textHint, size: 48),
          const SizedBox(height: 12),
          Text(
            message ?? 'No alerts — all your patients\' vitals are within normal range.',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}