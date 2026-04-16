import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/thingsboard_service.dart';
import '../widgets/sensor_card.dart';//nhiệt đô,
import '../widgets/control_card.dart';//đèn quạt PN
import '../widgets/safety_alert.dart';// cảnh báo 
//khi nhấn f5
import '../services/auth_service.dart';
import 'device_list_screen.dart';
//---------------------------------------
class Device2Screen extends StatefulWidget {
  final String jwtToken;
  final String deviceId;

  const Device2Screen({
    super.key,
    required this.jwtToken,
    required this.deviceId,
  });

  @override
  State<Device2Screen> createState() => _Device2ScreenState();
}

class _Device2ScreenState extends State<Device2Screen> {
  late ThingsBoardService _tbService;
  Timer? _timer;

  // --- 1. BIẾN DỮ LIỆU CẢM BIẾN ---
  double tLiving = 0;
  double hLiving = 0;
  double tBed = 0;
  double hBed = 0;

  // --- 2. BIẾN TRẠNG THÁI ---
  bool fanState = false;
  bool lightState = false;

  // [QUAN TRỌNG] Biến An Toàn (Gas & Lửa)
  bool isGas = false;
  bool isFire = false;
  bool isEarthquake = false;
  // Cờ chặn Timer khi đang bấm nút
  bool _isUserInteracting = false;
  
  // --- 3. BIẾN GIỌNG NÓI (THÊM MỚI) ---
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _textLog = "Nhấn mic để ra lệnh";

  @override
  void initState() {
    super.initState();
    _tbService = ThingsBoardService(
      jwtToken: widget.jwtToken,
      deviceId: widget.deviceId,
    );
    
    // --- THÊM DÒNG NÀY VÀO ---
    _speech = stt.SpeechToText(); 
    // -------------------------

    _fetchData();

    // Tự động cập nhật mỗi 2 giây
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- 3. HÀM LẤY DỮ LIỆU (ĐÃ TÁCH RA 2 LUỒNG) ---
  Future<void> _fetchData() async {
    if (_isUserInteracting) return;

    // BƯỚC 1: Lấy Nhiệt độ/Độ ẩm từ TELEMETRY (Vì nó biến đổi liên tục)
    final telemetryData = await _tbService.getLatestTelemetry([
      'tempLiving',
      'humLiving',
      'tempBed',
      'humBed',
      'fireDetected',
      'gasDetected',
      'earthquakeDetected'
    ]);

    // BƯỚC 2: Lấy Trạng thái Đèn/Quạt từ ATTRIBUTES (Theo yêu cầu của bạn)
    // Lưu ý: Key phải khớp với code ESP32 (fanState, lightState)
    final attributesData = await _tbService.getAttributes(
      keys: "fanState,lightState",
    );

    if (mounted) {
      setState(() {
        // --- Cập nhật Cảm biến (Telemetry) ---
        if (telemetryData != null) {
          tLiving =
              double.tryParse(
                telemetryData['tempLiving']?[0]['value'] ?? '0',
              ) ??
              0;
          hLiving =
              double.tryParse(telemetryData['humLiving']?[0]['value'] ?? '0') ??
              0;
          tBed =
              double.tryParse(telemetryData['tempBed']?[0]['value'] ?? '0') ??
              0;
          hBed =
              double.tryParse(telemetryData['humBed']?[0]['value'] ?? '0') ?? 0;
          isGas = (telemetryData['gasDetected']?[0]['value'] == 'true');
          isFire = (telemetryData['fireDetected']?[0]['value'] == 'true');
          isEarthquake =(telemetryData['earthquakeDetected']?[0]['value'] == 'true');
        }

        // --- Cập nhật Nút bấm (Attributes) ---
        // Service của bạn đã xử lý _safeParse nên ở đây nhận được bool luôn
        if (attributesData.isNotEmpty) {
          fanState = attributesData['fanState'] ?? false;
          lightState = attributesData['lightState'] ?? false;
        }
      });
    }
  }
  
  // --- 4. HÀM GỬI LỆNH (RPC) ---
  Future<void> _sendCommand(String method, bool value) async {
    _isUserInteracting = true; // Khóa Timer

    setState(() {
      if (method == 'setFanState') fanState = value;
      if (method == 'setLightState') lightState = value;
    });

    // Gửi lệnh RPC
    await _tbService.sendRpcCommand(method, value);

    // Đợi 3s để ESP32 xử lý và cập nhật lại Attributes trên Server
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      _isUserInteracting = false; // Mở khóa Timer
      _fetchData(); // Lấy lại dữ liệu từ Attributes để đồng bộ
    }
  }
  
  // ================== HÀM XỬ LÝ GIỌNG NÓI ==================

  void _listen() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (val) {
            print('Status: $val');
            if (val == 'done' || val == 'notListening') {
              setState(() => _isListening = false);
            }
          },
          onError: (val) {
            print('Error: $val');
            setState(() => _textLog = "Lỗi: ${val.errorMsg}");
          },
        );

        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            // localeId: 'vi_VN', // Mở dòng này nếu muốn ép buộc tiếng Việt
            onResult: (val) {
              setState(() {
                _textLog = val.recognizedWords;
                if (val.hasConfidenceRating && val.confidence > 0) {
                  _processVoiceCommand(val.recognizedWords.toLowerCase());
                }
              });
            },
          );
        } else {
          _logAndPrint("Lỗi: Không khởi động được Micro");
        }
      } catch (e) {
        _logAndPrint("Lỗi Code: $e");
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _processVoiceCommand(String command) {
    _logAndPrint("Lệnh: $command");

    // --- XỬ LÝ QUẠT ---
    if (command.contains("quạt")) {
      if (command.contains("bật") || command.contains("mở")) {
        _sendCommand("setFanState", true);
        _logAndPrint("-> Đã bật Quạt");
      } else if (command.contains("tắt")) {
        _sendCommand("setFanState", false);
        _logAndPrint("-> Đã tắt Quạt");
      }
    }
    // --- XỬ LÝ ĐÈN ---
    else if (command.contains("đèn")) {
      if (command.contains("bật") || command.contains("mở")) {
        _sendCommand("setLightState", true);
        _logAndPrint("-> Đã bật Đèn ngủ");
      } else if (command.contains("tắt")) {
        _sendCommand("setLightState", false);
        _logAndPrint("-> Đã tắt Đèn ngủ");
      }
    }
    // --- XỬ LÝ TẮT HẾT ---
    else if (command.contains("tắt hết") || command.contains("đi ngủ")) {
      _sendCommand("setFanState", false);
      _sendCommand("setLightState", false);
      _logAndPrint("-> Chúc ngủ ngon (Tắt hết)");
    }
  }

  void _logAndPrint(String msg) {
    print(msg);
    setState(() => _textLog = msg);
  }

  
 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Phòng Ngủ & An Toàn"),
        backgroundColor: Colors.teal,
        centerTitle: true,
      // --- THÊM ĐOẠN NÀY ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // 1. Xóa nhớ thiết bị
            await AuthService.clearLastDevice();

            // 2. Về danh sách
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => DeviceListScreen(jwtToken: widget.jwtToken),
                ),
              );
            }
          },
        ),
        // ---------------------
      ),
      // --- NÚT MICRO ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _listen,
        backgroundColor: _isListening ? Colors.red : Colors.teal,
        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
        label: Text(_isListening ? "Đang nghe..." : "Ra lệnh"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- KHUNG HIỂN THỊ LỜI NÓI ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Text(
                _textLog,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.teal.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // --- 1. KHỐI CẢNH BÁO (Đã tách ra file riêng) ---
            // Chỉ cần truyền biến vào là xong, rất gọn!
            SafetyAlert(isFire: isFire, isGas: isGas,isEarthquake:isEarthquake),

            // --- 2. KHỐI CẢM BIẾN ---
            SensorCard(
              title: "PHÒNG KHÁCH",
              temperature: tLiving,
              humidity: hLiving,
              color: Colors.orange,
            ),
            const SizedBox(height: 15),
            SensorCard(
              title: "PHÒNG NGỦ",
              temperature: tBed,
              humidity: hBed,
              color: Colors.blue,
            ),

            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 10),

            // --- 3. KHỐI ĐIỀU KHIỂN ---
            const Text(
              "BẢNG ĐIỀU KHIỂN",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 15),

            ControlCard(
              title: "Quạt Phòng Ngủ",
              value: fanState,
              icon: Icons.mode_fan_off_outlined,
              activeColor: Colors.green,
              onChanged: (v) => _sendCommand("setFanState", v),
            ),
            const SizedBox(height: 15),
            ControlCard(
              title: "Đèn Phòng Ngủ",
              value: lightState,
              icon: Icons.lightbulb,
              activeColor: Colors.orange,
              onChanged: (v) => _sendCommand("setLightState", v),
            ),
          ],
        ),
      ),
    );
  }
}
