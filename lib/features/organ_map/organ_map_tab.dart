import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/services/api_service.dart';
import 'organ_detail_screen.dart';

final organLabProvider =
FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(backendUserIdProvider) ?? 0;
  if (userId == 0) return {};
  final result = await apiService.getLatestLabReport(userId);
  if (result == null || result['status'] == 'no_data') return {};
  return result;
});

class OrganMapTab extends ConsumerWidget {
  const OrganMapTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labAsync = ref.watch(organLabProvider);
    final lab = labAsync.value ?? {};
    final organs = _buildOrgans(lab);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildHumanBody(context, organs),
              const SizedBox(height: 12),
              _buildOrganList(context, organs),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────

  List<Map<String, dynamic>> _buildOrgans(
      Map<String, dynamic> lab) {
    String fmt(String key, String unit,
        {String fallback = 'No data'}) {
      final v = lab[key];
      if (v == null || v == 0) return fallback;
      final n =
      v is num ? v : double.tryParse(v.toString());
      if (n == null) return fallback;
      return '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)} $unit';
    }

    return [
      {
        'id': 'brain',
        'name': 'Brain',
        'color': AppColors.primary,
        'bg': AppColors.primaryLight,
        'icon': Icons.psychology_rounded,
        'summary': 'Sleep & neurological health',
        'status': 'Check vitals',
      },
      {
        'id': 'heart',
        'name': 'Heart',
        'color': AppColors.danger,
        'bg': AppColors.dangerLight,
        'icon': Icons.favorite_rounded,
        'summary': fmt('hemoglobin', 'g% Hb'),
        'status':
        lab['hemoglobin'] != null ? 'Real data' : 'No data',
      },
      {
        'id': 'lungs',
        'name': 'Lungs',
        'color': AppColors.blue,
        'bg': AppColors.blueLight,
        'icon': Icons.air_rounded,
        'summary': fmt('rbc', 'mil/cmm RBC'),
        'status':
        lab['rbc'] != null ? 'Real data' : 'No data',
      },
      {
        'id': 'liver',
        'name': 'Liver',
        'color': AppColors.warning,
        'bg': AppColors.warningLight,
        'icon': Icons.water_drop_rounded,
        'summary': fmt('sgpt', 'U/L SGPT'),
        'status':
        lab['sgpt'] != null ? 'Real data' : 'No data',
      },
      {
        'id': 'stomach',
        'name': 'Stomach',
        'color': AppColors.success,
        'bg': AppColors.successLight,
        'icon': Icons.circle_rounded,
        'summary': fmt('glucose', 'mg/dL Glucose'),
        'status':
        lab['glucose'] != null ? 'Real data' : 'No data',
      },
      {
        'id': 'kidneys',
        'name': 'Kidneys',
        'color': const Color(0xFFD4537E),
        'bg': const Color(0xFFFBEAF0),
        'icon': Icons.opacity_rounded,
        'summary': fmt('creatinine', 'mg/dL Creat.'),
        'status': lab['creatinine'] != null
            ? 'Real data'
            : 'No data',
      },
    ];
  }

  // ─────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.primary,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Body organ map',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white)),
          SizedBox(height: 4),
          Text('Tap any organ to view health data',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryMid)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────

  Widget _buildHumanBody(BuildContext context,
      List<Map<String, dynamic>> organs) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border:
            Border.all(color: AppColors.border)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 340,
              width: double.infinity,
              child: CustomPaint(
                  painter: HumanBodyPainter()),
            ),
            SizedBox(
              height: 340,
              width: 200,
              child: Stack(
                children: [
                  _organBtn(context, organs,
                      'brain', 75, 8, 50, 36),
                  _organBtn(context, organs,
                      'heart', 82, 118, 36, 36),
                  _organBtn(context, organs,
                      'lungs', 46, 110, 32, 48),
                  _organBtn(context, organs,
                      'lungs', 122, 110, 32, 48),
                  _organBtn(context, organs,
                      'liver', 108, 162, 38, 28),
                  _organBtn(context, organs,
                      'stomach', 70, 158, 34, 26),
                  _organBtn(context, organs,
                      'kidneys', 50, 190, 24, 32),
                  _organBtn(context, organs,
                      'kidneys', 126, 190, 24, 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────

  Widget _organBtn(
      BuildContext context,
      List<Map<String, dynamic>> organs,
      String id,
      double l,
      double t,
      double w,
      double h) {
    final organ =
    organs.firstWhere((o) => o['id'] == id);

    return Positioned(
      left: l,
      top: t,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrganDetailScreen(organ: organ),
          ),
        ),
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: (organ['bg'] as Color)
                .withOpacity(0.85),
            borderRadius:
            BorderRadius.circular(8),
            border: Border.all(
                color: organ['color'] as Color,
                width: 1.5),
          ),
          child: Center(
            child: Text(
              organ['name'],
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color:
                organ['color'] as Color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────

  Widget _buildOrganList(BuildContext context,
      List<Map<String, dynamic>> organs) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text('Organ status summary',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius:
                BorderRadius.circular(14),
                border:
                Border.all(color: AppColors.border)),
            child: Column(
              children:
              organs.asMap().entries.map((e) {
                final isLast =
                    e.key == organs.length - 1;
                final organ = e.value;

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrganDetailScreen(
                              organ: organ),
                    ),
                  ),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                        bottom: BorderSide(
                            color:
                            AppColors.border,
                            width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(organ['icon'],
                            color: organ['color']),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(organ['name']),
                              Text(organ['summary']),
                            ],
                          ),
                        ),
                        Text('${organ['status']}'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────

class HumanBodyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade100;

    canvas.drawCircle(
        Offset(size.width / 2, 40), 30, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}