// lib/main.dart

import 'package:flutter/material.dart';// thư viện giao diện
import 'screens/login_screen.dart';   // màn hình đăng nhập
import 'screens/device_list_screen.dart'; // danh sách thiết bị
import 'services/auth_service.dart';//bộ xử lý lưu trữ Token và thông tin đăng nhập
import 'screens/device1_screen.dart'; // Import màn hình 1
import 'screens/device2_screen.dart'; // Import màn hình 2

void main() async {
  WidgetsFlutterBinding.ensureInitialized();// đảm bảo hệ thống Flutter đã được khởi tạo
// 1. Gọi AuthService để lấy Token từ bộ nhớ máy lên.
  // Dùng 'await' để bắt App phải đợi lấy xong mới chạy tiếp.
  await AuthService.loadToken();

  // 2. Lấy thông tin thiết bị cuối cùng người dùng từng mở (Ví dụ: đang ở phòng ngủ).
  await AuthService.loadLastDevice();

  // 3. Sau khi chuẩn bị xong dữ liệu, bắt đầu vẽ giao diện MyApp.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    //  Kiểm tra xem token có tồn tại không
    final String? token = AuthService.getToken();
    final String? lastId = AuthService.lastDeviceId;
    final String? lastName = AuthService.lastDeviceName;
    final String? lastType = AuthService.lastDeviceType;// giao diện phù hợp  
    
    // Logic chọn màn hình khởi động
    Widget startScreen;
    if (token == null) {
      // 1. Chưa đăng nhập
      startScreen = const LoginScreen();
    } else {
      // 2. Đã đăng nhập, kiểm tra xem có thiết bị cũ không
      if (lastId != null && lastType == "TYPE_2") {
        // Vào thẳng Device 2
        startScreen = Device2Screen(jwtToken: token, deviceId: lastId);
      } else if (lastId != null && lastType == "TYPE_1") {
        // Vào thẳng Device 1
        startScreen = HomeScreen(
          jwtToken: token,
          deviceId: lastId,
          deviceName: lastName ?? "Device",
        );
      } else {
        // Không có thiết bị cũ -> Vào danh sách chọn
        startScreen = DeviceListScreen(jwtToken: token);
      }
    }
    // --- CẤU HÌNH GIAO DIỆN CHUNG ---
    return MaterialApp(
      debugShowCheckedModeBanner:
          false, // Tắt cái chữ "Debug" nhỏ ở góc phải màn hình
      title: 'Smart Home ThingsBoard', // Tên App khi đa nhiệm
      theme: ThemeData(primarySwatch: Colors.blue), // Màu chủ đạo là Xanh dương
      home:
          startScreen, // <--- Đưa màn hình đã quyết định ở trên vào đây để hiển thị
    );
  }
}
