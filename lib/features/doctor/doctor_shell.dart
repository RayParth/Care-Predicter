import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import 'doctor_dashboard_tab.dart';
import 'doctor_patients_tab.dart';
import 'doctor_alerts_tab.dart';

final doctorTabProvider = StateProvider<int>((ref) => 0);

class DoctorShell extends ConsumerWidget {
  const DoctorShell({super.key});

  static const _tabs = [
    DoctorDashboardTab(),
    DoctorPatientsTab(),
    DoctorAlertsTab(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(doctorTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard',
                    active: index == 0, onTap: () => ref.read(doctorTabProvider.notifier).state = 0),
                _NavItem(icon: Icons.people_rounded, label: 'Patients',
                    active: index == 1, onTap: () => ref.read(doctorTabProvider.notifier).state = 1),
                _NavItem(icon: Icons.notifications_rounded, label: 'Alerts',
                    active: index == 2, onTap: () => ref.read(doctorTabProvider.notifier).state = 2),
              ],
            ),
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

  const _NavItem({required this.icon, required this.label,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.blueLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22,
                color: active ? AppColors.blue : AppColors.textHint),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.blue : AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}