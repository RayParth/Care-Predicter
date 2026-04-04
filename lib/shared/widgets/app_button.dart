import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    final fg = textColor ?? AppColors.white;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: isOutlined
          ? OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: bg,
          side: BorderSide(color: bg, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: _child(bg),
      )
          : ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: _child(fg),
      ),
    );
  }

  Widget _child(Color c) {
    if (isLoading) {
      return SizedBox(
          width: 22,
          height: 22,
          child:
          CircularProgressIndicator(color: c, strokeWidth: 2.5));
    }
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      );
    }
    return Text(label,
        style:
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w500));
  }
}
