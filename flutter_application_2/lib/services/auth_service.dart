import 'package:http/http.dart' as http; // thư viện để gửi yêu cầu mang (get, post)
import 'dart:convert'; // thư viện để chuyển đổi giua JSON và Map(object trong dart)
import 'package:shared_preferences/shared_preferences.dart'; // thư viện để lưu trữ dữ nhỏ gọn trên thiết bị
import '../constants.dart';

class AuthService {
  static String? _jwtToken; // ?: biến có thê chứa giá trị null
  // static : thuộc về class   _:private
  //----------LOGIN(xác thực)----------
  Future<bool> login(String email, String password) async {
    // async làm hàm bất đồng bộ.await để tạm dừng trong hàm async cho đến khi tác vụ xong.
    final url = Uri.parse('$THINGSBOARD_SERVER/api/auth/login');
    // Tạo địa chỉ URL để gửi yêu cầu đăng nhập
    try {
      // Gửi yêu cầu POST lên server
      final response = await http.post(//tạm dừng chờ phản hồi
        url,
        headers: {
          'Content-Type': 'application/json',
        }, // nói với server dữ liệu có dạng json
        //chuyển dổi Map thành JSON
        body: jsonEncode({
          'username': email,
          'password': password,
        }), 
      );
      //nếu server trả về mã 200 (thành công)
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); //json -> MAP
        _jwtToken = data['token'];// lấy token từ map luu vào biến

        // Lưu token xuống bộ nhớ thiết bị
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _jwtToken!);// !: chắc chắn không null

        return true; // đăng nhập OK
      }
    } catch (e) {
      print("Login error: $e");
    }
    return false; // đăng nhập thất bại
  }

  static String? getToken() => _jwtToken;// hàm lấy token

  static Future<void> loadToken() async {// hàm load token từ bộ nhớ thiết bị
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('jwt_token');
  }

  // ==== 2. LẤY DANH SÁCH THIẾT BỊ USER ĐƯỢC QUYỀN TRUY CẬP ====

  // Biến lưu ID của Customer mà User thuộc về
  String? _currentCustomerId;

  // Hàm lấy thông tin thiết bị của User
  Future<List<dynamic>> getUserDevices() async {
    if (_jwtToken == null) return [];// nếu chưa có token thì trả về rỗng

    // --- BƯỚC 1: TÌM XEM USER NÀY THUỘC VỀ CUSTOMER NÀO ---
    if (_currentCustomerId == null) {
      // Gửi yêu cầu lấy thông tin User hiện tại
      final userUrl = Uri.parse('$THINGSBOARD_SERVER/api/auth/user');
      final userResponse = await http.get(
        userUrl,
        headers: {'X-Authorization': 'Bearer $_jwtToken'},// gửi kèm token để xác thực
      );

      if (userResponse.statusCode != 200) return [];// lỗi thì trả về rỗng
      
      final userData = jsonDecode(userResponse.body);// json -> map
      final customerIdObject = userData['customerId'];// lấy thông tin customerId từ map

      // Kiểm tra nếu User thuộc về một Customer thực sự
      if (customerIdObject != null && customerIdObject['id'] != null) {
        // nếu có Customer ID thì lưu lại
        _currentCustomerId = customerIdObject['id'] as String;
      } else {
        // Nếu không có Customer ID (ví dụ: User không thuộc Customer nào), trả về rỗng
        return [];
      }
    }

    // Nếu Customer ID vẫn null hoặc là ID hệ thống (dành cho Admin/Tenant)
    if (_currentCustomerId == null ||
        _currentCustomerId == '13814000-1111-2222-3333-444444444444') {
      return [];
    }

    // --- BƯỚC 2: LẤY DANH SÁCH THIẾT BỊ THUỘC VỀ CUSTOMER NÀY ---
    // Tạo URL để lấy danh sách thiết bị
    final devicesUrl = Uri.parse(
      '$THINGSBOARD_SERVER/api/customer/$_currentCustomerId/devices?pageSize=100&page=0',
    );
    // Gửi yêu cầu GET để lấy danh sách thiết bị
    final devicesResponse = await http.get(
      devicesUrl,
      headers: {'X-Authorization': 'Bearer $_jwtToken'},
    );

    if (devicesResponse.statusCode == 200) {
      final data = jsonDecode(devicesResponse.body);
      return data['data'] ?? [];
    } else {
      // Nếu vẫn lỗi 400 (Bad Request), thông báo mã lỗi và Body để debug
      print('DEVICES API STATUS: ${devicesResponse.statusCode}');
      print('DEVICES API BODY: ${devicesResponse.body}');
    }

    return [];
  }


  // ==== 3. LƯU VẾT THIẾT BỊ ĐÃ CHỌN  ====

  static String? _lastDeviceId;
  static String? _lastDeviceName;
  static String? _lastDeviceType; // "TYPE_1" hoặc "TYPE_2"

  // Hàm lưu lại thiết bị vừa chọn
  static Future<void> saveLastDevice(
    String id,
    String name,
    String type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // Lưu vào ổ cứng máy (shared preferences) để tắt app vẫn nhớ
    await prefs.setString('last_device_id', id);
    await prefs.setString('last_device_name', name);
    await prefs.setString('last_device_type', type);
    // Lưu vào biến tạm trong app
    _lastDeviceId = id;
    _lastDeviceName = name;
    _lastDeviceType = type;
  }

  // Hàm xóa vết (Dùng khi đăng xuất hoặc khi bấm nút Back quay lại danh sách)
  static Future<void> clearLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    // Xóa khỏi ổ cứng máy
    await prefs.remove('last_device_id');
    await prefs.remove('last_device_name');
    await prefs.remove('last_device_type');
    // Xóa khỏi biến tạm trong app
    _lastDeviceId = null;
    _lastDeviceName = null;
    _lastDeviceType = null;
  }

  // Hàm load thông tin thiết bị cũ lên
  static Future<void> loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    // Load từ ổ cứng máy
    _lastDeviceId = prefs.getString('last_device_id');
    _lastDeviceName = prefs.getString('last_device_name');
    _lastDeviceType = prefs.getString('last_device_type');
  }

  // Getter để lấy dữ liệu ra dùng
  static String? get lastDeviceId => _lastDeviceId;
  static String? get lastDeviceName => _lastDeviceName;
  static String? get lastDeviceType => _lastDeviceType;
}


