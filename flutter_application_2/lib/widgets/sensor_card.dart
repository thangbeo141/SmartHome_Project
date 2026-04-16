import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final String title;
  final double temperature;
  final double humidity;
  final MaterialColor color;

  const SensorCard({
    super.key,
    required this.title,
    required this.temperature,
    required this.humidity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [color.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.shade200, width: 2),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
            ),
            const Divider(thickness: 1),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_buildTemp(), _buildHum()],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemp() {
    return Column(
      children: [
        const Icon(Icons.thermostat, size: 40, color: Colors.redAccent),
        const SizedBox(height: 5),
        Text(
          "${temperature.toStringAsFixed(1)}°C",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const Text("Nhiệt độ", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildHum() {
    return Column(
      children: [
        const Icon(Icons.water_drop, size: 40, color: Colors.blueAccent),
        const SizedBox(height: 5),
        Text(
          "${humidity.toStringAsFixed(0)}%",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const Text("Độ ẩm", style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
