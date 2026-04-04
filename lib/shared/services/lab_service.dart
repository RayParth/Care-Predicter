import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_config.dart';

class LabService {
  LabService._();

  static Future<List<dynamic>> getLabReports(int userId) async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.labs}/$userId');
      return res.data as List;
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getLatestLabReport(int userId) async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.labs}/$userId/latest');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> uploadLabReport({
    required File file,
    required String fileName,
    required int userId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file':    await MultipartFile.fromFile(file.path, filename: fileName),
        'user_id': userId.toString(),
      });
      final res = await ApiClient.instance.post(
        ApiEndpoints.labUpload,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout:    Duration(seconds: AppConfig.sendTimeout),
          receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
        ),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot reach backend. Check WiFi and AppConfig.baseUrl.');
      }
      throw Exception('Upload failed: ${e.message}');
    }
  }
}