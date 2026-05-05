import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/auth_service.dart';

// ── OrganDetailScreen ─────────────────────────────────────────────────────────
//
// Receives the organ map built by OrganMapTab._buildOrgans(lab).
// That map already contains real lab values from the database.
// This screen NEVER uses hardcoded values.
//
// Each organ shows:
//   - Real readings pulled from the lab/vitals data passed in via organ map
//   - A "no data" state when a value is missing
//   - An AI health tip that adapts to whether values are present
//
class OrganDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> organ;

  const OrganDetailScreen({super.key, required this.organ});

  // ── Reference ranges used for status badges ───────────────────────────────

  static const Map<String, Map<String, double>> _ranges = {
    'hemoglobin':    {'low': 12.0, 'high': 17.5},
    'rbc':           {'low': 3.5,  'high': 5.5},
    'wbc':           {'low': 4000, 'high': 11000},
    'platelets':     {'low': 150000, 'high': 400000},
    'glucose':       {'low': 70.0, 'high': 100.0},
    'cholesterol':   {'low': 0,    'high': 200.0},
    'triglycerides': {'low': 0,    'high': 150.0},
    'creatinine':    {'low': 0.6,  'high': 1.3},
    'uric_acid':     {'low': 2.5,  'high': 7.0},
    'sgpt':          {'low': 7.0,  'high': 56.0},
    'sgot':          {'low': 10.0, 'high': 40.0},
    'hba1c':         {'low': 0,    'high': 5.7},
    'tsh':           {'low': 0.4,  'high': 4.0},
    'vitamin_d':     {'low': 20.0, 'high': 50.0},
    'vitamin_b12':   {'low': 200,  'high': 900},
    'ldl':           {'low': 0,    'high': 130.0},
    'hdl':           {'low': 40.0, 'high': 999},
    'sodium':        {'low': 136,  'high': 145},
    'potassium':     {'low': 3.5,  'high': 5.0},
  };

  // ── Which lab keys map to each organ ─────────────────────────────────────

  static const Map<String, List<Map<String, String>>> _organKeys = {
    'heart': [
      {'key': 'cholesterol',   'label': 'Cholesterol',   'unit': 'mg/dL'},
      {'key': 'triglycerides', 'label': 'Triglycerides', 'unit': 'mg/dL'},
      {'key': 'ldl',           'label': 'LDL',           'unit': 'mg/dL'},
      {'key': 'hdl',           'label': 'HDL',           'unit': 'mg/dL'},
    ],
    'lungs': [
      {'key': 'rbc',        'label': 'RBC',        'unit': 'mil/cmm'},
      {'key': 'hemoglobin', 'label': 'Hemoglobin', 'unit': 'g%'},
    ],
    'brain': [
      {'key': 'sodium',    'label': 'Sodium',    'unit': 'mEq/L'},
      {'key': 'potassium', 'label': 'Potassium', 'unit': 'mEq/L'},
    ],
    'liver': [
      {'key': 'sgpt',      'label': 'SGPT / ALT', 'unit': 'U/L'},
      {'key': 'sgot',      'label': 'SGOT / AST', 'unit': 'U/L'},
      {'key': 'bilirubin', 'label': 'Bilirubin',  'unit': 'mg/dL'},
    ],
    'stomach': [
      {'key': 'glucose',   'label': 'Glucose',  'unit': 'mg/dL'},
      {'key': 'hba1c',     'label': 'HbA1c',    'unit': '%'},
      {'key': 'uric_acid', 'label': 'Uric Acid', 'unit': 'mg/dL'},
    ],
    'kidneys': [
      {'key': 'creatinine', 'label': 'Creatinine',   'unit': 'mg/dL'},
      {'key': 'uric_acid',  'label': 'Uric Acid',    'unit': 'mg/dL'},
      {'key': 'potassium',  'label': 'Potassium',    'unit': 'mEq/L'},
    ],
  };

  // ── AI tips — generic, no fake numbers ───────────────────────────────────

  static const Map<String, String> _tipsWithData = {
    'heart':   'Based on your lab values, monitor your cholesterol and triglyceride levels. Maintain light aerobic exercise and avoid high-sodium, high-fat foods.',
    'lungs':   'Your blood cell counts help assess oxygen-carrying capacity. Keep up regular breathing exercises and avoid smoke or dusty environments.',
    'brain':   'Electrolyte balance affects brain function. Stay well hydrated and maintain consistent sleep and meal schedules.',
    'liver':   'Liver enzyme values are visible above. Limit alcohol intake, avoid excessive medication, and stay hydrated.',
    'stomach': 'Blood glucose and HbA1c values are shown above. Eat fibre-rich meals and avoid refined sugars and processed foods.',
    'kidneys': 'Creatinine and uric acid levels indicate kidney function. Drink 2–3 litres of water daily and avoid excessive salt intake.',
  };

  static const Map<String, String> _tipsNoData = {
    'heart':   'Upload a lab report with cholesterol and triglycerides to see your cardiac health indicators here.',
    'lungs':   'Upload a lab report with RBC and hemoglobin to see your lung and oxygen capacity indicators here.',
    'brain':   'Upload a lab report with sodium and potassium to see your neurological health indicators here.',
    'liver':   'Upload a lab report with SGPT, SGOT, and bilirubin to see your liver health indicators here.',
    'stomach': 'Upload a lab report with glucose and HbA1c to see your metabolic health indicators here.',
    'kidneys': 'Upload a lab report with creatinine and uric acid to see your kidney health indicators here.',
  };

  // ── Status logic ──────────────────────────────────────────────────────────

  String _status(String key, double value) {
    final range = _ranges[key];
    if (range == null) return 'Check';
    if (value < range['low']!)  return 'Low';
    if (value > range['high']!) return 'High';
    return 'Normal';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Normal': return AppColors.success;
      case 'Low':    return AppColors.warning;
      case 'High':   return AppColors.danger;
      default:       return AppColors.textHint;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Normal': return AppColors.successLight;
      case 'Low':    return AppColors.warningLight;
      case 'High':   return AppColors.dangerLight;
      default:       return AppColors.surface;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organId   = organ['id']   as String;
    final organName = organ['name'] as String;
    final color     = organ['color'] as Color;
    final bg        = organ['bg']   as Color;

    // Get the lab data map passed through the organ object
    // OrganMapTab sets organ['labData'] to the full lab map from DB
    final labData   = (organ['labData'] as Map<String, dynamic>?) ?? {};

    // Build rows from real data only
    final keyDefs = _organKeys[organId] ?? [];
    final rows    = <Map<String, dynamic>>[];

    for (final def in keyDefs) {
      final key   = def['key']!;
      final label = def['label']!;
      final unit  = def['unit']!;
      final raw   = labData[key];

      if (raw != null && raw is num && raw > 0) {
        final value  = raw.toDouble();
        final status = _status(key, value);
        rows.add({
          'label':  label,
          'value':  '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} $unit',
          'status': status,
        });
      }
    }

    final hasData = rows.isNotEmpty;
    final tip = hasData
        ? (_tipsWithData[organId] ?? '')
        : (_tipsNoData[organId]   ?? '');

    // Get user name for header subtitle
    final userName = ref.watch(userProfileProvider).name;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
            color: color,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_ios_rounded,
                      color: bg, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(organName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text(
                      userName.isNotEmpty
                          ? '$userName · health data overview'
                          : 'Health data overview',
                      style: TextStyle(
                          fontSize: 11,
                          color: bg.withOpacity(0.9)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
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
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Lab readings',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                              // Source badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasData
                                      ? AppColors.successLight
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasData
                                      ? 'From your lab report'
                                      : 'No data yet',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: hasData
                                          ? AppColors.success
                                          : AppColors.textHint,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (!hasData) ...[
                          // No data state — clear message, no fake numbers
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                14, 8, 14, 20),
                            child: Column(
                              children: [
                                Icon(Icons.science_outlined,
                                    color: AppColors.textHint, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  'No lab data for $organName yet',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Upload a lab report from the Labs tab to see real readings here.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.5),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Real readings from lab report
                          ...rows.asMap().entries.map((entry) {
                            final i      = entry.key;
                            final r      = entry.value;
                            final isLast = i == rows.length - 1;
                            final status = r['status'] as String;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                    top: BorderSide(
                                        color: AppColors.border,
                                        width: 0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(r['label'],
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                              AppColors.textPrimary)),
                                      Text(r['value'],
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color:
                                              AppColors.textPrimary)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusBg(status),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: Text(status,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
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
                        Row(children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            hasData ? 'AI health tip' : 'How to get data',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(tip,
                            style: TextStyle(
                                fontSize: 12,
                                color: color,
                                height: 1.6)),
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