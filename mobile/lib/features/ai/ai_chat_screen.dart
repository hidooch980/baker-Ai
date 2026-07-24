import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

/// دستیار هوشمند نانوایی: پرسش و پاسخ فارسی بر اساس داده‌های واقعی سیستم.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  String? _conversationId;
  bool _isSending = false;

  Future<void> _send() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isSending) return;
    setState(() {
      _messages.add({'role': 'USER', 'content': question});
      _isSending = true;
    });
    _questionController.clear();
    _scrollToEnd();
    try {
      final response = await ApiClient.instance.dio.post('/ai/ask', data: {
        'question': question,
        if (_conversationId != null) 'conversationId': _conversationId,
      });
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _conversationId = data['conversationId'] as String?;
        _messages.add({'role': 'ASSISTANT', 'content': (data['answer'] ?? '') as String});
        _isSending = false;
      });
      _scrollToEnd();
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ASSISTANT', 'content': apiErrorMessage(e)});
        _isSending = false;
      });
    }
  }

  void _scrollToEnd() {
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

  void _newChat() {
    setState(() {
      _conversationId = null;
      _messages.clear();
    });
  }

  Future<void> _showHistory() async {
    try {
      final response = await ApiClient.instance.dio.get('/ai/conversations');
      if (!mounted) return;
      final conversations = (response.data as List).cast<Map<String, dynamic>>();
      final selectedId = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => ListView(
          padding: const EdgeInsets.all(12),
          children: conversations.isEmpty
              ? const [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('گفتگویی وجود ندارد.')))]
              : conversations
                  .map((c) => ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(c['title'] as String? ?? 'بدون عنوان'),
                        subtitle: Text((c['createdAt'] as String? ?? '').split('T').first),
                        onTap: () => Navigator.pop(context, c['id'] as String),
                      ))
                  .toList(),
        ),
      );
      if (selectedId == null) return;
      final conversationResponse = await ApiClient.instance.dio.get('/ai/conversations/$selectedId');
      if (!mounted) return;
      final conversation = conversationResponse.data as Map<String, dynamic>;
      final messages = (conversation['messages'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _conversationId = selectedId;
        _messages
          ..clear()
          ..addAll(messages.map((m) => {'role': (m['role'] ?? '') as String, 'content': (m['content'] ?? '') as String}));
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دستیار هوشمند نانوایی'),
        actions: [
          IconButton(tooltip: 'تاریخچه گفتگوها', icon: const Icon(Icons.history), onPressed: _showHistory),
          IconButton(tooltip: 'گفتگوی جدید', icon: const Icon(Icons.add_comment_outlined), onPressed: _newChat),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'درباره فروش امروز، بدهی مشتریان، موجودی آرد و سوخت یا هزینه‌ها سوال بپرسید.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'USER';
                      return Align(
                        alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(message['content'] ?? ''),
                        ),
                      );
                    },
                  ),
          ),
          if (_isSending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      decoration: const InputDecoration(hintText: 'سوال خود را بنویسید...', border: OutlineInputBorder()),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(icon: const Icon(Icons.send), onPressed: _isSending ? null : _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
