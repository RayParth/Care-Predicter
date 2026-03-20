import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/services/api_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_badge.dart';

final _ocrResultsProvider =
StateProvider<Map<String, String>>((ref) => {});
final _extractingProvider = StateProvider<bool>((ref) => false);
final _savedProvider = StateProvider<bool>((ref) => false);

class LabUploadTab extends ConsumerStatefulWidget {
  const LabUploadTab({super.key});

  @override
  ConsumerState<LabUploadTab> createState() =>
      _LabUploadTabState();
}

class _LabUploadTabState extends ConsumerState<LabUploadTab> {
  String? _fileName;

  final _mockResults = const {
    'Glucose': '94 mg/dL',
    'Hemoglobin': '13.2 g/dL',
    'WBC count': '7,200 /µL',
    'Platelets': '2.4 L/µL',
    'Cholesterol': '178 mg/dL',
    'Triglycerides': '140 mg/dL',
    'Creatinine': '0.9 mg/dL',
    'Uric acid': '5.4 mg/dL',
  };

  final _refs = const {
    'Glucose': '70–100',
    'Hemoglobin': '12–17',
    'WBC count': '4k–11k',
    'Platelets': '1.5–4',
    'Cholesterol': '< 200',
    'Triglycerides': '< 150',
    'Creatinine': '0.7–1.3',
    'Uric acid': '3.5–7',
  };

  final _statuses = const {
    'Glucose': 'Normal',
    'Hemoglobin': 'Normal',
    'WBC count': 'Normal',
    'Platelets': 'Normal',
    'Cholesterol': 'Normal',
    'Triglycerides': 'Borderline',
    'Creatinine': 'Normal',
    'Uric acid': 'Normal',
  };

  Future<void> _extract(String name) async {
    setState(() => _fileName = name);
    ref.read(_extractingProvider.notifier).state = true;
    ref.read(_ocrResultsProvider.notifier).state = {};
    ref.read(_savedProvider.notifier).state = false;

    await Future.delayed(const Duration(seconds: 2));

    ref.read(_ocrResultsProvider.notifier).state = _mockResults;
    ref.read(_extractingProvider.notifier).state = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('OCR extraction complete — 8 values found'),
          backgroundColor: AppColors.teal,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _save() async {
    final userId = ref.read(backendUserIdProvider) ?? 1;
    await apiService.saveLabReport(
      userId: userId,
      values: {
        'lab_name': 'Uploaded Report',
        'report_date': DateTime.now().toIso8601String(),
        'glucose': 94.0,
        'hemoglobin': 13.2,
        'cholesterol': 178.0,
        'triglycerides': 140.0,
        'creatinine': 0.9,
      },
    );
    ref.read(_savedProvider.notifier).state = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lab report saved to health record'),
          backgroundColor: AppColors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_ocrResultsProvider);
    final extracting = ref.watch(_extractingProvider);
    final saved = ref.watch(_savedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 12),
              _uploadCard(),
              const SizedBox(height: 12),
              if (extracting) _extractingCard(),
              if (results.isNotEmpty)
                _resultsCard(results, saved),
              if (results.isNotEmpty) _aiTip(),
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
          Text('Tesseract OCR extracts values automatically',
              style: TextStyle(
                  fontSize: 12, color: AppColors.primaryMid)),
        ],
      ),
    );
  }

  Widget _uploadCard() {
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
              _fileName ?? 'Upload PDF or photo',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _fileName != null
                      ? AppColors.primary
                      : AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
                'Tesseract OCR will extract all lab values',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: AppButton(
                  label: 'Take photo',
                  onTap: () => _extract('lab_photo.jpg'),
                  icon: Icons.camera_alt_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Browse PDF',
                  onTap: () => _extract('lab_report.pdf'),
                  icon: Icons.picture_as_pdf_rounded,
                  isOutlined: true,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
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
              Text('Extracting values...',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark)),
              Text('Tesseract OCR is reading your report',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _resultsCard(
      Map<String, String> results, bool saved) {
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
                  const Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text('CBC Report',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(
                          'Krupa Diagnostic · 14 Mar 2026',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textHint)),
                    ],
                  ),
                  const StatusBadge(
                      label: 'OCR extracted',
                      type: BadgeType.normal),
                ],
              ),
            ),
            ...results.entries.toList().asMap().entries.map((e) {
              final idx = e.key;
              final key = e.value.key;
              final val = e.value.value;
              final isLast = idx == results.length - 1;
              final status = _statuses[key] ?? 'Normal';
              final ref = _refs[key] ?? '';
              final isBorderline = status != 'Normal';

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
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(key,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary)),
                        Text('Ref: $ref',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint)),
                      ],
                    ),
                    Row(children: [
                      Text(val,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: status,
                        type: isBorderline
                            ? BadgeType.warning
                            : BadgeType.normal,
                      ),
                    ]),
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
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiTip() {
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
            const Text(
                'Triglycerides slightly elevated at 140 mg/dL. Reduce sugary drinks and refined carbs. Increase omega-3 rich foods. Next HbA1c test suggested in 3 months.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    height: 1.6)),
          ],
        ),
      ),
    );
  }
}
