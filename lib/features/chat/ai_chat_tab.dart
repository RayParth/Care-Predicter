import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

final _messagesProvider =
StateProvider<List<ChatMessage>>((ref) => [
  ChatMessage(
    text:
    'Hello! I am your AI health assistant. Ask me anything about your vitals, diet, or lab results.',
    isUser: false,
  ),
]);

final _loadingProvider = StateProvider<bool>((ref) => false);

class AiChatTab extends ConsumerStatefulWidget {
  const AiChatTab({super.key});

  @override
  ConsumerState<AiChatTab> createState() =>
      _AiChatTabState();
}

class _AiChatTabState extends ConsumerState<AiChatTab> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  String _respond(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('glucose') || m.contains('sugar')) {
      return 'Your glucose is 94 mg/dL — normal (70–100). Eat whole grains, avoid refined sugar, and space meals every 3–4 hours.';
    } else if (m.contains('heart') || m.contains('bp')) {
      return 'Your heart rate is 76 bpm and BP 118/76 mmHg — both normal. Keep up 30 minutes of brisk walking daily.';
    } else if (m.contains('sleep')) {
      return 'You are getting 7.2 hours — good. Avoid screens 1 hour before bed and keep a consistent sleep schedule.';
    } else if (m.contains('cholesterol')) {
      return 'Total cholesterol 178 mg/dL is fine. Triglycerides at 140 mg/dL are borderline — reduce fried food, add omega-3 foods.';
    } else if (m.contains('exercise') || m.contains('workout')) {
      return 'Aim for 30 minutes of brisk walking or light cardio daily. Strength training 2–3 times per week is recommended.';
    } else if (m.contains('diet') || m.contains('eat')) {
      return 'Eat whole grains, lean proteins, vegetables, and 2–3 litres of water daily. Avoid processed food and sugary drinks.';
    } else if (m.contains('spo2') || m.contains('oxygen')) {
      return 'Your SpO₂ is 98% — excellent. If it drops below 92% seek immediate medical attention.';
    } else if (m.contains('kidney') || m.contains('creatinine')) {
      return 'Creatinine 0.9 mg/dL — excellent. Drink 2–3 litres of water daily and avoid excessive painkillers.';
    } else {
      return 'Your overall health score is 82 — good condition. Ask me about diet, exercise, sleep, or any specific lab value.';
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    final msgs = [...ref.read(_messagesProvider)];
    msgs.add(ChatMessage(text: text, isUser: true));
    ref.read(_messagesProvider.notifier).state = msgs;
    ref.read(_loadingProvider.notifier).state = true;

    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 1200));

    final updated = [...ref.read(_messagesProvider)];
    updated.add(ChatMessage(text: _respond(text), isUser: false));
    ref.read(_messagesProvider.notifier).state = updated;
    ref.read(_loadingProvider.notifier).state = false;
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(_messagesProvider);
    final loading = ref.watch(_loadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                itemCount: msgs.length + (loading ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == msgs.length && loading) {
                    return _typingIndicator();
                  }
                  return _bubble(msgs[i]);
                },
              ),
            ),
            _suggestions(),
            _inputBar(),
            const SizedBox(height: 0),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: AppColors.primary,
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded,
              color: AppColors.tealMid, size: 18),
        ),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI health assistant',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white)),
              Text('Personalised for your health data',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.primaryMid)),
            ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20)),
          child: const Text('Live',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.tealMid,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _bubble(ChatMessage msg) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: 10,
          left: msg.isUser ? 50 : 0,
          right: msg.isUser ? 0 : 50),
      child: Align(
        alignment: msg.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isUser
                ? AppColors.primary
                : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
              Radius.circular(msg.isUser ? 16 : 4),
              bottomRight:
              Radius.circular(msg.isUser ? 4 : 16),
            ),
            border: msg.isUser
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: Text(msg.text,
              style: TextStyle(
                  fontSize: 13,
                  color: msg.isUser
                      ? AppColors.white
                      : AppColors.textPrimary,
                  height: 1.5)),
        ),
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 50),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [0, 1, 2].map((i) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 2),
                child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _suggestions() {
    final list = [
      'What should I eat?',
      'Is my cholesterol ok?',
      'Sleep tips',
      'Exercise advice',
    ];
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: list.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            _ctrl.text = list[i];
            _send();
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryMid),
            ),
            child: Text(list[i],
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
            top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            onSubmitted: (_) => _send(),
            textInputAction: TextInputAction.send,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ask about your health...',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded,
                color: AppColors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}
