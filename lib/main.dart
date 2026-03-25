import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/colors.dart';
import 'features/auth/login_screen.dart';
import 'features/doctor/doctor_shell.dart';
import 'features/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString('name') ?? '';
  final role = prefs.getString('role') ?? '';
  final email = prefs.getString('email') ?? '';
  final isLoggedIn =
      name.isNotEmpty && role.isNotEmpty && email.isNotEmpty;

  runApp(ProviderScope(
    child: CarePredicterApp(
      isLoggedIn: isLoggedIn,
      role: role,
    ),
  ));
}

class CarePredicterApp extends StatelessWidget {
  final bool isLoggedIn;
  final String role;

  const CarePredicterApp({
    super.key,
    required this.isLoggedIn,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Care Predicter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
        ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.white,
        useMaterial3: true,
      ),
      home: isLoggedIn
          ? (role == 'doctor'
          ? const DoctorShell()
          : const MainShell())
          : const LoginScreen(),
    );
  }
}