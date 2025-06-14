import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatbotScreen extends StatefulWidget {
  final int userId;
  final Function(List<Map<String, dynamic>>)? onChatHistoryUpdated;

  const ChatbotScreen({super.key, this.onChatHistoryUpdated, required this.userId});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _chatHistory = [];
  bool _isTyping = false;
  String? _currentAttachmentPath;
  String? _currentAttachmentType;

  // Thêm static instance để có thể gọi từ bên ngoài
  static ChatbotScreenState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this;
    _loadChatHistory();
    
    // Test fall event sau khi load chat history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Delay một chút để đảm bảo UI đã được build xong
      Future.delayed(const Duration(seconds: 1), () {
        handleFallEvent();
      });
    });
  }

  @override
  void dispose() {
    _instance = null;
    _messageController.dispose();
    super.dispose();
  }
// Thêm vào class ChatbotScreenState

// Hàm xử lý sự kiện vital signs - chỉ hiện phản hồi từ bot
Future<void> handleVitalSignsEvent(double temp, int heartRate, int spo2, int sys, int dia) async {
  final vitalMessage = "temp: $temp heartRate: $heartRate spo2: $spo2 sys: $sys dia: $dia";
  print('Handling vital signs event: $vitalMessage');
  setState(() {
    // Chỉ thêm placeholder cho bot reply, không thêm tin nhắn user
    _messages.add(ChatMessage(text: '', isUser: false)); // Placeholder
    _isTyping = true;
  });

  final index = _messages.length - 1;

  try {
    debugPrint('Sending vital signs to API...');
    debugPrint('Request body: ${jsonEncode({
      "stream": false,
      "model": "veronai",
      "messages": [
        {
          "role": "user",
          "content": vitalMessage
        }
      ],
    })}');

    final response = await http.post(
      Uri.parse('http://127.0.0.1:5050/api/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'HealthApp/1.0',
      },
      body: jsonEncode({
        "stream": false,
        "model": "veronai",
        "messages": [
          {
            "role": "user",
            "content": vitalMessage
          }
        ],
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Request timeout after 30 seconds');
      },
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final content = jsonData['choices']?[0]?['message']?['content'] ?? 'Không thể nhận phản hồi từ chatbot';

      setState(() {
        _messages[index] = ChatMessage(text: content, isUser: false);
      });

      // Lưu với tin nhắn ẩn để backup
      await _saveChatHistory(vitalMessage, content);
    } else {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi khi gửi dữ liệu vital signs: ${response.statusCode} - ${response.reasonPhrase}',
          isUser: false,
        );
      });
    }
  } on TimeoutException catch (e) {
    setState(() {
      _messages[index] = ChatMessage(
        text: 'Lỗi: Kết nối quá thời gian chờ khi gửi dữ liệu vital signs.',
        isUser: false,
      );
    });
    debugPrint('Timeout error: $e');
  } on SocketException catch (e) {
    setState(() {
      _messages[index] = ChatMessage(
        text: 'Lỗi kết nối mạng khi gửi dữ liệu vital signs.',
        isUser: false,
      );
    });
    debugPrint('Socket error: $e');
  } catch (e) {
    setState(() {
      _messages[index] = ChatMessage(
        text: 'Lỗi không xác định khi gửi dữ liệu vital signs: $e',
        isUser: false,
      );
    });
    debugPrint('General error: $e');
  } finally {
    setState(() {
      _isTyping = false;
    });
  }
}

// Static method để gọi từ bất kỳ đâu
static void triggerVitalSignsEvent(double temp, int heartRate, int spo2, int sys, int dia) {
  _instance?.handleVitalSignsEvent(temp, heartRate, spo2, sys, dia);
}
   // Hàm xử lý sự kiện fall - chỉ hiện phản hồi từ bot
  Future<void> handleFallEvent() async {
    const fallMessage = "Mai Đông Thức_Huyết áp cao";
    
    setState(() {
      // Chỉ thêm placeholder cho bot reply, không thêm tin nhắn user
      _messages.add(ChatMessage(text: '', isUser: false)); // Placeholder
      _isTyping = true;
    });

    final index = _messages.length - 1;

    try {
      debugPrint('Sending fall event to API...');
      debugPrint('Request body: ${jsonEncode({
        "stream": false,
        "model": "veronai",
        "messages": [
          {
            "role": "user",
            "content": fallMessage
          }
        ],
      })}');

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5050/api/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'HealthApp/1.0',
        },
        body: jsonEncode({
          "stream": false,
          "model": "veronai",
          "messages": [
            {
              "role": "user",
              "content": fallMessage
            }
          ],
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final content = jsonData['choices']?[0]?['message']?['content'] ?? 'Không thể nhận phản hồi từ chatbot';

        setState(() {
          _messages[index] = ChatMessage(text: content, isUser: false);
        });

        // Lưu với tin nhắn ẩn để backup
        await _saveChatHistory(fallMessage, content);
      } else {
        setState(() {
          _messages[index] = ChatMessage(
            text: 'Lỗi khi gửi thông báo ngã: ${response.statusCode} - ${response.reasonPhrase}',
            isUser: false,
          );
        });
      }
    } on TimeoutException catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi: Kết nối quá thời gian chờ khi gửi thông báo ngã.',
          isUser: false,
        );
      });
      debugPrint('Timeout error: $e');
    } on SocketException catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi kết nối mạng khi gửi thông báo ngã.',
          isUser: false,
        );
      });
      debugPrint('Socket error: $e');
    } catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi không xác định khi gửi thông báo ngã: $e',
          isUser: false,
        );
      });
      debugPrint('General error: $e');
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }
  // Static method để gọi từ bất kỳ đâu
  static void triggerFallEvent() {
    _instance?.handleFallEvent();
  }

  // ...existing code... (giữ nguyên tất cả các hàm khác)

    Future<void> _loadChatHistory() async {
    try {
      final response = await http.get(
        Uri.parse('https://api-chatbot-beta.vercel.app/history_chat?user_id=${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> history = jsonDecode(response.body);
        
        // Chuyển đổi từ API response thành ChatMessage objects
        final List<ChatMessage> messages = history.map((item) {
          return ChatMessage(
            text: item['content'] ?? '',
            isUser: item['role'] == 'user',
          );
        }).toList();

        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });

        // Cập nhật local storage để backup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chatHistory', jsonEncode(history));
        
        debugPrint('Loaded ${messages.length} messages from server');
        
        // Kiểm tra nếu lịch sử trống thì gửi "xin chào"
        if (messages.isEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _sendGreeting();
          });
        }
        
      } else {
        debugPrint('Lỗi khi tải lịch sử chat: ${response.statusCode}');
        // Fallback to local storage nếu server không available
        await _loadChatHistoryFromLocal();
      }
    } catch (e) {
      debugPrint('Lỗi khi gọi API lịch sử chat: $e');
      // Fallback to local storage nếu có lỗi network
      await _loadChatHistoryFromLocal();
    }
  }

  Future<void> _loadChatHistoryFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getString('chatHistory');
    if (history != null) {
      final List<dynamic> chatData = jsonDecode(history);
      
      final List<ChatMessage> messages = chatData.map((item) {
        return ChatMessage(
          text: item['content'] ?? '',
          isUser: item['role'] == 'user',
        );
      }).toList();

      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
      
      debugPrint('Loaded ${messages.length} messages from local storage');
      
      // Kiểm tra nếu lịch sử local cũng trống thì gửi "xin chào"
      if (messages.isEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _sendGreeting();
        });
      }
    } else {
      // Không có lịch sử local nào, gửi "xin chào"
      Future.delayed(const Duration(milliseconds: 500), () {
        _sendGreeting();
      });
    }
  }

  // Hàm gửi lời chào tương tự như handleFallEvent
  Future<void> _sendGreeting() async {
    const greetingMessage = "xin chào";
    
    setState(() {
      // Chỉ thêm placeholder cho bot reply, không thêm tin nhắn user
      _messages.add(ChatMessage(text: '', isUser: false)); // Placeholder
      _isTyping = true;
    });

    final index = _messages.length - 1;

    try {
      debugPrint('Sending greeting to API...');
      debugPrint('Request body: ${jsonEncode({
        "stream": false,
        "model": "veronai",
        "messages": [
          {
            "role": "user",
            "content": greetingMessage
          }
        ],
      })}');

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5050/api/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'HealthApp/1.0',
        },
        body: jsonEncode({
          "stream": false,
          "model": "veronai",
          "messages": [
            {
              "role": "user",
              "content": greetingMessage
            }
          ],
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final content = jsonData['choices']?[0]?['message']?['content'] ?? 'Không thể nhận phản hồi từ chatbot';

        setState(() {
          _messages[index] = ChatMessage(text: content, isUser: false);
        });

        // Lưu lời chào để backup
        await _saveChatHistory(greetingMessage, content);
      } else {
        setState(() {
          _messages[index] = ChatMessage(
            text: 'Lỗi khi gửi lời chào: ${response.statusCode} - ${response.reasonPhrase}',
            isUser: false,
          );
        });
      }
    } on TimeoutException catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi: Kết nối quá thời gian chờ khi gửi lời chào.',
          isUser: false,
        );
      });
      debugPrint('Timeout error: $e');
    } on SocketException catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi kết nối mạng khi gửi lời chào.',
          isUser: false,
        );
      });
      debugPrint('Socket error: $e');
    } catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi không xác định khi gửi lời chào: $e',
          isUser: false,
        );
      });
      debugPrint('General error: $e');
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  // ...existing code... (giữ nguyên tất cả các hàm khác)
  Future<void> _saveChatHistory(String userMessage, String botReply) async {
    try {
      final response = await http.post(
        Uri.parse('https://api-chatbot-beta.vercel.app/history_chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user': userMessage,
          'assistant': botReply,
          'user_id': widget.userId,
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

// ...existing code...
  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty && _currentAttachmentPath == null) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: '', isUser: false)); // Placeholder
      _isTyping = true;
    });

    final index = _messages.length - 1;

    // Chỉ lấy 2 cuộc hội thoại gần nhất (4 tin nhắn: 2 user + 2 assistant)
    final List<Map<String, String>> history = _messages
        .where((message) => message.text.isNotEmpty) // Filter out empty messages
        .map((message) => {
              "role": message.isUser ? "user" : "assistant",
              "content": message.text,
            })
        .toList()
        .reversed // Đảo ngược để lấy từ cuối
        .take(5) // Lấy tối đa 4 tin nhắn (2 cặp hội thoại)
        .toList()
        .reversed // Đảo ngược lại về thứ tự ban đầu
        .toList();

    try {
      debugPrint('Sending request to API...');
      debugPrint('Request body: ${jsonEncode({
        "stream": false,
        "model": "veronai",
        "messages": history,
      })}');

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5050/api/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'HealthApp/1.0',
        },
        body: jsonEncode({
          "stream": false,
          "model": "veronai",
          "messages": history,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final content = jsonData['choices']?[0]?['message']?['content'] ?? 'No response';

        setState(() {
          _messages[index] = ChatMessage(text: content, isUser: false);
        });

        await _saveChatHistory(text, content);
      } else {
        setState(() {
          _messages[index] = ChatMessage(
            text: 'Lỗi API: ${response.statusCode} - ${response.reasonPhrase}\nResponse: ${response.body}',
            isUser: false,
          );
        });
      }
    } on TimeoutException catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi: Kết nối quá thời gian chờ. Vui lòng thử lại.',
          isUser: false,
        );
      });
      debugPrint('Timeout error: $e');
    } on SocketException catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi kết nối mạng: Không thể kết nối đến server. Kiểm tra kết nối internet.',
          isUser: false,
        );
      });
      debugPrint('Socket error: $e');
    } on FormatException catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi định dạng dữ liệu từ server.',
          isUser: false,
        );
      });
      debugPrint('Format error: $e');
    } catch (e) {
      setState(() {
        _messages[index] = ChatMessage(
          text: 'Lỗi không xác định: $e',
          isUser: false,
        );
      });
      debugPrint('General error: $e');
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }// ...existing code...
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _currentAttachmentPath = image.path;
          _currentAttachmentType = 'image';
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _currentAttachmentPath = result.files.single.path!;
          _currentAttachmentType = 'file';
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
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
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[300]!, width: 1.0),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: Colors.black,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: const Text('Tập tin'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickFile();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Camera'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo),
                          title: const Text('Ảnh'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Hỏi bất cứ điều gì',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Colors.black,
            onPressed: () {
              if (_messageController.text.isNotEmpty ||
                  _currentAttachmentPath != null) {
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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
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
            Colors.blue[800]!.withAlpha((128 + (index * 51)).toInt()),
          ),
        ),
      ),
    );
  }
}



class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final String? attachmentPath;
  final String? attachmentType;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.attachmentPath,
    this.attachmentType,
  });

  @override
Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            decoration: BoxDecoration(
              // ĐÂY LÀ NƠI CHỈNH MÀU NỀN TIN NHẮN
              color: isUser 
                  ? Colors.blue[100]        // Màu nền tin nhắn của user
                  : Colors.grey[100],       // Màu nền tin nhắn của bot
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attachmentPath != null) _buildAttachment(),
                if (text.isNotEmpty) _buildTextContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextContent() {
    // Kiểm tra nếu là tin nhắn từ bot và có chứa markdown
    if (!isUser && _containsMarkdown(text)) {
      return MarkdownBody(
        data: text,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          strong: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          em: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black,
          ),
          code: TextStyle(
            backgroundColor: Colors.grey[100],
            fontFamily: 'monospace',
            fontSize: 13,
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          blockquote: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              left: BorderSide(
                color: Colors.grey[300]!,
                width: 4,
              ),
            ),
          ),
          listBullet: const TextStyle(
            color: Colors.black,
          ),
          h1: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          h2: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          h3: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        selectable: true,
      );
    } else {
      // Hiển thị text thường cho tin nhắn user hoặc không có markdown
      return Text(
        text,
        style: const TextStyle(
          color: Colors.black,
        ),
      );
    }
  }

  // Kiểm tra xem text có chứa markdown không
  bool _containsMarkdown(String text) {
    final markdownPatterns = [
      RegExp(r'\*\*.*?\*\*'), // Bold
      RegExp(r'\*.*?\*'),     // Italic
      RegExp(r'`.*?`'),       // Code
      RegExp(r'^#{1,6}\s'),   // Headers
      RegExp(r'^\*\s'),       // List items
      RegExp(r'^\-\s'),       // List items
      RegExp(r'^\d+\.\s'),    // Numbered list
      RegExp(r'^>\s'),        // Blockquote
    ];
    
    return markdownPatterns.any((pattern) => pattern.hasMatch(text));
  }

  Widget _buildAttachment() {
    if (attachmentType == 'image') {
      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(
            File(attachmentPath!),
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                attachmentPath!.split('/').last,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }
}