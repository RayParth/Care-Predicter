import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_config.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  )..interceptors.addAll([
    _AuthInterceptor(),
  ]);

  static Dio get instance => _dio;

  static Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  static Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  static Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {
    if (err.response?.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    }
    handler.next(err);
  }
}