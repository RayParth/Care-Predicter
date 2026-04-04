import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'profile_setup_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.06,
              vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text('Select your role',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                  'This determines what you see in Care Predicter',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              _RoleCard(
                title: 'Patient / User',
                subtitle:
                'Monitor your own health vitals,\nupload lab reports, chat with AI',
                icon: Icons.person_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primaryLight,
                tags: const [
                  'Vitals',
                  'Lab OCR',
                  'AI Chat',
                  'Organ Map',
                  'Alerts'
                ],
                tagColor: AppColors.primaryLight,
                tagTextColor: AppColors.primaryDark,
                isHighlighted: true,
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const ProfileSetupScreen(role: 'patient')),
                ),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: 'Doctor',
                subtitle:
                'View patient summaries,\nconsultations, AI-generated reports',
                icon: Icons.medical_services_rounded,
                iconColor: AppColors.blue,
                iconBg: AppColors.blueLight,
                tags: const [
                  'Patient queue',
                  'AI summaries',
                  'Alerts'
                ],
                tagColor: AppColors.blueLight,
                tagTextColor: AppColors.blue,
                isHighlighted: false,
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const ProfileSetupScreen(role: 'doctor')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final List<String> tags;
  final Color tagColor;
  final Color tagTextColor;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.tags,
    required this.tagColor,
    required this.tagTextColor,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.primaryLight
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isHighlighted
                  ? AppColors.primary
                  : AppColors.border,
              width: isHighlighted ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isHighlighted
                                ? AppColors.primaryDark
                                : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: isHighlighted
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isHighlighted
                      ? AppColors.primary
                      : AppColors.textHint),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius:
                    BorderRadius.circular(20)),
                child: Text(t,
                    style: TextStyle(
                        fontSize: 11,
                        color: tagTextColor,
                        fontWeight: FontWeight.w500)),
              ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}