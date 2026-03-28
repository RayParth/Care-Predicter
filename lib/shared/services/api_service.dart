import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'http://10.117.123.108:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // ── Gmail OAuth register ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String name,
    required String role,
    String? gender,
    int? age,
    double? weight,
    double? height,
    String? bloodGroup,
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'email': email,
        'name': name,
        'role': role,
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age,
        if (weight != null) 'weight': weight,
        if (height != null) 'height': height,
        if (bloodGroup != null) 'blood_group': bloodGroup,
      });
      return res.data;
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }

  // ── Email + Password register ────────────────────────────────────────

  Future<Map<String, dynamic>?> registerWithEmail({
    required String email,
    required String name,
    required String password,
    required String role,
    String? gender,
    int? age,
    double? weight,
    double? height,
    String? bloodGroup,
  }) async {
    try {
      final res = await _dio.post('/auth/register-email', data: {
        'email': email,
        'name': name,
        'password': password,
        'role': role,
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age,
        if (weight != null) 'weight': weight,
        if (height != null) 'height': height,
        if (bloodGroup != null) 'blood_group': bloodGroup,
      });
      return res.data;
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Registration failed';
      throw Exception(msg);
    }
  }

  // ── Email + Password login ───────────────────────────────────────────

  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/auth/login-email', data: {
        'email': email,
        'password': password,
      });
      return res.data;
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Login failed';
      throw Exception(msg);
    }
  }

  // ── Send OTP ─────────────────────────────────────────────────────────

  Future<void> sendOtp(String email) async {
    try {
      await _dio.post('/auth/send-otp', data: {'email': email});
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Failed to send OTP';
      throw Exception(msg);
    }
  }

  // ── Verify OTP ───────────────────────────────────────────────────────

  Future<bool> verifyOtp(String email, String code) async {
    try {
      await _dio.post('/auth/verify-otp', data: {
        'email': email,
        'code': code,
      });
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Invalid OTP';
      throw Exception(msg);
    }
  }

  // ── Get user by email ─────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final res = await _dio.get('/auth/user/$email');
      return res.data;
    } catch (e) {
      return null;
    }
  }

  // ── Save vitals ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> saveVitals({
    required int userId,
    required double heartRate,
    required double spo2,
    required int steps,
    required double calories,
    required double sleepHours,
    required double temperature,
  }) async {
    try {
      final res = await _dio.post('/vitals/', data: {
        'user_id': userId,
        'heart_rate': heartRate,
        'spo2': spo2,
        'steps': steps,
        'calories': calories,
        'sleep_hours': sleepHours,
        'temperature': temperature,
      });
      return res.data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLatestVitals(int userId) async {
    try {
      final res = await _dio.get('/vitals/$userId/latest');
      return res.data;
    } catch (e) {
      return null;
    }
  }

  // ── Get lab reports history ──────────────────────────────────────────

  Future<List<dynamic>> getLabReports(int userId) async {
    try {
      final res = await _dio.get('/labs/$userId');
      return res.data as List;
    } catch (e) {
      return [];
    }
  }

  // ── Save lab report ───────────────────────────────────────────────────

  Future<Map<String, dynamic>?> saveLabReport({
    required int userId,
    required Map<String, dynamic> values,
  }) async {
    try {
      final res = await _dio.post('/labs/', data: {
        'user_id': userId,
        ...values,
      });
      return res.data;
    } catch (e) {
      return null;
    }
  }

  // ── Consultation ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> createConsultation({
    required int patientId,
    required String doctorName,
    required String aiSummary,
  }) async {
    try {
      final res = await _dio.post('/consult/', data: {
        'patient_id': patientId,
        'doctor_name': doctorName,
        'ai_summary': aiSummary,
      });
      return res.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isOnline() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

final apiService = ApiService();