import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ThingsBoardService {
  final String jwtToken;
  final String deviceId;

  ThingsBoardService({required this.jwtToken, required this.deviceId});

  // --- 1. LẤY TRẠNG THÁI (Sửa logic parse JSON) ---

  Future<Map<String, dynamic>?> getLatestTelemetry(List<String> keys) async {
    try {
      // Chuyển List ['temp', 'hum'] thành chuỗi "temp,hum"
      String keysStr = keys.join(',');

      // Lưu ý: Dùng biến THINGSBOARD_SERVER giống code cũ của bạn
      final url =
          "$THINGSBOARD_SERVER/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries?keys=$keysStr";

      final response = await http.get(
        Uri.parse(url),
        headers: {"X-Authorization": "Bearer $jwtToken"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("❌ Lỗi Telemetry: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> getAttributes({
    String keys = "led1State,led2State,ledAutoMode,doorState,windowState,windowAutoMode,fanState,lightState",
  }) async {
    try {
      final url =
          "$THINGSBOARD_SERVER/api/plugins/telemetry/DEVICE/$deviceId/values/attributes?keys=$keys";

      final response = await http.get(
        Uri.parse(url),
        headers: {"X-Authorization": "Bearer $jwtToken"},
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(
          response.body,
        ); // Để dynamic để check kiểu
        final Map<String, dynamic> result = {};

        // [SỬA QUAN TRỌNG] Kiểm tra xem dữ liệu là List hay Map
        if (data is List) {
          // Trường hợp trả về: [{"key":"led1", "value":0}, ...]
          for (var item in data) {
            if (item is Map) {
              String key = item['key'];
              dynamic val = item['value'];
              result[key] = _safeParse(val);
            }
          }
        } else if (data is Map) {
          // Trường hợp trả về Map (đề phòng server đổi kiểu)
          data.forEach((key, value) {
            // Đôi khi value lại là một List chứa object
            if (value is List && value.isNotEmpty) {
              result[key] = _safeParse(value[0]['value']);
            } else {
              result[key] = _safeParse(value);
            }
          });
        }

        return result;
      }
    } catch (e) {
      print("❌ Lỗi Service GET: $e");
    }
    return {};
  }

  // --- 2. GỬI LỆNH  ---
  Future<bool> sendRpcCommand(String method, dynamic params) async {
    try {
      final url = "$THINGSBOARD_SERVER/api/plugins/rpc/oneway/$deviceId";
      final body = jsonEncode({"method": method, "params": params});

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "X-Authorization": "Bearer $jwtToken",
        },
        body: body,
      );
      return response.statusCode == 200;
    } catch (e) {
      print("❌ Lỗi Service POST: $e");
      return false;
    }
  }

  // --- HÀM ÉP KIỂU (Đã đơn giản hóa) ---
  dynamic _safeParse(dynamic val) {
    if (val == null) return false;

    // Nếu giá trị là boolean
    if (val is bool) return val;

    // Nếu giá trị là số (0 hoặc 1)
    if (val is num) return val == 1;

    // Nếu giá trị là chuỗi ("true", "1", "on")
    if (val is String) {
      String s = val.toString().toLowerCase();
      return (s == "true" || s == "1" || s == "on");
    }

    return false;
  }
}
