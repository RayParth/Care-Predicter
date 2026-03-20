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

  UserProfile({
    required this.name,
    required this.email,
    required this.gender,
    required this.age,
    required this.weight,
    required this.height,
    required this.bloodGroup,
    required this.role,
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
  UserProfileNotifier() : super(UserProfile.empty()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = UserProfile(
      name: p.getString('name') ?? '',
      email: p.getString('email') ?? '',
      gender: p.getString('gender') ?? '',
      age: p.getInt('age') ?? 0,
      weight: p.getDouble('weight') ?? 0,
      height: p.getDouble('height') ?? 0,
      bloodGroup: p.getString('bloodGroup') ?? '',
      role: p.getString('role') ?? '',
    );
  }

  Future<void> save(UserProfile profile) async {
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
  }

  Future<void> clear() async {
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