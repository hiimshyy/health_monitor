import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chatbot_page.dart';
import 'notification_page.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/chatbot_drawer.dart';
// Thêm class UserProfile để parse dữ liệu từ API
class UserProfile {
  final String fullname;
  final String email;
  final String phone;
  final int dayOfBirth;
  final int monthOfBirth;
  final int yearOfBirth;
  final String gender;
  final double height;
  final double weight;
  final String medicalHistory; // Thêm dòng này

  UserProfile({
    required this.fullname,
    required this.email,
    required this.phone,
    required this.dayOfBirth,
    required this.monthOfBirth,
    required this.yearOfBirth,
    required this.gender,
    required this.height,
    required this.weight,
    required this.medicalHistory, // Thêm dòng này
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullname: json['fullname'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      dayOfBirth: json['day_of_birth'] ?? 1,
      monthOfBirth: json['month_of_birth'] ?? 1,
      yearOfBirth: json['year_of_birth'] ?? 2000,
      gender: json['gender'] ?? '',
      height: (json['height'] ?? 0).toDouble(),
      weight: (json['weight'] ?? 0).toDouble(),
      medicalHistory: json['medical_history'] ?? 'Không có', // Thêm dòng này
    );
  }
}

class Profile {
  final String id;
  final String name;
  final String? avatar;
  final int age;
  final String gender;
  final String relationship;

  Profile({
    required this.id,
    required this.name,
    this.avatar,
    required this.age,
    required this.gender,
    required this.relationship,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'age': age,
        'gender': gender,
        'relationship': relationship,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        name: json['name'],
        avatar: json['avatar'],
        age: json['age'],
        gender: json['gender'],
        relationship: json['relationship'],
      );
}

class HomePage extends StatefulWidget {
  final int userId;
  const HomePage({super.key, required this.userId});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String fullName = '';
  String medicalHistory = "Không có";
  bool isConnected = false;
  late MqttServerClient client;
  List<Map<String, dynamic>> _chatHistory = [];
  List<Profile> _profiles = [];
  Profile? _currentProfile;

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
    _loadProfiles();
    _loadMeasurementHistory();
    _connectToMqtt();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    try {
      // Gọi API để lấy thông tin profile
      final response = await http.get(
        Uri.parse('https://api-chatbot-beta.vercel.app/get_profile?user_id=${widget.userId}')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['message'] == "Profile retrieved successfully") {
          // Parse dữ liệu profile
          final userProfile = UserProfile.fromJson(data['profile']);
          medicalHistory = userProfile.medicalHistory;
          // Cập nhật fullName trong SharedPreferences
          await prefs.setString('fullName', userProfile.fullname);
          
          if (!mounted) return;
          
          // Cập nhật state với fullName mới
          setState(() {
            fullName = userProfile.fullname;
          });
          
          print('Đã cập nhật fullName: $fullName');
        } else {
          print('Lỗi: ${data['message']}');
          // Fallback nếu không thể lấy được thông tin từ API
          setState(() {
            fullName = 'Người dùng ${widget.userId}';
          });
        }
      } else {
        print('Lỗi kết nối: ${response.statusCode}');
        // Fallback nếu không thể kết nối đến API
        setState(() {
          fullName = 'Người dùng ${widget.userId}';
        });
      }
    } catch (e) {
      print('Lỗi khi gọi API: $e');
      // Fallback khi có lỗi
      if (!mounted) return;
      setState(() {
        fullName = 'Người dùng ${widget.userId}';
      });
    }
  }


  Future<void> _loadProfiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? profilesJson = prefs.getString('profiles');
    if (profilesJson != null) {
      List<dynamic> profilesList = jsonDecode(profilesJson);
      setState(() {
        _profiles = profilesList.map((p) => Profile.fromJson(p)).toList();
      });
      await _loadCurrentProfile();
    }
  }

  Future<void> _saveProfiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'profiles', jsonEncode(_profiles.map((p) => p.toJson()).toList()));
  }

Future<void> _loadMeasurementHistory() async {
  try {
    debugPrint('Loading measurement history from API...');
    
    final response = await http.get(
      Uri.parse('https://api-chatbot-beta.vercel.app/get_vital_sign?user_id=${widget.userId}')
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      debugPrint('API Response: $data');
      
      if (!mounted) return;
      
      setState(() {
        measurementHistory = data.map((item) => {
          'time': item['time'],
          'temperature': double.tryParse(item['temp'].toString()) ?? 0.0,
          'heartRate': item['heartRate'] ?? 0,
          'spo2': item['spo2'] ?? 0,
          'sys': item['sys'] ?? 0,
          'dia': item['dia'] ?? 0,
        }).toList();
      });
      
      debugPrint('✅ Loaded ${measurementHistory.length} measurement records from API');
      
      // Lưu vào SharedPreferences để backup
      await _saveMeasurementHistory();
      
    } else {
      debugPrint('❌ HTTP Error: ${response.statusCode}');
      // Fallback: load từ SharedPreferences nếu API lỗi
      await _loadMeasurementHistoryFromLocal();
    }
  } catch (e) {
    debugPrint('❌ Error loading measurement history from API: $e');
    // Fallback: load từ SharedPreferences nếu có lỗi
    await _loadMeasurementHistoryFromLocal();
  }
}

// Hàm backup để load từ SharedPreferences
Future<void> _loadMeasurementHistoryFromLocal() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('measurementHistory');
    
    if (!mounted) return;
    
    if (historyJson != null) {
      setState(() {
        measurementHistory = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
      });
      debugPrint('📱 Loaded measurement history from local storage');
    } else {
      setState(() {
        measurementHistory = [];
      });
      debugPrint('📱 No local measurement history found');
    }
  } catch (e) {
    debugPrint('❌ Error loading local measurement history: $e');
    if (!mounted) return;
    setState(() {
      measurementHistory = [];
    });
  }
}

  Future<void> _saveMeasurementHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('measurementHistory', jsonEncode(measurementHistory));
  }
  Future<void> _saveVitalSignToAPI(double temp, int heartRate, int spo2, int sys, int dia) async {
  try {
    final url = 'https://api-chatbot-beta.vercel.app/save_vital_sign?user_id=${widget.userId}&temp=$temp&heart_rate=$heartRate&spo2=$spo2&sys=$sys&dia=$dia';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true || data['message'] != null) {
        debugPrint('Vital sign saved successfully to database');
      } else {
        debugPrint('Failed to save vital sign: ${data['message']}');
      }
    } else {
      debugPrint('HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error saving vital sign to API: $e');
  }
}
// ...existing code...
Future<void> _predictHealthStatus(
    double temp, int heartRate, int spo2, int sys, int dia, String medicalHistory) async {
  try {
    final response = await http.post(
      Uri.parse('https://api-model-predict.vercel.app/api/chat/completions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "messages": [
          {
            "role": "user",
            "content":
                "temp: $temp heartRate: $heartRate spo2: $spo2 sys: $sys dia: $dia \nTiểu sử bệnh: $medicalHistory"
          }
        ],
      }),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final content = jsonData['choices']?[0]?['message']?['content']?.toString() ?? 'No response';
      print("temp: $temp heartRate: $heartRate spo2: $spo2 sys: $sys dia: $dia \nTiểu sử bệnh: $medicalHistory");
      print('Predict result: $content');

      // Kiểm tra kết quả và hiện thông báo nếu cần
      if (content.trim() != "0") {
        // Ví dụ: nếu trả về "1 - Huyết áp cao" thì hiện thông báo "Huyết áp cao"
        String message = content;
        // Nếu muốn chỉ lấy phần sau dấu "-", bạn có thể tách chuỗi:
        if (content.contains('-')) {
          message = content.split('-')[1].trim();
        }
        // Hiện thông báo
if (context.mounted) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 48),
              const SizedBox(height: 16),
              const Text(
                'Cảnh báo sức khỏe',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 18, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Tôi biết rồi',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
      }
    } else {
      print('Predict API error: ${response.statusCode} - ${response.reasonPhrase}');
    }
  } catch (e) {
    print('Error calling predict API: $e');
  }
}
// ...existing code...
  Future<void> _connectToMqtt() async {
    client = MqttServerClient(
        '1df19fa858774630a1197a48081cc0c1.s1.eu.hivemq.cloud',
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
    debugPrint('Got message in listener');
    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String message =
        MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    debugPrint('Message: $message');

    try {
      final data = jsonDecode(message);
      debugPrint('Parsed JSON data: $data');
      if (!mounted) return;
      
      // Extract values
      final double tempValue = (data['temp'] as num).toDouble();
      final int spo2Value = (data['spo2'] as num).toInt();
      final int heartRateValue = (data['hr'] as num).toInt();
      final int sysValue = (data['sys'] as num).toInt();
      final int diaValue = (data['dia'] as num).toInt();
      
      setState(() {
        temperature = tempValue;
        spo2 = spo2Value;
        heartRate = heartRateValue;
        sys = sysValue;
        dia = diaValue;
        final now = DateTime.now();
        lastUpdated =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.day}/${now.month}/${now.year}';
      });

      print('Temperature: $temperature°C');
      print('Heart Rate: $heartRate bpm');
      print('SpO2: $spo2%');
      print('Blood Pressure: $sys/$dia mmHg');
      print('Last Updated: $lastUpdated');

      // Save to API
      _saveVitalSignToAPI(tempValue, heartRateValue, spo2Value, sysValue, diaValue);
      ChatbotScreenState.triggerVitalSignsEvent(tempValue, heartRateValue, spo2Value, sysValue, diaValue);

      _predictHealthStatus(tempValue, heartRateValue, spo2Value, sysValue, diaValue, medicalHistory);
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
      await client.connect('chechanh2003', '0576289825Asd');
    } catch (e) {
      debugPrint('Failed to connect to MQTT broker: $e');
      client.disconnect();
    }
  }

  void _handleChatHistoryUpdated(List<Map<String, dynamic>> history) {
    setState(() {
      _chatHistory = history;
    });
  }

  void _handleNewChat() {
    setState(() {
      // Clear current chat and start new one
    });
  }

  Future<void> _saveCurrentProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_currentProfile != null) {
      await prefs.setString('currentProfileId', _currentProfile!.id);
    }
  }

  Future<void> _loadCurrentProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentProfileId = prefs.getString('currentProfileId');
    if (currentProfileId != null && _profiles.isNotEmpty) {
      setState(() {
        _currentProfile = _profiles.firstWhere(
          (p) => p.id == currentProfileId,
          orElse: () => _profiles.first,
        );
      });
    }
  }

  void _switchProfile(String profileId) async {
    final newProfile = _profiles.firstWhere((p) => p.id == profileId);
    if (_currentProfile?.id != newProfile.id) {
      await _saveCurrentProfile(); // Lưu profile hiện tại
      setState(() {
        _currentProfile = newProfile;
      });
    }
  }

  void _showAddProfileDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    String selectedGender = 'Nam';
    String selectedRelationship = 'Bố';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Thêm thành viên mới',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Tên',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: ageController,
                        decoration: InputDecoration(
                          labelText: 'Tuổi',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Giới tính',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: ['Nam', 'Nữ'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedGender = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: selectedRelationship,
                        decoration: InputDecoration(
                          labelText: 'Mối quan hệ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: [
                          'Bố',
                          'Mẹ',
                          'Con trai',
                          'Con gái',
                          'Ông',
                          'Bà',
                          'Khác'
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedRelationship = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              if (nameController.text.isNotEmpty &&
                                  ageController.text.isNotEmpty) {
                                final newProfile = Profile(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  name: nameController.text,
                                  age: int.parse(ageController.text),
                                  gender: selectedGender,
                                  relationship: selectedRelationship,
                                );
                                setState(() {
                                  _profiles.add(newProfile);
                                  _currentProfile = newProfile;
                                });
                                _saveProfiles();
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                            ),
                            child: const Text('Thêm'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Scaffold(
            extendBodyBehindAppBar: false,
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
                        _currentProfile?.name ?? fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            color: Colors.blue[800],
                          ),
                        ),
                        itemBuilder: (BuildContext context) {
                          return [
                            ..._profiles.map((profile) => PopupMenuItem<String>(
                                  value: profile.id,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.blue[100],
                                        child: Text(
                                          profile.name[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${profile.age} tuổi - ${profile.relationship}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_currentProfile?.id == profile.id)
                                        Icon(Icons.check_circle,
                                            color: Colors.green, size: 20),
                                    ],
                                  ),
                                )),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'add',
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline,
                                      color: Colors.blue[800]),
                                  const SizedBox(width: 10),
                                  const Text('Thêm thành viên mới'),
                                ],
                              ),
                            ),
                          ];
                        },
                        onSelected: (String value) {
                          if (value == 'add') {
                            _showAddProfileDialog();
                          } else {
                            _switchProfile(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            drawer: CustomDrawer(fullName: fullName, user_id: widget.userId),
            body: HomeScreen(
              temperature: temperature,
              heartRate: heartRate,
              spo2: spo2,
              sys: sys,
              dia: dia,
              lastUpdated: lastUpdated,
              measurementHistory: measurementHistory,
            ),
          ),
          Scaffold(
            extendBodyBehindAppBar: false,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Chatbot',
                style: TextStyle(
                  color: Colors.black,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  _selectedIndex = 0; // Quay về trang chính (Home)
                });
              },
            ),
              
            ),
            drawer: ChatbotDrawer(
              fullName: fullName,
              chatHistory: _chatHistory,
              onChatSelected: (chat) {
                // Handle chat selection
                setState(() {
                  // Update chat history if needed
                });
              },
              onNewChat: _handleNewChat,
            ),
            body: ChatbotScreen(
              onChatHistoryUpdated: _handleChatHistoryUpdated,
              userId: widget.userId,
            ),
          ),
          Scaffold(
            extendBodyBehindAppBar: false,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'Thông báo',
                style: TextStyle(
                  color: Colors.black,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
            ),
            body: const NotificationScreen(),
          ),
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

  Map<String, dynamic> _getLatestMeasurements() {
    if (measurementHistory.isNotEmpty) {
      return measurementHistory.first;
    }
    return {
      'temperature': temperature,
      'heartRate': heartRate,
      'spo2': spo2,
      'sys': sys,
      'dia': dia,
      'time': lastUpdated,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final latestMeasurements = _getLatestMeasurements();

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(15.0, topPadding, 15.0, 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      'Cập nhật lúc: ${latestMeasurements['time']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 10),
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
                          latestMeasurements['temperature'] == 0.0
                              ? '...'
                              : '${latestMeasurements['temperature'].toStringAsFixed(1)} °C',
                          Colors.yellow[50]!,
                          Colors.yellow[800]!,
                        ),
                        _buildHealthCard(
                          Icons.favorite,
                          'Nhịp tim',
                          latestMeasurements['heartRate'] == 0
                              ? '...'
                              : '${latestMeasurements['heartRate']} bpm',
                          Colors.pink[50]!,
                          Colors.pink[800]!,
                        ),
                        _buildHealthCard(
                          Icons.opacity,
                          'SpO2',
                          latestMeasurements['spo2'] == 0
                              ? '...'
                              : '${latestMeasurements['spo2']}%',
                          Colors.teal[50]!,
                          Colors.teal[800]!,
                        ),
                        _buildHealthCard(
                          Icons.bloodtype,
                          'Huyết áp',
                          latestMeasurements['sys'] == 0 &&
                                  latestMeasurements['dia'] == 0
                              ? '...'
                              : '${latestMeasurements['sys']}/${latestMeasurements['dia']} mmHg',
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
