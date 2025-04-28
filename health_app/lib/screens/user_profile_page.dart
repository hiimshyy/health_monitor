import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

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
  bool isEditing = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      fullName = prefs.getString('fullName') ?? '';
      gender = prefs.getString('gender') ?? '';
      birthDay = prefs.getInt('birthDay');
      birthMonth = prefs.getInt('birthMonth');
      birthYear = prefs.getInt('birthYear');
      height = prefs.getString('height') ?? '';
      weight = prefs.getString('weight') ?? '';

      _fullNameController.text = fullName;
      _heightController.text = height;
      _weightController.text = weight;
    });
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('fullName', _fullNameController.text);
      await prefs.setString('gender', gender);

      if (birthDay != null) await prefs.setInt('birthDay', birthDay!);
      if (birthMonth != null) await prefs.setInt('birthMonth', birthMonth!);
      if (birthYear != null) await prefs.setInt('birthYear', birthYear!);

      await prefs.setString('height', _heightController.text);
      await prefs.setString('weight', _weightController.text);

      setState(() {
        isEditing = false;
        fullName = _fullNameController.text;
        height = _heightController.text;
        weight = _weightController.text;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu thông tin thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi lưu thông tin'),
            backgroundColor: Colors.red,
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
                  value: gender.isEmpty ? null : gender,
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng chọn giới tính';
                    }
                    return null;
                  },
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
    super.dispose();
  }
}
