import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'organ_detail_screen.dart';

class OrganMapScreen extends StatefulWidget {
  const OrganMapScreen({super.key});

  @override
  State<OrganMapScreen> createState() => _OrganMapScreenState();
}

class _OrganMapScreenState extends State<OrganMapScreen> {
  int _currentIndex = 1;

  final List<Map<String, dynamic>> _organs = [
    {
      'id': 'brain',
      'name': 'Brain',
      'color': AppColors.primary,
      'bg': AppColors.primaryLight,
      'icon': Icons.psychology_rounded,
      'summary': 'Sleep 7.2 hrs · Good',
      'status': 'Good',
    },
    {
      'id': 'heart',
      'name': 'Heart',
      'color': AppColors.danger,
      'bg': AppColors.dangerLight,
      'icon': Icons.favorite_rounded,
      'summary': '76 bpm · Normal',
      'status': 'Normal',
    },
    {
      'id': 'lungs',
      'name': 'Lungs',
      'color': AppColors.blue,
      'bg': AppColors.blueLight,
      'icon': Icons.air_rounded,
      'summary': 'SpO₂ 98% · Good',
      'status': 'Good',
    },
    {
      'id': 'liver',
      'name': 'Liver',
      'color': AppColors.warning,
      'bg': AppColors.warningLight,
      'icon': Icons.water_drop_rounded,
      'summary': 'SGPT 28 · Normal',
      'status': 'Normal',
    },
    {
      'id': 'stomach',
      'name': 'Stomach',
      'color': AppColors.success,
      'bg': AppColors.successLight,
      'icon': Icons.circle_rounded,
      'summary': 'Glucose 94 · Normal',
      'status': 'Normal',
    },
    {
      'id': 'kidneys',
      'name': 'Kidneys',
      'color': const Color(0xFFD4537E),
      'bg': const Color(0xFFFBEAF0),
      'icon': Icons.opacity_rounded,
      'summary': 'Creatinine 0.9 · OK',
      'status': 'Normal',
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
                  _buildHumanBody(),
                  const SizedBox(height: 12),
                  _buildOrganList(),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Body organ map',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap any organ to view health data',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumanBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Human body SVG drawn with CustomPaint
            SizedBox(
              height: 340,
              width: double.infinity,
              child: CustomPaint(
                painter: HumanBodyPainter(),
              ),
            ),
            // Organ tap buttons positioned over the body
            SizedBox(
              height: 340,
              width: 200,
              child: Stack(
                children: [
                  // Brain
                  _buildOrganButton('brain', 75, 8, 50, 36),
                  // Heart
                  _buildOrganButton('heart', 82, 118, 36, 36),
                  // Left lung
                  _buildOrganButton('lungs', 46, 110, 32, 48),
                  // Right lung
                  _buildOrganButton('lungs', 122, 110, 32, 48),
                  // Liver
                  _buildOrganButton('liver', 108, 162, 38, 28),
                  // Stomach
                  _buildOrganButton('stomach', 70, 158, 34, 26),
                  // Left kidney
                  _buildOrganButton('kidneys', 50, 190, 24, 32),
                  // Right kidney
                  _buildOrganButton('kidneys', 126, 190, 24, 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganButton(
      String organId, double left, double top, double width, double height) {
    final organ = _organs.firstWhere((o) => o['id'] == organId);
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _openOrganDetail(organ),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: (organ['bg'] as Color).withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: organ['color'] as Color,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              organ['name'],
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: organ['color'] as Color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _openOrganDetail(Map<String, dynamic> organ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrganDetailScreen(organ: organ),
      ),
    );
  }

  Widget _buildOrganList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Organ status summary',
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
              children: _organs.asMap().entries.map((entry) {
                final index = entry.key;
                final organ = entry.value;
                final isLast = index == _organs.length - 1;
                return _buildOrganListRow(organ, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganListRow(Map<String, dynamic> organ, bool isLast) {
    return GestureDetector(
      onTap: () => _openOrganDetail(organ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Organ icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: organ['bg'] as Color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: organ['color'] as Color,
                  width: 1.5,
                ),
              ),
              child: Icon(
                organ['icon'] as IconData,
                color: organ['color'] as Color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Name and summary
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organ['name'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    organ['summary'],
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
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: organ['bg'] as Color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                organ['status'] + ' →',
                style: TextStyle(
                  fontSize: 11,
                  color: organ['color'] as Color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for human body outline
class HumanBodyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE6F1FB)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFF185FA5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;

    // Head
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, 28), width: 44, height: 52),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, 28), width: 44, height: 52),
      outlinePaint,
    );

    // Neck
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 10, 52, 20, 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, paint);
    canvas.drawRRect(neckRect, outlinePaint);

    // Torso
    final torsoPath = Path()
      ..moveTo(cx - 38, 68)
      ..quadraticBezierTo(cx - 42, 72, cx - 44, 90)
      ..lineTo(cx - 42, 180)
      ..quadraticBezierTo(cx - 40, 184, cx - 36, 184)
      ..lineTo(cx + 36, 184)
      ..quadraticBezierTo(cx + 40, 184, cx + 42, 180)
      ..lineTo(cx + 44, 90)
      ..quadraticBezierTo(cx + 42, 72, cx + 38, 68)
      ..close();
    canvas.drawPath(torsoPath, paint);
    canvas.drawPath(torsoPath, outlinePaint);

    // Left arm
    final leftArmPath = Path()
      ..moveTo(cx - 38, 72)
      ..quadraticBezierTo(cx - 52, 80, cx - 56, 102)
      ..lineTo(cx - 54, 160)
      ..quadraticBezierTo(cx - 52, 166, cx - 46, 166)
      ..lineTo(cx - 40, 166)
      ..quadraticBezierTo(cx - 36, 164, cx - 36, 158)
      ..lineTo(cx - 38, 110)
      ..close();
    canvas.drawPath(leftArmPath, paint);
    canvas.drawPath(leftArmPath, outlinePaint);

    // Right arm
    final rightArmPath = Path()
      ..moveTo(cx + 38, 72)
      ..quadraticBezierTo(cx + 52, 80, cx + 56, 102)
      ..lineTo(cx + 54, 160)
      ..quadraticBezierTo(cx + 52, 166, cx + 46, 166)
      ..lineTo(cx + 40, 166)
      ..quadraticBezierTo(cx + 36, 164, cx + 36, 158)
      ..lineTo(cx + 38, 110)
      ..close();
    canvas.drawPath(rightArmPath, paint);
    canvas.drawPath(rightArmPath, outlinePaint);

    // Left leg
    final leftLegPath = Path()
      ..moveTo(cx - 36, 184)
      ..lineTo(cx - 38, 270)
      ..quadraticBezierTo(cx - 38, 278, cx - 30, 278)
      ..lineTo(cx - 18, 278)
      ..quadraticBezierTo(cx - 12, 278, cx - 12, 270)
      ..lineTo(cx - 10, 184)
      ..close();
    canvas.drawPath(leftLegPath, paint);
    canvas.drawPath(leftLegPath, outlinePaint);

    // Right leg
    final rightLegPath = Path()
      ..moveTo(cx + 36, 184)
      ..lineTo(cx + 38, 270)
      ..quadraticBezierTo(cx + 38, 278, cx + 30, 278)
      ..lineTo(cx + 18, 278)
      ..quadraticBezierTo(cx + 12, 278, cx + 12, 270)
      ..lineTo(cx + 10, 184)
      ..close();
    canvas.drawPath(rightLegPath, paint);
    canvas.drawPath(rightLegPath, outlinePaint);

    // Left foot
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - 24, 284), width: 26, height: 14),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - 24, 284), width: 26, height: 14),
      outlinePaint,
    );

    // Right foot
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + 24, 284), width: 26, height: 14),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + 24, 284), width: 26, height: 14),
      outlinePaint,
    );

    // Pulse lines on arms
    final pulsePaint = Paint()
      ..color = const Color(0xFFE24B4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Left arm pulse
    final leftPulse = Path()
      ..moveTo(cx - 54, 125)
      ..lineTo(cx - 50, 125)
      ..lineTo(cx - 48, 117)
      ..lineTo(cx - 45, 133)
      ..lineTo(cx - 42, 125)
      ..lineTo(cx - 38, 125);
    canvas.drawPath(leftPulse, pulsePaint);

    // Right arm pulse
    final rightPulse = Path()
      ..moveTo(cx + 38, 125)
      ..lineTo(cx + 42, 125)
      ..lineTo(cx + 44, 117)
      ..lineTo(cx + 47, 133)
      ..lineTo(cx + 50, 125)
      ..lineTo(cx + 54, 125);
    canvas.drawPath(rightPulse, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}