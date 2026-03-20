import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../shared/widgets/bottom_nav_bar.dart';

class ConsultScreen extends ConsumerStatefulWidget {
  const ConsultScreen({super.key});

  @override
  ConsumerState<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends ConsumerState<ConsultScreen> {
  int _currentIndex = 4;
  bool _requestSent = false;
  String? _selectedDoctor;

  final List<Map<String, dynamic>> _doctors = [
    {
      'name': 'Dr. Priya Sharma',
      'spec': 'Cardiologist',
      'exp': '5 yrs exp',
      'status': 'Available',
      'initials': 'PS',
      'isAvailable': true,
    },
    {
      'name': 'Dr. Rohan Mehta',
      'spec': 'General Physician',
      'exp': '8 yrs exp',
      'status': 'Available',
      'initials': 'RM',
      'isAvailable': true,
    },
    {
      'name': 'Dr. Anita Joshi',
      'spec': 'Pulmonologist',
      'exp': '6 yrs exp',
      'status': 'Busy',
      'initials': 'AJ',
      'isAvailable': false,
    },
    {
      'name': 'Dr. Vikram Patel',
      'spec': 'Endocrinologist',
      'exp': '10 yrs exp',
      'status': 'Available',
      'initials': 'VP',
      'isAvailable': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildAiSummaryCard(),
                  const SizedBox(height: 12),
                  _buildDoctorList(),
                  const SizedBox(height: 12),
                  if (_selectedDoctor != null && !_requestSent)
                    _buildSendButton(),
                  if (_requestSent) _buildSuccessCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 0) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      color: AppColors.primary,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.primaryMid,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Doctor consultation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              Text(
                'AI summary sent with your request',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryMid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryMid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'AI patient summary — auto-generated',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Dhara Patel · 24F · HR 76 bpm · SpO₂ 98% · BP 118/76 · Glucose 94 mg/dL · Triglycerides 140 mg/dL (borderline) · Sleep 7.2 hrs · Health score 82. No critical alerts currently active. Routine follow-up recommended.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryMid),
              ),
              child: const Text(
                'This summary will be sent to the doctor with your request',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryDark,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available doctors',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _doctors.asMap().entries.map((entry) {
                final index = entry.key;
                final doctor = entry.value;
                final isLast = index == _doctors.length - 1;
                return _buildDoctorRow(doctor, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorRow(Map<String, dynamic> doctor, bool isLast) {
    final isSelected = _selectedDoctor == doctor['name'];
    final isAvailable = doctor['isAvailable'] as bool;

    return GestureDetector(
      onTap: isAvailable
          ? () {
        setState(() {
          _selectedDoctor = doctor['name'];
          _requestSent = false;
        });
      }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.white,
          borderRadius: isLast
              ? const BorderRadius.only(
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          )
              : BorderRadius.zero,
          border: isLast
              ? null
              : Border(
            bottom: BorderSide(
                color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.blueLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  doctor['initials'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.white
                        : AppColors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor['name'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${doctor['spec']} · ${doctor['exp']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isAvailable
                    ? AppColors.successLight
                    : AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                doctor['status'],
                style: TextStyle(
                  fontSize: 11,
                  color: isAvailable
                      ? AppColors.success
                      : AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sending to: $_selectedDoctor',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _requestSent = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Send consultation request + AI summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC0DD97)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Request sent successfully',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF27500A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your request and AI summary have been sent to $_selectedDoctor. You will be notified when they respond.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3B6D11),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _requestSent = false;
                        _selectedDoctor = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(
                          color: AppColors.success),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('New request'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Go home'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}