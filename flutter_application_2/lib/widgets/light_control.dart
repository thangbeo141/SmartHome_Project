import 'package:flutter/material.dart';

class LightControl extends StatelessWidget {
  final bool ledAutoMode;
  final bool led1State;
  //final bool led2State;
  final Function(bool) onAutoModeChanged;
  final Function(bool) onLed1Changed;
  //final Function(bool) onLed2Changed;

  const LightControl({
    super.key,
    required this.ledAutoMode,
    required this.led1State,
    //required this.led2State,
    required this.onAutoModeChanged,
    required this.onLed1Changed,
    //required this.onLed2Changed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            title: const Text(
              "Chế độ Tự động",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              ledAutoMode ? "Hệ thống tự động" : "Điều khiển thủ công",
              style: TextStyle(color: ledAutoMode ? Colors.green : Colors.grey),
            ),
            value: ledAutoMode,
            onChanged: onAutoModeChanged,
          ),
        ),

        const Divider(height: 40),

        IgnorePointer(
          ignoring: ledAutoMode,
          child: Opacity(
            opacity: ledAutoMode ? 0.5 : 1,
            child: Column(
              children: [
                _buildSwitch(
                  "Đèn Ngoài ",
                  led1State,
                  Icons.lightbulb,
                  Icons.lightbulb_outline,
                  onLed1Changed,
                ),
                const SizedBox(height: 10),
                // _buildSwitch(
                //   "Đèn Ngoài 2",
                //   led2State,
                //   Icons.lightbulb,
                //   Icons.lightbulb_outline,
                //   onLed2Changed,
                // ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(
    String title,
    bool value,
    IconData onIcon,
    IconData offIcon,
    Function(bool) onChanged,
  ) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          value ? onIcon : offIcon,
          color: value ? Colors.amber : Colors.grey,
        ),
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
