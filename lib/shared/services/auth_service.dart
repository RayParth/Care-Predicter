
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_endpoints.dart';

class AuthService {
AuthService._();

// ───────────────── REGISTER WITH EMAIL ─────────────────
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

return res.data as Map<String, dynamic>;
} on DioException catch (e) {
throw Exception(e.response?.data['detail'] ?? 'Registration failed');
}
}

// ───────────────── LOGIN WITH EMAIL ─────────────────
static Future<Map<String, dynamic>> loginWithEmail({
required String email,
required String password,
}) async {
try {
final res = await ApiClient.post(ApiEndpoints.loginEmail, data: {
'email': email,
'password': password,
});

final data = res.data as Map<String, dynamic>;

// ✅ SAFE TOKEN HANDLING
final token = data['access_token'];
if (token != null && token is String) {
await _saveToken(token);
}

return data;
} on DioException catch (e) {
throw Exception(e.response?.data['detail'] ?? 'Login failed');
}
}

// ───────────────── GOOGLE REGISTER ─────────────────
static Future<Map<String, dynamic>?> registerGoogle({
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
final res = await ApiClient.post(ApiEndpoints.register, data: {
'email': email,
'name': name,
'role': role,
if (gender != null) 'gender': gender,
if (age != null) 'age': age,
if (weight != null) 'weight': weight,
if (height != null) 'height': height,
if (bloodGroup != null) 'blood_group': bloodGroup,
});

return res.data as Map<String, dynamic>;
} catch (_) {
return null;
}
}

// ───────────────── SEND OTP ─────────────────
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

// ───────────────── VERIFY OTP ─────────────────
static Future<Map<String, dynamic>> verifyOtp(
String email, String code) async {
try {
final res = await ApiClient.post(ApiEndpoints.verifyOtp, data: {
'email': email,
'code': code,
});

final data = res.data as Map<String, dynamic>;

// ✅ VALIDATE RESPONSE
if (data['user'] == null) {
throw Exception(data['message'] ?? 'Invalid OTP response');
}

// ✅ SAFE TOKEN HANDLING
final token = data['access_token'];
if (token != null && token is String) {
await _saveToken(token);
}

return data;
} on DioException catch (e) {
throw Exception(e.response?.data['detail'] ?? 'Invalid OTP');
}
}

// ───────────────── GET USER BY EMAIL ─────────────────
static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
try {
final res = await ApiClient.get('${ApiEndpoints.userByEmail}/$email');
return res.data as Map<String, dynamic>;
} catch (_) {
return null;
}
}

// ───────────────── LAB REPORT ─────────────────
  static Future<Map<String, dynamic>?> getLatestLabReport(int userId) async {
    try {
      final res = await ApiClient.get('/labs/$userId/latest');
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

// ───────────────── LOGOUT ─────────────────
static Future<void> logout() async {
final prefs = await SharedPreferences.getInstance();
await prefs.remove('auth_token');
}

// ───────────────── SAVE TOKEN ─────────────────
static Future<void> _saveToken(String token) async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString('auth_token', token);
}
}

