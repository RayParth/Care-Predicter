import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/services/api_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';

final _ocrResultsProvider =
StateProvider<Map<String, dynamic>>((ref) => {});
final _extractingProvider = StateProvider<bool>((ref) => false);
final _savedProvider = StateProvider<bool>((ref) => false);
final _errorProvider = StateProvider<String?>((ref) => null);
final _fileNameProvider = StateProvider<String?>((ref) => null);
final _rawTextProvider = StateProvider<String>((ref) => '');

class LabUploadTab extends ConsumerWidget {
  const LabUploadTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(_ocrResultsProvider);
    final extracting = ref.watch(_extractingProvider);
    final saved = ref.watch(_savedProvider);
    final error = ref.watch(_errorProvider);
    final fileName = ref.watch(_fileNameProvider);
    final rawText = ref.watch(_rawTextProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 12),
              _uploadCard(context, ref, fileName),
              const SizedBox(height: 12),
              if (extracting) _extractingCard(),
              if (error != null) _errorCard(context, ref, error),
              if (results.isNotEmpty) _resultsCard(context, ref, results, saved),
              if (results.isNotEmpty) _aiTip(results),
              // Show raw text preview for debugging during development
              if (rawText.isNotEmpty && results.isEmpty) _rawTextDebug(rawText),
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
          Text('Lab report upload',
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

  Widget _uploadCard(
      BuildContext context, WidgetRef ref, String? fileName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        child: Column(
          children: [
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
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
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
          ],
        ),
      ),
    );
  }

  Future<void> _pickCamera(BuildContext context, WidgetRef ref) async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ref.read(_errorProvider.notifier).state =
      'Camera permission denied. Go to phone Settings → Apps → Care Predicter → Permissions → Allow camera.';
      return;
    }

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
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
      if (picked.path == null) {
        ref.read(_errorProvider.notifier).state =
        'Could not access file path. Try again.';
        return;
      }

      ref.read(_fileNameProvider.notifier).state = picked.name;
      await _upload(context, ref, File(picked.path!), picked.name);
    } catch (e) {
      ref.read(_errorProvider.notifier).state = 'File picker error: $e';
    }
  }

  Future<void> _upload(
      BuildContext context, WidgetRef ref, File file, String name) async {
    ref.read(_extractingProvider.notifier).state = true;
    ref.read(_ocrResultsProvider.notifier).state = {};
    ref.read(_errorProvider.notifier).state = null;
    ref.read(_savedProvider.notifier).state = false;
    ref.read(_rawTextProvider.notifier).state = '';

    try {
      const backendUrl = 'http://10.117.123.108:8000';
      final userId = ref.read(backendUserIdProvider) ?? 1;

      final dio = Dio(BaseOptions(
        baseUrl: backendUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ));

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: name),
        'user_id': userId.toString(),
      });

      final response = await dio.post(
        '/ocr/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': 'application/json'},
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String?;
      final extracted =
          (data['extracted_values'] as Map<String, dynamic>?) ?? {};
      final rawText = (data['raw_text'] as String?) ?? '';

      ref.read(_rawTextProvider.notifier).state = rawText;

      if (extracted.isNotEmpty) {
        ref.read(_ocrResultsProvider.notifier).state = extracted;
        // Mark as already saved since backend saves during OCR
        ref.read(_savedProvider.notifier).state = true;
      } else if (status == 'no_text') {
        ref.read(_errorProvider.notifier).state =
        'OCR found no text. Use a well-lit, clear photo.';
      } else {
        ref.read(_errorProvider.notifier).state =
        'OCR ran but found no lab values.\n\nRaw text: "${rawText.substring(0, rawText.length.clamp(0, 150))}"';
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        ref.read(_errorProvider.notifier).state =
        'Cannot reach backend at 172.16.56.108:8000\n\nCheck:\n1. Backend running\n2. Same WiFi\n3. Firewall allows port 8000';
      } else {
        ref.read(_errorProvider.notifier).state =
        'Upload error: ${e.message}';
      }
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
        child: Row(children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Uploading and extracting...',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark)),
              Text('Tesseract OCR is reading your report',
                  style:
                  TextStyle(fontSize: 11, color: AppColors.primary)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _errorCard(
      BuildContext context, WidgetRef ref, String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppCard(
        color: AppColors.dangerLight,
        borderColor: const Color(0xFFF09595),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
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
                    fontSize: 12,
                    color: Color(0xFFA32D2D),
                    height: 1.5)),
            const SizedBox(height: 10),
            // Retry button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(_errorProvider.notifier).state = null;
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
          ],
        ),
      ),
    );
  }

  Widget _resultsCard(BuildContext context, WidgetRef ref,
      Map<String, dynamic> results, bool saved) {
    final entries = results.entries.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('OCR extracted values',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text('${entries.length} values found',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint)),
                  ]),
                  const StatusBadge(
                      label: 'Extracted', type: BadgeType.normal),
                ],
              ),
            ),
            // Result rows
            ...entries.asMap().entries.map((e) {
              final isLast = e.key == entries.length - 1;
              final key = e.value.key;
              final val = e.value.value;
              final displayKey = key[0].toUpperCase() +
                  key.substring(1).replaceAll('_', ' ');
              final displayVal =
              val is double ? val.toStringAsFixed(1) : val.toString();

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                      bottom: BorderSide(
                          color: AppColors.border, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayKey,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    Text(displayVal,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              );
            }),
            // Save button
            Padding(
              padding: const EdgeInsets.all(12),
              child: saved
                  ? const StatusBadge(
                  label: '✓ Saved to health record',
                  type: BadgeType.normal)
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _save(context, ref, results),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save to health record',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref,
      Map<String, dynamic> results) async {
    final userId = ref.read(backendUserIdProvider) ?? 1;
    await apiService.saveLabReport(
      userId: userId,
      values: {
        'lab_name': ref.read(_fileNameProvider) ?? 'Uploaded Report',
        'report_date': DateTime.now().toIso8601String(),
        ...results,
      },
    );
    ref.read(_savedProvider.notifier).state = true;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lab report saved to health record'),
            backgroundColor: AppColors.teal),
      );
    }
  }

  Widget _aiTip(Map<String, dynamic> results) {
    final tips = <String>[];

    final glucose = results['glucose'] as double?;
    final triglycerides = results['triglycerides'] as double?;
    final cholesterol = results['cholesterol'] as double?;
    final hemoglobin = results['hemoglobin'] as double?;
    final creatinine = results['creatinine'] as double?;
    final sgpt = results['sgpt'] as double?;

    if (glucose != null && glucose > 100) {
      tips.add('Glucose elevated at ${glucose.toStringAsFixed(0)} mg/dL — reduce refined sugar and carbs.');
    }
    if (triglycerides != null && triglycerides > 130) {
      tips.add('Triglycerides borderline — reduce fried food, increase omega-3.');
    }
    if (cholesterol != null && cholesterol > 190) {
      tips.add('Cholesterol elevated — add fibre, reduce saturated fats.');
    }
    if (hemoglobin != null && hemoglobin < 12) {
      tips.add('Hemoglobin low — eat iron-rich foods: spinach, lentils, eggs.');
    }
    if (creatinine != null && creatinine > 1.2) {
      tips.add('Creatinine slightly high — drink more water, reduce protein excess.');
    }
    if (sgpt != null && sgpt > 40) {
      tips.add('SGPT elevated — avoid alcohol and fatty food. Consider liver check.');
    }
    if (tips.isEmpty) {
      tips.add('All extracted values look within normal range. Keep up your healthy habits!');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: AppCard(
        color: AppColors.primaryLight,
        borderColor: AppColors.primaryMid,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 16),
              SizedBox(width: 6),
              Text('AI recommendation',
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
                            height: 1.5)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // Shows raw OCR text when no values extracted — helps debug bad images
  Widget _rawTextDebug(String rawText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: AppCard(
        color: AppColors.warningLight,
        borderColor: const Color(0xFFFAC775),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OCR raw text (debug)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning)),
            const SizedBox(height: 6),
            Text(
              rawText.length > 300
                  ? '${rawText.substring(0, 300)}...'
                  : rawText,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 6),
            const Text(
              'If you see text above but no values extracted, the lab report format may not match our patterns. Share the raw text with the developer.',
              style: TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}