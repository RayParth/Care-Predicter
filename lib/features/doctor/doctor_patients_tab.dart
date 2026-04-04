import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';

class DoctorPatientsTab extends StatefulWidget {
  const DoctorPatientsTab({super.key});

  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  String? _selectedPatient;

  final List<Map<String, dynamic>> _patients = [
    {
      'name': 'Dhara Patel', 'age': 24, 'gender': 'F', 'blood': 'B+',
      'score': 82, 'status': 'Good',
      'vitals': {'HR': '76 bpm', 'SpO₂': '98%', 'BP': '118/76', 'Temp': '36.8°C', 'Steps': '6,420'},
      'labs': {'Glucose': '94 mg/dL', 'Hemoglobin': '13.2 g/dL', 'Cholesterol': '178 mg/dL', 'Triglycerides': '140 mg/dL'},
      'note': '',
    },
    {
      'name': 'Ravi Sharma', 'age': 45, 'gender': 'M', 'blood': 'O+',
      'score': 61, 'status': 'Caution',
      'vitals': {'HR': '88 bpm', 'SpO₂': '96%', 'BP': '134/86', 'Temp': '37.1°C', 'Steps': '3,100'},
      'labs': {'Glucose': '118 mg/dL', 'Hemoglobin': '11.8 g/dL', 'Cholesterol': '212 mg/dL', 'Triglycerides': '148 mg/dL'},
      'note': '',
    },
    {
      'name': 'Priya Modi', 'age': 32, 'gender': 'F', 'blood': 'A+',
      'score': 91, 'status': 'Excellent',
      'vitals': {'HR': '68 bpm', 'SpO₂': '99%', 'BP': '112/72', 'Temp': '36.6°C', 'Steps': '9,840'},
      'labs': {'Glucose': '88 mg/dL', 'Hemoglobin': '14.1 g/dL', 'Cholesterol': '162 mg/dL', 'Triglycerides': '98 mg/dL'},
      'note': '',
    },
  ];

  final _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _selectedPatient == null
                  ? _buildPatientList()
                  : _buildPatientDetail(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.blue,
      child: Row(
        children: [
          if (_selectedPatient != null)
            GestureDetector(
              onTap: () => setState(() => _selectedPatient = null),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Color(0xFF85B7EB), size: 20),
            ),
          if (_selectedPatient != null) const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedPatient ?? 'Patient list',
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w600, color: Colors.white),
              ),
              Text(
                _selectedPatient != null ? 'Health summary + AI insights' : '${_patients.length} patients assigned',
                style: const TextStyle(fontSize: 11, color: Color(0xFF85B7EB)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _patients.length,
      itemBuilder: (_, i) {
        final p = _patients[i];
        final score = p['score'] as int;
        final statusColor = score >= 80 ? AppColors.success
            : score >= 60 ? AppColors.warning : AppColors.danger;
        final statusBg = score >= 80 ? AppColors.successLight
            : score >= 60 ? AppColors.warningLight : AppColors.dangerLight;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPatient = p['name'];
              _noteController.text = p['note'] ?? '';
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AppColors.blueLight, shape: BoxShape.circle),
                child: Center(child: Text(
                    p['name'].toString().substring(0, 1),
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w600, color: AppColors.blue))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'], style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
                  Text('${p['age']}${p['gender']} · Blood: ${p['blood']}',
                      style: const TextStyle(fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${score}/100',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: statusColor)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(p['status'],
                      style: TextStyle(fontSize: 10, color: statusColor,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildPatientDetail() {
    final p = _patients.firstWhere((x) => x['name'] == _selectedPatient);
    final score = p['score'] as int;
    final statusColor = score >= 80 ? AppColors.success
        : score >= 60 ? AppColors.warning : AppColors.danger;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Health score card
          AppCard(
            color: statusColor.withOpacity(0.08),
            borderColor: statusColor.withOpacity(0.3),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Health score', style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
                Text('$score', style: TextStyle(fontSize: 40,
                    fontWeight: FontWeight.w700, color: statusColor, height: 1)),
                Text(p['status'], style: TextStyle(fontSize: 12, color: statusColor)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${p['age']}${p['gender']}', style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
                Text('Blood: ${p['blood']}', style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),

          // Vitals
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _sectionHeader('Vitals — from Health Connect'),
              ...(p['vitals'] as Map<String, String>).entries.toList()
                  .asMap().entries.map((e) {
                final isLast = e.key == (p['vitals'] as Map).length - 1;
                return _dataRow(e.value.key, e.value.value, isLast);
              }),
            ]),
          ),
          const SizedBox(height: 10),

          // Lab values
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _sectionHeader('Lab values — OCR extracted'),
              ...(p['labs'] as Map<String, String>).entries.toList()
                  .asMap().entries.map((e) {
                final isLast = e.key == (p['labs'] as Map).length - 1;
                return _dataRow(e.value.key, e.value.value, isLast);
              }),
            ]),
          ),
          const SizedBox(height: 10),

          // AI summary
          AppCard(
            color: AppColors.blueLight,
            borderColor: const Color(0xFF85B7EB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.auto_awesome_rounded, color: AppColors.blue, size: 16),
                  SizedBox(width: 6),
                  Text('AI patient summary',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: Color(0xFF0C447C))),
                ]),
                const SizedBox(height: 8),
                Text(
                  _getAiSummary(p),
                  style: const TextStyle(fontSize: 12, color: AppColors.blue, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Clinical notes
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clinical notes',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add notes for this patient...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final idx = _patients.indexWhere((x) => x['name'] == _selectedPatient);
                      setState(() => _patients[idx]['note'] = _noteController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notes saved'),
                            backgroundColor: AppColors.success),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save notes'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14), topRight: Radius.circular(14)),
      ),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ]),
    );
  }

  Widget _dataRow(String label, String value, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12,
              color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  String _getAiSummary(Map p) {
    final score = p['score'] as int;
    if (score >= 80) {
      return '${p['name']} has stable health readings. All vitals within normal range. No anomalies detected in the last 24 hours. Routine follow-up recommended in 30 days.';
    } else if (score >= 60) {
      return '${p['name']} shows borderline readings. Triglycerides and cholesterol are slightly elevated. Blood pressure is in the pre-hypertension range. Recommend dietary counseling and a review in 2 weeks.';
    } else {
      return '${p['name']} has critical health readings. Immediate review recommended. Multiple parameters out of normal range. Consider in-person consultation.';
    }
  }
}