#include <Arduino.h>
#include <STM32FreeRTOS.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Keypad.h>
#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <HardwareSerial.h>
#include <LiquidCrystal_I2C.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>
#include "DHT.h"
#include <EEPROM.h>
// ==========================================
// CẤU HÌNH PHẦN CỨNG 
// ==========================================
LiquidCrystal_I2C lcd(0x27, 16, 2);
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();
#define DOOR_SERVO    0  
#define WINDOW_SERVO  1  
int angleToPulse(int ang) { return map(ang, 0, 180, 150, 600); }

#define SS_PIN PA4
#define RST_PIN PB11
MFRC522 rfid(SS_PIN, RST_PIN);
byte authorizedUID[4] = {0xDE, 0xB6, 0x6F, 0x06}; 

const byte ROWS = 4; const byte COLS = 3; 
char keys[ROWS][COLS] = {
  {'1','2','3'}, {'4','5','6'}, {'7','8','9'}, {'*','0','#'}
};
byte rowPins[ROWS] = {PB12, PB13, PB14, PB15}; 
byte colPins[COLS] = {PA0, PA1, PA2};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);
String correctPass = "1111";

#define RAIN_SENSOR_PIN PA3
#define LIGHT_SENSOR_PIN PA8
#define OUTDOOR_LIGHT_PIN PB0

Adafruit_SH1106G display = Adafruit_SH1106G(128, 64, &Wire, -1);

#define DHTPIN_KHACH PB8  
#define DHTPIN_NGU   PB9  
DHT dhtKhach(DHTPIN_KHACH, DHT11);
DHT dhtNgu(DHTPIN_NGU, DHT11);

#define TOUCH_PIN PB1
#define FAN_PIN   PB5
#define TOUCH_LIGHT_PIN PB10   
#define BEDROOM_LIGHT_PIN PB4 

#define FLAME_SENSOR_PIN PC14 
#define GAS_SENSOR_PIN   PC15 
#define BUZZER_PIN       PB3  
#define KITCHEN_FAN_PIN  PA15 

// ==========================================
// FREERTOS OBJECTS 
// ==========================================
SemaphoreHandle_t xMutexI2C;    
SemaphoreHandle_t xMutexSerial; 

QueueHandle_t xQueueLCD;   
QueueHandle_t xQueueServo; 
QueueHandle_t xQueueAuth;  

typedef enum {
  LCD_STANDBY, LCD_AUTH_SUCCESS, LCD_AUTH_FAIL, 
  LCD_LOCKED, LCD_INPUT_PASS, LCD_FIRE, LCD_GAS, LCD_REMOTE_OPEN
} LCDCmd_t;

typedef struct { LCDCmd_t cmd; int param; char str[17]; } LCDMessage_t;

typedef enum { SERVO_DOOR_OPEN, SERVO_DOOR_CLOSE, SERVO_WIN_OPEN, SERVO_WIN_CLOSE } ServoCmd_t;
typedef enum { AUTH_SUCCESS, AUTH_FAIL, AUTH_REMOTE_OPEN, AUTH_REMOTE_CLOSE } AuthEvent_t;

volatile bool windowAutoMode = true; 
volatile bool ledAutoMode = true; 
volatile bool fanState = false; 
volatile bool lightState = false;
volatile bool isLearningRFID = false;
// ==========================================
// HÀM TIỆN ÍCH AN TOÀN
// ==========================================
void safePrintln(const char* msg) {
  if (xSemaphoreTake(xMutexSerial, portMAX_DELAY) == pdTRUE) {
    Serial1.println(msg); xSemaphoreGive(xMutexSerial);
  }
}
void sendToLCD(LCDCmd_t cmd, int param = 0, const char* str = "") {
  LCDMessage_t msg; msg.cmd = cmd; msg.param = param;
  strncpy(msg.str, str, 16); msg.str[16] = '\0';
  xQueueSend(xQueueLCD, &msg, portMAX_DELAY);
}
void sendServoCmd(ServoCmd_t cmd) {
  xQueueSend(xQueueServo, &cmd, portMAX_DELAY);
}

// ==========================================
// TASK 1: XỬ LÝ NHẬP LIỆU (App + Keypad + Thẻ từ)
// ==========================================
void Task_Input(void *pvParameters) {
  String inputPass = ""; 
  for (;;) {
    // 1. Quét App (ESP32)
    if (Serial1.available()) {
      String cmd = Serial1.readStringUntil('\n'); cmd.trim(); 
      // TỐI ƯU FLASH: Dùng chuỗi ngắn gọn hơn
      if (cmd == "DOOR:1") {
        safePrintln("APP: DOOR OPEN"); safePrintln("{\"doorState\":true}");
        AuthEvent_t ev = AUTH_REMOTE_OPEN; xQueueSend(xQueueAuth, &ev, portMAX_DELAY);
      } else if (cmd == "DOOR:0") {
        safePrintln("APP: DOOR CLOSE");
        AuthEvent_t ev = AUTH_REMOTE_CLOSE; xQueueSend(xQueueAuth, &ev, portMAX_DELAY);
      } else if (cmd == "WIN_AUTO:1") {
        windowAutoMode = true;
        safePrintln("APP: WIN AUTO ON"); safePrintln("{\"windowAutoMode\":true}"); 
        bool isRainingNow = (digitalRead(RAIN_SENSOR_PIN) == LOW);
        if (isRainingNow) { sendServoCmd(SERVO_WIN_CLOSE); safePrintln("{\"windowState\":false}"); } 
        else { sendServoCmd(SERVO_WIN_OPEN); safePrintln("{\"windowState\":true}"); }
      } else if (cmd == "WIN_AUTO:0") {
        windowAutoMode = false;
        safePrintln("APP: WIN AUTO OFF"); safePrintln("{\"windowAutoMode\":false}"); 
      } else if (cmd == "WIN:1") {
        safePrintln("APP: WIN OPEN"); sendServoCmd(SERVO_WIN_OPEN); safePrintln("{\"windowState\":true}");     
      } else if (cmd == "WIN:0") {
        safePrintln("APP: WIN CLOSE"); sendServoCmd(SERVO_WIN_CLOSE); safePrintln("{\"windowState\":false}");       
      }
      else if (cmd == "LED_AUTO:1") {
        ledAutoMode = true;
        safePrintln("APP: LED AUTO ON"); safePrintln("{\"ledAutoMode\":true}");
        bool isDarkNow = (digitalRead(LIGHT_SENSOR_PIN) == HIGH);
        digitalWrite(OUTDOOR_LIGHT_PIN, isDarkNow ? HIGH : LOW);
        safePrintln(isDarkNow ? "{\"led1State\":true}" : "{\"led1State\":false}");
      } else if (cmd == "LED_AUTO:0") {
        ledAutoMode = false;
        safePrintln("APP: LED AUTO OFF"); safePrintln("{\"ledAutoMode\":false}"); 
      } else if (cmd == "LED1:1") {
        safePrintln("APP: LED ON"); digitalWrite(OUTDOOR_LIGHT_PIN, HIGH); safePrintln("{\"led1State\":true}");     
      } else if (cmd == "LED1:0") {
        safePrintln("APP: LED OFF"); digitalWrite(OUTDOOR_LIGHT_PIN, LOW); safePrintln("{\"led1State\":false}");       
      }
      // --- XỬ LÝ QUẠT PHÒNG NGỦ ---
      else if (cmd == "FAN:1") {
        fanState = true;
        digitalWrite(FAN_PIN, HIGH);
        safePrintln("APP: FAN ON"); 
        safePrintln("{\"fanState\":true}");     
      } else if (cmd == "FAN:0") {
        fanState = false;
        digitalWrite(FAN_PIN, LOW);
        safePrintln("APP: FAN OFF"); 
        safePrintln("{\"fanState\":false}");      
      } 
      // --- XỬ LÝ ĐÈN PHÒNG NGỦ ---
      else if (cmd == "LIGHT_BED:1") {
        lightState = true;
        digitalWrite(BEDROOM_LIGHT_PIN, HIGH);
        safePrintln("APP: BED LIGHT ON"); 
        safePrintln("{\"lightState\":true}");     
      } else if (cmd == "LIGHT_BED:0") {
        lightState = false;
        digitalWrite(BEDROOM_LIGHT_PIN, LOW);
        safePrintln("APP: BED LIGHT OFF"); 
        safePrintln("{\"lightState\":false}");      
      }
      // --- XỬ LÝ LỆNH ĐỔI MẬT KHẨU TỪ APP ---
      else if (cmd.startsWith("NEWPASS:")) {
        String newPassword = cmd.substring(8); 
        correctPass = newPassword; 
        
        // Lưu vào EEPROM ô số 0
        char passBuf[5];
        newPassword.toCharArray(passBuf, 5);
        EEPROM.put(0, passBuf); 
        
        safePrintln("APP: DA LUU MAT KHAU MOI VAO EEPROM");
        sendToLCD(LCD_STANDBY, 0, "  Doi MK Xong!  ");
      }
      // --- BẬT CHẾ ĐỘ HỌC THẺ RFID TỪ APP ---
      else if (cmd == "LEARN_RFID:1") {
        isLearningRFID = true;
        safePrintln("APP: SAN SANG HOC THE. HAY QUET THE!");
        sendToLCD(LCD_STANDBY, 0, " Quet the moi! "); // Báo lên màn hình
      }
    }

    // 2. Quét Keypad
    char key = keypad.getKey();
    if (key) {
      digitalWrite(PC13, !digitalRead(PC13)); 
      if (key == '#') {
        AuthEvent_t ev = (inputPass == correctPass) ? AUTH_SUCCESS : AUTH_FAIL;
        xQueueSend(xQueueAuth, &ev, portMAX_DELAY); inputPass = ""; 
      } else if (key == '*') { inputPass = ""; sendToLCD(LCD_STANDBY);
      } else {
        inputPass += key; String stars = ""; for(int i=0; i<inputPass.length(); i++) stars += "*";
        sendToLCD(LCD_INPUT_PASS, 0, stars.c_str());
      }
    }

    // 3. Quét RFID
    if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
      
      // KIỂM TRA XEM ĐANG Ở CHẾ ĐỘ NÀO
      if (isLearningRFID) {
        // ---- CHẾ ĐỘ HỌC: LƯU THẺ VÀO EEPROM ----
        for (byte i = 0; i < 4; i++) {
          authorizedUID[i] = rfid.uid.uidByte[i];
        }
        EEPROM.put(10, authorizedUID); // Lưu đè vào ô nhớ 10
        isLearningRFID = false;        // Tắt chế độ học
        
        safePrintln("APP: DA LUU THE RFID MOI");
        sendToLCD(LCD_STANDBY); // Trả lại màn hình bình thường
        
      } else {
        // ---- CHẾ ĐỘ BÌNH THƯỜNG: SO SÁNH MỞ CỬA ----
        bool match = true;
        for (byte i = 0; i < 4; i++) { 
          if (rfid.uid.uidByte[i] != authorizedUID[i]) match = false; 
        }
        AuthEvent_t ev = match ? AUTH_SUCCESS : AUTH_FAIL;
        xQueueSend(xQueueAuth, &ev, portMAX_DELAY);
      }
      
      rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    }
    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

// ==========================================
// TASK 2: GIÁM SÁT MÔI TRƯỜNG & AN NINH (Chỉ Gas & Lửa)
// ==========================================
void Task_Sensors(void *pvParameters) {
  pinMode(RAIN_SENSOR_PIN, INPUT_PULLUP); pinMode(LIGHT_SENSOR_PIN, INPUT_PULLUP);
  pinMode(TOUCH_PIN, INPUT); pinMode(FAN_PIN, OUTPUT); digitalWrite(FAN_PIN, LOW); 
  pinMode(TOUCH_LIGHT_PIN, INPUT); pinMode(BEDROOM_LIGHT_PIN, OUTPUT); digitalWrite(BEDROOM_LIGHT_PIN, LOW); 
  pinMode(FLAME_SENSOR_PIN, INPUT_PULLUP); pinMode(GAS_SENSOR_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT); pinMode(KITCHEN_FAN_PIN, OUTPUT); 
  digitalWrite(BUZZER_PIN, LOW); digitalWrite(KITCHEN_FAN_PIN, LOW); 
  pinMode(OUTDOOR_LIGHT_PIN, OUTPUT); digitalWrite(OUTDOOR_LIGHT_PIN, LOW);
  
  bool lastRain=false, lastLight=false, lastTouchFan=LOW, lastTouchLight=LOW, lastAlarm=false;
  
  // Chỉ theo dõi Lửa và Gas
  bool lastFire = false, lastGas = false;

  for (;;) {
    // 1. Mưa
    bool isRaining = (digitalRead(RAIN_SENSOR_PIN) == LOW);
    if (isRaining != lastRain) {
      if (windowAutoMode) { 
        if (isRaining) { safePrintln("SENS: MUA"); sendServoCmd(SERVO_WIN_CLOSE); safePrintln("{\"windowState\":false}"); } 
        else { safePrintln("SENS: TANH"); sendServoCmd(SERVO_WIN_OPEN); safePrintln("{\"windowState\":true}"); }
      } lastRain = isRaining; 
    }

    // 2. Ánh sáng
    bool isDark = (digitalRead(LIGHT_SENSOR_PIN) == HIGH);
    if (isDark != lastLight) {
      if (ledAutoMode) {
        digitalWrite(OUTDOOR_LIGHT_PIN, isDark ? HIGH : LOW);
        safePrintln(isDark ? "SENS: TOI" : "SENS: SANG");
        safePrintln(isDark ? "{\"led1State\":true}" : "{\"led1State\":false}"); 
      }
      lastLight = isDark;
    }

    // 3. Quạt & Đèn chạm
    bool touchFan = digitalRead(TOUCH_PIN);
    if (touchFan == HIGH && lastTouchFan == LOW) { 
      fanState = !fanState; 
      digitalWrite(FAN_PIN, fanState ? HIGH : LOW); 
      // Báo trạng thái lên ESP32 để đẩy lên Cloud -> App Flutter
      safePrintln(fanState ? "{\"fanState\":true}" : "{\"fanState\":false}");
    }
    lastTouchFan = touchFan;

    bool touchLight = digitalRead(TOUCH_LIGHT_PIN);
    if (touchLight == HIGH && lastTouchLight == LOW) { 
      lightState = !lightState; 
      digitalWrite(BEDROOM_LIGHT_PIN, lightState ? HIGH : LOW); 
      // Báo trạng thái lên ESP32 để đẩy lên Cloud -> App Flutter
      safePrintln(lightState ? "{\"lightState\":true}" : "{\"lightState\":false}");
    }
    lastTouchLight = touchLight;

    // ==========================================
    // 4. AN NINH (CHỈ CÓ LỬA VÀ GAS)
    // ==========================================
    bool fireDetected = (digitalRead(FLAME_SENSOR_PIN) == HIGH); // Tùy module, nếu ngược thì đổi thành LOW
    bool gasDetected = (digitalRead(GAS_SENSOR_PIN) == LOW);
    
    bool alarmActive = (fireDetected || gasDetected);

    digitalWrite(KITCHEN_FAN_PIN, gasDetected ? HIGH : LOW);
    digitalWrite(BUZZER_PIN, alarmActive ? HIGH : LOW);

    // Xử lý còi và màn hình LCD
    if (alarmActive && !lastAlarm) { 
      if (fireDetected) sendToLCD(LCD_FIRE);
      else if (gasDetected) sendToLCD(LCD_GAS);
      safePrintln("ALARM!"); 
    } 
    else if (!alarmActive && lastAlarm) { 
      sendToLCD(LCD_STANDBY); 
    }
    lastAlarm = alarmActive;

    // GỬI JSON SANG ESP32 (Chỉ có Lửa và Gas)
    if (fireDetected != lastFire || gasDetected != lastGas) {
      String jsonAlert = "{";
      jsonAlert += "\"fireDetected\":" + String(fireDetected ? "true" : "false") + ",";
      jsonAlert += "\"gasDetected\":" + String(gasDetected ? "true" : "false");
      jsonAlert += "}";
      
      safePrintln(jsonAlert.c_str()); // Gửi sang ESP32
      
      lastFire = fireDetected;
      lastGas = gasDetected;
    }

    vTaskDelay(pdMS_TO_TICKS(100)); 
  }
}

// ==========================================
// TASK 3: LOGIC CỬA CHÍNH
// ==========================================
void Task_DoorLogic(void *pvParameters) {
  int errorCount = 0; bool doorIsOpen = false;
  for (;;) {
    AuthEvent_t ev;
    TickType_t waitTime = doorIsOpen ? pdMS_TO_TICKS(5000) : portMAX_DELAY;
    if (xQueueReceive(xQueueAuth, &ev, waitTime) == pdPASS) {
      if (ev == AUTH_SUCCESS || ev == AUTH_REMOTE_OPEN) {
        if (ev == AUTH_SUCCESS) { errorCount = 0; safePrintln("AUTH OK"); }
        sendToLCD(ev == AUTH_SUCCESS ? LCD_AUTH_SUCCESS : LCD_REMOTE_OPEN);
        sendServoCmd(SERVO_DOOR_OPEN); doorIsOpen = true;
      } else if (ev == AUTH_FAIL) {
        errorCount++;
        if (errorCount >= 3) {
          for (int i = 10 * (1 << (errorCount - 3)); i > 0; i--) { sendToLCD(LCD_LOCKED, i); vTaskDelay(pdMS_TO_TICKS(1000)); }
          xQueueReset(xQueueAuth); sendToLCD(LCD_STANDBY);
        } else { sendToLCD(LCD_AUTH_FAIL, errorCount); vTaskDelay(pdMS_TO_TICKS(1500)); sendToLCD(LCD_STANDBY); }
      } else if (ev == AUTH_REMOTE_CLOSE) {
        sendServoCmd(SERVO_DOOR_CLOSE); sendToLCD(LCD_STANDBY); doorIsOpen = false;
      }
    } else {
      if (doorIsOpen) { safePrintln("AUTO CLOSE"); sendServoCmd(SERVO_DOOR_CLOSE); sendToLCD(LCD_STANDBY); safePrintln("{\"doorState\":false}"); doorIsOpen = false; }
    }
  }
}

// ==========================================
// TASK 4: MÀN HÌNH LCD
// ==========================================
void Task_LCD(void *pvParameters) {
  LCDMessage_t msg;
  for (;;) {
    if (xQueueReceive(xQueueLCD, &msg, portMAX_DELAY) == pdPASS) {
      xSemaphoreTake(xMutexI2C, portMAX_DELAY);  lcd.clear();
      switch (msg.cmd) {
        case LCD_STANDBY: 
          lcd.setCursor(0, 0); lcd.print(" HE THONG CUA "); 
          lcd.setCursor(0, 1); 
          if (strlen(msg.str) > 0) lcd.print(msg.str); // Nếu có chữ truyền vào -> In chữ đó
          else lcd.print("  San Sang...  ");         // Nếu không -> In mặc định
          break;
        case LCD_AUTH_SUCCESS: lcd.setCursor(0, 0); lcd.print(" XAC THUC DUNG! "); lcd.setCursor(0, 1); lcd.print(">> MO CUA... << "); break;
        case LCD_REMOTE_OPEN: lcd.setCursor(0, 0); lcd.print(" CUA MO TU XA "); break;
        case LCD_AUTH_FAIL: lcd.setCursor(0, 0); lcd.print("  SAI MAT KHAU  "); lcd.setCursor(0, 1); lcd.print("Sai lan: "); lcd.print(msg.param); break;
        case LCD_LOCKED: lcd.setCursor(0, 0); lcd.print("!!! KHOA !!!    "); lcd.setCursor(0, 1); lcd.print("Cho: "); lcd.print(msg.param); lcd.print(" giay  "); break;
        case LCD_INPUT_PASS: lcd.setCursor(0, 0); lcd.print("Nhap mat khau:  "); lcd.setCursor(0, 1); lcd.print(msg.str); break;
        case LCD_FIRE: lcd.setCursor(0, 0); lcd.print(" !!! CO CHAY !!!"); lcd.setCursor(0, 1); lcd.print("  SO TAN NGAY!  "); break;
        case LCD_GAS: lcd.setCursor(0, 0); lcd.print(" !!! KHI GAS !!!"); lcd.setCursor(0, 1); lcd.print("  SO TAN NGAY!  "); break;
      }
      xSemaphoreGive(xMutexI2C); 
    }
  }
}

// ==========================================
// TASK 5: ĐỘNG CƠ SERVO
// ==========================================
void Task_Servo(void *pvParameters) {
  ServoCmd_t cmd;
  for (;;) {
    if (xQueueReceive(xQueueServo, &cmd, portMAX_DELAY) == pdPASS) {
      xSemaphoreTake(xMutexI2C, portMAX_DELAY);
      switch (cmd) {
        case SERVO_DOOR_OPEN:  pwm.setPWM(DOOR_SERVO, 0, angleToPulse(90)); break;
        case SERVO_DOOR_CLOSE: pwm.setPWM(DOOR_SERVO, 0, angleToPulse(0));  break;
        case SERVO_WIN_OPEN:   pwm.setPWM(WINDOW_SERVO, 0, angleToPulse(90)); break;
        case SERVO_WIN_CLOSE:  pwm.setPWM(WINDOW_SERVO, 0, angleToPulse(0));  break;
      }
      xSemaphoreGive(xMutexI2C);
    }
  }
}

// ==========================================
// TASK 6: OLED & DHT
// ==========================================
void Task_OLED_DHT(void *pvParameters) {
  dhtKhach.begin(); dhtNgu.begin(); bool hienThiKhach = true;
  for (;;) {
    float t_K = dhtKhach.readTemperature(), h_K = dhtKhach.readHumidity();
    float t_N = dhtNgu.readTemperature(), h_N = dhtNgu.readHumidity();
    
    xSemaphoreTake(xMutexI2C, portMAX_DELAY);
    display.clearDisplay(); display.setTextColor(SH110X_WHITE);
    if (hienThiKhach) {
      display.setTextSize(1); display.setCursor(15, 0); display.print("--- PHONG KHACH ---");
      display.setTextSize(2); display.setCursor(10, 20); display.print(isnan(t_K) ? "Loi" : String(t_K, 1) + " C");
      display.setCursor(10, 45); display.print(isnan(h_K) ? "Loi" : "Am:" + String(h_K, 0) + "%");
    } else {
      display.setTextSize(1); display.setCursor(20, 0); display.print("--- PHONG NGU ---");
      display.setTextSize(2); display.setCursor(10, 20); display.print(isnan(t_N) ? "Loi" : String(t_N, 1) + " C");
      display.setCursor(10, 45); display.print(isnan(h_N) ? "Loi" : "Am:" + String(h_N, 0) + "%");
    }
    display.display(); xSemaphoreGive(xMutexI2C);
    // ================= THÊM ĐOẠN NÀY VÀO ĐÂY =================
    // Đóng gói dữ liệu DHT thành JSON gửi sang ESP32
    // Thêm điều kiện !isnan để lỡ cảm biến lỗi tuột dây, nó không gửi chữ "nan" lên làm sập App
    if (!isnan(t_K) && !isnan(h_K) && !isnan(t_N) && !isnan(h_N)) {
      String jsonDHT = "{";
      jsonDHT += "\"tempLiving\":" + String(t_K, 1) + ",";
      jsonDHT += "\"humLiving\":" + String(h_K, 0) + ",";
      jsonDHT += "\"tempBed\":" + String(t_N, 1) + ",";
      jsonDHT += "\"humBed\":" + String(h_N, 0);
      jsonDHT += "}";
      
      safePrintln(jsonDHT.c_str()); // Gửi sang ESP32
    }
    // ==========================================================
    hienThiKhach = !hienThiKhach; vTaskDelay(pdMS_TO_TICKS(3000));
  }
}

// ==========================================
// SETUP HỆ THỐNG
// ==========================================
void setup() {
  Serial1.begin(115200);
  // 1. ĐỌC MẬT KHẨU (Từ ô nhớ 0)
  char savedPass[5];
  EEPROM.get(0, savedPass);
  if (savedPass[0] >= '0' && savedPass[0] <= '9') {
    correctPass = String(savedPass); // Dùng mật khẩu đã lưu
  } else {
    char defaultPass[5] = "1111"; // Mặc định nếu chip mới
    EEPROM.put(0, defaultPass);
    correctPass = "1111";
  }

  // 2. ĐỌC THẺ RFID (Từ ô nhớ 10)
  byte savedUID[4];
  EEPROM.get(10, savedUID);
  if (savedUID[0] != 255) { // 255 là giá trị trống của EEPROM
    for (int i = 0; i < 4; i++) authorizedUID[i] = savedUID[i];
  } else {
    EEPROM.put(10, authorizedUID); // Lưu mảng mặc định vào EEPROM
  }

  Serial1.println("START");
  pinMode(PC13, OUTPUT); digitalWrite(PC13, HIGH);

  Wire.begin(PB7, PB6);
  if(!display.begin(0x3C, true)) { while(1); }
  display.clearDisplay(); display.setTextColor(SH110X_WHITE); display.setTextSize(2); display.setCursor(10, 25); display.print("SH1106 OK!"); display.display();
  
  Wire.setClock(100000); lcd.init(); lcd.backlight();
  SPI.begin(); rfid.PCD_Init();
  pwm.begin(); pwm.setPWMFreq(50); pwm.setPWM(DOOR_SERVO, 0, angleToPulse(0)); pwm.setPWM(WINDOW_SERVO, 0, angleToPulse(90));

  __HAL_RCC_AFIO_CLK_ENABLE(); __HAL_AFIO_REMAP_SWJ_NOJTAG();

  // Khởi tạo FreeRTOS IPCs
  xMutexI2C = xSemaphoreCreateMutex();
  xMutexSerial = xSemaphoreCreateMutex();
  xQueueLCD = xQueueCreate(5, sizeof(LCDMessage_t));
  xQueueServo = xQueueCreate(5, sizeof(ServoCmd_t));
  xQueueAuth = xQueueCreate(5, sizeof(AuthEvent_t));

  sendToLCD(LCD_STANDBY); 

  // Tạo 6 Task lớn (Cực kỳ an toàn, dư dả RAM)
  xTaskCreate(Task_Input, "Input", 250, NULL, 2, NULL);
  xTaskCreate(Task_Sensors, "Sensors", 200, NULL, 1, NULL);
  xTaskCreate(Task_DoorLogic, "Logic", 200, NULL, 3, NULL);
  xTaskCreate(Task_LCD, "LCD", 200, NULL, 1, NULL);
  xTaskCreate(Task_Servo, "Servo", 150, NULL, 2, NULL);
  xTaskCreate(Task_OLED_DHT, "OLED", 300, NULL, 1, NULL);

  vTaskStartScheduler();
}

void loop() {}