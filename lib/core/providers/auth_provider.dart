import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Tracks current Firebase user
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Tracks selected role: 'patient' or 'doctor'
final userRoleProvider = StateProvider<String?>((ref) => null);