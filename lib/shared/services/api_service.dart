import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = "http://10.117.123.108:8000";

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String name,
    required String role,
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'email': email,
        'name': name,
        'role': role,
      });
      return res.data;
    } catch (e) {
      return null;
    }
  }

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