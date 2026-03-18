
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../shared/widgets/bottom_nav_bar.dart';

// Message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

// Chat messages provider
final chatMessagesProvider =
StateProvider<List<ChatMessage>>((ref) => [
  ChatMessage(
    text: 'Hello Dhara! I am your AI health assistant. I can answer questions about your vitals, lab results, diet, and lifestyle. What would you like to know?',
    isUser: false,
    time: DateTime.now(),
  ),
]);

// Loading state provider
final chatLoadingProvider = StateProvider<bool>((ref) => false);

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  int _currentIndex = 2;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Predefined AI responses based on keywords
  // Will be replaced with real FastAPI + ML backend later
  String _getAiResponse(String userMessage) {
    final msg = userMessage.toLowerCase();

    if (msg.contains('sugar') || msg.contains('glucose')) {
      return 'Your glucose is 94 mg/dL — within normal range (70–100). To keep it stable: eat whole grains, legumes, and vegetables. Avoid refined sugar, white rice, and sweet drinks. Space meals every 3–4 hours and never skip breakfast.';
    } else if (msg.contains('heart') || msg.contains('bp') || msg.contains('blood pressure')) {
      return 'Your heart rate is 76 bpm and blood pressure is 118/76 mmHg — both normal. Your resting HR of 62 bpm shows good cardiovascular fitness. Keep up 30 minutes of brisk walking daily and reduce sodium intake.';
    } else if (msg.contains('sleep')) {
      return 'You are getting 7.2 hours of sleep — good. For better quality: avoid screens 1 hour before bed, keep a consistent sleep schedule, and reduce caffeine after 2 PM. Your stress index is slightly elevated at 42% which may be affecting deep sleep.';
    } else if (msg.contains('cholesterol')) {
      return 'Your total cholesterol is 178 mg/dL — normal. However, triglycerides are at 140 mg/dL which is borderline. Reduce fried food and sugary drinks. Increase omega-3 rich foods like fish, walnuts, and flaxseeds.';
    } else if (msg.contains('exercise') || msg.contains('workout')) {
      return 'With 6,420 steps today and a resting HR of 62 bpm, your fitness baseline is good. Aim for 30 minutes of brisk walking or light cardio daily. Avoid intense exercise if SpO₂ drops below 95%. Strength training 2–3 times per week is recommended.';
    } else if (msg.contains('diet') || msg.contains('eat') || msg.contains('food')) {
      return 'Based on your health data, I recommend: whole grains (brown rice, oats), lean proteins (fish, lentils, eggs), plenty of vegetables and fruits, and 2–3 litres of water daily. Avoid processed food, excess salt, and sugary drinks. Your triglycerides suggest reducing refined carbs.';
    } else if (msg.contains('spo2') || msg.contains('oxygen')) {
      return 'Your SpO₂ is 98% — excellent. Normal range is 95–100%. If it drops below 92%, seek immediate medical attention. To maintain good oxygen levels: do deep breathing exercises daily, stay active, and avoid smoking.';
    } else if (msg.contains('kidney') || msg.contains('creatinine')) {
      return 'Your creatinine is 0.9 mg/dL and eGFR is 92 mL/min — both excellent. Kidney function is normal. Drink at least 2–3 litres of water daily, reduce salt intake, and avoid excessive use of painkillers like ibuprofen.';
    } else if (msg.contains('stress') || msg.contains('anxiety')) {
      return 'Your stress index is at 42% — slightly elevated. Try 10 minutes of deep breathing or meditation daily. Regular exercise, good sleep, and reducing caffeine can significantly lower stress. Consider a short walk outdoors every evening.';
    } else if (msg.contains('weight') || msg.contains('bmi')) {
      return 'Your BMI is 22.4 — healthy range (18.5–24.9). Maintain this with balanced diet and regular activity. Avoid crash diets. Focus on sustainable habits: 3 balanced meals, light snacks, and 30 minutes of activity daily.';
    } else {
      return 'Based on your current health data — glucose 94, HR 76 bpm, SpO₂ 98%, cholesterol 178 — your overall health is good with a score of 82. Is there a specific health topic you would like to know more about? I can help with diet, exercise, sleep, or any specific lab value.';
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    // Add user message
    final messages = [...ref.read(chatMessagesProvider)];
    messages.add(ChatMessage(
      text: text,
      isUser: true,
      time: DateTime.now(),
    ));
    ref.read(chatMessagesProvider.notifier).state = messages;

    // Show loading
    ref.read(chatLoadingProvider.notifier).state = true;

    // Scroll to bottom
    _scrollToBottom();

    // Simulate AI response delay
    await Future.delayed(const Duration(milliseconds: 1200));

    // Add AI response
    final updatedMessages = [...ref.read(chatMessagesProvider)];
    updatedMessages.add(ChatMessage(
      text: _getAiResponse(text),
      isUser: false,
      time: DateTime.now(),
    ));
    ref.read(chatMessagesProvider.notifier).state = updatedMessages;
    ref.read(chatLoadingProvider.notifier).state = false;

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isLoading = ref.watch(chatLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(messages[index]);
              },
            ),
          ),
          _buildSuggestedQuestions(),
          _buildInputBar(),
          BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 0) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI health assistant',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              Text(
                'Personalised for Dhara Patel',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryMid,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Live',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.tealMid,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 10,
        left: isUser ? 50 : 0,
        right: isUser ? 0 : 50,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser
                ? null
                : Border.all(color: AppColors.border, width: 1),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 13,
              color: isUser ? AppColors.white : AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
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
            children: [
              _buildDot(0),
              const SizedBox(width: 4),
              _buildDot(1),
              const SizedBox(width: 4),
              _buildDot(2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestedQuestions() {
    final suggestions = [
      'What should I eat?',
      'Is my cholesterol ok?',
      'How is my sleep?',
      'Exercise tips',
    ];

    return Container(
      height: 36,
      color: AppColors.background,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _controller.text = suggestions[index];
              _sendMessage();
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
              child: Text(
                suggestions[index],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask about your health...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: AppColors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}