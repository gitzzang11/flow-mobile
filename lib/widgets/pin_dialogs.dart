import 'package:flutter/material.dart';
import '../services/pin_credential_store.dart';
import 'pin_pad.dart';

Future<String?> showCreatePinDialog(
  BuildContext context, {
  String title = 'PIN 설정',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CreatePinDialog(title: title),
  );
}

Future<bool> showVerifyPinDialog(
  BuildContext context,
  PinCredentialStore store,
) async {
  final pin = await showDialog<String>(
    context: context,
    builder: (context) => const _SinglePinDialog(title: '현재 PIN 확인'),
  );
  return pin != null && await store.verifyPin(pin);
}

class _CreatePinDialog extends StatefulWidget {
  const _CreatePinDialog({required this.title});
  final String title;
  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  String _first = '';
  String _second = '';
  bool _confirming = false;
  String? _error;
  void _changed(String value) {
    setState(() {
      _error = null;
      if (_confirming) {
        _second = value;
      } else {
        _first = value;
      }
    });
    if (value.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 120), _advance);
    }
  }

  void _advance() {
    if (!_confirming) {
      setState(() {
        _confirming = true;
        _second = '';
      });
    } else if (_second == _first) {
      Navigator.pop(context, _first);
    } else {
      setState(() {
        _error = 'PIN이 일치하지 않습니다. 다시 입력하세요.';
        _second = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_confirming ? '같은 PIN을 한 번 더 입력하세요.' : '사용할 숫자 4자리를 입력하세요.'),
        const SizedBox(height: 18),
        _PinDots(length: _confirming ? _second.length : _first.length),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 10),
        PinPad(value: _confirming ? _second : _first, onChanged: _changed),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
    ],
  );
}

class _SinglePinDialog extends StatefulWidget {
  const _SinglePinDialog({required this.title});
  final String title;
  @override
  State<_SinglePinDialog> createState() => _SinglePinDialogState();
}

class _SinglePinDialogState extends State<_SinglePinDialog> {
  String _value = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PinDots(length: _value.length),
        const SizedBox(height: 12),
        PinPad(
          value: _value,
          onChanged: (value) {
            setState(() => _value = value);
            if (value.length == 4) {
              final navigator = Navigator.of(context);
              Future<void>.delayed(const Duration(milliseconds: 100), () {
                if (mounted) navigator.pop(value);
              });
            }
          },
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
    ],
  );
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length});
  final int length;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      4,
      (index) => Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: index < length
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    ),
  );
}
