import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_card.dart';

class DoctorAlertsTab extends StatefulWidget {
  const DoctorAlertsTab({super.key});

  @override
  State<DoctorAlertsTab> createState() => _DoctorAlertsTabState();
}

class _DoctorAlertsTabState extends State<DoctorAlertsTab> {
  final List<Map<String, dynamic>> _alerts = [
    {
      'patient': 'Ravi Sharma',
      'parameter': 'Blood Pressure',
      'value': '148/92 mmHg',
      'severity': 'Critical',
      'time': '10:14 AM',
      'acknowledged': false,
    },
    {
      'patient': 'Dhara Patel',
      'parameter': 'Triglycerides',
      'value': '140 mg/dL',
      'severity': 'Warning',
      'time': 'Yesterday',
      'acknowledged': true,
    },
    {
      'patient': 'Priya Modi',
      'parameter': 'Heart Rate',
      'value': '108 bpm',
      'severity': 'Warning',
      'time': '2 days ago',
      'acknowledged': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              color: AppColors.blue,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patient alerts',
                      style: TextStyle(fontSize: 20,
                          fontWeight: FontWeight.w600, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Critical and warning notifications',
                      style: TextStyle(fontSize: 12, color: Color(0xFF85B7EB))),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _alerts.length,
                itemBuilder: (_, i) {
                  final a = _alerts[i];
                  final isCritical = a['severity'] == 'Critical';
                  final color = isCritical ? AppColors.danger : AppColors.warning;
                  final bg = isCritical ? AppColors.dangerLight : AppColors.warningLight;
                  final acked = a['acknowledged'] as bool;

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
                          Icon(isCritical ? Icons.warning_rounded : Icons.info_rounded,
                              color: acked ? AppColors.textHint : color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                              '${a['patient']} — ${a['parameter']}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: acked ? AppColors.textSecondary : color))),
                          Text(a['time'],
                              style: const TextStyle(fontSize: 10,
                                  color: AppColors.textHint)),
                        ]),
                        const SizedBox(height: 6),
                        Text('Value: ${a['value']}',
                            style: TextStyle(fontSize: 12,
                                color: acked ? AppColors.textHint : color)),
                        if (!acked) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => setState(
                                      () => _alerts[i]['acknowledged'] = true),
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
                        ] else
                          const Text('✓ Acknowledged',
                              style: TextStyle(fontSize: 11,
                                  color: AppColors.textHint)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}