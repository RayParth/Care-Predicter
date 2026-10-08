import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import '../../shared/services/health_connect.dart';
import '../../shared/services/lab_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? provider;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.provider,
  });
}

final _messagesProvider =
StateProvider<List<ChatMessage>>((ref) => [
  ChatMessage(
    text:
    'Hello! I am your Care AI health assistant. Ask me about your health data, lab results, diet, exercise, sleep, or general health questions.',
    isUser: false,
    provider: 'Care AI',
  ),
]);

final _loadingProvider = StateProvider<bool>((ref) => false);
final _providerProvider = StateProvider<String>((ref) => 'Care AI');

class AiChatTab extends ConsumerStatefulWidget {
  const AiChatTab({super.key});

  @override
  ConsumerState<AiChatTab> createState() => _AiChatTabState();
}

class _AiChatTabState extends ConsumerState<AiChatTab> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  final HealthConnectService _healthConnect =
  HealthConnectService();

  Future<Map<String, dynamic>> _buildHealthContext() async {
    final profile = ref.read(userProfileProvider);

    Map<String, dynamic> healthConnect = {};
    try {
      healthConnect =
      await _healthConnect.fetchTodayData();
    } catch (_) {}

    Map<String, dynamic>? latestLab;
    if (profile.backendUserId > 0) {
      latestLab =
      await LabService.getLatestLabReport(
        profile.backendUserId,
      );
    }

    return {
      'profile': {
        'age': profile.age,
        'gender': profile.gender,
        'weight_kg': profile.weight,
        'height_cm': profile.height,
        'blood_group': profile.bloodGroup,
        'bmi': profile.bmi,
      },
      'health_connect_today': healthConnect,
      'latest_lab_report': latestLab,
    };
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty ||
        ref.read(_loadingProvider)) {
      return;
    }

    _ctrl.clear();

    final current = [
      ...ref.read(_messagesProvider),
      ChatMessage(
        text: text,
        isUser: true,
      ),
    ];

    ref.read(_messagesProvider.notifier).state =
        current;
    ref.read(_loadingProvider.notifier).state = true;

    _scrollDown();

    try {
      final history = current
          .take(current.length - 1)
          .map(
            (message) => AiChatMessage(
          role: message.isUser
              ? 'user'
              : 'assistant',
          content: message.text,
        ),
      )
          .toList();

      final healthContext =
      await _buildHealthContext();

      final response =
      await AiService.sendMessage(
        message: text,
        history: history,
        healthContext: healthContext,
      );

      final updated = [
        ...ref.read(_messagesProvider),
        ChatMessage(
          text: response.text,
          isUser: false,
          provider: response.provider,
        ),
      ];

      ref.read(_messagesProvider.notifier).state =
          updated;

      ref.read(_providerProvider.notifier).state =
          response.provider;
    } catch (error) {
      final updated = [
        ...ref.read(_messagesProvider),
        ChatMessage(
          text:
          'I could not answer that. The online AI service is unavailable and the offline Gemma 4 model is not ready on this device. Install the offline model from the AI menu and try again.',
          isUser: false,
          provider: 'System',
        ),
      ];

      ref.read(_messagesProvider.notifier).state =
          updated;
    } finally {
      ref.read(_loadingProvider.notifier).state =
      false;
      _scrollDown();
    }
  }

  Future<void> _startOfflineInstall() async {
    if (!mounted) return;

    int progress = 0;
    bool finished = false;
    Object? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!finished && error == null && progress == 0) {
              Future.microtask(() async {
                try {
                  await AiService.installGemma4(
                    onProgress: (value) {
                      if (dialogContext.mounted) {
                        setState(() {
                          progress = value;
                        });
                      }
                    },
                  );

                  if (dialogContext.mounted) {
                    setState(() {
                      finished = true;
                    });
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    setState(() {
                      error = e;
                    });
                  }
                }
              });
            }

            return AlertDialog(
              title: const Text('Offline AI'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Text(
                      'Installation failed: $error',
                    )
                  else if (finished)
                    const Text(
                      'Gemma 4 is installed. '
                          'You can now use Care AI without internet.',
                    )
                  else ...[
                      const Text(
                        'Downloading Gemma 4 E2B. '
                            'Keep the app open and use Wi-Fi.',
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: progress == 0
                            ? null
                            : progress / 100,
                      ),
                      const SizedBox(height: 8),
                      Text('$progress%'),
                    ],
                ],
              ),
              actions: [
                if (finished || error != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext),
                    child: const Text('Done'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _scrollDown() {
    Future.delayed(
      const Duration(milliseconds: 100),
          () {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration:
            const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    AiService.closeGemma();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(_messagesProvider);
    final loading = ref.watch(_loadingProvider);
    final provider = ref.watch(_providerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(provider),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                itemCount:
                messages.length +
                    (loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length &&
                      loading) {
                    return _typingIndicator();
                  }

                  return _bubble(messages[index]);
                },
              ),
            ),
            _suggestions(),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header(String provider) {
    final offline =
    provider.contains('Gemma');

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        16,
        16,
        10,
        14,
      ),
      color: AppColors.primary,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
            const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.tealMid,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'AI health assistant',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              Text(
                offline
                    ? 'Offline • Gemma 4 E2B'
                    : 'Online • Gemini',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryMid,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration:
            BoxDecoration(
              color: AppColors.teal
                  .withOpacity(0.2),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Text(
              offline ? 'Offline' : 'Live',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.tealMid,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.white,
            ),
            onSelected: (value) {
              if (value == 'install') {
                _startOfflineInstall();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'install',
                child: Text(
                  'Install offline Gemma 4',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage msg) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: msg.isUser ? 50 : 0,
        right: msg.isUser ? 0 : 50,
      ),
      child: Align(
        alignment: msg.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
          msg.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration:
              BoxDecoration(
                color: msg.isUser
                    ? AppColors.primary
                    : AppColors.white,
                borderRadius:
                BorderRadius.only(
                  topLeft:
                  const Radius.circular(16),
                  topRight:
                  const Radius.circular(16),
                  bottomLeft:
                  Radius.circular(
                    msg.isUser ? 16 : 4,
                  ),
                  bottomRight:
                  Radius.circular(
                    msg.isUser ? 4 : 16,
                  ),
                ),
                border: msg.isUser
                    ? null
                    : Border.all(
                  color:
                  AppColors.border,
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13,
                  color: msg.isUser
                      ? AppColors.white
                      : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            if (!msg.isUser &&
                msg.provider != null)
              Padding(
                padding:
                const EdgeInsets.only(
                  top: 3,
                  left: 4,
                ),
                child: Text(
                  msg.provider!,
                  style: const TextStyle(
                    fontSize: 9,
                    color:
                    AppColors.textHint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 10,
        right: 50,
      ),
      child: Align(
        alignment:
        Alignment.centerLeft,
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration:
          BoxDecoration(
            color: AppColors.white,
            borderRadius:
            const BorderRadius.only(
              topLeft:
              Radius.circular(16),
              topRight:
              Radius.circular(16),
              bottomRight:
              Radius.circular(16),
              bottomLeft:
              Radius.circular(4),
            ),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: const SizedBox(
            width: 30,
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                _Dot(),
                _Dot(),
                _Dot(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestions() {
    const suggestions = [
      'What should I eat?',
      'Explain my health data',
      'Is my cholesterol okay?',
      'Give me sleep tips',
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection:
        Axis.horizontal,
        padding:
        const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        itemCount:
        suggestions.length,
        itemBuilder: (_, index) {
          return GestureDetector(
            onTap: () {
              _ctrl.text =
              suggestions[index];
              _send();
            },
            child: Container(
              margin:
              const EdgeInsets.only(
                right: 8,
              ),
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration:
              BoxDecoration(
                color:
                AppColors.primaryLight,
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
                border: Border.all(
                  color:
                  AppColors.primaryMid,
                ),
              ),
              child: Text(
                suggestions[index],
                style:
                const TextStyle(
                  fontSize: 11,
                  color:
                  AppColors.primaryDark,
                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8,
      ),
      decoration:
      BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled:
              !ref.watch(_loadingProvider),
              onSubmitted:
                  (_) => _send(),
              textInputAction:
              TextInputAction.send,
              style:
              const TextStyle(
                fontSize: 13,
                color:
                AppColors.textPrimary,
              ),
              decoration:
              InputDecoration(
                hintText:
                'Ask about your health...',
                hintStyle:
                const TextStyle(
                  fontSize: 13,
                  color:
                  AppColors.textHint,
                ),
                filled: true,
                fillColor:
                AppColors.background,
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    24,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 42,
              height: 42,
              decoration:
              const BoxDecoration(
                color:
                AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color:
                AppColors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration:
      const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
