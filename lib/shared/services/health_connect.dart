import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthConnectService {
  final Health _health = Health();

  // Track whether permissions have been granted this session
  bool _permissionsGranted = false;

  final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
  ];

  // ── Request Permissions ───────────────────────────────────────────────────
  //
  // Only request once per app session. Store the result.
  // Call this from main.dart on startup, not inside fetchTodayData.
  //
  Future<bool> requestPermissions() async {
    try {
      await Permission.activityRecognition.request();
      await _health.configure();

      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final granted = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );
      _permissionsGranted = granted;
      print('[HealthConnect] Permissions granted: $granted');
      return granted;
    } catch (e) {
      print('[HealthConnect] Permission error: $e');
      _permissionsGranted = false;
      return false;
    }
  }

  // ── Fetch Today's Data ────────────────────────────────────────────────────
  //
  // Returns a map that now includes:
  //   'connected': true/false  — whether Health Connect actually returned data
  //
  // The UI uses 'connected' to show the correct badge label and to decide
  // whether to show the score or "No data" state.
  //
  Future<Map<String, dynamic>> fetchTodayData() async {
    final now      = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    // Default result — all zeros, connected: false
    Map<String, dynamic> result = {
      'steps':      0,
      'heartRate':  0.0,
      'spo2':       0.0,
      'calories':   0.0,
      'sleepHours': 0.0,
      'temperature': 0.0,
      'systolic':   0.0,
      'diastolic':  0.0,
      'weight':     0.0,
      'height':     0.0,
      'connected':  false,   // NEW — tells UI Health Connect has no data
    };

    try {
      // If permissions were never granted this session, request them now
      if (!_permissionsGranted) {
        final granted = await requestPermissions();
        if (!granted) {
          print('[HealthConnect] Permissions not granted — returning empty data');
          return result;
        }
      }

      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime:   now,
        types:     _types,
      );

      final clean = _health.removeDuplicates(data);

      if (clean.isEmpty) {
        // Health Connect is connected but has no data recorded today
        print('[HealthConnect] No data points returned for today');
        return result;
      }

      int    stepCount      = 0;
      double totalCalories  = 0;
      double totalSleep     = 0;
      double latestHR       = 0;
      double latestSpo2     = 0;
      double latestTemp     = 0;
      double latestSystolic = 0;
      double latestDiastolic = 0;
      double latestWeight   = 0;
      double latestHeight   = 0;

      for (final point in clean) {
        final val = (point.value as NumericHealthValue).numericValue.toDouble();

        switch (point.type) {
          case HealthDataType.STEPS:
            stepCount += val.toInt();
            break;
          case HealthDataType.HEART_RATE:
            latestHR = val;
            break;
          case HealthDataType.BLOOD_OXYGEN:
            latestSpo2 = val;
            break;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            totalCalories += val;
            break;
          case HealthDataType.SLEEP_ASLEEP:
            final mins = point.dateTo.difference(point.dateFrom).inMinutes;
            totalSleep += mins / 60;
            break;
          case HealthDataType.BODY_TEMPERATURE:
            latestTemp = val;
            break;
          case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
            latestSystolic = val;
            break;
          case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
            latestDiastolic = val;
            break;
          case HealthDataType.WEIGHT:
            latestWeight = val;
            break;
          case HealthDataType.HEIGHT:
            latestHeight = val * 100; // convert m to cm
            break;
          default:
            break;
        }
      }

      result = {
        'steps':       stepCount,
        'heartRate':   latestHR,
        'spo2':        latestSpo2,
        'calories':    double.parse(totalCalories.toStringAsFixed(0)),
        'sleepHours':  double.parse(totalSleep.toStringAsFixed(1)),
        'temperature': latestTemp,
        'systolic':    latestSystolic,
        'diastolic':   latestDiastolic,
        'weight':      latestWeight,
        'height':      latestHeight,
        // connected = true only when at least one real metric has a value
        'connected':   latestHR > 0 || latestSpo2 > 0 || stepCount > 0,
      };

    } catch (e) {
      print('[HealthConnect] Fetch error: $e');
      // Return default result with connected: false
    }

    return result;
  }

  // ── Calculate Health Score ────────────────────────────────────────────────
  //
  // FIXED: Returns 0 when ALL metrics are missing.
  // Previously returned 100 even with zero data — that was wrong.
  //
  // Logic:
  //   - Count how many parameters actually have real data
  //   - If none have data → return 0 (UI shows "No data")
  //   - If some have data → score from 100 with penalties for bad values
  //
  int calculateHealthScore(Map<String, dynamic> data) {
    final hr    = (data['heartRate']   as double?) ?? 0;
    final spo2  = (data['spo2']        as double?) ?? 0;
    final steps = (data['steps']       as int?)    ?? 0;
    final sleep = (data['sleepHours']  as double?) ?? 0;
    final temp  = (data['temperature'] as double?) ?? 0;

    // Count how many parameters have real values
    int dataPoints = 0;
    if (hr    > 0) dataPoints++;
    if (spo2  > 0) dataPoints++;
    if (steps > 0) dataPoints++;
    if (sleep > 0) dataPoints++;
    if (temp  > 0) dataPoints++;

    // No data at all — return 0, not 100
    if (dataPoints == 0) return 0;

    int score = 100;

    // Heart rate penalties
    if (hr > 0) {
      if (hr > 120 || hr < 50) score -= 20;
      else if (hr > 100 || hr < 60) score -= 10;
    }

    // SpO2 penalties
    if (spo2 > 0) {
      if (spo2 < 90)      score -= 30;
      else if (spo2 < 95) score -= 15;
      else if (spo2 < 97) score -= 5;
    }

    // Steps penalties
    if (steps > 0) {
      if (steps < 2000)      score -= 15;
      else if (steps < 5000) score -= 8;
      else if (steps < 8000) score -= 3;
    }

    // Sleep penalties
    if (sleep > 0) {
      if (sleep < 5)      score -= 20;
      else if (sleep < 6) score -= 12;
      else if (sleep < 7) score -= 5;
    }

    // Temperature penalties
    if (temp > 0) {
      if (temp > 39)        score -= 25;
      else if (temp > 38.5) score -= 15;
      else if (temp > 37.5) score -= 5;
    }

    return score.clamp(0, 100);
  }

  // ── Weekly Data ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWeeklyData() async {
    final List<Map<String, dynamic>> weekly = [];

    for (int i = 6; i >= 0; i--) {
      final day   = DateTime.now().subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day);
      final end   = start.add(const Duration(days: 1));

      try {
        final data = await _health.getHealthDataFromTypes(
          startTime: start,
          endTime:   end,
          types: [HealthDataType.STEPS, HealthDataType.HEART_RATE],
        );

        int    steps = 0;
        double hr    = 0;
        for (final p in data) {
          final val = (p.value as NumericHealthValue).numericValue.toDouble();
          if (p.type == HealthDataType.STEPS)      steps += val.toInt();
          if (p.type == HealthDataType.HEART_RATE) hr = val;
        }

        weekly.add({
          'date':      '${day.day}/${day.month}',
          'steps':     steps,
          'heartRate': hr,
        });
      } catch (e) {
        weekly.add({
          'date':      '${day.day}/${day.month}',
          'steps':     0,
          'heartRate': 0.0,
        });
      }
    }

    return weekly;
  }
}

// Single global instance used across the app
final healthService = HealthConnectService();