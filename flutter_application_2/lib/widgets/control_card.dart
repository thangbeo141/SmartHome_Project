import 'package:flutter/material.dart';

class ControlCard extends StatelessWidget {
  final String title; // Tên thiết bị (VD: Quạt)
  final bool value; // Trạng thái hiện tại (true/false)
  final IconData icon; // Icon (Fan/Light)
  final Color activeColor; // Màu khi bật (Xanh/Cam)
  final Function(bool) onChanged; // Hàm xử lý khi gạt nút

  const ControlCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        // Tiêu đề đậm
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        // Chữ phụ bên dưới (Tự đổi màu theo trạng thái)
        subtitle: Text(
          value ? "Đang BẬT" : "Đang TẮT",
          style: TextStyle(
            color: value ? activeColor : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Icon bên trái (Tự đổi màu)
        secondary: Icon(
          icon,
          color: value ? activeColor : Colors.grey,
          size: 32,
        ),
        // Nút gạt
        value: value,
        activeColor: activeColor,
        onChanged: onChanged, // Gọi hàm callback ra bên ngoài
      ),
    );
  }
}
