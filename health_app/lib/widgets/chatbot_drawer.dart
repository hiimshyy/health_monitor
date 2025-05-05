import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatbotDrawer extends StatefulWidget {
  final String fullName;
  final List<Map<String, dynamic>> chatHistory;
  final Function(Map<String, dynamic>)? onChatSelected;
  final VoidCallback? onNewChat;

  const ChatbotDrawer({
    super.key,
    required this.fullName,
    this.chatHistory = const [],
    this.onChatSelected,
    this.onNewChat,
  });

  @override
  State<ChatbotDrawer> createState() => _ChatbotDrawerState();
}

class _ChatbotDrawerState extends State<ChatbotDrawer> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredChatHistory = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredChatHistory = widget.chatHistory;
  }

  @override
  void didUpdateWidget(ChatbotDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatHistory != widget.chatHistory) {
      _filteredChatHistory = widget.chatHistory;
    }
  }

  void _filterChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChatHistory = widget.chatHistory;
      } else {
        _filteredChatHistory = widget.chatHistory.where((chat) {
          final title = (chat['title'] ?? '').toString().toLowerCase();
          final message = (chat['lastMessage'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) || message.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chatHistory');
    if (mounted) {
      setState(() {
        _filteredChatHistory = [];
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
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              color: Colors.blue[800],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Lịch sử chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: widget.onNewChat,
                        tooltip: 'Cuộc trò chuyện mới',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm cuộc trò chuyện...',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon:
                                  const Icon(Icons.clear, color: Colors.white),
                              onPressed: () {
                                _searchController.clear();
                                _filterChats('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                    ),
                    onChanged: _filterChats,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filteredChatHistory.isEmpty
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
                            _searchController.text.isEmpty
                                ? 'Chưa có lịch sử chat'
                                : 'Không tìm thấy kết quả',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredChatHistory.length,
                      itemBuilder: (context, index) {
                        final chat = _filteredChatHistory[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(
                              Icons.chat,
                              color: Colors.blue[800],
                              size: 20,
                            ),
                          ),
                          title: Text(
                            chat['title'] ?? 'Cuộc trò chuyện ${index + 1}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            chat['lastMessage'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chat['time'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 20),
                                color: Colors.grey[500],
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final history =
                                      prefs.getString('chatHistory');
                                  if (history != null) {
                                    final List<dynamic> chats =
                                        jsonDecode(history);
                                    chats.removeAt(index);
                                    await prefs.setString(
                                        'chatHistory', jsonEncode(chats));
                                    if (mounted) {
                                      setState(() {
                                        _filteredChatHistory.removeAt(index);
                                      });
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            if (widget.onChatSelected != null) {
                              widget.onChatSelected!(chat);
                            }
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
            if (_filteredChatHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Xóa lịch sử chat'),
                        content: const Text(
                          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử chat?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            onPressed: () {
                              _clearChatHistory();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Xóa',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Xóa lịch sử chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[800],
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
