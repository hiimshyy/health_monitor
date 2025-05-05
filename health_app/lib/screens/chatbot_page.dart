import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/chatbot_drawer.dart';

class ChatbotScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>)? onChatHistoryUpdated;

  const ChatbotScreen({
    super.key,
    this.onChatHistoryUpdated,
  });

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _chatHistory = [];
  String _currentChatId = '';
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _startNewChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getString('chatHistory');
    if (history != null) {
      setState(() {
        _chatHistory = List<Map<String, dynamic>>.from(jsonDecode(history));
      });
      if (widget.onChatHistoryUpdated != null) {
        widget.onChatHistoryUpdated!(_chatHistory);
      }
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chatHistory', jsonEncode(_chatHistory));
    if (widget.onChatHistoryUpdated != null) {
      widget.onChatHistoryUpdated!(_chatHistory);
    }
  }

  void _startNewChat() {
    setState(() {
      _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _messages.add(const ChatMessage(
        text:
            'Xin chào! Tôi là trợ lý sức khỏe của bạn. Tôi có thể giúp gì cho bạn?',
        isUser: false,
      ));
    });
  }

  void _loadChat(Map<String, dynamic> chat) {
    setState(() {
      _currentChatId =
          chat['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      final List<dynamic> messages = jsonDecode(chat['messages'] ?? '[]');
      for (var msg in messages) {
        _messages.add(ChatMessage(
          text: msg['text'] ?? '',
          isUser: msg['isUser'] ?? false,
        ));
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
      ));
      _isTyping = true;
    });

    // Simulate bot response
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final botResponse = _getBotResponse(text);
    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(
        text: botResponse,
        isUser: false,
      ));
    });

    // Update chat history
    final chatData = {
      'id': _currentChatId,
      'title': text.length > 30 ? '${text.substring(0, 30)}...' : text,
      'lastMessage': text,
      'time': DateTime.now().toString(),
      'messages': jsonEncode(_messages
          .map((msg) => {
                'text': msg.text,
                'isUser': msg.isUser,
              })
          .toList()),
    };

    final existingIndex =
        _chatHistory.indexWhere((chat) => chat['id'] == _currentChatId);
    if (existingIndex != -1) {
      _chatHistory[existingIndex] = chatData;
    } else {
      _chatHistory.insert(0, chatData);
    }

    await _saveChatHistory();
  }

  String _getBotResponse(String userMessage) {
    // Simple response logic - can be enhanced with more sophisticated AI
    final lowerMessage = userMessage.toLowerCase();
    if (lowerMessage.contains('xin chào') || lowerMessage.contains('hello')) {
      return 'Xin chào! Tôi có thể giúp gì cho bạn?';
    } else if (lowerMessage.contains('sức khỏe') ||
        lowerMessage.contains('health')) {
      return 'Tôi có thể giúp bạn theo dõi và tư vấn về sức khỏe. Bạn muốn biết thông tin gì?';
    } else if (lowerMessage.contains('huyết áp') ||
        lowerMessage.contains('blood pressure')) {
      return 'Huyết áp bình thường là 120/80 mmHg. Bạn có thể theo dõi chỉ số huyết áp của mình trong ứng dụng.';
    } else if (lowerMessage.contains('nhịp tim') ||
        lowerMessage.contains('heart rate')) {
      return 'Nhịp tim bình thường ở người lớn là 60-100 nhịp/phút. Bạn có thể theo dõi nhịp tim của mình trong ứng dụng.';
    } else if (lowerMessage.contains('nhiệt độ') ||
        lowerMessage.contains('temperature')) {
      return 'Nhiệt độ cơ thể bình thường là 37°C. Bạn có thể theo dõi nhiệt độ của mình trong ứng dụng.';
    } else if (lowerMessage.contains('spo2') ||
        lowerMessage.contains('oxygen')) {
      return 'Chỉ số SpO2 bình thường là 95-100%. Bạn có thể theo dõi chỉ số SpO2 của mình trong ứng dụng.';
    } else {
      return 'Tôi hiểu câu hỏi của bạn. Bạn có thể cho tôi biết thêm chi tiết không?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                return _messages[index];
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(58),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Nhập tin nhắn...',
                border: InputBorder.none,
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Colors.blue[800],
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                _handleSubmitted(_messageController.text);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.medical_services, color: Colors.white),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                _buildDot(1),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.blue[800]!.withOpacity(0.5 + (index * 0.2)),
          ),
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.blue[800],
                child: const Icon(Icons.medical_services, color: Colors.white),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.person, color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }
}
