import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/services/auth_service.dart';
import 'organ_detail_screen.dart';

final organLabProvider =
FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(backendUserIdProvider) ?? 0;
  if (userId == 0) return {};
  final result = await AuthService.getLatestLabReport(userId);
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
    final fill = Paint()
      ..color = const Color(0xFFE6F1FB)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF185FA5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final cx = size.width / 2;

    void drawOval(double cx, double cy, double rx, double ry) {
      final r = Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2);
      canvas.drawOval(r, fill);
      canvas.drawOval(r, stroke);
    }

    void drawPath(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }

    // Head
    drawOval(cx, 28, 22, 26);
    // Neck
    final neck = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, 52, 20, 16),
        const Radius.circular(4));
    canvas.drawRRect(neck, fill);
    canvas.drawRRect(neck, stroke);
    // Torso
    drawPath(Path()
      ..moveTo(cx - 38, 68)
      ..quadraticBezierTo(cx - 42, 72, cx - 44, 90)
      ..lineTo(cx - 42, 180)
      ..quadraticBezierTo(cx - 40, 184, cx - 36, 184)
      ..lineTo(cx + 36, 184)
      ..quadraticBezierTo(cx + 40, 184, cx + 42, 180)
      ..lineTo(cx + 44, 90)
      ..quadraticBezierTo(cx + 42, 72, cx + 38, 68)
      ..close());
    // Left arm
    drawPath(Path()
      ..moveTo(cx - 38, 72)
      ..quadraticBezierTo(cx - 52, 80, cx - 56, 102)
      ..lineTo(cx - 54, 160)
      ..quadraticBezierTo(cx - 52, 166, cx - 46, 166)
      ..lineTo(cx - 40, 166)
      ..quadraticBezierTo(cx - 36, 164, cx - 36, 158)
      ..lineTo(cx - 38, 110)
      ..close());
    // Right arm
    drawPath(Path()
      ..moveTo(cx + 38, 72)
      ..quadraticBezierTo(cx + 52, 80, cx + 56, 102)
      ..lineTo(cx + 54, 160)
      ..quadraticBezierTo(cx + 52, 166, cx + 46, 166)
      ..lineTo(cx + 40, 166)
      ..quadraticBezierTo(cx + 36, 164, cx + 36, 158)
      ..lineTo(cx + 38, 110)
      ..close());
    // Left leg
    drawPath(Path()
      ..moveTo(cx - 36, 184)
      ..lineTo(cx - 38, 270)
      ..quadraticBezierTo(cx - 38, 278, cx - 30, 278)
      ..lineTo(cx - 18, 278)
      ..quadraticBezierTo(cx - 12, 278, cx - 12, 270)
      ..lineTo(cx - 10, 184)
      ..close());
    // Right leg
    drawPath(Path()
      ..moveTo(cx + 36, 184)
      ..lineTo(cx + 38, 270)
      ..quadraticBezierTo(cx + 38, 278, cx + 30, 278)
      ..lineTo(cx + 18, 278)
      ..quadraticBezierTo(cx + 12, 278, cx + 12, 270)
      ..lineTo(cx + 10, 184)
      ..close());
    // Feet
    drawOval(cx - 24, 284, 13, 7);
    drawOval(cx + 24, 284, 13, 7);

    // Pulse lines on arms
    final pulse = Paint()
      ..color = const Color(0xFFE24B4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(cx - 54, 125)
          ..lineTo(cx - 50, 125)
          ..lineTo(cx - 48, 117)
          ..lineTo(cx - 45, 133)
          ..lineTo(cx - 42, 125)
          ..lineTo(cx - 38, 125),
        pulse);
    canvas.drawPath(
        Path()
          ..moveTo(cx + 38, 125)
          ..lineTo(cx + 42, 125)
          ..lineTo(cx + 44, 117)
          ..lineTo(cx + 47, 133)
          ..lineTo(cx + 50, 125)
          ..lineTo(cx + 54, 125),
        pulse);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}