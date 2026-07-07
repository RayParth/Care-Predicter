import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final String email;
  final String gender;
  final int age;
  final double weight;
  final double height;
  final String bloodGroup;
  final String role;
  final int backendUserId;

  UserProfile({
    required this.name,
    required this.email,
    required this.gender,
    required this.age,
    required this.weight,
    required this.height,
    required this.bloodGroup,
    required this.role,
    this.backendUserId = 0,
  });

  factory UserProfile.empty() => UserProfile(
    name: '',
    email: '',
    gender: '',
    age: 0,
    weight: 0,
    height: 0,
    bloodGroup: '',
    role: '',
    backendUserId: 0,
  );

  UserProfile copyWith({
    String? name,
    String? email,
    String? gender,
    int? age,
    double? weight,
    double? height,
    String? bloodGroup,
    String? role,
    int? backendUserId,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      role: role ?? this.role,
      backendUserId: backendUserId ?? this.backendUserId,
    );
  }

  double get bmi {
    if (height <= 0 || weight <= 0) return 0;
    final h = height / 100;
    return weight / (h * h);
  }

  String get bmiCategory {
    final b = bmi;
    if (b <= 0) return '';
    if (b < 18.5) return 'Underweight';
    if (b < 25) return 'Healthy';
    if (b < 30) return 'Overweight';
    return 'Obese';
  }
}

class UserProfileNotifier extends StateNotifier<UserProfile> {
  // GUARD: once save() has been called explicitly (fresh login/register),
  // the background _load() from the constructor must NOT be allowed to
  // clobber that state with stale/empty SharedPreferences data.
  //
  // BUG THIS FIXES: _load() is fired unawaited from the constructor. On a
  // fresh install, login code calls save(profile) almost immediately after
  // the notifier is constructed. save() sets state synchronously and then
  // awaits disk writes. _load() started first but resolves its disk READ
  // later (after an await gap) and was overwriting the correct state with
  // UserProfile.empty() because it read prefs before save() had written to
  // them. This made the name/profile vanish on first login only, since a
  // subsequent app restart has no concurrent save() to race against.
  bool _hasExplicitSave = false;

  UserProfileNotifier() : super(UserProfile.empty()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (_hasExplicitSave) return; // an explicit save already won, don't clobber it
    state = UserProfile(
      name: p.getString('name') ?? '',
      email: p.getString('email') ?? '',
      gender: p.getString('gender') ?? '',
      age: p.getInt('age') ?? 0,
      weight: p.getDouble('weight') ?? 0,
      height: p.getDouble('height') ?? 0,
      bloodGroup: p.getString('bloodGroup') ?? '',
      role: p.getString('role') ?? '',
      backendUserId: p.getInt('backendUserId') ?? 0,
    );
  }

  Future<void> save(UserProfile profile) async {
    _hasExplicitSave = true;
    state = profile;
    final p = await SharedPreferences.getInstance();
    await p.setString('name', profile.name);
    await p.setString('email', profile.email);
    await p.setString('gender', profile.gender);
    await p.setInt('age', profile.age);
    await p.setDouble('weight', profile.weight);
    await p.setDouble('height', profile.height);
    await p.setString('bloodGroup', profile.bloodGroup);
    await p.setString('role', profile.role);
    await p.setInt('backendUserId', profile.backendUserId);
  }

  Future<void> clear() async {
    _hasExplicitSave = true; // logout is also an explicit, authoritative write
    state = UserProfile.empty();
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }

  bool get isComplete =>
      state.name.isNotEmpty && state.age > 0 && state.gender.isNotEmpty;
}

final userProfileProvider =
StateNotifierProvider<UserProfileNotifier, UserProfile>(
      (ref) => UserProfileNotifier(),
);