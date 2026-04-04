import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum BadgeType { normal, warning, danger, info }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;

  const StatusBadge(
      {super.key, required this.label, this.type = BadgeType.normal});

  Color get _bg {
    switch (type) {
      case BadgeType.normal: return AppColors.successLight;
      case BadgeType.warning: return AppColors.warningLight;
      case BadgeType.danger: return AppColors.dangerLight;
      case BadgeType.info: return AppColors.blueLight;
    }
  }

  Color get _text {
    switch (type) {
      case BadgeType.normal: return AppColors.success;
      case BadgeType.warning: return AppColors.warning;
      case BadgeType.danger: return AppColors.danger;
      case BadgeType.info: return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: _text,
              fontWeight: FontWeight.w500)),
    );
  }
}
