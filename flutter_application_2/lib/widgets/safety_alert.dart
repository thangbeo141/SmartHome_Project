// lib/widgets/safety_alert.dart
import 'package:flutter/material.dart';

class SafetyAlert extends StatelessWidget {
  final bool isFire; // Trạng thái lửa
  final bool isGas; // Trạng thái Gas
  final bool isEarthquake; // trạng thái rung
  
  const SafetyAlert({
    super.key, 
    required this.isFire, 
    required this.isGas,
    required this.isEarthquake,
  });

  @override
  Widget build(BuildContext context) {
    // Nếu không có gì nguy hiểm thì không hiện gì cả (SizedBox.shrink)
    if (!isFire && !isGas && !isEarthquake) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 1. Cảnh báo Lửa (Ưu tiên cao nhất)
        if (isFire)
          _buildAlertCard(
            "CẢNH BÁO: CÓ LỬA!",
            "Hệ thống báo động đang kêu...",
            Icons.local_fire_department,
            Colors.redAccent,
          ),

        // 2. Cảnh báo Gas
        if (isGas)
          _buildAlertCard(
            "CẢNH BÁO: RÒ RỈ GAS",
            "Quạt hút đã tự động bật!",
            Icons.warning_amber_rounded,
            Colors.deepOrange,
          ),
        
        // 1. Cảnh báo Động đất (Ưu tiên cao - Màu Nâu/Tím)
        if (isEarthquake)
          _buildAlertCard(
            "NGUY CƠ ĐỘNG ĐẤT!",
            "Phát hiện rung chấn mạnh -> Buzzer ON",
            Icons.vibration,
            Colors.brown,
          ),
        const SizedBox(height: 20), // Khoảng cách dưới cùng
      ],
    );
  }

  // Hàm con vẽ cái thẻ (chỉ dùng nội bộ trong file này)
  Widget _buildAlertCard(
    String title,
    String subTitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(subTitle, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}
