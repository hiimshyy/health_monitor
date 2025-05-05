import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

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

  Future<void> _startNewChat() async {
    final newChatId = DateTime.now().millisecondsSinceEpoch.toString();
    final welcomeMessage =
        'Xin chào! Tôi là trợ lý sức khỏe của bạn. Tôi có thể giúp gì cho bạn?';

    setState(() {
      _currentChatId = newChatId;
      _messages.clear();
      _messages.add(ChatMessage(
        text: welcomeMessage,
        isUser: false,
      ));
    });

    // Save new chat to history immediately
    final chatData = {
      'id': newChatId,
      'title': 'Cuộc trò chuyện mới',
      'lastMessage': welcomeMessage,
      'time': DateTime.now().toString(),
      'messages': jsonEncode([
        {
          'text': welcomeMessage,
          'isUser': false,
        }
      ]),
    };

    _chatHistory.insert(0, chatData);
    await _saveChatHistory();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty && _currentAttachmentPath == null) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        attachmentPath: _currentAttachmentPath,
        attachmentType: _currentAttachmentType,
      ));
      _currentAttachmentPath = null;
      _currentAttachmentType = null;
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
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
      FilePickerResult? result = await FilePicker.platform.pickFiles();
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
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentAttachmentPath != null) _buildAttachmentPreview(),
          Row(
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
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          if (_currentAttachmentType == 'image')
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                image: DecorationImage(
                  image: FileImage(File(_currentAttachmentPath!)),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.only(right: 8.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _currentAttachmentPath!.split('/').last,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _currentAttachmentPath = null;
                _currentAttachmentType = null;
              });
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
