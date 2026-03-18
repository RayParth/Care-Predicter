import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import '../../shared/widgets/metric_card.dart';
import '../lab/lab_upload_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: _buildBody(),
          ),
          BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LabUploadScreen(),
                  ),
                );
              } else if (index != 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_getScreenName(index) + ' — coming soon!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _getScreenName(int index) {
    switch (index) {
      case 1: return 'Body organ map';
      case 2: return 'AI Chat';
      case 3: return 'Lab upload';
      case 4: return 'Doctor consult';
      default: return 'Home';
    }
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildMetricGrid(),
          const SizedBox(height: 4),
          _buildLabReportSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Good morning',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primaryMid,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Dhara Patel',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 14),
          // Health score card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Health score',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryMid,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '82',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Good condition',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.tealMid,
                      ),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Health Connect: Live',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.tealMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Last sync: 2 min ago',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryMid,
                        ),
                      ),
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

  Widget _buildMetricGrid() {
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
            value: '76',
            unit: 'bpm',
            status: 'Normal',
            statusColor: AppColors.success,
            statusBg: AppColors.successLight,
            progress: 0.55,
            progressColor: AppColors.tealMid,
          ),
          MetricCard(
            label: 'SpO₂',
            value: '98',
            unit: '%',
            status: 'Excellent',
            statusColor: AppColors.success,
            statusBg: AppColors.successLight,
            progress: 0.90,
            progressColor: AppColors.tealMid,
          ),
          MetricCard(
            label: 'Steps today',
            value: '6,420',
            unit: '',
            status: '64% of goal',
            statusColor: AppColors.blue,
            statusBg: AppColors.blueLight,
            progress: 0.64,
            progressColor: AppColors.blue,
          ),
          MetricCard(
            label: 'Calories',
            value: '1,840',
            unit: 'kcal',
            status: 'Active day',
            statusColor: AppColors.warning,
            statusBg: AppColors.warningLight,
            progress: 0.73,
            progressColor: const Color(0xFFEF9F27),
          ),
          MetricCard(
            label: 'Sleep',
            value: '7.2',
            unit: 'hrs',
            status: 'Good',
            statusColor: AppColors.primary,
            statusBg: AppColors.primaryLight,
            progress: 0.72,
            progressColor: AppColors.primary,
          ),
          MetricCard(
            label: 'Temperature',
            value: '36.8',
            unit: '°C',
            status: 'Normal',
            statusColor: AppColors.success,
            statusBg: AppColors.successLight,
            progress: 0.80,
            progressColor: AppColors.tealMid,
          ),
        ],
      ),
    );
  }

  Widget _buildLabReportSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest lab report — OCR extracted',
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
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CBC · 14 Mar 2026',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lab rows
                _buildLabRow('Glucose', '94 mg/dL', 'Normal', false),
                _buildLabRow('Hemoglobin', '13.2 g/dL', 'Normal', false),
                _buildLabRow('Cholesterol', '178 mg/dL', 'Normal', false),
                _buildLabRow('Triglycerides', '140 mg/dL', 'Borderline', false),
                _buildLabRow('Creatinine', '0.9 mg/dL', 'Normal', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabRow(
      String name, String value, String status, bool isLast) {
    final isNormal = status == 'Normal';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isNormal ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: isNormal ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
