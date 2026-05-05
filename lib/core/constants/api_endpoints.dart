class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String register       = '/auth/register';
  static const String registerEmail  = '/auth/register-email';
  static const String loginEmail     = '/auth/login-email';
  static const String googleLogin    = '/auth/google-login';
  static const String setPassword    = '/auth/set-password';

  // Forgot password — step 1: send OTP to email
  static const String forgotPassword = '/auth/forgot-password';

  // Reset password — step 2: verify OTP + save new password
  static const String resetPassword  = '/auth/reset-password';

  static const String sendOtp        = '/auth/send-otp';
  static const String verifyOtp      = '/auth/verify-otp';
  static const String userByEmail    = '/auth/user';
  static const String profile        = '/auth/profile';

  // ── Vitals ────────────────────────────────────────────────────────────────
  static const String vitalsPost = '/vitals/';
  static const String vitals     = '/vitals';

  // ── Labs ──────────────────────────────────────────────────────────────────
  static const String labUpload = '/ocr/upload';
  static const String labs      = '/labs';

  // ── Consult ───────────────────────────────────────────────────────────────
  static const String consultPost = '/consult/';
  static const String consult     = '/consult';

  // ── Health check ──────────────────────────────────────────────────────────
  static const String health = '/health';

  static String withId(String base, int id) =>
      base.contains('{id}') ? base.replaceFirst('{id}', '$id') : '$base/$id';
}