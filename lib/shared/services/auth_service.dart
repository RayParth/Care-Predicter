import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_endpoints.dart';

class AuthService {
  AuthService._();

  // ── Google Login Check ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> googleLogin({
    required String email,
    required String name,
  }) async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.googleLogin,
        data: {'email': email, 'name': name, 'role': ''},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Google login check failed');
    }
  }

  // ── Register With Google ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> registerGoogle({
    required String email,
    required String name,
    required String role,
    String? gender,
    int? age,
    double? weight,
    double? height,
    String? bloodGroup,
    String? password,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.register, data: {
        'email': email,
        'name':  name,
        'role':  role,
        if (gender     != null) 'gender':      gender,
        if (age        != null) 'age':         age,
        if (weight     != null) 'weight':      weight,
        if (height     != null) 'height':      height,
        if (bloodGroup != null) 'blood_group': bloodGroup,
        if (password   != null && password.isNotEmpty) 'password': password,
      });
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Set Password ──────────────────────────────────────────────────────────

  static Future<bool> setPassword({
    required String email,
    required String password,
  }) async {
    try {
      await ApiClient.post(ApiEndpoints.setPassword, data: {
        'email':    email,
        'password': password,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Register With Email ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerWithEmail({
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
      final res = await ApiClient.post(ApiEndpoints.registerEmail, data: {
        'email':    email,
        'name':     name,
        'password': password,
        'role':     role,
        if (gender     != null) 'gender':      gender,
        if (age        != null) 'age':         age,
        if (weight     != null) 'weight':      weight,
        if (height     != null) 'height':      height,
        if (bloodGroup != null) 'blood_group': bloodGroup,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Registration failed');
    }
  }

  // ── Login With Email ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.loginEmail, data: {
        'email':    email,
        'password': password,
      });
      final data  = res.data as Map<String, dynamic>;
      final token = data['access_token'];
      if (token != null && token is String) await _saveToken(token);
      return data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Login failed');
    }
  }

  // ── Forgot Password — Step 1 ──────────────────────────────────────────────
  //
  // Sends a password-reset OTP to the user's email.
  // Throws Exception with the backend error message on failure.
  //
  static Future<void> forgotPassword({required String email}) async {
    try {
      await ApiClient.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to send reset code');
    }
  }

  // ── Reset Password — Step 2 ───────────────────────────────────────────────
  //
  // Verifies the OTP and saves the new password.
  // Throws Exception with the backend error message on failure.
  //
  static Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await ApiClient.post(
        ApiEndpoints.resetPassword,
        data: {
          'email':        email,
          'otp':          otp,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to reset password');
    }
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────

  static Future<void> sendOtp(String email, {String? phone}) async {
    try {
      await ApiClient.post(ApiEndpoints.sendOtp, data: {
        'email': email,
        if (phone != null) 'phone': phone,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to send OTP');
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> verifyOtp(
      String email, String code) async {
    try {
      final res  = await ApiClient.post(ApiEndpoints.verifyOtp,
          data: {'email': email, 'code': code});
      final data = res.data as Map<String, dynamic>;
      if (data['user'] == null) {
        throw Exception(data['message'] ?? 'Invalid OTP response');
      }
      final token = data['access_token'];
      if (token != null && token is String) await _saveToken(token);
      return data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Invalid OTP');
    }
  }

  // ── Get Latest Lab Report ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getLatestLabReport(int userId) async {
    try {
      final res = await ApiClient.get('/labs/$userId/latest');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}