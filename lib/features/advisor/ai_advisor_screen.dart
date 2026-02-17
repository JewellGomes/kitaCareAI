import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/models.dart';

// ============================================================
// AI ADVISOR SCREEN
// Role-aware chatbot powered by Google Gemini.
// [BACKEND]: For production, proxy all Gemini calls through
// your own backend to hide API keys and enable audit logging.
// ============================================================

class AiAdvisorScreen extends StatefulWidget {
  final UserRole role;

  const AiAdvisorScreen({super.key, required this.role});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // ── Role-dependent prompt config ───────────────────────────

  String get _initialMessage => widget.role == UserRole.ngo
      ? 'Selamat Sejahtera! I am KitaCare NGO Support AI. I can assist you with managing '
        'physical item needs, verifying drop-off receipts, or checking disbursement logs. '
        'How can I help your mission today?'
      : 'Selamat Sejahtera! I am KitaCare AI. I can help you find verified NGOs, manage '
        'your donation wallet, or find the nearest drop-off point for physical items. '
        'What would you like to know?';

  String get _systemPrompt => widget.role == UserRole.ngo
      ? 'You are KitaCare NGO AI. Help Malaysian NGOs with logistics, verifying Donation IDs, '
        'and listing physical needs. Use a professional and operational tone. '
        "Use terms like 'ROS registration', 'Drop-off point', 'Inventory', and 'Disbursement'."
      : 'You are KitaCare AI for Donors. Help Malaysians with charitable transparency, '
        "wallet security, and item matching. Use a warm and empathetic tone. "
        "Use terms like 'Sadaqah', 'Infaq', 'MyKad', and 'Impact Tracking'.";

  Color get _accent => widget.role == UserRole.ngo ? AppColors.blue600 : AppColors.emerald600;

  String get _hintText => widget.role == UserRole.ngo
      ? 'Ask about receipt verification or logistics...'
      : 'Ask about donation points or tax certificates...';

  // ── Lifecycle ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(role: 'ai', content: _initialMessage));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Gemini API call ────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // [BACKEND]: API INTERVENTION
      // Replace this direct Gemini call with a POST to your own backend:
      //   POST /api/ai/chat  { "message": text, "role": role.name }
      // Your backend forwards the request to Gemini with the system prompt.
      final aiReply = await _callGemini(userMessage: text);
      setState(() {
        _messages.add(ChatMessage(role: 'ai', content: aiReply));
      });
    } catch (e) {
      setState(() {
        _messages.add(const ChatMessage(
          role: 'ai',
          content: 'Error connecting to AI. Please check your internet connection.',
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  /// Calls the Gemini REST API directly.
  /// Replace with your backend proxy in production.
  Future<String> _callGemini({required String userMessage}) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiModel:generateContent'
      '?key=$kGeminiApiKey',
    );

    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': _systemPrompt}],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': userMessage}],
        },
      ],
      'generationConfig': {'maxOutputTokens': 512},
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List;
    if (candidates.isEmpty) return "I couldn't find an answer. Please try again.";

    final parts = (candidates.first['content']['parts'] as List);
    return parts.first['text'] as String? ?? "I couldn't find an answer.";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        height: MediaQuery.of(context).size.height - 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.slate100),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.slate50.withValues(alpha: 0.5),
        border: const Border(bottom: BorderSide(color: AppColors.slate100)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KitaCare ${widget.role.name.toUpperCase()} AI',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800)),
              const Text('EXPERT ADVISOR',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald600,
                      letterSpacing: 1.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _TypingIndicator();
        }
        return _MessageBubble(message: _messages[index], accent: _accent);
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.slate100)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: _hintText,
                hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                filled: true,
                fillColor: AppColors.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _accent, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.slate200 : _accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Color accent;

  const _MessageBubble({required this.message, required this.accent});

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isUser ? accent : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(_isUser ? 16 : 4),
                bottomRight: Radius.circular(_isUser ? 4 : 16),
              ),
              border: _isUser ? null : Border.all(color: AppColors.slate100),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
            ),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 13,
                color: _isUser ? Colors.white : AppColors.slate700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ───────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          FadeTransition(
            opacity: _animation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.slate100),
              ),
              child: const Text('Consulting KitaCare Knowledge...',
                  style: TextStyle(fontSize: 12, color: AppColors.slate400)),
            ),
          ),
        ],
      ),
    );
  }
}