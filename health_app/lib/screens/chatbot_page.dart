import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ChatbotScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>)? onChatHistoryUpdated;

  const ChatbotScreen({super.key, this.onChatHistoryUpdated});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _chatHistory = [];
  String _currentChatId = '';
  bool _isTyping = false;
  String? _currentAttachmentPath;
  String? _currentAttachmentType;

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
      widget.onChatHistoryUpdated?.call(_chatHistory);
    }
  }

  Future<void> _saveChatHistoryLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chatHistory', jsonEncode(_chatHistory));
    widget.onChatHistoryUpdated?.call(_chatHistory);
  }

  Future<void> _saveChatHistory(String userMessage, String botReply) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/history_chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user': userMessage,
          'assistant': botReply,
          'conversation_id': _currentChatId,
          'user_id': 1,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('conversation_id: $_currentChatId');
        debugPrint('Lịch sử cuộc trò chuyện đã được lưu.');
      } else {
        debugPrint('Lỗi khi lưu lịch sử: ${response.body}');
      }
    } catch (e) {
      debugPrint('Lỗi khi gửi yêu cầu lưu lịch sử: $e');
    }
  }

  Future<void> _startNewChat() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/id_conversation?&user_id=1'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> conversationIds = jsonDecode(response.body);
        final newChatId = (conversationIds.isNotEmpty
                ? (conversationIds.cast<int>().reduce((a, b) => a > b ? a : b) + 1)
                : 1)
            .toString();

        const welcomeMessage =
            'Xin chào! Tôi là trợ lý sức khỏe của bạn. Tôi có thể giúp gì cho bạn?';

        setState(() {
          _currentChatId = newChatId;
          _messages.clear();
          _messages.add(ChatMessage(text: welcomeMessage, isUser: false));
        });

        final chatData = {
          'id': newChatId,
          'title': 'Cuộc trò chuyện mới',
          'lastMessage': welcomeMessage,
          'time': DateTime.now().toString(),
          'messages': jsonEncode([
            {'text': welcomeMessage, 'isUser': false}
          ]),
        };

        _chatHistory.insert(0, chatData);
        await _saveChatHistoryLocally();
      } else {
        throw Exception('Failed to fetch conversation IDs');
      }
    } catch (e) {
      debugPrint('Error starting new chat: $e');
    }
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty && _currentAttachmentPath == null) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: '', isUser: false)); // Placeholder
      _isTyping = true;
    });

    final index = _messages.length - 1;
    String buffer = '';

    final List<Map<String, String>> history = _messages
        .map((message) => {
              "role": message.isUser ? "user" : "assistant",
              "content": message.text,
            })
        .toList();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('https://chat.hacfe.io.vn/api/chat/completions'),
      )
        ..headers.addAll({
          'Authorization': 'Bearer sk-05e4688dd2794cfc89850827b07530c2',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          "stream": true,
          "model": "veronai2",
          "messages": history,
        });

      final response = await request.send();

      if (response.statusCode == 200) {
        final stream = response.stream.transform(utf8.decoder);

        await for (final chunk in stream) {
          for (final line in const LineSplitter().convert(chunk)) {
            if (line.trim().isEmpty) continue;
            if (line.trim() == 'data: [DONE]') break;

            final cleaned = line.replaceFirst(RegExp(r'^data:\s*'), '');

            try {
              final jsonData = json.decode(cleaned) as Map<String, dynamic>;
              final delta = jsonData['choices']?[0]?['delta']?['content'];

              if (delta != null && delta.isNotEmpty) {
                buffer += delta;

                setState(() {
                  _messages[index] = ChatMessage(text: buffer, isUser: false);
                });
              }
            } catch (e) {
              debugPrint('Error parsing stream chunk: $e');
            }
          }
        }

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
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

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
              color: isUser ? Colors.grey[200] : Colors.transparent,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attachmentPath != null) _buildAttachment(),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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