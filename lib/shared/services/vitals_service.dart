import '../../core/network/api_client.dart';
import '../../core/constants/api_endpoints.dart';

class VitalsService {
  VitalsService._();

  static Future<Map<String, dynamic>?> saveVitals({
    required int userId,
    required double heartRate,
    required double spo2,
    required int steps,
    required double calories,
    required double sleepHours,
    required double temperature,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.vitalsPost, data: {
        'user_id':     userId,
        'heart_rate':  heartRate,
        'spo2':        spo2,
        'steps':       steps,
        'calories':    calories,
        'sleep_hours': sleepHours,
        'temperature': temperature,
      });
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getLatestVitals(int userId) async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.vitals}/$userId/latest');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}