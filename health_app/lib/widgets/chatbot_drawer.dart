import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:health_app/screens/chatbot_page.dart'; // Thêm dòng này

class ChatbotDrawer extends StatefulWidget {
  final String fullName;

  const ChatbotDrawer({
    super.key,
    required this.fullName,
  });

  @override
  _ChatbotDrawerState createState() => _ChatbotDrawerState();
}

class _ChatbotDrawerState extends State<ChatbotDrawer> {
  List<int> chatHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5000/id_conversation'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          chatHistory = data.cast<int>();
          isLoading = false;
        });
      } else {
        debugPrint('Lỗi khi lấy lịch sử trò chuyện: ${response.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi khi gửi yêu cầu lấy lịch sử: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              color: Colors.blue[800],
              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Lịch sử chat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                      children: [
                        // "Cuộc trò chuyện mới" ở đầu danh sách
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: const Icon(
                              Icons.add,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Cuộc trò chuyện mới',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            // Xử lý khi chọn "Cuộc trò chuyện mới"
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChatbotScreen(
                                  initialMessages: [], // Truyền danh sách trống để bắt đầu cuộc trò chuyện mới
                                ),
                              ),
                            );
                            debugPrint('Bắt đầu cuộc trò chuyện mới');
                          },
                        ),
                        // Danh sách lịch sử trò chuyện
                        Expanded(
                          child: chatHistory.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 50,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Chưa có lịch sử chat',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: chatHistory.length,
                                  itemBuilder: (context, index) {
                                    final id = chatHistory[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue[100],
                                        child: const Icon(
                                          Icons.chat,
                                          color:
                                              Color.fromARGB(255, 21, 101, 192),
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        'Cuộc trò chuyện $id',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                     onTap: () async {
  try {
    // Gửi yêu cầu GET để lấy nội dung đoạn chat
    final response = await http.get(
      Uri.parse('http://127.0.0.1:5000/history_chat?conversation_id=$id'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> chatData = json.decode(response.body);

      // Chuyển sang màn hình ChatbotScreen và truyền dữ liệu
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            extendBodyBehindAppBar: true, // Đảm bảo không mất extendBodyBehindAppBar
            appBar: AppBar(
              backgroundColor: Colors.blue[800],
              elevation: 0,
              title: const Text(
                'Lịch sử Chatbot',
                style: TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
            body: ChatbotScreen(
              initialMessages: chatData.map((item) {
                return ChatMessage(
                  text: item['content'],
                  isUser: item['role'] == 'user',
                );
              }).toList(),
            ),
          ),
        ),
      );
    } else {
      debugPrint('Lỗi khi lấy nội dung đoạn chat: ${response.body}');
    }
  } catch (e) {
    debugPrint('Lỗi khi gửi yêu cầu lấy nội dung đoạn chat: $e');
  }
},
                                      //   onTap: () {
                                      //   // Xử lý khi chọn một cuộc trò chuyện
                                      //   Navigator.pop(context);
                                      //   debugPrint('Mở cuộc trò chuyện $id');
                                      // },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
