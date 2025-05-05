import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_setup_page.dart'; // Import màn hình mới
import 'home_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  WelcomeScreenState createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
  }

  Future<void> _checkInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);

    if (!mounted) return;
    setState(() {
      _hasInternet = isConnected;
    });

    if (!_hasInternet && mounted) {
      _showNoInternetDialog();
    }
  }

  void _showNoInternetDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Internet!'),
          content: const Text('Vui lòng kiểm tra kết nối internet của bạn.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _checkInternetConnection();
              },
              child: const Text('Thử lại'),
            ),
          ],
        );
      },
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(127),
      builder: (BuildContext context) {
        return _LoginDialog();
      },
    );
  }

  void _showSignUpDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(26),
      builder: (BuildContext context) {
        return _SignUpDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/images/welcome_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(26),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _hasInternet
                        ? () {
                            _showLoginDialog();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _hasInternet ? Colors.blue[800] : Colors.grey,
                      padding:
                          EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'ĐĂNG NHẬP',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  OutlinedButton(
                    onPressed: _hasInternet
                        ? () {
                            _showSignUpDialog();
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color:
                              _hasInternet ? Colors.blue[800]! : Colors.grey),
                      padding:
                          EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'ĐĂNG KÝ',
                      style: TextStyle(
                        fontSize: 16,
                        color: _hasInternet ? Colors.blue[800] : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginDialog extends StatefulWidget {
  @override
  __LoginDialogState createState() => __LoginDialogState();
}

class __LoginDialogState extends State<_LoginDialog> {
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmailOrPhone(String value) {
    if (value.isEmpty) {
      return 'Vui lòng nhập email hoặc số điện thoại';
    }
    if (value.contains('@')) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        return 'Email không hợp lệ';
      }
    } else if (!RegExp(r'^0\d{9}$').hasMatch(value)) {
      return 'Số điện thoại không hợp lệ (phải có 10 chữ số, bắt đầu bằng 0)';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    return null;
  }

  Future<bool> _checkFirstLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLogin = prefs.getBool('isFirstLogin') ??
        true; // Mặc định là true nếu chưa có giá trị
    if (isFirstLogin) {
      await prefs.setBool(
          'isFirstLogin', false); // Đánh dấu đã đăng nhập lần đầu
    }
    return isFirstLogin;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đăng nhập',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _emailOrPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Email hoặc số điện thoại',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.person),
                    errorText:
                        _validateEmailOrPhone(_emailOrPhoneController.text),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    errorText: _validatePassword(_passwordController.text),
                  ),
                  obscureText: _obscureText,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    String emailOrPhone = _emailOrPhoneController.text;
                    String password = _passwordController.text;

                    if (emailOrPhone == 'admin' && password == 'admin') {
                      debugPrint("Đăng nhập thành công với tài khoản admin");
                      bool isFirstLogin = await _checkFirstLogin();
                      if (!mounted) return;
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      if (isFirstLogin) {
                        navigator.pushReplacement(
                          MaterialPageRoute(
                              builder: (context) => UserProfileSetupScreen()),
                        );
                      } else {
                        navigator.pushReplacement(
                          MaterialPageRoute(builder: (context) => HomePage()),
                        );
                      }
                    } else {
                      String? emailOrPhoneError =
                          _validateEmailOrPhone(emailOrPhone);
                      String? passwordError = _validatePassword(password);

                      if (emailOrPhoneError != null || passwordError != null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Vui lòng kiểm tra lại thông tin')),
                        );
                      } else {
                        debugPrint(
                            "Đăng nhập với $emailOrPhone và mật khẩu: $password");
                        bool isFirstLogin = await _checkFirstLogin();
                        if (!mounted) return;
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        if (isFirstLogin) {
                          navigator.pushReplacement(
                            MaterialPageRoute(
                                builder: (context) => UserProfileSetupScreen()),
                          );
                        } else {
                          navigator.pushReplacement(
                            MaterialPageRoute(builder: (context) => HomePage()),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'ĐĂNG NHẬP',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Hoặc đăng nhập bằng',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        debugPrint("Đăng nhập bằng Facebook");
                      },
                      child: Image.asset(
                        'lib/assets/icons/facebook-96.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        debugPrint("Đăng nhập bằng Google");
                      },
                      child: Image.asset(
                        'lib/assets/icons/google-96.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        debugPrint("Đăng nhập bằng Zalo");
                      },
                      child: Image.asset(
                        'lib/assets/icons/zalo-96.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpDialog extends StatefulWidget {
  @override
  __SignUpDialogState createState() => __SignUpDialogState();
}

class __SignUpDialogState extends State<_SignUpDialog> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureText = true;
  bool _obscureConfirmText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  String? _validatePhone(String phone) {
    if (phone.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
      return 'Số điện thoại không hợp lệ (phải có 10 chữ số, bắt đầu bằng 0)';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (password.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự';
    }
    if (!RegExp(
            r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
        .hasMatch(password)) {
      return 'Mật khẩu phải chứa ít nhất một chữ cái in hoa, một chữ cái thường, một số và một ký tự đặc biệt';
    }
    return null;
  }

  String? _validateConfirmPassword(String password, String confirmPassword) {
    if (confirmPassword.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu';
    }
    if (password != confirmPassword) {
      return 'Mật khẩu không khớp';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đăng ký',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.email),
                    errorText: _validateEmail(_emailController.text),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.phone),
                    errorText: _validatePhone(_phoneController.text),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    errorText: _validatePassword(_passwordController.text),
                  ),
                  obscureText: _obscureText,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmText
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmText = !_obscureConfirmText;
                        });
                      },
                    ),
                    errorText: _validateConfirmPassword(
                        _passwordController.text,
                        _confirmPasswordController.text),
                  ),
                  obscureText: _obscureConfirmText,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    String email = _emailController.text;
                    String phone = _phoneController.text;
                    String password = _passwordController.text;
                    String confirmPassword = _confirmPasswordController.text;

                    String? emailError = _validateEmail(email);
                    String? phoneError = _validatePhone(phone);
                    String? passwordError = _validatePassword(password);
                    String? confirmPasswordError =
                        _validateConfirmPassword(password, confirmPassword);

                    if (emailError != null ||
                        phoneError != null ||
                        passwordError != null ||
                        confirmPasswordError != null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Vui lòng kiểm tra lại thông tin')),
                      );
                    } else {
                      debugPrint(
                          "Đăng ký với email: $email, số điện thoại: $phone, mật khẩu: $password");
                      if (!mounted) return;
                      final navigator = Navigator.of(context);
                      navigator.pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'ĐĂNG KÝ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Hoặc đăng ký bằng',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        debugPrint("Đăng ký bằng Facebook");
                      },
                      child: Image.asset(
                        'lib/assets/icons/facebook-96.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        debugPrint("Đăng ký bằng Google");
                      },
                      child: Image.asset(
                        'lib/assets/icons/google-96.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        debugPrint("Đăng ký bằng Zalo");
                      },
                      child: Image.asset(
                        'lib/assets/icons/zalo-96.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
