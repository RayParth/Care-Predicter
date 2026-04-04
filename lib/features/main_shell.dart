import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import 'dashboard/home_tab.dart';
import 'organ_map/organ_map_tab.dart';
import 'chat/ai_chat_tab.dart';
import 'lab/lab_upload_tab.dart';
import 'consult/consult_tab.dart';

final shellIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _tabs = [
    HomeTab(),
    OrganMapTab(),
    AiChatTab(),
    LabUploadTab(),
    ConsultTab(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: index,
        children: _tabs,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: index,
        onTap: (i) =>
        ref.read(shellIndexProvider.notifier).state = i,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _BottomNav(
      {required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
            top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: currentIndex == 0,
                  onTap: () => onTap(0)),
              _NavItem(
                  icon: Icons.accessibility_new_rounded,
                  label: 'Body',
                  active: currentIndex == 1,
                  onTap: () => onTap(1)),
              _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'AI Chat',
                  active: currentIndex == 2,
                  onTap: () => onTap(2)),
              _NavItem(
                  icon: Icons.science_rounded,
                  label: 'Labs',
                  active: currentIndex == 3,
                  onTap: () => onTap(3)),
              _NavItem(
                  icon: Icons.people_rounded,
                  label: 'Consult',
                  active: currentIndex == 4,
                  onTap: () => onTap(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryLight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: active
                    ? AppColors.primary
                    : AppColors.textHint),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: active
                        ? AppColors.primary
                        : AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}
