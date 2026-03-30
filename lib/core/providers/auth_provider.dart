import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userRoleProvider = StateProvider<String?>((ref) => null);

// Now reads from persisted profile instead of resetting on restart
final backendUserIdProvider = Provider<int>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.backendUserId;
});