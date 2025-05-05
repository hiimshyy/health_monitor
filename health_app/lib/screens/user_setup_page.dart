import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class UserProfileSetupScreen extends StatefulWidget {
  const UserProfileSetupScreen({super.key});

  @override
  UserProfileSetupScreenState createState() => UserProfileSetupScreenState();
}

class UserProfileSetupScreenState extends State<UserProfileSetupScreen> {
  final _fullNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedGender;
  final List<String> _genders = ['Nam', 'Nữ', 'Khác'];

  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;
  final List<int> _days = List.generate(31, (index) => index + 1);
  final List<int> _months = List.generate(12, (index) => index + 1);
  final List<int> _years =
      List.generate(100, (index) => DateTime.now().year - index);

  @override
  void dispose() {
    _fullNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    String fullName = _fullNameController.text;
    String? gender = _selectedGender;
    String height = _heightController.text;
    String weight = _weightController.text;

    if (fullName.isEmpty ||
        gender == null ||
        _selectedDay == null ||
        _selectedMonth == null ||
        _selectedYear == null ||
        height.isEmpty ||
        weight.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ thông tin'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Lưu thông tin cá nhân vào SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('fullName', fullName);
      await prefs.setString('gender', gender);
      await prefs.setInt('birthDay', _selectedDay!);
      await prefs.setInt('birthMonth', _selectedMonth!);
      await prefs.setInt('birthYear', _selectedYear!);
      await prefs.setString('height', height);
      await prefs.setString('weight', weight);

      debugPrint("Lưu thông tin: Họ và tên: $fullName, Giới tính: $gender, "
          "Ngày sinh: $_selectedDay/$_selectedMonth/$_selectedYear, "
          "Chiều cao: $height cm, Cân nặng: $weight kg");

      // Chuyển hướng đến HomePage
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Thiết lập thông tin',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background color
          Positioned.fill(
            child: Container(
              color: Colors.white,
            ),
          ),
          // Content
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),
                        Text(
                          '*Vui lòng điền chính xác các thông tin!',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        // Form fields
                        // Name and Gender
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: _fullNameController,
                                textCapitalization: TextCapitalization.words,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Họ và tên',
                                  labelStyle:
                                      TextStyle(color: Colors.blue[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[800]!),
                                  ),
                                  prefixIcon: Icon(Icons.person,
                                      color: Colors.blue[800]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _selectedGender,
                                decoration: InputDecoration(
                                  labelText: 'Giới tính',
                                  labelStyle:
                                      TextStyle(color: Colors.blue[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[800]!),
                                  ),
                                  prefixIcon:
                                      Icon(Icons.wc, color: Colors.blue[800]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _genders.map((String gender) {
                                  return DropdownMenuItem<String>(
                                    value: gender,
                                    child: Text(gender,
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedGender = newValue;
                                  });
                                },
                                dropdownColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<int>(
                                value: _selectedDay,
                                decoration: InputDecoration(
                                  labelText: 'Ngày',
                                  labelStyle:
                                      TextStyle(color: Colors.blue[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[800]!),
                                  ),
                                  prefixIcon: Icon(Icons.calendar_today,
                                      color: Colors.blue[800]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _days.map((int day) {
                                  return DropdownMenuItem<int>(
                                    value: day,
                                    child: Text(day.toString(),
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  setState(() {
                                    _selectedDay = newValue;
                                  });
                                },
                                dropdownColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<int>(
                                value: _selectedMonth,
                                decoration: InputDecoration(
                                  labelText: 'Tháng',
                                  labelStyle:
                                      TextStyle(color: Colors.blue[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[800]!),
                                  ),
                                  prefixIcon: Icon(Icons.calendar_today,
                                      color: Colors.blue[800]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _months.map((int month) {
                                  return DropdownMenuItem<int>(
                                    value: month,
                                    child: Text(month.toString(),
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  setState(() {
                                    _selectedMonth = newValue;
                                  });
                                },
                                dropdownColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 6,
                              child: DropdownButtonFormField<int>(
                                value: _selectedYear,
                                decoration: InputDecoration(
                                  labelText: 'Năm',
                                  labelStyle:
                                      TextStyle(color: Colors.blue[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[800]!),
                                  ),
                                  prefixIcon: Icon(Icons.calendar_today,
                                      color: Colors.blue[800]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _years.map((int year) {
                                  return DropdownMenuItem<int>(
                                    value: year,
                                    child: Text(year.toString(),
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  setState(() {
                                    _selectedYear = newValue;
                                  });
                                },
                                dropdownColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Chiều cao (cm)',
                                  labelStyle:
                                      TextStyle(color: Colors.blue[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[800]!),
                                  ),
                                  prefixIcon: Icon(Icons.height,
                                      color: Colors.blue[800]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Cân nặng (kg)',
                                  labelStyle:
                                      TextStyle(color: Colors.blue[900]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide:
                                        BorderSide(color: Colors.blue[800]!),
                                  ),
                                  prefixIcon: Icon(Icons.monitor_weight,
                                      color: Colors.blue[800]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Submit button at bottom
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Bắt đầu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
