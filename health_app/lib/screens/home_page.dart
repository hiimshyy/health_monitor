import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'chatbot_page.dart';
import 'notification_page.dart';
import '../widgets/custom_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String fullName = '';
  bool isConnected = false;
  late MqttServerClient client;

  // Dữ liệu sức khỏe
  double temperature = 0.0;
  int heartRate = 0;
  int spo2 = 0;
  int sys = 0;
  int dia = 0;
  String lastUpdated = 'Chưa cập nhật';

  // Lịch sử đo
  List<Map<String, dynamic>> measurementHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMeasurementHistory();
    _connectToMqtt();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      fullName = prefs.getString('fullName') ?? 'Người dùng';
    });
  }

  Future<void> _loadMeasurementHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('measurementHistory');
    if (!mounted) return;
    if (historyJson != null) {
      setState(() {
        measurementHistory =
            List<Map<String, dynamic>>.from(jsonDecode(historyJson));
      });
    }
  }

  Future<void> _saveMeasurementHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('measurementHistory', jsonEncode(measurementHistory));
  }

  Future<void> _connectToMqtt() async {
    client = MqttServerClient(
        '42cb8a3135f84357959ce239305850c0.s1.eu.hivemq.cloud',
        'flutter_client');
    client.port = 8883;
    client.secure = true;
    client.logging(on: false);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;

    client.onConnected = () {
      debugPrint('MQTT Client connected');
      client.subscribe('health/data', MqttQos.atLeastOnce);
      debugPrint('Subscribed to health/data');

      // Set up message handler
      client.updates!.listen(
        (List<MqttReceivedMessage<MqttMessage>> c) {
          // debugPrint('Got message in listener');
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String message =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          // debugPrint('Message: $message');

          try {
            final data = jsonDecode(message);
            // debugPrint('Parsed JSON data: $data');
            if (!mounted) return;
            setState(() {
              temperature = (data['temp'] as num).toDouble();
              spo2 = (data['spo2'] as num).toInt();
              heartRate = (data['hr'] as num).toInt();
              sys = (data['sys'] as num).toInt();
              dia = (data['dia'] as num).toInt();
              final now = DateTime.now();
              lastUpdated =
                  '${now.hour}:${now.minute}:${now.second} ${now.day}/${now.month}/${now.year}';
            });

            // Add to measurement history
            measurementHistory.insert(0, {
              'time': lastUpdated,
              'temperature': temperature,
              'heartRate': heartRate,
              'spo2': spo2,
              'sys': sys,
              'dia': dia,
            });
            if (measurementHistory.length > 10) {
              measurementHistory = measurementHistory.sublist(0, 10);
            }
            _saveMeasurementHistory();
          } catch (e) {
            debugPrint('Error processing message: $e');
          }
        },
        onError: (error) {
          debugPrint('MQTT listener error: $error');
        },
        onDone: () {
          debugPrint('MQTT listener done');
        },
      );

      if (!mounted) return;
      setState(() {
        isConnected = true;
      });
    };

    client.onDisconnected = () {
      debugPrint('MQTT Client disconnected');
      if (!mounted) return;
      setState(() {
        isConnected = false;
      });
    };

    try {
      debugPrint('Connecting to MQTT broker...');
      await client.connect('smarthome', 'Smarthome2023');
    } catch (e) {
      debugPrint('Failed to connect to MQTT broker: $e');
      client.disconnect();
    }
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.menu,
              color: Colors.black,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: CustomDrawer(fullName: fullName),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            temperature: temperature,
            heartRate: heartRate,
            spo2: spo2,
            sys: sys,
            dia: dia,
            lastUpdated: lastUpdated,
            measurementHistory: measurementHistory,
          ),
          const ChatbotScreen(),
          const NotificationScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chatbot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Thông báo',
          ),
        ],
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final double temperature;
  final int heartRate;
  final int spo2;
  final int sys;
  final int dia;
  final String lastUpdated;
  final List<Map<String, dynamic>> measurementHistory;

  const HomeScreen({
    super.key,
    required this.temperature,
    required this.heartRate,
    required this.spo2,
    required this.sys,
    required this.dia,
    required this.lastUpdated,
    required this.measurementHistory,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(15.0, topPadding, 15.0, 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard container with health cards
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông số sức khỏe',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cập nhật lúc: $lastUpdated',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.1,
                      children: [
                        _buildHealthCard(
                          Icons.thermostat,
                          'Nhiệt độ',
                          temperature == 0.0
                              ? '...'
                              : '${temperature.toStringAsFixed(1)} °C',
                          Colors.yellow[50]!,
                          Colors.yellow[800]!,
                        ),
                        _buildHealthCard(
                          Icons.favorite,
                          'Nhịp tim',
                          heartRate == 0 ? '...' : '$heartRate bpm',
                          Colors.pink[50]!,
                          Colors.pink[800]!,
                        ),
                        _buildHealthCard(
                          Icons.opacity,
                          'SpO2',
                          spo2 == 0 ? '...' : '$spo2%',
                          Colors.teal[50]!,
                          Colors.teal[800]!,
                        ),
                        _buildHealthCard(
                          Icons.bloodtype,
                          'Huyết áp',
                          sys == 0 && dia == 0 ? '...' : '$sys/$dia mmHg',
                          Colors.purple[50]!,
                          Colors.purple[800]!,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // History section
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch sử đo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildMeasurementHistory(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthCard(IconData icon, String label, String value,
      Color bgColor, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementHistory() {
    if (measurementHistory.isEmpty) {
      return Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'Chưa có dữ liệu lịch sử',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: measurementHistory.length,
      itemBuilder: (context, index) {
        final record = measurementHistory[index];
        return Container(
          margin: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.blue[800]),
                    SizedBox(width: 5),
                    Text(
                      record['time'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildHistoryItem(
                        Icons.thermostat,
                        '${record['temperature'].toStringAsFixed(1)} °C',
                        Colors.teal[800]!,
                      ),
                    ),
                    Expanded(
                      child: _buildHistoryItem(
                        Icons.favorite,
                        '${record['heartRate']} bpm',
                        Colors.pink[800]!,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildHistoryItem(
                        Icons.opacity,
                        '${record['spo2']}%',
                        Colors.blue[800]!,
                      ),
                    ),
                    Expanded(
                      child: _buildHistoryItem(
                        Icons.arrow_upward,
                        '${record['sys']}/${record['dia']} mmHg',
                        Colors.purple[800]!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      'Xin chào! Tôi là trợ lý sức khỏe của bạn. Tôi có thể giúp gì cho bạn?',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
      ));
    });
    _scrollToBottom();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    _processMessage(text);
  }

  void _processMessage(String text) {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      String response = _getBotResponse(text.toLowerCase());
      setState(() {
        _isTyping = false;
        _addBotMessage(response);
      });
    });
  }

  String _getBotResponse(String message) {
    if (message.contains('xin chào') ||
        message.contains('hello') ||
        message.contains('hi')) {
      return 'Xin chào! Tôi có thể giúp gì cho bạn?';
    } else if (message.contains('sức khỏe') || message.contains('bệnh')) {
      return 'Tôi có thể giúp bạn theo dõi các chỉ số sức khỏe như nhịp tim, huyết áp, SpO2 và nhiệt độ cơ thể. Bạn muốn biết thêm thông tin gì?';
    } else if (message.contains('nhịp tim') || message.contains('heart rate')) {
      return 'Nhịp tim bình thường của người trưởng thành là từ 60-100 nhịp/phút. Bạn có thể theo dõi nhịp tim của mình qua ứng dụng này.';
    } else if (message.contains('huyết áp') ||
        message.contains('blood pressure')) {
      return 'Huyết áp bình thường là dưới 120/80 mmHg. Bạn nên đo huyết áp thường xuyên để theo dõi sức khỏe.';
    } else if (message.contains('spo2') || message.contains('oxy')) {
      return 'SpO2 là nồng độ oxy trong máu. Chỉ số bình thường là từ 95-100%. Nếu dưới 90% thì bạn nên đi khám bác sĩ.';
    } else if (message.contains('nhiệt độ') ||
        message.contains('temperature')) {
      return 'Nhiệt độ cơ thể bình thường là từ 36.5-37.5°C. Nếu nhiệt độ cao hơn 38°C, bạn có thể đang bị sốt.';
    } else if (message.contains('cảm ơn') || message.contains('thank')) {
      return 'Không có gì! Nếu bạn cần thêm thông tin, đừng ngại hỏi tôi nhé!';
    } else {
      return 'Xin lỗi, tôi không hiểu câu hỏi của bạn. Bạn có thể hỏi về các chỉ số sức khỏe như nhịp tim, huyết áp, SpO2 hoặc nhiệt độ cơ thể.';
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
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
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

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
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
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        shape: BoxShape.circle,
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
          Flexible(
            child: Container(
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

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  NotificationScreenState createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      title: 'Cảnh báo sức khỏe',
      message:
          'Nhịp tim của bạn đang cao hơn bình thường. Vui lòng nghỉ ngơi và theo dõi.',
      time: '5 phút trước',
      icon: Icons.favorite,
      color: Colors.red,
    ),
    NotificationItem(
      title: 'Nhắc nhở',
      message: 'Đã đến giờ đo huyết áp hàng ngày của bạn.',
      time: '1 giờ trước',
      icon: Icons.access_time,
      color: Colors.orange,
    ),
    NotificationItem(
      title: 'Cập nhật',
      message: 'Dữ liệu sức khỏe của bạn đã được cập nhật.',
      time: '2 giờ trước',
      icon: Icons.update,
      color: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có thông báo',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(_notifications[index]);
              },
            ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.color.withAlpha(26),
          child: Icon(
            notification.icon,
            color: notification.color,
          ),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              notification.time,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showNotificationOptions(notification);
          },
        ),
      ),
    );
  }

  void _showNotificationOptions(NotificationItem notification) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Xóa thông báo'),
                onTap: () {
                  setState(() {
                    _notifications.remove(notification);
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Đánh dấu đã đọc'),
                onTap: () {
                  // Xử lý đánh dấu đã đọc
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationItem {
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;

  NotificationItem({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
  });
}
