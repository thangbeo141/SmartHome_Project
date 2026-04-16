// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../constants.dart';
import 'device_list_screen.dart'; // Chuyển hướng sang đây

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Controllers để lấy dữ liệu từ TextField cho email và password
  // Khởi tạo với giá trị mặc định từ constants.dart để dễ test
  final TextEditingController _emailController = TextEditingController(
    text: THINGSBOARD_USER_EMAIL,
  );
  // 2. Controller cho password
  final TextEditingController _passwordController = TextEditingController(
    text: THINGSBOARD_USER_PASSWORD,
  );
  // 3. Biến để theo dõi trạng thái loading
  bool _isLoading = false;
//-------- Hàm xử lý khi bấm nút Đăng nhập --------
  void _handleLogin() async {
    // Bật trạng thái loading
    setState(() => _isLoading = true);
    // Gọi hàm login từ AuthService
    final authService = AuthService();
    final success = await authService.login(
      _emailController.text,
      _passwordController.text,
    );
    // Kiểm tra an toàn: nếu màn hình này đã tắt (người dùng bấm Back) thì không làm gì nữa
    if (!mounted) return;

    setState(() => _isLoading = false);// Tắt trạng thái loading
    // Kiểm tra kết quả đăng nhập
    if (success) {
      // Đăng nhập thành công -> Sang màn hình chọn thiết bị
      final token = AuthService.getToken();
      if (token != null) {
        // Chuyển hướng sang DeviceListScreen và truyền token
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DeviceListScreen(jwtToken: token),
          ),
        );
      }
    } else {
      // Đăng nhập thất bại -> Hiện thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập thất bại! Kiểm tra lại Email/Pass'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập Smart Home')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),//căn lề
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,// căn giữa màn hình
          children: [
            // TextField cho email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),// khoảng cách giữa 2 TextField
            // TextField cho password
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
            ),
            const SizedBox(height: 20),// khoảng cách trước nút Đăng nhập
            //nút bấm Đăng nhập
            _isLoading
                ? const CircularProgressIndicator()// Hiện vòng tròn loading khi đang đăng nhập
                : ElevatedButton(
                    onPressed: _handleLogin,// Gọi hàm xử lý đăng nhập khi bấm nút
                    child: const Text('Đăng nhập'),
                  ),
          ],
        ),
      ),
    );
  }
}
