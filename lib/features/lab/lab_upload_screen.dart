import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../shared/widgets/bottom_nav_bar.dart';

// Holds the OCR extracted results
final ocrResultsProvider = StateProvider<Map<String, String>>((ref) => {});
final isExtractingProvider = StateProvider<bool>((ref) => false);

class LabUploadScreen extends ConsumerStatefulWidget {
  const LabUploadScreen({super.key});

  @override
  ConsumerState<LabUploadScreen> createState() => _LabUploadScreenState();
}

class _LabUploadScreenState extends ConsumerState<LabUploadScreen> {
  int _currentIndex = 3;
  File? _selectedFile;
  String? _selectedFileName;

  // Simulated OCR results — will be replaced with real Tesseract API later
  final Map<String, String> _mockOcrResults = {
    'Glucose': '94 mg/dL',
    'Hemoglobin': '13.2 g/dL',
    'WBC count': '7,200 /µL',
    'Platelets': '2.4 L/µL',
    'Cholesterol': '178 mg/dL',
    'Triglycerides': '140 mg/dL',
    'Creatinine': '0.9 mg/dL',
    'Uric acid': '5.4 mg/dL',
  };

  final Map<String, String> _referenceRanges = {
    'Glucose': '70–100',
    'Hemoglobin': '12–17',
    'WBC count': '4k–11k',
    'Platelets': '1.5–4',
    'Cholesterol': '< 200',
    'Triglycerides': '< 150',
    'Creatinine': '0.7–1.3',
    'Uric acid': '3.5–7',
  };

  final Map<String, String> _statuses = {
    'Glucose': 'Normal',
    'Hemoglobin': 'Normal',
    'WBC count': 'Normal',
    'Platelets': 'Normal',
    'Cholesterol': 'Normal',
    'Triglycerides': 'Borderline',
    'Creatinine': 'Normal',
    'Uric acid': 'Normal',
  };

  Future<void> _simulateOcrExtraction() async {
    ref.read(isExtractingProvider.notifier).state = true;
    ref.read(ocrResultsProvider.notifier).state = {};

    // Simulate OCR processing delay
    await Future.delayed(const Duration(seconds: 2));

    ref.read(ocrResultsProvider.notifier).state = _mockOcrResults;
    ref.read(isExtractingProvider.notifier).state = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR extraction complete — 8 values found'),
          backgroundColor: Color(0xFF1D9E75),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onFilePicked(String fileName) {
    setState(() {
      _selectedFileName = fileName;
    });
    _simulateOcrExtraction();
  }

  @override
  Widget build(BuildContext context) {
    final ocrResults = ref.watch(ocrResultsProvider);
    final isExtracting = ref.watch(isExtractingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildUploadCard(),
                  const SizedBox(height: 12),
                  if (isExtracting) _buildExtractingIndicator(),
                  if (ocrResults.isNotEmpty) _buildOcrResults(ocrResults),
                  if (ocrResults.isNotEmpty) _buildAiRecommendation(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      color: AppColors.primary,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.primaryMid,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lab report upload',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              Text(
                'Tesseract OCR extracts values automatically',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryMid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedFileName != null
                ? AppColors.primary
                : AppColors.border,
            width: _selectedFileName != null ? 2 : 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            // Upload icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFileName ?? 'Upload PDF or photo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _selectedFileName != null
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tesseract OCR will extract all lab values',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _onFilePicked('lab_report_photo.jpg'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text(
                      'Take photo',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onFilePicked('lab_report.pdf'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text(
                      'Browse PDF',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryMid),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extracting values...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  'Tesseract OCR is reading your report',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrResults(Map<String, String> results) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CBC — Dhara Patel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Krupa Diagnostic Centre · 14 Mar 2026',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'OCR extracted',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Result rows
            ...results.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final key = entry.value.key;
              final value = entry.value.value;
              final isLast = index == results.length - 1;
              final status = _statuses[key] ?? 'Normal';
              final ref = _referenceRanges[key] ?? '';
              final isNormal = status == 'Normal';

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                    bottom: BorderSide(
                        color: AppColors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          key,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Ref: $ref',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isNormal
                                ? AppColors.successLight
                                : AppColors.warningLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: isNormal
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            // Save button
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lab report saved to health record'),
                        backgroundColor: Color(0xFF1D9E75),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Save to health record',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiRecommendation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryMid),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'AI recommendation for Dhara',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Triglycerides are slightly elevated at 140 mg/dL. Reduce sugary drinks and refined carbohydrates. Increase omega-3 rich foods like fish and walnuts. Next HbA1c test suggested in 3 months.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}