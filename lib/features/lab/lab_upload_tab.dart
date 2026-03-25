import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
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
              if (error != null) _errorCard(error),
              if (results.isNotEmpty)
                _resultsCard(context, ref, results, saved),
              if (results.isNotEmpty) _aiTip(results),
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
          Text(
              'Upload PDF, JPG, JPEG or PNG — OCR extracts values',
              style: TextStyle(
                  fontSize: 12, color: AppColors.primaryMid)),
        ],
      ),
    );
  }

  Widget _uploadCard(BuildContext context, WidgetRef ref,
      String? fileName) {
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
              fileName ?? 'Upload PDF or photo',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fileName != null
                      ? AppColors.primary
                      : AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
                'Supports PDF, JPG, JPEG, PNG files',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: AppButton(
                  label: 'Take photo',
                  icon: Icons.camera_alt_rounded,
                  onTap: () =>
                      _pickCamera(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Browse file',
                  icon: Icons.folder_open_rounded,
                  isOutlined: true,
                  onTap: () =>
                      _pickFile(context, ref),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCamera(
      BuildContext context, WidgetRef ref) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ref.read(_errorProvider.notifier).state =
      'Camera permission denied. Please allow camera access in phone settings.';
      return;
    }

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null) {
        ref.read(_fileNameProvider.notifier).state = photo.name;
        await _uploadAndExtract(
            context, ref, File(photo.path), photo.name);
      }
    } catch (e) {
      ref.read(_errorProvider.notifier).state =
      'Camera error: $e';
      print('Camera error: $e');
    }
  }

  Future<void> _pickFile(
      BuildContext context, WidgetRef ref) async {
    // Request storage permission first
    final status = await Permission.storage.request();
    final photosStatus = await Permission.photos.request();

    print('Storage permission: $status');
    print('Photos permission: $photosStatus');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final name = result.files.single.name;
        ref.read(_fileNameProvider.notifier).state = name;
        await _uploadAndExtract(context, ref, file, name);
      }
    } catch (e) {
      ref.read(_errorProvider.notifier).state =
      'File picker error: $e';
      print('File picker error: $e');
    }
  }

  Future<void> _uploadAndExtract(BuildContext context,
      WidgetRef ref, File file, String name) async {
    ref.read(_extractingProvider.notifier).state = true;
    ref.read(_ocrResultsProvider.notifier).state = {};
    ref.read(_errorProvider.notifier).state = null;
    ref.read(_savedProvider.notifier).state = false;
    ref.read(_rawTextProvider.notifier).state = '';

    try {
      // Build multipart form
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: name,
        ),
      });

      // Call real FastAPI OCR endpoint
      final dio = Dio(BaseOptions(
        baseUrl: 'http://10.0.2.2:8000',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.post(
        '/ocr/upload',
        data: formData,
        options: Options(
            contentType: 'multipart/form-data'),
      );

      final data = response.data as Map<String, dynamic>;

// Try both keys — backend returns both
      final labValues = (data['lab_values'] as Map<String, dynamic>?)
          ?? (data['extracted_values'] as Map<String, dynamic>?)
          ?? {};

      final rawText = (data['raw_text_preview'] as String?) ?? '';

      print('OCR status: ${data['status']}');
      print('Values found: ${data['values_found']}');
      print('Raw text preview: $rawText');

      if (labValues.isEmpty) {
        ref.read(_errorProvider.notifier).state =
        'No lab values found in the uploaded file. Make sure the image is clear and contains lab report data.';
      } else {
        ref.read(_ocrResultsProvider.notifier).state =
            labValues;
        ref.read(_rawTextProvider.notifier).state =
            rawText;
      }
    } catch (e) {
      ref.read(_errorProvider.notifier).state =
      'Upload failed: Make sure the backend is running on port 8000. Error: $e';
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
                strokeWidth: 2.5,
                color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Extracting values...',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark)),
              Text('OCR is reading your lab report',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _errorCard(String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppCard(
        color: AppColors.dangerLight,
        borderColor: const Color(0xFFF09595),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(error,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA32D2D),
                      height: 1.5)),
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
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text('OCR extracted results',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(
                          '${entries.length} values found',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textHint)),
                    ],
                  ),
                  const StatusBadge(
                      label: 'Extracted',
                      type: BadgeType.normal),
                ],
              ),
            ),
            ...entries.asMap().entries.map((e) {
              final isLast = e.key == entries.length - 1;
              final key = e.value.key;
              final val = e.value.value;
              final displayVal = val is double
                  ? val.toStringAsFixed(1)
                  : val.toString();

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                      bottom: BorderSide(
                          color: AppColors.border,
                          width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      key[0].toUpperCase() +
                          key.substring(1).replaceAll('_', ' '),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary),
                    ),
                    Text(displayVal,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(12),
              child: saved
                  ? const StatusBadge(
                  label: '✓ Saved to health record',
                  type: BadgeType.normal)
                  : AppButton(
                label: 'Save to health record',
                onTap: () =>
                    _save(context, ref, results),
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
        'lab_name': 'Uploaded Report',
        'report_date': DateTime.now().toIso8601String(),
        ...results,
      },
    );
    ref.read(_savedProvider.notifier).state = true;
    if (ref.context.mounted) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        const SnackBar(
          content: Text('Lab report saved to health record'),
          backgroundColor: AppColors.teal,
        ),
      );
    }
  }

  Widget _aiTip(Map<String, dynamic> results) {
    final tips = <String>[];
    final glucose =
    results['glucose'] as double?;
    final triglycerides =
    results['triglycerides'] as double?;
    final cholesterol =
    results['cholesterol'] as double?;
    final hemoglobin =
    results['hemoglobin'] as double?;
    final creatinine =
    results['creatinine'] as double?;

    if (glucose != null && glucose > 100) {
      tips.add('Glucose elevated — reduce refined sugar and refined carbs.');
    }
    if (triglycerides != null && triglycerides > 130) {
      tips.add('Triglycerides borderline — reduce fried food and increase omega-3 foods.');
    }
    if (cholesterol != null && cholesterol > 190) {
      tips.add('Cholesterol is elevated — add more fibre and reduce saturated fats.');
    }
    if (hemoglobin != null && hemoglobin < 12) {
      tips.add('Hemoglobin low — increase iron-rich foods like spinach, lentils, and eggs.');
    }
    if (creatinine != null && creatinine > 1.2) {
      tips.add('Creatinine slightly high — drink more water and reduce protein excess.');
    }
    if (tips.isEmpty) {
      tips.add('All extracted values are within normal range. Keep up your healthy habits!');
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
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary)),
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
}