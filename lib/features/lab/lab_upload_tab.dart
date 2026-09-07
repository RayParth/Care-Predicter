import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/lab_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';

final _ocrResultsProvider  = StateProvider<Map<String, dynamic>>((ref) => {});
final _extractingProvider  = StateProvider<bool>((ref) => false);
final _savedProvider       = StateProvider<bool>((ref) => false);
final _errorProvider       = StateProvider<String?>((ref) => null);
final _fileNameProvider    = StateProvider<String?>((ref) => null);
final _rawTextProvider     = StateProvider<String>((ref) => '');
final _showUploadProvider  = StateProvider<bool>((ref) => false);

final labHistoryProvider =
FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final userId = ref.watch(userProfileProvider).backendUserId;
  if (userId == 0) return [];
  return await LabService.getLabReports(userId);
});

class LabUploadTab extends ConsumerWidget {
  const LabUploadTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results      = ref.watch(_ocrResultsProvider);
    final extracting   = ref.watch(_extractingProvider);
    final saved        = ref.watch(_savedProvider);
    final error        = ref.watch(_errorProvider);
    final fileName     = ref.watch(_fileNameProvider);
    final rawText      = ref.watch(_rawTextProvider);
    final showUpload   = ref.watch(_showUploadProvider);
    final historyAsync = ref.watch(labHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 12),
              historyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                ),
                error: (_, __) => _noReportsCard(context, ref),
                data: (history) {
                  if (history.isEmpty && !showUpload) {
                    return _noReportsCard(context, ref);
                  }
                  if (history.isNotEmpty && !showUpload) {
                    return Column(children: [
                      _historySection(context, ref, history),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: AppButton(
                          label: 'Upload new report',
                          icon: Icons.upload_file_rounded,
                          isOutlined: true,
                          onTap: () => ref
                              .read(_showUploadProvider.notifier)
                              .state = true,
                        ),
                      ),
                    ]);
                  }
                  return const SizedBox.shrink();
                },
              ),
              if (showUpload ||
                  ref.watch(labHistoryProvider).value?.isEmpty == true) ...[
                const SizedBox(height: 4),
                _uploadCard(context, ref, fileName),
                const SizedBox(height: 12),
                if (extracting) _extractingCard(),
                if (error != null) _errorCard(ref, error),
                if (results.isNotEmpty) _resultsCard(context, ref, results, saved),
                if (results.isNotEmpty) _aiTip(results),
                if (rawText.isNotEmpty && results.isEmpty) _rawTextDebug(rawText),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      color: AppColors.primary,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lab reports',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white)),
          SizedBox(height: 4),
          Text('Upload PDF, JPG, JPEG or PNG — OCR extracts values',
              style: TextStyle(fontSize: 12, color: AppColors.primaryMid)),
        ],
      ),
    );
  }

  Widget _noReportsCard(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        child: Column(children: [
          const Icon(Icons.science_outlined, color: AppColors.textHint, size: 48),
          const SizedBox(height: 12),
          const Text('No lab reports yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
              'Upload your first lab report — OCR will extract all values automatically',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppButton(
            label: 'Upload lab report',
            icon: Icons.upload_file_rounded,
            onTap: () =>
            ref.read(_showUploadProvider.notifier).state = true,
          ),
        ]),
      ),
    );
  }

  Widget _historySection(
      BuildContext context, WidgetRef ref, List<dynamic> history) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
                '${history.length} report${history.length == 1 ? '' : 's'} found',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const StatusBadge(label: 'From database', type: BadgeType.info),
          ]),
          const SizedBox(height: 8),
          ...history.asMap().entries.map((e) {
            final report = e.value as Map<String, dynamic>;
            return _reportCard(report, e.key == 0);
          }),
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report, bool isLatest) {
    final labName = report['lab_name'] ?? 'Lab report';
    final uploadedAt = report['uploaded_at'] ?? '';
    String dateStr = '';
    if (uploadedAt is String && uploadedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(uploadedAt);
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    final values = _extractTestMap(report);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        color: isLatest ? AppColors.primaryLight : AppColors.white,
        borderColor: isLatest ? AppColors.primaryMid : AppColors.border,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isLatest
                  ? AppColors.primary.withOpacity(0.08)
                  : AppColors.surface,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labName.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      if (dateStr.isNotEmpty)
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Row(children: [
                  if (isLatest)
                    const StatusBadge(label: 'Latest', type: BadgeType.normal),
                  const SizedBox(width: 6),
                  StatusBadge(
                      label: '${values.length} values', type: BadgeType.info),
                ]),
              ],
            ),
          ),
          ...values.entries.take(5).toList().asMap().entries.map((e) {
            final isLast = e.key == values.entries.take(5).length - 1 &&
                values.length <= 5;
            final test = e.value.value;
            return _testValueRow(
              e.value.key,
              test,
              isLast: isLast,
            );
          }),
          if (values.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Text('+ ${values.length - 5} more values',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
            )
          else
            const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Map<String, dynamic> _extractTestMap(Map<String, dynamic> report) {
    final extracted = report['extracted_data'];
    if (extracted is Map) {
      final tests = extracted['tests'];
      if (tests is Map) {
        return Map<String, dynamic>.from(tests);
      }
    }

    // Compatibility with reports created before dynamic extraction.
    final legacyKeys = [
      'hemoglobin', 'rbc', 'wbc', 'platelets', 'glucose',
      'cholesterol', 'triglycerides', 'creatinine', 'uric_acid',
      'bilirubin', 'sgpt', 'sgot', 'hba1c', 'tsh', 'vitamin_d',
      'vitamin_b12', 'sodium', 'potassium', 'calcium', 'ldl', 'hdl',
      'mcv', 'mch', 'pcv'
    ];

    final values = <String, dynamic>{};
    for (final key in legacyKeys) {
      final value = report[key];
      if (value != null && value != 0) {
        values[key] = {
          'display_name': _prettyLabel(key),
          'value': value,
          'unit': null,
          'reference_range': null,
          'qualitative_result': null,
          'flag': null,
        };
      }
    }
    return values;
  }

  String _prettyLabel(String key) {
    if (key.isEmpty) return key;
    return key
        .split('_')
        .map((part) => part.isEmpty
        ? part
        : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'Not reported';
    if (value is num) {
      return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    }
    return value.toString();
  }

  String _testDisplayValue(String key, dynamic rawTest) {
    if (rawTest is Map) {
      final qualitative = rawTest['qualitative_result'];
      final value = rawTest['value'];
      final unit = rawTest['unit'];
      final valuePart = qualitative != null && qualitative.toString().isNotEmpty
          ? qualitative.toString()
          : _formatValue(value);
      final unitPart = unit != null && unit.toString().isNotEmpty
          ? ' ${unit.toString()}'
          : '';
      return '$valuePart$unitPart';
    }
    return _formatValue(rawTest);
  }

  Widget _testValueRow(String key, dynamic rawTest, {bool isLast = false}) {
    final label = rawTest is Map && rawTest['display_name'] != null
        ? rawTest['display_name'].toString()
        : _prettyLabel(key);
    final value = _testDisplayValue(key, rawTest);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _uploadCard(BuildContext context, WidgetRef ref, String? fileName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.upload_file_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            fileName ?? 'Upload your lab report',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fileName != null
                    ? AppColors.primary
                    : AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Text('Supports PDF, JPG, JPEG, PNG',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickCamera(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Take photo',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickFile(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Browse file',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _pickCamera(BuildContext context, WidgetRef ref) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ref.read(_errorProvider.notifier).state = 'Camera permission denied.';
      return;
    }
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null) return;
      ref.read(_fileNameProvider.notifier).state = photo.name;
      await _upload(context, ref, File(photo.path), photo.name);
    } catch (e) {
      ref.read(_errorProvider.notifier).state = 'Camera error: $e';
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.path == null) return;
      ref.read(_fileNameProvider.notifier).state = picked.name;
      await _upload(context, ref, File(picked.path!), picked.name);
    } catch (e) {
      ref.read(_errorProvider.notifier).state = 'File picker error: $e';
    }
  }

  // ── THIS IS THE FIXED _upload METHOD ─────────────────────────────────────
  // Removed the duplicate old Dio code. Uses only LabService now.
  Future<void> _upload(
      BuildContext context, WidgetRef ref, File file, String name) async {
    ref.read(_extractingProvider.notifier).state = true;
    ref.read(_ocrResultsProvider.notifier).state = {};
    ref.read(_errorProvider.notifier).state = null;
    ref.read(_savedProvider.notifier).state = false;
    ref.read(_rawTextProvider.notifier).state = '';

    try {
      final userId = ref.read(userProfileProvider).backendUserId;

      final data = await LabService.uploadLabReport(
        file: file,
        fileName: name,
        userId: userId,
      );

      final dynamicData = data['extracted_data'];
      final extracted = dynamicData is Map
          ? Map<String, dynamic>.from(dynamicData)
          : <String, dynamic>{};
      final rawText = (data['raw_text'] as String?) ?? '';

      ref.read(_rawTextProvider.notifier).state = rawText;

      final tests = extracted['tests'];
      if (tests is Map && tests.isNotEmpty) {
        ref.read(_ocrResultsProvider.notifier).state = extracted;
        ref.read(_savedProvider.notifier).state = true;
        ref.invalidate(labHistoryProvider);
      } else {
        // Backward-compatible fallback if an older backend response is used.
        final legacy = data['extracted_values'];
        if (legacy is Map && legacy.isNotEmpty) {
          ref.read(_ocrResultsProvider.notifier).state = {
            'patient': {},
            'report': {},
            'tests': {
              for (final entry in legacy.entries)
                entry.key.toString(): {
                  'display_name': _prettyLabel(entry.key.toString()),
                  'value': entry.value,
                  'unit': null,
                  'reference_range': null,
                  'qualitative_result': null,
                  'flag': null,
                }
            },
            'interpretation': [],
            'other_information': {},
          };
          ref.read(_savedProvider.notifier).state = true;
          ref.invalidate(labHistoryProvider);
        } else {
          final preview = rawText.substring(0, rawText.length.clamp(0, 150));
          ref.read(_errorProvider.notifier).state =
          'No laboratory values were extracted.\n\nRaw: "$preview"';
        }
      }
    } on DioException catch (e) {
      ref.read(_errorProvider.notifier).state =
      e.type == DioExceptionType.connectionError
          ? 'Cannot reach backend. Check WiFi and AppConfig.baseUrl.'
          : 'Upload error: ${e.message}';
    } catch (e) {
      ref.read(_errorProvider.notifier).state = 'Error: $e';
    }

    ref.read(_extractingProvider.notifier).state = false;
  }

  Widget _extractingCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppCard(
        color: AppColors.primaryLight,
        borderColor: AppColors.primaryMid,
        child: const Row(children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary),
          ),
          SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Uploading and extracting...',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark)),
            Text('Tesseract OCR is reading your report',
                style: TextStyle(fontSize: 11, color: AppColors.primary)),
          ]),
        ]),
      ),
    );
  }

  Widget _errorCard(WidgetRef ref, String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppCard(
        color: AppColors.dangerLight,
        borderColor: const Color(0xFFF09595),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.error_rounded, color: AppColors.danger, size: 18),
            SizedBox(width: 8),
            Text('Upload failed',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA32D2D))),
          ]),
          const SizedBox(height: 6),
          Text(error,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFA32D2D), height: 1.5)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ref.read(_errorProvider.notifier).state    = null;
                ref.read(_fileNameProvider.notifier).state = null;
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Try again'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _resultsCard(BuildContext context, WidgetRef ref,
      Map<String, dynamic> results, bool saved) {
    final rawTests = results['tests'];
    final tests = rawTests is Map
        ? Map<String, dynamic>.from(rawTests)
        : <String, dynamic>{};
    final entries = tests.entries.toList();
    final interpretation = results['interpretation'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Extracted laboratory data',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Text('${entries.length} values found',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                ]),
                const StatusBadge(label: 'Extracted', type: BadgeType.normal),
              ],
            ),
          ),
          ...entries.asMap().entries.map((e) {
            final isLast = e.key == entries.length - 1 &&
                (interpretation is! List || interpretation.isEmpty);
            return _testValueRow(
              e.value.key,
              e.value.value,
              isLast: isLast,
            );
          }),
          if (interpretation is List && interpretation.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: const Text('Report interpretation',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            ...interpretation.map((item) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primary)),
                  Expanded(
                    child: Text(item.toString(),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4)),
                  ),
                ],
              ),
            )),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: saved
                ? const StatusBadge(
                label: '✓ Saved to health record', type: BadgeType.normal)
                : AppButton(
              label: 'Save to health record',
              onTap: () => _save(context, ref, results),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref,
      Map<String, dynamic> results) async {
    // Already saved automatically by uploadLabReport in LabService.
    // Just update the UI state.
    ref.read(_savedProvider.notifier).state = true;
    ref.invalidate(labHistoryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lab report saved to health record'),
            backgroundColor: AppColors.teal),
      );
    }
  }

  Widget _aiTip(Map<String, dynamic> results) {
    final testsRaw = results['tests'];
    final tests = testsRaw is Map
        ? Map<String, dynamic>.from(testsRaw)
        : <String, dynamic>{};
    final tips = <String>[];

    num? numericValue(String key) {
      final test = tests[key];
      if (test is Map) {
        final value = test['value'];
        return value is num ? value : num.tryParse(value?.toString() ?? '');
      }
      return test is num ? test : null;
    }

    void check(String key, String tip, bool Function(num) cond) {
      final value = numericValue(key);
      if (value != null && cond(value)) tips.add(tip);
    }

    // These are intentionally limited to the app's existing simple rules.
    // Do not pretend that arbitrary lab values can be safely interpreted here.
    check('glucose', 'Glucose is above the app\'s configured review threshold.',
            (v) => v > 100);
    check('triglycerides',
        'Triglycerides are above the app\'s configured review threshold.',
            (v) => v > 130);
    check('cholesterol',
        'Cholesterol is above the app\'s configured review threshold.',
            (v) => v > 190);
    check('hemoglobin',
        'Hemoglobin is below the app\'s configured review threshold.',
            (v) => v < 12);
    check('creatinine',
        'Creatinine is above the app\'s configured review threshold.',
            (v) => v > 1.2);
    check('sgpt', 'SGPT is above the app\'s configured review threshold.',
            (v) => v > 40);

    if (tips.isEmpty) {
      tips.add(
          'Values were extracted from the report. Use the laboratory reference ranges and a clinician for medical interpretation.');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: AppCard(
        color: AppColors.primaryLight,
        borderColor: AppColors.primaryMid,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 16),
            SizedBox(width: 6),
            Text('Report note',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark)),
          ]),
          const SizedBox(height: 8),
          ...tips.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primary)),
                  Expanded(
                      child: Text(t,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              height: 1.5))),
                ]),
          )),
        ]),
      ),
    );
  }

  Widget _rawTextDebug(String rawText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: AppCard(
        color: AppColors.warningLight,
        borderColor: const Color(0xFFFAC775),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OCR raw text (debug)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning)),
          const SizedBox(height: 6),
          Text(
            rawText.length > 300 ? '${rawText.substring(0, 300)}...' : rawText,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'monospace'),
          ),
        ]),
      ),
    );
  }
}