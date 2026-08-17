import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../services/biometric_service.dart';
import '../services/pin_credential_store.dart';
import '../widgets/pin_pad.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.settings,
    required this.pinStore,
    required this.biometricService,
    required this.onUnlock,
    required this.onExternalActivityChanged,
  });
  final AppSettings settings;
  final PinCredentialStore pinStore;
  final BiometricService biometricService;
  final VoidCallback onUnlock;
  final ValueChanged<bool> onExternalActivityChanged;
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const _attemptsKey = 'flow_pin_failed_attempts';
  static const _lockoutKey = 'flow_pin_lockout_until';
  String _pin = '';
  String? _error;
  int _remaining = 0;
  bool _checking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadState().then((_) {
      if (mounted && widget.settings.biometricEnabled && _remaining == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_lockoutKey) ?? 0;
    final seconds = ((until - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil();
    if (seconds > 0) {
      _startTimer(seconds);
    } else {
      await prefs.remove(_lockoutKey);
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remaining = seconds;
      _pin = '';
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return timer.cancel();
      if (_remaining <= 1) {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_lockoutKey);
        await prefs.remove(_attemptsKey);
        if (mounted) {
          setState(() {
            _remaining = 0;
            _error = null;
          });
        }
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _biometric() async {
    if (_checking || _remaining > 0) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    widget.onExternalActivityChanged(true);
    var authenticated = false;
    try {
      authenticated = await widget.biometricService.authenticate();
    } on Object {
      authenticated = false;
    } finally {
      widget.onExternalActivityChanged(false);
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (!authenticated) {
        _pin = '';
        _error = '생체인증을 취소했습니다. PIN을 입력하세요.';
      }
    });
    if (authenticated) widget.onUnlock();
  }

  Future<void> _checkPin() async {
    if (_pin.length != 4 || _checking || _remaining > 0) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final valid = await widget.pinStore.verifyPin(_pin);
    if (!mounted) return;
    if (valid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_attemptsKey);
      await prefs.remove(_lockoutKey);
      HapticFeedback.lightImpact();
      widget.onUnlock();
      return;
    }
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_attemptsKey) ?? 0) + 1;
    await prefs.setInt(_attemptsKey, attempts);
    if (attempts >= 10) {
      final until = DateTime.now().add(const Duration(minutes: 1));
      await prefs.setInt(_lockoutKey, until.millisecondsSinceEpoch);
      _startTimer(60);
      setState(() {
        _checking = false;
        _error = '10회 실패하여 잠금 해제가 제한됩니다.';
      });
    } else {
      setState(() {
        _checking = false;
        _pin = '';
        _error = 'PIN이 일치하지 않습니다. ($attempts/10)';
      });
    }
  }

  void _pinChanged(String value) {
    setState(() {
      _pin = value;
      _error = null;
    });
    if (value.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 100), _checkPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedOut = _remaining > 0;
    return Scaffold(
      key: const ValueKey('lock-screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 34,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    lockedOut ? '잠금 해제 제한' : '잠금 해제',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lockedOut
                        ? '$_remaining초 후 다시 시도할 수 있습니다.'
                        : 'PIN 4자리를 입력하세요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: 15,
                        height: 15,
                        margin: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _pin.length
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  PinPad(
                    value: _pin,
                    onChanged: _pinChanged,
                    enabled: !_checking && !lockedOut,
                  ),
                  if (widget.settings.biometricEnabled && !lockedOut) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _checking ? null : _biometric,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('생체인증으로 열기'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
