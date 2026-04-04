import '../../core/network/api_client.dart';
import '../../core/constants/api_endpoints.dart';

class ConsultService {
  ConsultService._();

  static Future<Map<String, dynamic>?> createConsultation({
    required int patientId,
    required String doctorName,
    required String aiSummary,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.consultPost, data: {
        'patient_id':  patientId,
        'doctor_name': doctorName,
        'ai_summary':  aiSummary,
      });
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}