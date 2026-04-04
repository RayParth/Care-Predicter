class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register      = '/auth/register';
  static const String registerEmail = '/auth/register-email';
  static const String loginEmail    = '/auth/login-email';
  static const String sendOtp       = '/auth/send-otp';
  static const String verifyOtp     = '/auth/verify-otp';
  static const String userByEmail   = '/auth/user';
  static const String profile       = '/auth/profile';

  // Vitals
  static const String vitalsPost   = '/vitals/';
  static const String vitals       = '/vitals';

  // Labs
  static const String labUpload = '/ocr/upload';
  static const String labs      = '/labs';

  // Consult
  static const String consultPost = '/consult/';
  static const String consult     = '/consult';

  // Health check
  static const String health = '/health';

  static String withId(String base, int id) =>
      base.contains('{id}') ? base.replaceFirst('{id}', '$id') : '$base/$id';
}