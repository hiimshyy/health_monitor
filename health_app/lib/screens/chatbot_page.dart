import 'package:flutter/material.dart';
import 'dart:convert'; // Thêm thư viện này để xử lý JSON
import 'package:http/http.dart' as http; // Thêm thư viện này để thực hiện HTTP requests
import 'package:flutter_markdown/flutter_markdown.dart'; // Import thư viện markdown

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

Future<void> _saveChatHistory(String userMessage, String botReply) async {
  try {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/history_chat'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'user': userMessage,
        'assistant': botReply,
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('Lịch sử cuộc trò chuyện đã được lưu.');
    } else {
      debugPrint('Lỗi khi lưu lịch sử: ${response.body}');
    }
  } catch (e) {
    debugPrint('Lỗi khi gửi yêu cầu lưu lịch sử: $e');
  }
}

Future<void> _handleSubmitted(String text) async {
  _messageController.clear();

  // Hiển thị tin nhắn người dùng
  setState(() {
    _messages.add(ChatMessage(text: text, isUser: true));
    _messages.add(ChatMessage(text: '', isUser: false)); // Dành chỗ cho tin nhắn bot
  });

  final index = _messages.length - 1; // Vị trí của bot message
  String buffer = '';

  // Tạo lịch sử hội thoại
  final List<Map<String, String>> history = _messages
      .map((message) => {
            "role": message.isUser ? "user" : "assistant",
            "content": message.text,
          })
      .toList();

  try {
    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:3000/api/chat/completions'),
    )
      ..headers.addAll({
        'Authorization': 'Bearer sk-7462a3aa19e941d7ae7881b923542ff7',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        "stream": true,
        "model": "sthealthy",
        "messages": history, // Gửi lịch sử hội thoại
      });

    final response = await request.send();

    if (response.statusCode == 200) {
  final stream = response.stream.transform(utf8.decoder);

  await for (final chunk in stream) {
    for (final line in const LineSplitter().convert(chunk)) {
      if (line.trim().isEmpty) continue; // Bỏ qua dòng trống
      if (line.trim() == 'data: [DONE]') break; // Bỏ qua dòng kết thúc

      // Loại bỏ tiền tố "data: " nếu có
      final cleaned = line.replaceFirst(RegExp(r'^data:\s*'), '');

      try {
        // Parse JSON từ dòng đã được làm sạch
        final jsonData = json.decode(cleaned) as Map<String, dynamic>;
        final delta = jsonData['choices']?[0]?['delta']?['content'];

        if (delta != null && delta.isNotEmpty) {
          // Cập nhật buffer với từng phần dữ liệu nhận được
          buffer += delta;

          // Cập nhật giao diện ngay lập tức
          setState(() {
            _messages[index] = ChatMessage(
              text: buffer,
              isUser: false,
            );
          });
        }
      } catch (e) {
        debugPrint('Error parsing stream chunk: $e');
      }
    }
  }

  // Lưu lịch sử trò chuyện sau khi nhận phản hồi đầy đủ
  await _saveChatHistory(text, buffer);
} else {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi: Không thể kết nối đến API.',
          isUser: false,
        );
      });
    }
  } catch (e) {
    setState(() {
      _messages[index] = ChatMessage(
        text: 'Lỗi: $e',
        isUser: false,
      );
    });
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
              itemCount: _messages.length,
              itemBuilder: (context, index) {
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
            child: MarkdownBody(
              data: text, // Hiển thị nội dung markdown
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: isUser ? Colors.white : Colors.black,
                ),
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