import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ChatbotDrawer extends StatefulWidget {
  final String fullName;
  final List<Map<String, dynamic>> chatHistory; // Thêm tham số này
  final Function(Map<String, dynamic>)? onChatSelected;
  final VoidCallback? onNewChat;

  const ChatbotDrawer({
    super.key,
    required this.fullName,
    required this.chatHistory, // Thêm tham số này
    this.onChatSelected,
    this.onNewChat,
  });

  @override
  State<ChatbotDrawer> createState() => _ChatbotDrawerState();
}

class _ChatbotDrawerState extends State<ChatbotDrawer> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredChatHistory = [];
  final Map<String, List<Map<String, dynamic>>> _groupedChats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
  }

  Future<void> _fetchChatHistory() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/id_conversation?&user_id=1'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> conversationIds = jsonDecode(response.body);
        final List<Map<String, dynamic>> chatHistory = conversationIds
            .map((id) => {
                  'id': id,
                  'title': 'Trò chuyện số $id',
                  'time': DateTime.now().toString(),
                })
            .toList();

        setState(() {
          _filteredChatHistory = chatHistory;
          _groupChatsByDate();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load chat history');
      }
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _groupChatsByDate() {
    _groupedChats.clear();
    for (var chat in _filteredChatHistory) {
      final date = chat['time'] ?? '';
      if (!_groupedChats.containsKey(date)) {
        _groupedChats[date] = [];
      }
      _groupedChats[date]!.add(chat);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final now = DateTime.now();
      final date = DateTime.parse(dateStr);
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Hôm nay';
      } else if (difference.inDays == 1) {
        return 'Hôm qua';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  void _filterChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _fetchChatHistory();
      } else {
        _filteredChatHistory = _filteredChatHistory.where((chat) {
          final title = (chat['title'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return title.contains(searchLower);
        }).toList();
      }
      _groupChatsByDate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey[600], size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey[600], size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterChats('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: _filterChats,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.black87),
                    onPressed: widget.onNewChat,
                    tooltip: 'Cuộc trò chuyện mới',
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredChatHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 30,
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
                          itemCount: _groupedChats.length,
                          itemBuilder: (context, index) {
                            final date = _groupedChats.keys.elementAt(index);
                            final chats = _groupedChats[date]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Text(
                                    _formatDate(date),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ...chats.map((chat) => ListTile(
                                      title: Text(
                                        chat['title'] ?? 'Cuộc trò chuyện',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      onTap: () {
                                        if (widget.onChatSelected != null) {
                                          widget.onChatSelected!(chat);
                                        }
                                        Navigator.pop(context);
                                      },
                                    )),
                              ],
                            );
                          },
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