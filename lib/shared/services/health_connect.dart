import 'package:health/health.dart';

class HealthConnectService {
  final Health _health = Health();

  final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
  ];

  // Sleep is queried separately because overnight sleep can start
  // before midnight and continue into today.
  final HealthDataType _sleepType = HealthDataType.SLEEP_SESSION;

  // ---------------------------------------------------------------------------
  // PERMISSIONS
  // ---------------------------------------------------------------------------

  Future<bool> requestPermissions() async {
    try {
      print('[HealthConnect] Requesting permissions...');

      final permissions = _types
          .map((type) => HealthDataAccess.READ)
          .toList();

      permissions.add(HealthDataAccess.READ);

      final allTypes = [..._types, _sleepType];

      final granted = await _health.requestAuthorization(
        allTypes,
        permissions: permissions,
      );

      print('[HealthConnect] Permission result: $granted');

      return granted;
    } catch (e, stackTrace) {
      print('[HealthConnect] Permission error: $e');
      print(stackTrace);
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      final permissions = _types
          .map((type) => HealthDataAccess.READ)
          .toList();

      permissions.add(HealthDataAccess.READ);

      final allTypes = [..._types, _sleepType];

      final result = await _health.hasPermissions(
        allTypes,
        permissions: permissions,
      );

      print('[HealthConnect] Has permissions: $result');

      return result ?? false;
    } catch (e, stackTrace) {
      print('[HealthConnect] Permission check error: $e');
      print(stackTrace);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // HEALTH DATA
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> fetchTodayData() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    final result = <String, dynamic>{
      'steps': 0,
      'heartRate': 0.0,
      'spo2': 0.0,
      'calories': 0.0,
      'sleepHours': 0.0,
      'temperature': 0.0,
      'systolic': 0.0,
      'diastolic': 0.0,
      'weight': 0.0,
      'height': 0.0,
      'connected': false,
    };

    try {
      print('');
      print('==================================================');
      print('[HealthConnect] FETCH TODAY DATA');
      print('[HealthConnect] Start: $midnight');
      print('[HealthConnect] End:   $now');
      print('==================================================');

      // -----------------------------------------------------------------------
      // 1. NORMAL HEALTH DATA
      // -----------------------------------------------------------------------

      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: _types,
      );

      final cleanData = _health.removeDuplicates(data);

      print(
        '[HealthConnect] Normal records: '
            '${data.length} → ${cleanData.length} after duplicate removal',
      );

      // -----------------------------------------------------------------------
      // 2. SLEEP DATA
      // -----------------------------------------------------------------------
      //
      // Query the previous 12 hours as well as today.
      //
      // Example:
      // Yesterday 11:25 PM → Today 7:07 AM
      //
      // A midnight → now query can miss the beginning of that session.
      // -----------------------------------------------------------------------

      final sleepStart = midnight.subtract(const Duration(hours: 12));

      final sleepData = await _health.getHealthDataFromTypes(
        startTime: sleepStart,
        endTime: now,
        types: [_sleepType],
      );

      final cleanSleepData = _health.removeDuplicates(sleepData);

      print(
        '[HealthConnect] Sleep records: '
            '${sleepData.length} → ${cleanSleepData.length} after duplicate removal',
      );

      // -----------------------------------------------------------------------
      // ACCUMULATED VALUES
      // -----------------------------------------------------------------------

      int stepCount = 0;
      double totalActiveCalories = 0;
      double totalCaloriesBurned = 0;

      // -----------------------------------------------------------------------
      // LATEST MEASUREMENTS
      // -----------------------------------------------------------------------

      HealthDataPoint? latestHRPoint;
      HealthDataPoint? latestSpo2Point;
      HealthDataPoint? latestTempPoint;
      HealthDataPoint? latestWeightPoint;
      HealthDataPoint? latestHeightPoint;

      // BP must be handled as a matched pair.
      HealthDataPoint? latestSystolicPoint;
      HealthDataPoint? latestDiastolicPoint;

      // -----------------------------------------------------------------------
      // PROCESS NORMAL DATA
      // -----------------------------------------------------------------------

      for (final point in cleanData) {
        final value = _numericValue(point);

        if (value == null) {
          print(
            '[HealthConnect] Skipping non-numeric '
                '${point.type}: ${point.value}',
          );
          continue;
        }

        print(
          '[HealthConnect] '
              '${point.type} = $value '
              '${point.unit} '
              '[${point.dateFrom} → ${point.dateTo}]',
        );

        switch (point.type) {
          case HealthDataType.STEPS:
            stepCount += value.toInt();
            break;

          case HealthDataType.HEART_RATE:
            if (_isNewer(point, latestHRPoint)) {
              latestHRPoint = point;
            }
            break;

          case HealthDataType.BLOOD_OXYGEN:
            if (_isNewer(point, latestSpo2Point)) {
              latestSpo2Point = point;
            }
            break;

          case HealthDataType.ACTIVE_ENERGY_BURNED:
            totalActiveCalories += value;
            break;

          case HealthDataType.TOTAL_CALORIES_BURNED:
            totalCaloriesBurned += value;
            break;

          case HealthDataType.BODY_TEMPERATURE:
          // The health package converts the temperature to Celsius.
          //
          // Reject only values that are physically impossible for a
          // living human (sensor glitch / fat-finger entry, e.g. 88°F
          // typed into a Celsius field ≈ 31.1°C). Do NOT try to filter
          // out real but abnormal readings (e.g. hypothermia ~32-35°C)
          // here — that range overlaps with garbage data and cannot be
          // told apart by value alone. Medical classification
          // (low/high/critical) is the backend's job — see
          // backend/routes/vitals.py check_thresholds().
            if (value >= 32.0 && value <= 45.0) {
              if (_isNewer(point, latestTempPoint)) {
                latestTempPoint = point;
              }
            } else {
              print(
                '[HealthConnect] Ignoring physically impossible temperature: '
                    '$value°C',
              );
            }
            break;

          case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
            if (_isNewer(point, latestSystolicPoint)) {
              latestSystolicPoint = point;
            }
            break;

          case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
            if (_isNewer(point, latestDiastolicPoint)) {
              latestDiastolicPoint = point;
            }
            break;

          case HealthDataType.WEIGHT:
            if (_isNewer(point, latestWeightPoint)) {
              latestWeightPoint = point;
            }
            break;

          case HealthDataType.HEIGHT:
            if (_isNewer(point, latestHeightPoint)) {
              latestHeightPoint = point;
            }
            break;

          default:
            break;
        }
      }

      // -----------------------------------------------------------------------
      // LATEST VALUES
      // -----------------------------------------------------------------------

      final latestHR = latestHRPoint == null
          ? 0.0
          : (_numericValue(latestHRPoint!) ?? 0.0);

      final latestSpo2 = latestSpo2Point == null
          ? 0.0
          : (_numericValue(latestSpo2Point!) ?? 0.0);

      final latestTemp = latestTempPoint == null
          ? 0.0
          : (_numericValue(latestTempPoint!) ?? 0.0);

      final latestWeight = latestWeightPoint == null
          ? 0.0
          : (_numericValue(latestWeightPoint!) ?? 0.0);

      // Health Connect height is returned in meters by the health package.
      // Convert meters → centimeters for the app.
      final latestHeightMeters = latestHeightPoint == null
          ? 0.0
          : (_numericValue(latestHeightPoint!) ?? 0.0);

      final latestHeightCm =
      latestHeightMeters > 0 ? latestHeightMeters * 100 : 0.0;

      // -----------------------------------------------------------------------
      // BLOOD PRESSURE PAIR
      // -----------------------------------------------------------------------
      //
      // Only accept systolic + diastolic if they are reasonably close in time.
      //
      // This prevents creating a fake pair such as:
      //
      // 10:00 → 120/80
      // 10:30 → 135/85
      //
      // and accidentally displaying 135/80.
      // -----------------------------------------------------------------------

      double latestSystolic = 0.0;
      double latestDiastolic = 0.0;

      if (latestSystolicPoint != null && latestDiastolicPoint != null) {
        final difference = latestSystolicPoint!.dateFrom
            .difference(latestDiastolicPoint!.dateFrom)
            .abs();

        if (difference <= const Duration(minutes: 5)) {
          latestSystolic =
              _numericValue(latestSystolicPoint!) ?? 0.0;

          latestDiastolic =
              _numericValue(latestDiastolicPoint!) ?? 0.0;
        } else {
          print(
            '[HealthConnect] BP readings are too far apart: '
                '${difference.inMinutes} minutes. '
                'Ignoring unmatched pair.',
          );
        }
      }


      // -----------------------------------------------------------------------
      // CALORIES
      // -----------------------------------------------------------------------
      //
      // Prefer total calories (BMR + activity) since Google Fit on this
      // device writes total, not active. Fall back to active-only if a
      // future source only provides that. Do NOT sum both — total already
      // includes active, summing them would double-count.
      // -----------------------------------------------------------------------

      final resolvedCalories =
      totalCaloriesBurned > 0 ? totalCaloriesBurned : totalActiveCalories;

      // -----------------------------------------------------------------------
      // SLEEP
      // -----------------------------------------------------------------------

      final sleepHours = _calculateSleepHours(
        cleanSleepData,
        midnight,
        now,
      );

      // -----------------------------------------------------------------------
      // RESULT
      // -----------------------------------------------------------------------

      result['steps'] = stepCount;
      result['heartRate'] = latestHR;
      result['spo2'] = latestSpo2;
      result['calories'] =
          double.parse(resolvedCalories.toStringAsFixed(0));
      result['sleepHours'] =
          double.parse(sleepHours.toStringAsFixed(1));
      result['temperature'] = latestTemp;
      result['systolic'] = latestSystolic;
      result['diastolic'] = latestDiastolic;
      result['weight'] = latestWeight;
      result['height'] = latestHeightCm;

      // IMPORTANT:
      // This currently means "at least one data point was returned".
      // We will redesign this later into separate:
      // Health Connect available / permission granted / data available.
      result['connected'] =
          stepCount > 0 ||
              latestHR > 0 ||
              latestSpo2 > 0 ||
              latestTemp > 0 ||
              latestSystolic > 0 ||
              latestDiastolic > 0 ||
              latestWeight > 0 ||
              latestHeightCm > 0 ||
              resolvedCalories > 0 ||
              sleepHours > 0;

      print('');
      print('---------------- FINAL RESULT ----------------');
      print('[HealthConnect] Steps:       ${result['steps']}');
      print('[HealthConnect] HR:          ${result['heartRate']} bpm');
      print('[HealthConnect] SpO2:        ${result['spo2']} %');
      print('[HealthConnect] Calories:    ${result['calories']} kcal');
      print('[HealthConnect] Sleep:       ${result['sleepHours']} hours');
      print('[HealthConnect] Temperature: ${result['temperature']} °C');
      print(
        '[HealthConnect] BP:          '
            '${result['systolic']}/${result['diastolic']} mmHg',
      );
      print('[HealthConnect] Weight:      ${result['weight']}');
      print('[HealthConnect] Height:      ${result['height']} cm');
      print('[HealthConnect] Connected:   ${result['connected']}');
      print('------------------------------------------------');
      print('');

      return result;
    } catch (e, stackTrace) {
      print('[HealthConnect] FETCH ERROR: $e');
      print(stackTrace);
      return result;
    }
  }

  // ---------------------------------------------------------------------------
  // SLEEP CALCULATION
  // ---------------------------------------------------------------------------

  double _calculateSleepHours(
      List<HealthDataPoint> sleepData,
      DateTime midnight,
      DateTime now,
      ) {
    if (sleepData.isEmpty) {
      print('[HealthConnect] No sleep records found.');
      return 0.0;
    }

    final sessions = <_SleepInterval>[];

    for (final point in sleepData) {
      var start = point.dateFrom;
      var end = point.dateTo;

      if (end.isBefore(start)) {
        continue;
      }

      final relevantStart =
      midnight.subtract(const Duration(hours: 12));

      if (end.isBefore(relevantStart) || start.isAfter(now)) {
        continue;
      }

      if (start.isBefore(relevantStart)) {
        start = relevantStart;
      }

      if (end.isAfter(now)) {
        end = now;
      }

      if (!end.isAfter(start)) {
        continue;
      }

      final duration = end.difference(start);

      print(
        '[HealthConnect] Sleep session: '
            '$start → $end '
            '(${duration.inMinutes} min)',
      );

      sessions.add(
        _SleepInterval(
          start: start,
          end: end,
        ),
      );
    }

    if (sessions.isEmpty) {
      print('[HealthConnect] No relevant sleep sessions for today.');
      return 0.0;
    }

    sessions.sort((a, b) => a.start.compareTo(b.start));

    final merged = <_SleepInterval>[];

    for (final session in sessions) {
      if (merged.isEmpty) {
        merged.add(session);
        continue;
      }

      final previous = merged.last;

      if (!session.start.isAfter(previous.end)) {
        if (session.end.isAfter(previous.end)) {
          merged[merged.length - 1] = _SleepInterval(
            start: previous.start,
            end: session.end,
          );
        }
      } else {
        merged.add(session);
      }
    }

    var totalMinutes = 0;

    for (final session in merged) {
      final minutes = session.end.difference(session.start).inMinutes;

      print(
        '[HealthConnect] Merged sleep: '
            '${session.start} → ${session.end} '
            '($minutes min)',
      );

      totalMinutes += minutes;
    }

    final hours = totalMinutes / 60.0;

    print(
      '[HealthConnect] Total sleep: '
          '${hours.toStringAsFixed(2)} hours',
    );

    return hours;
  }

  // ---------------------------------------------------------------------------
  // HEALTH SCORE
  // ---------------------------------------------------------------------------

  int calculateHealthScore(Map<String, dynamic> data) {
    final hr = (data['heartRate'] as double?) ?? 0;
    final spo2 = (data['spo2'] as double?) ?? 0;
    final steps = (data['steps'] as int?) ?? 0;
    final sleep = (data['sleepHours'] as double?) ?? 0;
    final temp = (data['temperature'] as double?) ?? 0;

    int dataPoints = 0;
    if (hr > 0) dataPoints++;
    if (spo2 > 0) dataPoints++;
    if (steps > 0) dataPoints++;
    if (sleep > 0) dataPoints++;
    if (temp > 0) dataPoints++;

    if (dataPoints == 0) return 0;

    int score = 100;

    if (hr > 0) {
      if (hr > 120 || hr < 50) score -= 20;
      else if (hr > 100 || hr < 60) score -= 10;
    }
    if (spo2 > 0) {
      if (spo2 < 90) score -= 30;
      else if (spo2 < 95) score -= 15;
      else if (spo2 < 97) score -= 5;
    }
    if (steps > 0) {
      if (steps < 2000) score -= 15;
      else if (steps < 5000) score -= 8;
      else if (steps < 8000) score -= 3;
    }
    if (sleep > 0) {
      if (sleep < 5) score -= 20;
      else if (sleep < 6) score -= 12;
      else if (sleep < 7) score -= 5;
    }
    if (temp > 0) {
      if (temp > 39 || temp < 32) score -= 25;
      else if (temp > 38.5 || temp < 35) score -= 15;
      else if (temp > 37.5) score -= 5;
    }

    return score.clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // WEEKLY DATA
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchWeeklyData() async {
    final List<Map<String, dynamic>> weekly = [];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      try {
        final data = await _health.getHealthDataFromTypes(
          startTime: start,
          endTime: end,
          types: [HealthDataType.STEPS, HealthDataType.HEART_RATE],
        );

        int steps = 0;
        double hr = 0;
        for (final p in data) {
          final val = _numericValue(p) ?? 0;
          if (p.type == HealthDataType.STEPS) steps += val.toInt();
          if (p.type == HealthDataType.HEART_RATE) hr = val;
        }

        weekly.add({
          'date': '${day.day}/${day.month}',
          'steps': steps,
          'heartRate': hr,
        });
      } catch (e) {
        weekly.add({
          'date': '${day.day}/${day.month}',
          'steps': 0,
          'heartRate': 0.0,
        });
      }
    }

    return weekly;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  double? _numericValue(HealthDataPoint point) {
    final value = point.value;

    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }

    return null;
  }

  bool _isNewer(
      HealthDataPoint candidate,
      HealthDataPoint? current,
      ) {
    if (current == null) {
      return true;
    }

    return candidate.dateFrom.isAfter(current.dateFrom);
  }
}

// -----------------------------------------------------------------------------
// INTERNAL SLEEP MODEL
// -----------------------------------------------------------------------------

class _SleepInterval {
  final DateTime start;
  final DateTime end;

  _SleepInterval({
    required this.start,
    required this.end,
  });
}

final healthService = HealthConnectService();