#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <WebServer.h> // <--- THÊM THƯ VIỆN NÀY ĐỂ MỞ CỔNG CHO PYTHON

// ================= CẤU HÌNH MẠNG & SERVER =================
const char* ssid = "Kim Lien";         // <-- ĐIỀN TÊN WIFI
const char* password = "kimducthang141";        // <-- ĐIỀN MẬT KHẨU WIFI
const char* mqtt_server = "demo.thingsboard.io"; 
const char* token = "fOxrJ9DQPhbIVu4eI7KM"; // <-- ĐIỀN TOKEN CỦA THIẾT BỊ
// 👇 THÊM 3 DÒNG NÀY ĐỂ CHỐT CỨNG IP
IPAddress staticIP(192, 168, 1, 100); // 👈 Ép cứng thành đuôi .100 cho số nó đẹp và đỡ trùng
IPAddress gateway(192, 168, 1, 1);    // 👈 Cổng mạng mặc định của nhà bác sĩ
IPAddress subnet(255, 255, 255, 0);
// 👇 THÊM 2 DÒNG NÀY ĐỂ THÔNG ĐƯỜNG INTERNET
IPAddress primaryDNS(8, 8, 8, 8);   // DNS chính của Google
IPAddress secondaryDNS(8, 8, 4, 4); // DNS phụ của Google

WiFiClient espClient;
PubSubClient client(espClient);

// Khởi tạo WebServer chạy trên cổng 80 cho Python
WebServer server(80);

// Khai báo chân cho Serial2 (Giao tiếp với STM32)
#define RXD2 22
#define TXD2 23

// ================= HÀM KẾT NỐI WIFI =================
void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Dang ket noi WiFi: ");
  Serial.println(ssid);
  // 👇 THÊM DÒNG NÀY VÀO TRƯỚC WIFI.BEGIN
  // if (!WiFi.config(staticIP, gateway, subnet, primaryDNS, secondaryDNS)) {
  //   Serial.println("Loi: Khong the cau hinh IP Tinh!");
  // }

  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi OK!");
  
  // 👇 IN IP RA ĐỂ BÁC SĨ DÁN VÀO PYTHON 👇
  Serial.print(">>> IP CUA ESP32 LA (Copy cho Python): ");
  Serial.println(WiFi.localIP());
  Serial.println("=========================================");
}

// ================= HÀM NHẬN LỆNH TỪ APP (THINGSBOARD) =================
void callback(char* topic, byte* payload, unsigned int length) {
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, payload, length);
  
  if (error) {
    Serial.println("Loi doc JSON!");
    return;
  }

  String method = doc["method"]; // Tên nút bấm
  bool params = doc["params"];   // Trạng thái (true/false)

  // In ra màn hình máy tính để dễ debug
  Serial.print(">>> APP GOI LENH: ");
  Serial.print(method);
  Serial.print(" -> ");
  Serial.println(params ? "MO" : "DONG");

  // CHỈ XỬ LÝ ĐÚNG LỆNH CỬA CHÍNH
  if (method == "setDoor") {
    if (params == true) {
      Serial2.println("DOOR:1"); 
      Serial.println("[GUI SANG STM32] DOOR:1");
    } else {
      Serial2.println("DOOR:0"); 
      Serial.println("[GUI SANG STM32] DOOR:0");
    }
  }
  // XỬ LÝ NÚT GẠT: CHẾ ĐỘ TỰ ĐỘNG CỬA SỔ
  else if (method == "setWindowAutoMode") {  
    if (params == true) { 
      Serial2.println("WIN_AUTO:1"); 
      Serial.println("[GUI SANG STM32] WIN_AUTO:1 (BAT AUTO)");
    } else { 
      Serial2.println("WIN_AUTO:0"); 
      Serial.println("[GUI SANG STM32] WIN_AUTO:0 (TAT AUTO)");
    }
  }

  // XỬ LÝ LỆNH MỞ/ĐÓNG CỬA SỔ THỦ CÔNG
  else if (method == "setWindow") {          
    if (params == true) { 
      Serial2.println("WIN:1"); 
      Serial.println("[GUI SANG STM32] WIN:1");
    } else { 
      Serial2.println("WIN:0"); 
      Serial.println("[GUI SANG STM32] WIN:0");
    }
  }
  
  // --- 4. XỬ LÝ NÚT GẠT: CHẾ ĐỘ TỰ ĐỘNG ĐÈN SÂN ---
  else if (method == "setLedAutoMode") {
    if (params == true) { 
      Serial2.println("LED_AUTO:1"); 
      Serial.println("[GUI SANG STM32] LED_AUTO:1 (BAT AUTO DEN)");
    } else { 
      Serial2.println("LED_AUTO:0"); 
      Serial.println("[GUI SANG STM32] LED_AUTO:0 (TAT AUTO DEN)");
    }
  }

  // --- 5. XỬ LÝ NÚT: ĐÈN NGOÀI SÂN THỦ CÔNG ---
  else if (method == "setLed1State") {
    if (params == true) { 
      Serial2.println("LED1:1"); 
      Serial.println("[GUI SANG STM32] LED1:1 (BAT DEN SAN)");
    } else { 
      Serial2.println("LED1:0"); 
      Serial.println("[GUI SANG STM32] LED1:0 (TAT DEN SAN)");
    }
  }

  // --- 6. XỬ LÝ LỆNH: QUẠT PHÒNG NGỦ ---
  else if (method == "setFanState") {
    if (params == true) { 
      Serial2.println("FAN:1"); 
      Serial.println("[GUI SANG STM32] FAN:1 (BAT QUAT)");
      // Cập nhật ngay lên Attributes để App Flutter đồng bộ mượt mà
      client.publish("v1/devices/me/attributes", "{\"fanState\":true}"); 
    } else { 
      Serial2.println("FAN:0"); 
      Serial.println("[GUI SANG STM32] FAN:0 (TAT QUAT)");
      client.publish("v1/devices/me/attributes", "{\"fanState\":false}");
    }
  }

  // --- 7. XỬ LÝ LỆNH: ĐÈN PHÒNG NGỦ ---
  else if (method == "setLightState") {
    if (params == true) { 
      Serial2.println("LIGHT_BED:1"); 
      Serial.println("[GUI SANG STM32] LIGHT_BED:1 (BAT DEN NGU)");
      // Cập nhật ngay lên Attributes để App Flutter đồng bộ mượt mà
      client.publish("v1/devices/me/attributes", "{\"lightState\":true}");
    } else { 
      Serial2.println("LIGHT_BED:0"); 
      Serial.println("[GUI SANG STM32] LIGHT_BED:0 (TAT DEN NGU)");
      client.publish("v1/devices/me/attributes", "{\"lightState\":false}");
    }
  }
  // --- 8. XỬ LÝ LỆNH ĐỔI MẬT KHẨU TỪ APP ---
  else if (method == "setNewPass") {
    // Ép kiểu params lấy dạng chuỗi (String) thay vì bool
    String newPass = doc["params"].as<String>(); 
    Serial2.println("NEWPASS:" + newPass);
    Serial.println("[GUI SANG STM32] DOI MAT KHAU MOI: " + newPass);
  }
  
  // --- 9. XỬ LÝ LỆNH HỌC THẺ RFID TỪ APP ---
  else if (method == "learnRFID") {
    Serial2.println("LEARN_RFID:1");
    Serial.println("[GUI SANG STM32] BAT CHE DO HOC THE RFID");
  }
}

// ================= KẾT NỐI THINGSBOARD =================
void reconnect() {
  while (!client.connected()) {
    Serial.print("Dang ket noi ThingsBoard...");
    if (client.connect("ESP32_Test_Door", token, NULL)) {
      Serial.println(" OK!");
      // Đăng ký nhận lệnh RPC từ App
      client.subscribe("v1/devices/me/rpc/request/+"); 
    } else {
      Serial.print(" Loi, thu lai sau 5s...");
      delay(5000);
    }
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200); 
  Serial2.begin(115200, SERIAL_8N1, RXD2, TXD2); 

  setup_wifi();
  
  // --- THÊM: CẤU HÌNH API LẮNG NGHE LỆNH FACE ID TỪ PYTHON ---
  server.on("/door", []() {
    if (server.hasArg("state")) {
      String state = server.arg("state");
      if (state == "1") {
        Serial2.println("DOOR:1"); // Ép STM32 mở cửa ngay lập tức
        Serial.println("\n[CAMERA FACE ID] Phat hien ADMIN -> Gui STM32: DOOR:1");
        
        // (Tùy chọn) Cập nhật trạng thái mở cửa lên App Flutter luôn cho đồng bộ
        client.publish("v1/devices/me/telemetry", "{\"doorState\":true}");
        
        server.send(200, "text/plain", "OK: Door Opened");
      } 
    } else {
      server.send(400, "text/plain", "Error: Thieu tham so");
    }
  });
  server.begin(); // Bật Server HTTP
  // -------------------------------------------------------------

  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);
}

// ================= VÒNG LẶP CHÍNH =================
void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop(); // Vòng lặp của ThingsBoard (App Flutter)
  
  server.handleClient(); // Vòng lặp của WebServer (Python Face ID)

  // Đọc dữ liệu từ STM32 gửi sang
  if (Serial2.available()) {
    String dataFromSTM32 = Serial2.readStringUntil('\n');
    dataFromSTM32.trim(); 
    
    // 1. TÍNH NĂNG LOA PHÓNG THANH: In mọi thứ STM32 nói lên máy tính
    Serial.println("[STM32]: " + dataFromSTM32);
    
    // 2. TÍNH NĂNG IOT: Nếu là chuỗi JSON thì đẩy lên Cloud ThingsBoard
    if (dataFromSTM32.length() > 0 && dataFromSTM32.startsWith("{")) {
      client.publish("v1/devices/me/telemetry", dataFromSTM32.c_str());
      client.publish("v1/devices/me/attributes", dataFromSTM32.c_str());
    }
  }
}