import 'package:flutter/material.dart';

class WindowControl extends StatelessWidget {
  final bool windowAutoMode;
  final bool windowState;
  final Function(bool) onAutoModeChanged;
  final Function(bool) onWindowChanged;

  const WindowControl({
    super.key,
    required this.windowAutoMode,
    required this.windowState,
    required this.onAutoModeChanged,
    required this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 4,
          child: SwitchListTile(
            title: const Text(
              "Chế độ Cửa sổ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              windowAutoMode ? "Tự động theo mưa" : "Điều khiển thủ công",
              style: TextStyle(
                color: windowAutoMode ? Colors.green : Colors.grey,
              ),
            ),
            value: windowAutoMode,
            onChanged: onAutoModeChanged,
          ),
        ),

        IgnorePointer(
          ignoring: windowAutoMode,
          child: Opacity(
            opacity: windowAutoMode ? 0.5 : 1,
            child: Card(
              child: SwitchListTile(
                secondary: Icon(
                  windowState ? Icons.window : Icons.window_outlined,
                  color: windowState ? Colors.blue : Colors.grey,
                ),
                title: const Text("Cửa sổ"),
                subtitle: Text(windowState ? "Đang mở" : "Đang đóng"),
                value: windowState,
                onChanged: onWindowChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
