import 'package:flutter/material.dart';

class DoorControl extends StatelessWidget {
  final bool doorState;
  final Function(bool) onChanged;

  const DoorControl({
    super.key,
    required this.doorState,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          doorState ? Icons.door_front_door : Icons.door_back_door,
          color: doorState ? Colors.green : Colors.grey,
        ),
        title: const Text("Cửa Chính"),
        subtitle: Text(
          doorState ? "Đang mở" : "Đang đóng",
          style: TextStyle(color: doorState ? Colors.green : Colors.grey),
        ),
        value: doorState,
        onChanged: onChanged,
      ),
    );
  }
}
