import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthConnectService {
  final Health _health = Health();

  final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
  ];

  // ── Check permissions (no dialog) ────────────────────────────────────────
  //
  // Use this to silently check if permissions are already granted.
  // Returns true/false without showing any dialog.
  // Call this from HomeTab.initState() to decide whether to show the banner.
  //
  // NOTE: this is intentionally NOT called inside fetchTodayData() anymore.
  // See the comment there for why.
  //
  Future<bool> hasPermissions() async {
    try {
      await _health.configure();
      return await _health.hasPermissions(_types) ?? false;
    } catch (e) {
      return false;
    }
  }

  // ── Request permissions (shows dialog) ───────────────────────────────────
  //
  // MUST be called from a user interaction (button tap) inside a live Activity.
  // NEVER call this from a FutureProvider, initState, or any background context.
  // Android requires a registered ActivityResultLauncher — calling from background
  // throws "Permission launcher not found" and crashes silently.
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
      print('[HealthConnect] Permissions granted: $granted');
      return granted;
    } catch (e) {
      print('[HealthConnect] Permission error: $e');
      return false;
    }
  }

  // ── Fetch Today's Data ────────────────────────────────────────────────────
  //
  // FIXED (round 2): removed the hasPermissions() gate that used to run at
  // the top of this method.
  //
  // Bug: right after a fresh grant, the underlying `health` plugin's
  // hasPermissions(_types) call is unreliable across a mixed list of 10
  // data types (steps, heart rate, blood pressure, temperature, weight,
  // height, sleep, ...) — it frequently returns null instead of a clean
  // true/false while Health Connect is still settling the newly-granted
  // state. Our old code did `?? false`, so a null (uncertain) response
  // silently collapsed into "not granted" — even though the OS-level log
  // (`FLUTTER_HEALTH: 8 Health Connect permissions were granted!`) and our
  // own requestPermissions() log (`Permissions granted: true`) both
  // confirmed access was actually granted seconds earlier. Every single
  // fetch was bailing out early and returning empty data as a result.
  //
  // Fix: don't re-check permissions here at all. If they're genuinely
  // missing, getHealthDataFromTypes() below will simply return no data
  // (or throw, which the existing catch handles) — we don't need a second,
  // less reliable gate in front of it. Permission status for UI purposes
  // (showing the "Grant Access" banner) is still handled correctly by
  // hasPermissions() being called separately from HomeTab.initState().
  //
  // FIXED (original): SLEEP_SESSION was requested in _types but the old
  // switch only handled SLEEP_ASLEEP, so sleep data always fell through to
  // `default` and sleepHours stayed 0.0 forever, silently. Also added a
  // type guard before the NumericHealthValue cast — SLEEP_SESSION points
  // are not numeric values (they're a duration derived from dateFrom/dateTo),
  // so the old unconditional cast would throw once sleep data actually
  // started reaching the switch.
  //
  Future<Map<String, dynamic>> fetchTodayData() async {
    final now      = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    Map<String, dynamic> result = {
      'steps':       0,
      'heartRate':   0.0,
      'spo2':        0.0,
      'calories':    0.0,
      'sleepHours':  0.0,
      'temperature': 0.0,
      'systolic':    0.0,
      'diastolic':   0.0,
      'weight':      0.0,
      'height':      0.0,
      'connected':   false,
    };

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime:   now,
        types:     _types,
      );

      final clean = _health.removeDuplicates(data);

      if (clean.isEmpty) {
        print('[HealthConnect] No data points returned for today');
        return result;
      }

      int    stepCount       = 0;
      double totalCalories   = 0;
      double totalSleep      = 0;
      double latestHR        = 0;
      double latestSpo2      = 0;
      double latestTemp      = 0;
      double latestSystolic  = 0;
      double latestDiastolic = 0;
      double latestWeight    = 0;
      double latestHeight    = 0;

      for (final point in clean) {
        // FIXED: guard the cast. SLEEP_SESSION (and potentially other
        // non-scalar types) do not come back as NumericHealthValue — the
        // old unconditional cast would throw as soon as a sleep point was
        // actually reached. Numeric-only types read `val`; SLEEP_SESSION
        // computes its own duration below from dateFrom/dateTo instead.
        double val = 0;
        if (point.value is NumericHealthValue) {
          val = (point.value as NumericHealthValue).numericValue.toDouble();
        }

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
          case HealthDataType.SLEEP_SESSION:
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
            latestHeight = val * 100;
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
        'connected':   latestHR > 0 || latestSpo2 > 0 || stepCount > 0,
      };

    } catch (e) {
      print('[HealthConnect] Fetch error: $e');
    }

    return result;
  }

  // ── Calculate Health Score ────────────────────────────────────────────────
  //
  // Returns 0 when ALL metrics are missing — never shows a fake 100.
  //
  int calculateHealthScore(Map<String, dynamic> data) {
    final hr    = (data['heartRate']   as double?) ?? 0;
    final spo2  = (data['spo2']        as double?) ?? 0;
    final steps = (data['steps']       as int?)    ?? 0;
    final sleep = (data['sleepHours']  as double?) ?? 0;
    final temp  = (data['temperature'] as double?) ?? 0;

    int dataPoints = 0;
    if (hr    > 0) dataPoints++;
    if (spo2  > 0) dataPoints++;
    if (steps > 0) dataPoints++;
    if (sleep > 0) dataPoints++;
    if (temp  > 0) dataPoints++;

    if (dataPoints == 0) return 0;

    int score = 100;

    if (hr > 0) {
      if (hr > 120 || hr < 50) score -= 20;
      else if (hr > 100 || hr < 60) score -= 10;
    }
    if (spo2 > 0) {
      if (spo2 < 90)      score -= 30;
      else if (spo2 < 95) score -= 15;
      else if (spo2 < 97) score -= 5;
    }
    if (steps > 0) {
      if (steps < 2000)      score -= 15;
      else if (steps < 5000) score -= 8;
      else if (steps < 8000) score -= 3;
    }
    if (sleep > 0) {
      if (sleep < 5)      score -= 20;
      else if (sleep < 6) score -= 12;
      else if (sleep < 7) score -= 5;
    }
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
          double val = 0;
          if (p.value is NumericHealthValue) {
            val = (p.value as NumericHealthValue).numericValue.toDouble();
          }
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