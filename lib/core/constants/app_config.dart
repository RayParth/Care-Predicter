class AppConfig {
  // ── Change ONLY this one line to switch between local and ngrok ──
  static const String baseUrl = 'https://cathey-unincorporated-krishna.ngrok-free.dev';

// static const String baseUrl = 'http://172.16.56.108:8000'; // local WiFi
// static const String baseUrl = 'http://10.0.2.2:8000';      // emulator
// static const String baseUrl = 'https://your-app.railway.app'; // production

// Add these to AppConfig class
  static const int connectTimeout = 30;
  static const int receiveTimeout = 60;
  static const int sendTimeout    = 60;

// Health thresholds (these drive ALL threshold comparisons in the app)
  static const double hrCriticalHigh = 130;
  static const double hrHigh         = 100;
  static const double hrLow          = 60;
  static const double spo2Critical   = 90;
  static const double spo2Low        = 95;
  static const double tempCritical   = 39.0;
  static const double tempFever      = 38.5;
  static const double tempElevated   = 37.5;
  static const int    stepsGoal      = 10000;
  static const int    stepsGood      = 8000;
  static const int    stepsFair      = 5000;
}