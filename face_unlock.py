import cv2
import face_recognition
import time
import os
import numpy as np
import requests  

# ================== CẤU HÌNH ==================
# 👇 QUAN TRỌNG: Sửa IP này thành IP mà ESP32 in ra trên Arduino IDE
ESP32_URL = "http://172.20.10.3/door" 

# Đã sửa lại đường dẫn theo thư mục mới của bác sĩ ở ổ D
IMAGE_FILE = r"D:\python\admin_clean.jpg"

admin_present = False
door_opened_for_admin = False

ADMIN_LOST_DELAY = 2.0  # giây
last_seen_admin_time = 0

# ================== GỬI LỆNH MỞ CỬA (TRỰC TIẾP XUỐNG ESP32) ==================
def send_open_door_command():
    try:
        # Bắn HTTP GET thẳng xuống WebServer của ESP32 với lệnh state=1
        resp = requests.get(f"{ESP32_URL}?state=1", timeout=3)
        
        if resp.status_code == 200:
            print("🔓 ĐÃ GỬI LỆNH MỞ CỬA THẲNG XUỐNG ESP32!")
        else:
            print(f"❌ Gửi lệnh lỗi, ESP32 phản hồi: {resp.text}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Không tìm thấy ESP32! (Kiểm tra lại IP hoặc WiFi): {e}")

# ================== LOAD ẢNH ADMIN ==================
def load_clean_face(image_path):
    if not os.path.exists(image_path):
        print(f"❌ Không tìm thấy ảnh tại {image_path}")
        return None

    img = cv2.imread(image_path)
    if img is None:
        return None

    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img = np.ascontiguousarray(img, dtype=np.uint8)

    encs = face_recognition.face_encodings(img)
    if len(encs) == 0:
        return None

    return encs[0]

# ================== MAIN ==================
def run_face_id():
    global admin_present, door_opened_for_admin, last_seen_admin_time

    print("⏳ Đang nạp ảnh admin...")
    known_encoding = load_clean_face(IMAGE_FILE)
    if known_encoding is None:
        print("❌ Lỗi ảnh admin")
        return

    cap = cv2.VideoCapture(0)
    print("📷 CAMERA ĐÃ BẬT - SẴN SÀNG NHẬN DIỆN")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        small = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)
        rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
        rgb = np.ascontiguousarray(rgb, dtype=np.uint8)

        locs = face_recognition.face_locations(rgb)
        encs = face_recognition.face_encodings(rgb, locs)

        admin_found = False

        for (top, right, bottom, left), face_enc in zip(locs, encs):
            match = face_recognition.compare_faces(
                [known_encoding], face_enc, tolerance=0.45
            )[0]

            top *= 4
            right *= 4
            bottom *= 4
            left *= 4

            color = (0, 255, 0) if match else (0, 0, 255)
            name = "ADMIN" if match else "UNKNOWN"

            cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
            cv2.putText(
                frame,
                name,
                (left, top - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.8,
                color,
                2,
            )

            if match:
                admin_found = True

        # ===== LOGIC MỞ CỬA =====
        current_time = time.time()

        if admin_found:
            last_seen_admin_time = current_time

            if not admin_present:
                print("👤 ADMIN XUẤT HIỆN")
                admin_present = True

            if not door_opened_for_admin:
                print("🔓 MỞ CỬA 1 LẦN")
                send_open_door_command() # Bắn lệnh siêu tốc
                door_opened_for_admin = True

        else:
            if admin_present and (
                current_time - last_seen_admin_time > ADMIN_LOST_DELAY
            ):
                print("🚶 ADMIN RỜI KHUNG HÌNH")
                admin_present = False
                door_opened_for_admin = False

        cv2.imshow("Face ID System", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    run_face_id()