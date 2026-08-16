import 'package:flutter/material.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, {IconData? icon}) => Padding(
      padding: const EdgeInsets.all(5),
      child: Semantics(
        button: true,
        label: icon == Icons.backspace_outlined ? '한 자리 지우기' : label,
        child: SizedBox(
          width: 68,
          height: 52,
          child: FilledButton.tonal(
            onPressed: !enabled
                ? null
                : () {
                    if (icon != null) {
                      if (value.isNotEmpty) {
                        onChanged(value.substring(0, value.length - 1));
                      }
                    } else if (value.length < 4) {
                      onChanged('$value$label');
                    }
                  },
            child: icon == null
                ? Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Icon(icon),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map(button).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 78),
            button('0'),
            button('', icon: Icons.backspace_outlined),
          ],
        ),
      ],
    );
  }
}
