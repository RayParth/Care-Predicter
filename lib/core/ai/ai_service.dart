import 'package:flutter_gemma/flutter_gemma.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

class AiChatMessage {
  final String role;
  final String content;

  const AiChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
  };
}

class AiResponse {
  final String text;
  final String provider;
  final String? model;
  final bool offline;

  const AiResponse({
    required this.text,
    required this.provider,
    this.model,
    required this.offline,
  });
}

/// AI service:
///
/// ONLINE:
/// Flutter -> FastAPI -> Gemini API
///
/// OFFLINE / Gemini unavailable:
/// Flutter -> Gemma 4 E2B locally
class AiService {
  AiService._();

  static dynamic _gemmaModel;
  static dynamic _gemmaChat;
  static bool _gemmaReady = false;

  static const String gemmaModelUrl =
      'https://huggingface.co/litert-community/'
      'gemma-4-E2B-it-litert-lm/resolve/main/'
      'gemma-4-E2B-it.litertlm';

  // ---------------------------------------------------------------------------
  // MAIN AI METHOD
  // ---------------------------------------------------------------------------

  static Future<AiResponse> sendMessage({
    required String message,
    required List<AiChatMessage> history,
    required Map<String, dynamic> healthContext,
  }) async {
    // Try online Gemini first.
    try {
      return await _sendToCloud(
        message: message,
        history: history,
        healthContext: healthContext,
      );
    } catch (_) {
      // Gemini/backend unavailable.
      // Fall back to local Gemma.
    }

    // Try offline Gemma.
    return _sendToGemma(
      message: message,
      history: history,
      healthContext: healthContext,
    );
  }

  // ---------------------------------------------------------------------------
  // GEMINI THROUGH FASTAPI
  // ---------------------------------------------------------------------------

  static Future<AiResponse> _sendToCloud({
    required String message,
    required List<AiChatMessage> history,
    required Map<String, dynamic> healthContext,
  }) async {
    final response = await ApiClient.post(
      ApiEndpoints.aiChat,
      data: {
        'message': message,
        'history': history
            .where(
              (m) =>
          m.role == 'user' ||
              m.role == 'assistant',
        )
            .take(20)
            .map((m) => m.toJson())
            .toList(),
        'health_context': healthContext,
      },
    );

    final data = Map<String, dynamic>.from(
      response.data as Map,
    );

    if (data['ok'] != true ||
        data['response'] == null) {
      throw Exception(
        'Gemini returned an invalid response',
      );
    }

    return AiResponse(
      text: data['response'].toString(),
      provider:
      data['provider']?.toString() ?? 'Gemini',
      model: data['model']?.toString(),
      offline: false,
    );
  }

  // ---------------------------------------------------------------------------
  // LOCAL GEMMA 4
  // ---------------------------------------------------------------------------

  static Future<AiResponse> _sendToGemma({
    required String message,
    required List<AiChatMessage> history,
    required Map<String, dynamic> healthContext,
  }) async {
    await _ensureGemmaReady();

    final prompt = StringBuffer()
      ..writeln('USER HEALTH CONTEXT:')
      ..writeln(healthContext)
      ..writeln()
      ..writeln(
        'Use this context only for personalized claims.',
      )
      ..writeln();

    for (final item in history.take(12)) {
      prompt.writeln(
        '${item.role.toUpperCase()}: ${item.content}',
      );
    }

    prompt
      ..writeln('USER: $message')
      ..writeln('ASSISTANT:');

    await _gemmaChat.addQueryChunk(
      Message.text(
        text: prompt.toString(),
        isUser: true,
      ),
    );

    final result =
    await _gemmaChat.generateChatResponse();

    final text = result is TextResponse
        ? result.token
        : result.toString();

    return AiResponse(
      text: text.trim(),
      provider: 'Gemma 4 E2B',
      model: 'gemma-4-E2B-it',
      offline: true,
    );
  }

  // ---------------------------------------------------------------------------
  // INITIALIZE GEMMA
  // ---------------------------------------------------------------------------

  static Future<void> _ensureGemmaReady() async {
    if (_gemmaReady &&
        _gemmaModel != null &&
        _gemmaChat != null) {
      return;
    }

    await FlutterGemma.initialize();

    try {
      _gemmaModel =
      await FlutterGemma.getActiveModel(
        maxTokens: 4096,
        preferredBackend: PreferredBackend.cpu,
      );
    } catch (_) {
      throw Exception(
        'Gemma 4 is not installed on this device. '
            'Install the offline model first.',
      );
    }

    _gemmaChat =
    await _gemmaModel.createChat(
      systemInstruction: '''
You are Care AI running OFFLINE on an Android phone using Gemma 4 E2B.

You are a health-information assistant, not a doctor.

Rules:
- Never invent measurements.
- Only use supplied health context for personalized claims.
- Never diagnose disease.
- Never recommend changing prescription medicines.
- If important information is missing, say it is missing.
- For potentially dangerous symptoms, advise urgent medical evaluation.
- Keep answers concise and understandable.
- You have no internet access in this mode.
''',
      maxOutputTokens: 700,
    );

    _gemmaReady = true;
  }

  // ---------------------------------------------------------------------------
  // INSTALL GEMMA 4
  // ---------------------------------------------------------------------------

  static Future<void> installGemma4({
    void Function(int progress)? onProgress,
  }) async {
    await FlutterGemma.initialize();

    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    )
        .fromNetwork(gemmaModelUrl)
        .withProgress((progress) {
      onProgress?.call(progress);
    })
        .install();

    await closeGemma();
  }

  // ---------------------------------------------------------------------------
  // CLOSE GEMMA
  // ---------------------------------------------------------------------------

  static Future<void> closeGemma() async {
    try {
      if (_gemmaChat != null) {
        await _gemmaChat.close();
      }
    } catch (_) {}

    try {
      if (_gemmaModel != null) {
        await _gemmaModel.close();
      }
    } catch (_) {}

    _gemmaChat = null;
    _gemmaModel = null;
    _gemmaReady = false;
  }
}