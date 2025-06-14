import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Thêm dòng này
import 'dart:convert';

class PersonalInfoScreen extends StatefulWidget {
  final int user_id;
  const PersonalInfoScreen({super.key, required this.user_id,});

  @override
  PersonalInfoScreenState createState() => PersonalInfoScreenState();
}

class PersonalInfoScreenState extends State<PersonalInfoScreen> {
  String fullName = '';
  String gender = '';
  int? birthDay;
  int? birthMonth;
  int? birthYear;
  String height = '';
  String weight = '';
  String medicalHistory = ''; // Thêm biến này
  bool isEditing = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _medicalHistoryController = TextEditingController(); // Thêm controller này

  final _formKey = GlobalKey<FormState>();

  final List<String> _genders = ['Nam', 'Nữ', 'Khác'];

  // Màu sắc chủ đạo
  final Color primaryColor = const Color(0xFF1976D2); // Dark blue
  final Color secondaryColor = const Color(0xFF64B5F6); // Light blue
  final Color backgroundColor = const Color(0xFFE3F2FD); // Very light blue
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF0D47A1); // Darker blue for text

  @override
  void initState() {
    super.initState();
    debugPrint('Initial gender value: "$gender"');
    debugPrint('Available genders: $_genders');
    _loadUserData();
  }

Future<void> _loadUserData() async {
  try {
    print(widget.user_id);
    final response = await http.get(
      Uri.parse('https://api-chatbot-beta.vercel.app/get_profile?user_id=${widget.user_id}')
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final profile = data['profile'];
      
      setState(() {
        fullName = profile['fullname'] ?? '';
        
        // Normalize gender value để khớp với dropdown items
        String apiGender = profile['gender']?.toString().toLowerCase() ?? '';
        if (apiGender == 'nu' || apiGender == 'nữ' || apiGender == 'female') {
          gender = 'Nữ';
        } else if (apiGender == 'nam' || apiGender == 'male') {
          gender = 'Nam';
        } else if (apiGender == 'khac' || apiGender == 'khác' || apiGender == 'other') {
          gender = 'Khác';
        } else {
          gender = ''; // Giá trị mặc định nếu không khớp
        }
        
        // Kiểm tra ngày sinh hợp lệ
        int? dayValue = profile['day_of_birth'];
        int? monthValue = profile['month_of_birth'];
        int? yearValue = profile['year_of_birth'];
        
        birthDay = (dayValue != null && dayValue >= 1 && dayValue <= 31) ? dayValue : null;
        birthMonth = (monthValue != null && monthValue >= 1 && monthValue <= 12) ? monthValue : null;
        birthYear = (yearValue != null && yearValue >= 1900) ? yearValue : null;
        
        height = profile['height']?.toString() ?? '';
        weight = profile['weight']?.toString() ?? '';
        medicalHistory = profile['medical_history'] ?? '';

        _fullNameController.text = fullName;
        _heightController.text = height;
        _weightController.text = weight;
        _medicalHistoryController.text = medicalHistory;
      });
      
      debugPrint('Profile loaded: $profile');
      debugPrint('Normalized gender: $gender');
    } else {
      print('Failed to load profile. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error loading profile: $e');
  }
}
Widget _buildMedicalHistoryField() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.medical_information, color: primaryColor, size: 24),
      const SizedBox(width: 10),
      Expanded(
        child: isEditing
            ? TextFormField(
                controller: _medicalHistoryController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Tiểu sử bệnh tật',
                  labelStyle: TextStyle(color: textColor),
                  hintText: 'Nhập tiểu sử bệnh tật (nếu có)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: secondaryColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: secondaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  alignLabelWithHint: true,
                ),
                style: TextStyle(color: textColor),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: secondaryColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  medicalHistory.isEmpty ? 'Chưa có thông tin' : medicalHistory,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ),
      ),
    ],
  );
}
Future<void> _saveUserData() async {
  if (!_formKey.currentState!.validate()) return;

  try {
    // Gửi API edit_profile với POST
    final response = await http.post(
      Uri.parse('https://api-chatbot-beta.vercel.app/update_user'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': widget.user_id,
        'fullname': _fullNameController.text,
        'gender': gender,
        'day_of_birth': birthDay,
        'month_of_birth': birthMonth,
        'year_of_birth': birthYear,
        'height': _heightController.text,
        'weight': _weightController.text,
        'medical_history': _medicalHistoryController.text,
      }),
    );
    
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Sửa điều kiện kiểm tra - kiểm tra message thay vì success
      if (data['message'] != null && data['message'].toString().contains('successfully')) {
        // Lưu vào SharedPreferences để backup
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('fullName', _fullNameController.text);
        await prefs.setString('gender', gender);
        await prefs.setString('medicalHistory', _medicalHistoryController.text);

        if (birthDay != null) await prefs.setInt('birthDay', birthDay!);
        if (birthMonth != null) await prefs.setInt('birthMonth', birthMonth!);
        if (birthYear != null) await prefs.setInt('birthYear', birthYear!);

        await prefs.setString('height', _heightController.text);
        await prefs.setString('weight', _weightController.text);

        // Cập nhật state
        setState(() {
          isEditing = false;
          fullName = _fullNameController.text;
          height = _heightController.text;
          weight = _weightController.text;
          medicalHistory = _medicalHistoryController.text;
        });

        debugPrint('Profile updated successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật thông tin thành công!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${data['message'] ?? 'Không thể cập nhật thông tin'}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi HTTP: ${response.statusCode}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Error updating profile: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
  void _cancelEditing() {
    setState(() {
      isEditing = false;
      _fullNameController.text = fullName;
      _heightController.text = height;
      _weightController.text = weight;
      _medicalHistoryController.text = medicalHistory; // Thêm dòng này
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _cancelEditing,
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: _saveUserData,
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        Icons.person,
                        'Họ và tên',
                        _fullNameController,
                        isEditing: isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildGenderField(),
                      const SizedBox(height: 15),
                      _buildBirthDateFields(),
                      const SizedBox(height: 15),
                      _buildTextField(
                        Icons.height,
                        'Chiều cao',
                        _heightController,
                        isEditing: isEditing,
                        keyboardType: TextInputType.number,
                        suffixText: 'cm',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập chiều cao';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Chiều cao phải là số';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        Icons.fitness_center,
                        'Cân nặng',
                        _weightController,
                        isEditing: isEditing,
                        keyboardType: TextInputType.number,
                        suffixText: 'kg',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập cân nặng';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Cân nặng phải là số';
                          }
                          return null;
                        },
                      ),
                      // Thêm sau field cân nặng
                      const SizedBox(height: 15),
                      _buildMedicalHistoryField(), // Thêm field mới
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool isEditing = false,
    TextInputType? keyboardType,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: isEditing
              ? TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(color: textColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: secondaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: secondaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    suffixText: suffixText,
                    suffixStyle: TextStyle(color: textColor),
                  ),
                  style: TextStyle(color: textColor),
                  keyboardType: keyboardType,
                  validator: validator,
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: secondaryColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    controller.text.isEmpty
                        ? 'Chưa có thông tin'
                        : '${controller.text}${suffixText != null ? ' $suffixText' : ''}',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
Widget _buildGenderField() {
  return Row(
    children: [
      Icon(Icons.wc, color: primaryColor, size: 24),
      const SizedBox(width: 10),
      Expanded(
        child: isEditing
            ? DropdownButtonFormField<String>(
                value: gender.isEmpty ? null : gender, // Chỉ set value nếu không empty
                decoration: InputDecoration(
                  labelText: 'Giới tính',
                  labelStyle: TextStyle(color: textColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: secondaryColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: secondaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(color: textColor),
                dropdownColor: cardColor,
                items: _genders.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    gender = newValue ?? '';
                  });
                },
                hint: const Text('Chọn giới tính'), // Thêm hint
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: secondaryColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  gender.isEmpty ? 'Chưa có thông tin' : gender,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ),
      ),
    ],
  );
}

  Widget _buildBirthDateFields() {
    return Row(
      children: [
        Icon(Icons.calendar_today, color: primaryColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: isEditing
              ? Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: birthDay,
                        decoration: InputDecoration(
                          labelText: 'Ngày',
                          labelStyle: TextStyle(color: textColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                        dropdownColor: cardColor,
                        items: List.generate(31, (index) => index + 1)
                            .map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            birthDay = newValue;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: birthMonth,
                        decoration: InputDecoration(
                          labelText: 'Tháng',
                          labelStyle: TextStyle(color: textColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                        dropdownColor: cardColor,
                        items: List.generate(12, (index) => index + 1)
                            .map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            birthMonth = newValue;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: birthYear,
                        decoration: InputDecoration(
                          labelText: 'Năm',
                          labelStyle: TextStyle(color: textColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                        dropdownColor: cardColor,
                        items: List.generate(
                                100, (index) => DateTime.now().year - index)
                            .map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            birthYear = newValue;
                          });
                        },
                      ),
                    ),
                  ],
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: secondaryColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    birthDay != null && birthMonth != null && birthYear != null
                        ? '$birthDay/$birthMonth/$birthYear'
                        : 'Chưa có thông tin',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

@override
void dispose() {
  _fullNameController.dispose();
  _heightController.dispose();
  _weightController.dispose();
  _medicalHistoryController.dispose(); // Thêm dòng này
  super.dispose();
}
}
