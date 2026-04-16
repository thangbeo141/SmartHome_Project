import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'device1_screen.dart'; // Đổi lại tên file cho đúng với dự án của bạn
import 'device2_screen.dart'; 
import 'login_screen.dart';

class DeviceListScreen extends StatefulWidget {
  final String jwtToken; // token chìa khoá để gọi API
  const DeviceListScreen({super.key, required this.jwtToken});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _devices = []; // danh sách thiết bị
  bool _isLoading = true; // trạng thái đang tải

  @override
  void initState() {
    super.initState();
    _fetchDevices(); 
  }

  Future<void> _fetchDevices() async {
    final devices = await _authService.getUserDevices();
    if (mounted) {
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- LẤY ID CỦA CON ESP32 TRUNG TÂM ---
    // Giả sử ThingsBoard trả về ít nhất 1 thiết bị, ta lấy thiết bị đầu tiên làm Gateway
    String gatewayId = "";
    String gatewayName = "";
    if (_devices.isNotEmpty) {
      gatewayId = _devices[0]['id']['id'];
      gatewayName = _devices[0]['name'] ?? 'Gateway Device';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chọn Khu Vực"),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const Center(child: Text("Không tìm thấy thiết bị ESP32 nào trên ThingsBoard!"))
          : ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // ==========================================
                // THẺ 1: KHU VỰC CỬA & PHÒNG KHÁCH (Màn hình 1)
                // ==========================================
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: const Icon(Icons.sensor_door, size: 50, color: Colors.blue),
                    title: const Text(
                      "Khu Vực 1: Cửa & Phòng Khách",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text("Dùng chung Gateway: ...${gatewayId.substring(0, 8)}"),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                    onTap: () async {
                      // Vẫn lưu vào bộ nhớ tạm là đang dùng màn 1
                      await AuthService.saveLastDevice(gatewayId, gatewayName, "TYPE_1");
                      
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen( // Tên class màn hình 1 của bạn
                              jwtToken: widget.jwtToken,
                              deviceId: gatewayId, // <-- TRUYỀN ID CỦA ESP32 VÀO
                              deviceName: gatewayName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),

                // ==========================================
                // THẺ 2: KHU VỰC PHÒNG NGỦ (Màn hình 2)
                // ==========================================
                Card(
                  elevation: 4,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: const Icon(Icons.bed, size: 50, color: Colors.orange),
                    title: const Text(
                      "Khu Vực 2: Phòng Ngủ",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text("Dùng chung Gateway: ...${gatewayId.substring(0, 8)}"),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.orange),
                    onTap: () async {
                      // Vẫn lưu vào bộ nhớ tạm là đang dùng màn 2
                      await AuthService.saveLastDevice(gatewayId, gatewayName, "TYPE_2");

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Device2Screen(
                              jwtToken: widget.jwtToken,
                              deviceId: gatewayId, // <-- VẪN TRUYỀN ID CỦA ESP32 ĐÓ VÀO
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}