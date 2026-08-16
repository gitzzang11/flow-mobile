import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();
  final LocalAuthentication _authentication;

  Future<bool> isAvailable() async {
    try {
      return await _authentication.isDeviceSupported() &&
          await _authentication.canCheckBiometrics;
    } on Object {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      if (!await isAvailable()) return false;
      return _authentication.authenticate(
        localizedReason: 'Flow 앱 잠금을 해제하려면 생체인증을 진행하세요.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}
