import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; // Thư viện giọng nói
import '../services/thingsboard_service.dart';
import '../widgets/light_control.dart';
import '../widgets/door_control.dart';
import '../widgets/window_control.dart';
import '../widgets/safety_alert.dart';
// quay lại khi f5
import '../services/auth_service.dart';
import 'device_list_screen.dart';

class HomeScreen extends StatefulWidget {// màn hình điều khiển thiết bị
  final String jwtToken;
  final String deviceId;
  final String deviceName;

  const HomeScreen({
    super.key,
    required this.jwtToken,
    required this.deviceId,
    this.deviceName = "Điều khiển Đèn",
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool led1State = false;
  bool led2State = false;
  bool ledAutoMode = true;
  bool doorState = false; // cửa chính
  bool windowState = false;
  bool windowAutoMode = true;
  // [CẢNH BÁO AN TOÀN]
  bool isGas = false;
  bool isFire = false;
  bool isEarthquake = false;
  late ThingsBoardService _service;//để gọi API
  Timer? _timer;// Timer để lấy dữ liệu định kỳ

  
  // false: Timer được phép chạy cập nhật UI.
  // true: Timer phải đứng im, không được sửa UI (để tránh giật lag khi bạn đang bấm). 
  bool _isUserInteracting = false;

  // --- 1. BIẾN CHO GIỌNG NÓI ---
  late stt.SpeechToText _speech;
  bool _isListening = false;//đang nghe hay không
  String _textLog = "Nhấn mic để ra lệnh"; // Dòng chữ hiển thị câu bạn nói

  @override
  void initState() {
    super.initState();
    _service = ThingsBoardService(
      jwtToken: widget.jwtToken,
      deviceId: widget.deviceId,
    );// khởi tạo dịch vụ ThingsBoard
   
    _speech = stt.SpeechToText();// khởi tạo dịch vụ giọng nói
    
    _fetchData();// Lấy dữ liệu
    // Thiết lập Timer để lấy dữ liệu định kỳ mỗi 2 giây
    _timer = Timer.periodic(const Duration(seconds: 2), (t) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }// huỷ Timer
//-------- 1. HÀM LẤY DỮ LIỆU TỪ THINGSBOARD -----
  Future<void> _fetchData() async {
    if (_isUserInteracting) return;

    // 1. Lấy trạng thái nút bấm (Cũ)
    final data = await _service.getAttributes();
    
    // 2. Lấy tín hiệu cảnh báo an toàn (MỚI THÊM)
    final telemetryData = await _service.getLatestTelemetry([
      'fireDetected',
      'gasDetected',
      'earthquakeDetected'
    ]);

    if (mounted) {
      setState(() {
        // Cập nhật nút bấm
        if (data.isNotEmpty) {
          led1State = data['led1State'] ?? false;
          led2State = data['led2State'] ?? false;
          ledAutoMode = data['ledAutoMode'] ?? true;
          doorState = data['doorState'] ?? false;
          windowState = data['windowState'] ?? false;
          windowAutoMode = data['windowAutoMode'] ?? true;
        }

        // Cập nhật cảnh báo an toàn (MỚI THÊM)
        if (telemetryData != null) {
          isGas = (telemetryData['gasDetected']?[0]['value'] == 'true');
          isFire = (telemetryData['fireDetected']?[0]['value'] == 'true');
          isEarthquake = (telemetryData['earthquakeDetected']?[0]['value'] == 'true');
        }
      });
    }
  }
//-------- 2. HÀM GỬI LỆNH ĐIỀU KHIỂN TỚI THINGSBOARD -----
  Future<void> _sendCommand(String method, bool value) async {
    // 1. Đánh dấu là người dùng đang tương tác,timer không được sửa UI
    _isUserInteracting = true;

    // 2. Cập nhật UI ngay lập tức cho mượt
    setState(() {
      if (method == "setLedAutoMode")
        ledAutoMode = value;
      else if (method == "setLed1State")
        led1State = value;
      else if (method == "setLed2State")
        led2State = value;
      else if (method == "setDoor")
        doorState = value;
      else if (method == "setWindowAutoMode")
        windowAutoMode = value; 
      else if (method == "setWindow")
        windowState = value;
  
    });

    // 3. Gửi lệnh
    await _service.sendRpcCommand(method, value ? 1 : 0);

    // 4. Đợi 3 giây cho ESP32 và Server đồng bộ xong xuôi
    await Future.delayed(const Duration(seconds: 3));

    // 5. Thả  cho Timer hoạt động lại
    if (mounted) {
      _isUserInteracting = false;
      _fetchData(); // Lấy dữ liệu mới nhất ngay
    }
  }

  // --- 3. HÀM LẮNG NGHE GIỌNG NÓI ---
  void _listen() async {
    if (!_isListening) {
      // Bắt đầu nghe
      bool available = await _speech.initialize(
        onStatus: (val) => print('Status: $val'),
        onError: (val) => print('Error: $val'),
      );

      if (available) {// nếu dịch vụ sẵn sàng
        setState(() => _isListening = true);

        // localeId: 'vi_VN' để nhận diện tiếng Việt
        _speech.listen(
          localeId: 'vi_VN',
          onResult: (val) {
            setState(() {
              _textLog = val.recognizedWords; // Cập nhật câu nói lên màn hình

              // Nếu nhận diện xong câu (finalResult = true) thì xử lý lệnh
              if (val.hasConfidenceRating && val.confidence > 0) {
                _processVoiceCommand(val.recognizedWords.toLowerCase());
              }
            });
          },
        );
      }
    } else {
      // Dừng nghe
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // --- 4. HÀM PHÂN TÍCH CÂU NÓI -> LỆNH ---
 void _processVoiceCommand(String command) {
    print("Câu lệnh nhận được: $command");

    // ================== 1. XỬ LÝ ĐÈN ==================
    if (command.contains("đèn")) {
      // --- Xử lý chế độ TỰ ĐỘNG của Đèn ---
      if (command.contains("tự động")) {
        if (command.contains("bật") || command.contains("mở")) {
          _sendCommand("setLedAutoMode", true);
          setState(() => _textLog = "Đã bật Tự động Đèn");
        } else if (command.contains("tắt")) {
          _sendCommand("setLedAutoMode", false);
          setState(() => _textLog = "Đã tắt Tự động Đèn");
        }
      }
      // --- Xử lý Bật/Tắt THỦ CÔNG (Chỉ khi Auto = False) ---
      else if (command.contains("bật") || command.contains("mở")) {
        if (ledAutoMode) {
          setState(() => _textLog = "Lỗi: Hãy tắt chế độ Tự động Đèn trước!");
        } else {
          _sendCommand("setLed1State", true);
          _sendCommand("setLed2State", true); // Bật cả 2 đèn cho tiện
        }
      } else if (command.contains("tắt")) {
        if (ledAutoMode) {
          setState(() => _textLog = "Lỗi: Hãy tắt chế độ Tự động Đèn trước!");
        } else {
          _sendCommand("setLed1State", false);
          _sendCommand("setLed2State", false);
        }
      }
    }
    // ================== 2. XỬ LÝ CỬA SỔ (THÊM MỚI) ==================
    else if (command.contains("cửa sổ")) {
      // --- Xử lý chế độ TỰ ĐỘNG của Cửa Sổ ---
      if (command.contains("tự động")) {
        if (command.contains("bật") || command.contains("mở")) {
          _sendCommand("setWindowAutoMode", true);
          setState(() => _textLog = "Đã bật Tự động Cửa sổ");
        } else if (command.contains("tắt")) {
          _sendCommand("setWindowAutoMode", false);
          setState(() => _textLog = "Đã tắt Tự động Cửa sổ");
        }
      }
      // --- Xử lý Mở/Đóng THỦ CÔNG (Chỉ khi Auto = False) ---
      else if (command.contains("mở")) {
        if (windowAutoMode) {
          setState(
            () => _textLog = "Lỗi: Hãy tắt chế độ Tự động Cửa sổ trước!",
          );
        } else {
          _sendCommand("setWindow", true);
        }
      } else if (command.contains("đóng")) {
        if (windowAutoMode) {
          setState(
            () => _textLog = "Lỗi: Hãy tắt chế độ Tự động Cửa sổ trước!",
          );
        } else {
          _sendCommand("setWindow", false);
        }
      }
    }
    // ================== 3. XỬ LÝ CỬA CHÍNH (Giữ nguyên) ==================
    // Cửa chính không có chế độ Auto nên không cần check
    else if (command.contains("cửa") && !command.contains("sổ")) {
      // Logic: Nếu nói "cửa" mà không có chữ "sổ" -> là Cửa chính
      if (command.contains("mở")) {
        _sendCommand("setDoor", true);
      } else if (command.contains("đóng")) {
        _sendCommand("setDoor", false);
      }
    }
  }
  
  // Hàm 1: Đổi mật khẩu
  void _showChangePasswordDialog() {
    TextEditingController passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Đổi Mật Khẩu Cửa", style: TextStyle(color: Colors.teal)),
          content: TextField(
            controller: passController,
            keyboardType: TextInputType.number,
            maxLength: 4, 
            decoration: const InputDecoration(
              hintText: "Nhập 4 số mới...",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                if (passController.text.length == 4) {
                  // Gọi API gửi chuỗi mật khẩu xuống ESP32
                  _service.sendRpcCommand('setNewPass', passController.text);
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã lưu mật khẩu mới vào mạch!"), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Vui lòng nhập đúng 4 chữ số!"), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text("Lưu Mới"),
            )
          ],
        );
      }
    );
  }

  // Hàm 2: Học thẻ RFID
  void _startLearnRFID() {
    _service.sendRpcCommand('learnRFID', true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chế Độ Thêm Thẻ", style: TextStyle(color: Colors.orange)),
        content: const Text(
          "Hệ thống đã sẵn sàng.\n\nHãy cầm thẻ từ MỚI quẹt vào ổ khóa ngay bây giờ để lưu thẻ!",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đã Hiểu"),
          )
        ],
      ),
    );
  }

 // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cửa  & Phòng Khách"),
        backgroundColor: Colors.teal, // <-- THÊM MÀU XANH CHO THANH TIÊU ĐỀ
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await AuthService.clearLastDevice();
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => DeviceListScreen(jwtToken: widget.jwtToken),
                ),
              );
            }
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _listen,
        backgroundColor: _isListening ? Colors.red : Colors.teal, // <-- Đổi sang tông màu Teal
        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
        label: Text(_isListening ? "Đang nghe..." : "Ra lệnh"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16), // Chỉnh lại padding cho chuẩn với phòng ngủ
        child: Column(
          children: [
            // ==========================================
            // 1. KHUNG HIỂN THỊ CHỮ (Đã ép full viền)
            // ==========================================
            Container(
              width: double.infinity, // <-- Lệnh ép khung giãn full 2 bên
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100), // <-- Thêm viền màu xanh
              ),
              child: Text(
                _textLog,
                style: TextStyle(
                  fontStyle: FontStyle.italic, 
                  color: Colors.teal.shade800, // <-- Đổi chữ thành màu xanh cho đồng bộ
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // ===== KHỐI CẢNH BÁO =====
            SafetyAlert(isFire: isFire, isGas: isGas, isEarthquake: isEarthquake),
            const SizedBox(height: 15),
            
            // ===== ĐÈN =====
            LightControl(
              ledAutoMode: ledAutoMode,
              led1State: led1State,
              onAutoModeChanged: (v) => _sendCommand("setLedAutoMode", v),
              onLed1Changed: (v) => _sendCommand("setLed1State", v),
            ),
            const SizedBox(height: 20),

            // ===== CỬA CHÍNH =====
            DoorControl(
              doorState: doorState,
              onChanged: (v) => _sendCommand("setDoor", v),
            ),
            const Divider(height: 40),

            // ===== CỬA SỔ =====
            WindowControl(
              windowAutoMode: windowAutoMode,
              windowState: windowState,
              onAutoModeChanged: (v) => _sendCommand("setWindowAutoMode", v),
              onWindowChanged: (v) => _sendCommand("setWindow", v),
            ),

            // ==================================================
            // KHỐI CÀI ĐẶT BẢO MẬT (Đổi MK & RFID)
            // ==================================================
            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const Text(
              "CÀI ĐẶT BẢO MẬT",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 15),

            // Nút Đổi mật khẩu
            Card(
              elevation: 2,
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.dialpad, color: Colors.white)),
                title: const Text("Đổi mật khẩu Keypad"),
                subtitle: const Text("Thay đổi 4 số mở cửa"),
                trailing: const Icon(Icons.edit),
                onTap: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: 10),

            // Nút Thêm Thẻ RFID
            Card(
              elevation: 2,
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.nfc, color: Colors.white)),
                title: const Text("Thêm thẻ RFID mới"),
                subtitle: const Text("Ghi đè mã thẻ cũ"),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: _startLearnRFID,
              ),
            ),
            
            const SizedBox(height: 80), // Tạo khoảng trống dưới cùng
          ],
        ),
      ),
    );
  }
}