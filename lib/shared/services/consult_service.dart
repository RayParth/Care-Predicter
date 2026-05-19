import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_endpoints.dart';

class ConsultService {
  ConsultService._();

  // ── Patient: create a consultation request ────────────────────────────────

  static Future<Map<String, dynamic>?> createConsultation({
    required int    patientId,
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

  // ── Patient: get own consultation history ─────────────────────────────────

  static Future<List<dynamic>> getConsultationsForPatient(int patientId) async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.consult}/$patientId');
      return res.data as List;
    } catch (_) {
      return [];
    }
  }

  // ── Doctor: get all consultations sent to them ────────────────────────────
  //
  // NEW METHOD.
  // Returns list of consultations enriched with patient profile,
  // latest vitals, and latest lab values.
  // The doctor_name here is the doctor's name as stored in the DB
  // (matches what patient typed when sending the request).
  //
  static Future<List<dynamic>> getConsultationsForDoctor(
      String doctorName) async {
    try {
      final encoded = Uri.encodeComponent(doctorName);
      final res = await ApiClient.get(
          '${ApiEndpoints.consult}/doctor/$encoded');
      return res.data as List;
    } catch (_) {
      return [];
    }
  }

  // ── Doctor: accept or reject a consultation ───────────────────────────────
  //
  // NEW METHOD.
  // status must be: "accepted", "rejected", "pending", or "completed"
  //
  static Future<bool> updateStatus({
    required int    consultId,
    required String status,
    String          notes = '',
  }) async {
    try {
      await ApiClient.put(
        '${ApiEndpoints.consult}/$consultId/status',
        data: {'status': status, 'notes': notes},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}