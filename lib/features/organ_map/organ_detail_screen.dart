
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class OrganDetailScreen extends StatelessWidget {
  final Map<String, dynamic> organ;

  const OrganDetailScreen({super.key, required this.organ});

  Map<String, List<Map<String, String>>> get _organData => {
    'heart': [
      {'label': 'Heart rate', 'value': '76 bpm', 'ref': '60–100', 'status': 'Normal'},
      {'label': 'Blood pressure', 'value': '118/76 mmHg', 'ref': '< 120/80', 'status': 'Normal'},
      {'label': 'Resting HR', 'value': '62 bpm', 'ref': '< 70', 'status': 'Excellent'},
      {'label': 'ECG status', 'value': 'Sinus rhythm', 'ref': 'Normal', 'status': 'Normal'},
      {'label': 'Cholesterol', 'value': '178 mg/dL', 'ref': '< 200', 'status': 'Normal'},
      {'label': 'LDL', 'value': '102 mg/dL', 'ref': '< 130', 'status': 'Normal'},
    ],
    'lungs': [
      {'label': 'SpO₂', 'value': '98%', 'ref': '> 95%', 'status': 'Excellent'},
      {'label': 'Respiratory rate', 'value': '16 /min', 'ref': '12–20', 'status': 'Normal'},
      {'label': 'Peak flow', 'value': '480 L/min', 'ref': '> 400', 'status': 'Normal'},
      {'label': 'FEV1', 'value': '92%', 'ref': '> 80%', 'status': 'Good'},
    ],
    'brain': [
      {'label': 'Sleep duration', 'value': '7.2 hrs', 'ref': '7–9 hrs', 'status': 'Good'},
      {'label': 'Sleep quality', 'value': '78%', 'ref': '> 70%', 'status': 'Good'},
      {'label': 'Stress index', 'value': '42%', 'ref': '< 40%', 'status': 'Moderate'},
      {'label': 'Activity score', 'value': '68%', 'ref': '> 60%', 'status': 'Active'},
    ],
    'liver': [
      {'label': 'SGPT', 'value': '28 U/L', 'ref': '7–56', 'status': 'Normal'},
      {'label': 'SGOT', 'value': '24 U/L', 'ref': '10–40', 'status': 'Normal'},
      {'label': 'Bilirubin', 'value': '0.8 mg/dL', 'ref': '0.2–1.2', 'status': 'Normal'},
      {'label': 'ALT', 'value': '30 U/L', 'ref': '7–56', 'status': 'Normal'},
    ],
    'stomach': [
      {'label': 'Glucose', 'value': '94 mg/dL', 'ref': '70–100', 'status': 'Normal'},
      {'label': 'HbA1c', 'value': '5.4%', 'ref': '< 5.7%', 'status': 'Normal'},
      {'label': 'Insulin', 'value': '8 µU/mL', 'ref': '2–25', 'status': 'Normal'},
      {'label': 'BMI', 'value': '22.4', 'ref': '18.5–24.9', 'status': 'Healthy'},
    ],
    'kidneys': [
      {'label': 'Creatinine', 'value': '0.9 mg/dL', 'ref': '0.7–1.3', 'status': 'Normal'},
      {'label': 'BUN', 'value': '14 mg/dL', 'ref': '7–20', 'status': 'Normal'},
      {'label': 'eGFR', 'value': '92 mL/min', 'ref': '> 60', 'status': 'Normal'},
      {'label': 'Uric acid', 'value': '5.4 mg/dL', 'ref': '3.5–7', 'status': 'Normal'},
    ],
  };

  Map<String, String> get _aiTips => {
    'heart': 'Your cardiac readings are stable. Maintain light aerobic exercise and avoid high-sodium foods. Walk at least 30 minutes daily.',
    'lungs': 'Lung function is good. Avoid dusty environments and do deep-breathing exercises daily. Stay away from smoke.',
    'brain': 'Sleep is adequate. Reduce screen time before bed and practice mindfulness to lower your stress index.',
    'liver': 'Liver enzymes are within normal range. Limit alcohol intake and stay well hydrated throughout the day.',
    'stomach': 'Blood sugar is well controlled. Eat fibre-rich meals and avoid skipping breakfast to maintain stable glucose.',
    'kidneys': 'Kidney function is excellent. Drink 2–3 litres of water daily and reduce salt intake.',
  };

  @override
  Widget build(BuildContext context) {
    final organId = organ['id'] as String;
    final readings = _organData[organId] ?? [];
    final tip = _aiTips[organId] ?? '';
    final color = organ['color'] as Color;
    final bg = organ['bg'] as Color;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
            color: color,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: bg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organ['name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Dhara Patel · health data overview',
                      style: TextStyle(
                        fontSize: 11,
                        color: bg.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Readings card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Text(
                            'Readings',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        ...readings.asMap().entries.map((entry) {
                          final i = entry.key;
                          final r = entry.value;
                          final isLast = i == readings.length - 1;
                          final isNormal = r['status'] != 'Moderate' &&
                              r['status'] != 'Borderline';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : Border(
                                top: BorderSide(
                                    color: AppColors.border,
                                    width: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['label']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      r['value']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isNormal
                                        ? AppColors.successLight
                                        : AppColors.warningLight,
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    r['status']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isNormal
                                          ? AppColors.success
                                          : AppColors.warning,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // AI tip card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: color,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI health tip for Dhara',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tip,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}