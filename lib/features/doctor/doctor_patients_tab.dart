import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/consult_service.dart';
import '../../shared/widgets/app_card.dart';
import 'doctor_dashboard_tab.dart'; // reuse doctorConsultationsProvider

// ── DoctorPatientsTab ─────────────────────────────────────────────────────────

class DoctorPatientsTab extends ConsumerStatefulWidget {
  const DoctorPatientsTab({super.key});

  @override
  ConsumerState<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends ConsumerState<DoctorPatientsTab> {
  // Which consultation is being viewed in detail
  Map<String, dynamic>? _selected;

  // Clinical notes — stored per consultId for this session
  final Map<int, TextEditingController> _noteControllers = {};

  @override
  void dispose() {
    for (final c in _noteControllers.values) c.dispose();
    super.dispose();
  }

  TextEditingController _noteFor(int consultId) {
    return _noteControllers.putIfAbsent(
        consultId, () => TextEditingController());
  }

  // ── Score from vitals ─────────────────────────────────────────────────────

  int _scoreFromVitals(Map<String, dynamic>? v) {
    if (v == null) return 0;
    int score = 100;
    final hr   = (v['heart_rate'] as num?)?.toDouble() ?? 0;
    final spo2 = (v['spo2']       as num?)?.toDouble() ?? 0;
    final steps = (v['steps']     as num?)?.toInt()    ?? 0;
    final sleep = (v['sleep_hours'] as num?)?.toDouble() ?? 0;
    final temp  = (v['temperature'] as num?)?.toDouble() ?? 0;

    int points = 0;
    if (hr > 0)    points++;
    if (spo2 > 0)  points++;
    if (steps > 0) points++;
    if (sleep > 0) points++;
    if (temp > 0)  points++;
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
    if (steps > 0) {
      if (steps < 2000)      score -= 15;
      else if (steps < 5000) score -= 8;
      else if (steps < 8000) score -= 3;
    }
    if (sleep > 0) {
      if (sleep < 5)      score -= 20;
      else if (sleep < 6) score -= 12;
      else if (sleep < 7) score -= 5;
    }
    if (temp > 0) {
      if (temp > 39)        score -= 25;
      else if (temp > 38.5) score -= 15;
      else if (temp > 37.5) score -= 5;
    }
    return score.clamp(0, 100);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final consultAsync = ref.watch(doctorConsultationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.blue,
              onRefresh: () async =>
                  ref.invalidate(doctorConsultationsProvider),
              child: consultAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.blue)),
                error: (_, __) => _buildEmpty('Could not load patients'),
                data: (list) {
                  if (list.isEmpty) {
                    return _buildEmpty('No patient requests yet');
                  }
                  return _selected == null
                      ? _buildPatientList(list)
                      : _buildPatientDetail(_selected!);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.blue,
      child: Row(children: [
        if (_selected != null)
          GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: const Icon(Icons.arrow_back_ios_rounded,
                color: Color(0xFF85B7EB), size: 20),
          ),
        if (_selected != null) const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _selected != null
                ? (_selected!['patient']?['name'] ?? 'Patient detail')
                : 'Patient list',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
          Text(
            _selected != null
                ? 'Health summary + AI insights'
                : 'All consultation requests',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF85B7EB)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildEmpty(String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const Icon(Icons.people_outline_rounded,
              color: AppColors.textHint, size: 48),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  // ── Patient List ──────────────────────────────────────────────────────────

  Widget _buildPatientList(List<dynamic> consultations) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: consultations.length,
      itemBuilder: (_, i) {
        final c      = consultations[i] as Map<String, dynamic>;
        final p      = c['patient']     as Map<String, dynamic>?;
        final v      = c['vitals']      as Map<String, dynamic>?;
        final name   = p?['name']       ?? 'Unknown';
        final age    = p?['age'];
        final gender = p?['gender'];
        final status = c['status']      as String;
        final score  = _scoreFromVitals(v);

        final scoreColor = score == 0
            ? AppColors.textHint
            : score >= 80
            ? AppColors.success
            : score >= 60
            ? AppColors.warning
            : AppColors.danger;
        final scoreBg = score == 0
            ? AppColors.surface
            : score >= 80
            ? AppColors.successLight
            : score >= 60
            ? AppColors.warningLight
            : AppColors.dangerLight;

        return GestureDetector(
          onTap: () => setState(() => _selected = c),
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
                    color: AppColors.blueLight,
                    shape: BoxShape.circle),
                child: Center(
                  child: Text(
                      name.isNotEmpty
                          ? name.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 20,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text(
                      [
                        if (age != null) '${age}y',
                        if (gender != null) gender,
                        'Status: $status',
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  score == 0 ? '--' : '$score/100',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scoreColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: scoreBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    score == 0
                        ? 'No vitals'
                        : score >= 80
                        ? 'Good'
                        : score >= 60
                        ? 'Caution'
                        : 'Critical',
                    style: TextStyle(
                        fontSize: 10,
                        color: scoreColor,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // ── Patient Detail ────────────────────────────────────────────────────────

  Widget _buildPatientDetail(Map<String, dynamic> c) {
    final p      = c['patient'] as Map<String, dynamic>?;
    final v      = c['vitals']  as Map<String, dynamic>?;
    final labs   = c['labs']    as Map<String, dynamic>?;
    final score  = _scoreFromVitals(v);
    final consultId = c['id'] as int;
    final status = c['status'] as String;

    final scoreColor = score == 0
        ? AppColors.textHint
        : score >= 80
        ? AppColors.success
        : score >= 60
        ? AppColors.warning
        : AppColors.danger;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [

        // Health score card
        AppCard(
          color: scoreColor.withOpacity(0.08),
          borderColor: scoreColor.withOpacity(0.3),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Health score',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(
                score == 0 ? '--' : '$score',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                    height: 1),
              ),
              Text(
                score == 0
                    ? 'No vitals recorded'
                    : score >= 80
                    ? 'Good'
                    : score >= 60
                    ? 'Caution'
                    : 'Needs attention',
                style: TextStyle(fontSize: 12, color: scoreColor),
              ),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (p?['age'] != null)
                Text('${p!['age']}y · ${p['gender'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              if (p?['blood_group'] != null)
                Text('Blood: ${p!['blood_group']}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),

        // Accept / Reject buttons
        if (status == 'pending')
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus(consultId, 'accepted'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Accept'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateStatus(consultId, 'rejected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reject'),
              ),
            ),
          ])
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: status == 'accepted'
                  ? AppColors.successLight
                  : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: status == 'accepted'
                      ? AppColors.success
                      : AppColors.danger),
            ),
            child: Text(
              status == 'accepted'
                  ? '✓ You accepted this consultation'
                  : '✗ You rejected this consultation',
              style: TextStyle(
                  fontSize: 13,
                  color: status == 'accepted'
                      ? AppColors.success
                      : AppColors.danger,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 10),

        // Vitals card
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _sectionHeader('Vitals — from Health Connect'),
            if (v == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No vitals recorded yet. Patient needs to connect Health Connect.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              _dataRow('Heart rate',
                  v['heart_rate'] != null
                      ? '${(v['heart_rate'] as num).toStringAsFixed(0)} bpm'
                      : '--',
                  false),
              _dataRow('SpO₂',
                  v['spo2'] != null
                      ? '${(v['spo2'] as num).toStringAsFixed(0)}%'
                      : '--',
                  false),
              _dataRow('Steps',
                  v['steps'] != null ? '${v['steps']}' : '--',
                  false),
              _dataRow('Sleep',
                  v['sleep_hours'] != null
                      ? '${(v['sleep_hours'] as num).toStringAsFixed(1)} hrs'
                      : '--',
                  false),
              _dataRow('Temperature',
                  v['temperature'] != null
                      ? '${(v['temperature'] as num).toStringAsFixed(1)}°C'
                      : '--',
                  true),
            ],
          ]),
        ),
        const SizedBox(height: 10),

        // Lab values card
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _sectionHeader('Lab values — from uploaded report'),
            if (labs == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No lab report uploaded yet.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              for (final entry in {
                'Glucose':       labs['glucose'],
                'Hemoglobin':    labs['hemoglobin'],
                'Cholesterol':   labs['cholesterol'],
                'Triglycerides': labs['triglycerides'],
                'Creatinine':    labs['creatinine'],
                'SGPT':          labs['sgpt'],
                'SGOT':          labs['sgot'],
                'HbA1c':         labs['hba1c'],
              }.entries.where((e) => e.value != null))
                _dataRow(
                  entry.key,
                  (entry.value as num).toStringAsFixed(1),
                  entry.key == 'HbA1c',
                ),
            ],
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
                Icon(Icons.auto_awesome_rounded,
                    color: AppColors.blue, size: 16),
                SizedBox(width: 6),
                Text('Patient AI summary',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C447C))),
              ]),
              const SizedBox(height: 8),
              Text(
                c['ai_summary'] ?? 'No summary provided.',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.blue,
                    height: 1.6),
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
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _noteFor(consultId),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add clinical notes for this patient...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textHint),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Notes saved'),
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
      ]),
    );
  }

  // ── Update consultation status ─────────────────────────────────────────────

  Future<void> _updateStatus(int consultId, String status) async {
    final success = await ConsultService.updateStatus(
      consultId: consultId,
      status:    status,
    );

    if (success && mounted) {
      ref.invalidate(doctorConsultationsProvider);
      setState(() {
        // Update status locally without waiting for refresh
        if (_selected != null) {
          _selected = Map.from(_selected!)..['status'] = status;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Consultation $status'),
        backgroundColor: status == 'accepted'
            ? AppColors.success
            : AppColors.danger,
      ));
    }
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14)),
      ),
      child: Row(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]),
    );
  }

  Widget _dataRow(String label, String value, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom:
        BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}