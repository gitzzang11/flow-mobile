import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backup_service.dart';
import '../services/biometric_service.dart';
import '../services/pin_credential_store.dart';
import '../store.dart';
import '../widgets/app_toast.dart';
import '../widgets/pin_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.pinStore,
    required this.biometricService,
    required this.backupService,
    required this.onChanged,
    required this.onLockNow,
    required this.onExternalActivityChanged,
  });
  final PromptStore store;
  final PinCredentialStore pinStore;
  final BiometricService biometricService;
  final BackupService backupService;
  final Future<void> Function() onChanged;
  final VoidCallback onLockNow;
  final ValueChanged<bool> onExternalActivityChanged;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings get settings => widget.store.settings;
  Future<void> _update(AppSettings value) async {
    setState(() => widget.store.settings = value);
    await widget.onChanged();
  }

  Future<void> _toggleLock(bool enabled) async {
    if (enabled) {
      final pin = await showCreatePinDialog(context);
      if (pin == null) return;
      try {
        await widget.pinStore.setPin(pin);
        if (!await widget.pinStore.verifyPin(pin)) {
          throw StateError('PIN verification failed');
        }
        await _update(settings.copyWith(lockEnabled: true, legacyPinCode: ''));
      } on Object {
        if (mounted) {
          showAppToast(context, 'PIN을 안전하게 저장하지 못했습니다.', error: true);
        }
      }
    } else {
      final verified = await showVerifyPinDialog(context, widget.pinStore);
      if (!mounted) return;
      if (!verified) {
        return showAppToast(context, 'PIN이 일치하지 않습니다.', error: true);
      }
      await widget.pinStore.clear();
      await _update(
        settings.copyWith(
          lockEnabled: false,
          biometricEnabled: false,
          legacyPinCode: '',
        ),
      );
    }
  }

  Future<void> _changePin() async {
    if (!await showVerifyPinDialog(context, widget.pinStore)) {
      if (mounted) showAppToast(context, '현재 PIN이 일치하지 않습니다.', error: true);
      return;
    }
    if (!mounted) return;
    final pin = await showCreatePinDialog(context, title: '새 PIN 설정');
    if (pin == null) return;
    await widget.pinStore.setPin(pin);
    if (mounted) showAppToast(context, 'PIN을 변경했습니다.');
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (!settings.lockEnabled) {
      showAppToast(context, '먼저 앱 잠금을 켜세요.', error: true);
      return;
    }
    if (enabled) {
      widget.onExternalActivityChanged(true);
      final available = await widget.biometricService.isAvailable();
      if (!available) {
        widget.onExternalActivityChanged(false);
        if (mounted) {
          showAppToast(context, '이 기기에서 생체인증을 사용할 수 없습니다.', error: true);
        }
        return;
      }
      final authenticated = await widget.biometricService.authenticate();
      widget.onExternalActivityChanged(false);
      if (!authenticated) return;
    }
    await _update(settings.copyWith(biometricEnabled: enabled));
  }

  Rect _shareOrigin() {
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  Future<void> _export() async {
    widget.onExternalActivityChanged(true);
    try {
      await widget.backupService.exportBackup(
        widget.store,
        origin: _shareOrigin(),
      );
    } on Object {
      if (mounted) showAppToast(context, '백업 파일을 만들지 못했습니다.', error: true);
    } finally {
      widget.onExternalActivityChanged(false);
    }
  }

  Future<void> _import() async {
    widget.onExternalActivityChanged(true);
    try {
      final raw = await widget.backupService.pickBackupJson();
      if (raw == null || !mounted) return;
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('백업을 불러올까요?'),
              content: const Text(
                '현재 프롬프트와 폴더가 백업 데이터로 교체됩니다. 기기의 PIN과 생체인증 설정은 유지됩니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('불러오기'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      final rollback = widget.store.exportToJson();
      try {
        widget.store.importFromJsonString(raw);
        await widget.onChanged();
      } on Object {
        widget.store.importFromJsonString(rollback);
        rethrow;
      }
      if (mounted) showAppToast(context, '백업을 불러왔습니다.');
    } on FormatException {
      if (mounted) showAppToast(context, '올바른 Flow 백업 파일이 아닙니다.', error: true);
    } on Object {
      if (mounted) showAppToast(context, '백업을 불러오지 못했습니다.', error: true);
    } finally {
      widget.onExternalActivityChanged(false);
    }
  }

  Future<void> _deleteAll() async {
    if (settings.lockEnabled &&
        !await showVerifyPinDialog(context, widget.pinStore)) {
      if (mounted) showAppToast(context, 'PIN이 일치하지 않습니다.', error: true);
      return;
    }
    if (!mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('전체 데이터를 삭제할까요?'),
            content: const Text(
              '모든 프롬프트, 폴더, 설정과 잠금 정보가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('전체 삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.pinStore.clear();
    widget.store
      ..prompts.clear()
      ..folders.clear()
      ..settings = const AppSettings();
    await widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  Widget _header(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Future<void> _showPrivacyPolicy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('개인정보 처리 안내'),
      content: const SingleChildScrollView(
        child: Text(
          'Flow는 프롬프트와 폴더를 기기 내부에 저장하며 별도 서버로 전송하지 않습니다.\n\n'
          'PIN 원문은 저장하지 않고 운영체제 보안 저장소에 검증용 해시만 저장합니다. '
          '생체인증 정보는 Android와 iOS가 직접 처리하며 Flow가 생체정보에 접근하지 않습니다.\n\n'
          '사용자가 공유 또는 백업을 실행한 경우에만 선택한 앱이나 파일 위치로 데이터가 전달됩니다. '
          '백업 파일에는 PIN과 PIN 해시가 포함되지 않습니다.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('settings-screen'),
    appBar: AppBar(title: const Text('설정')),
    body: ListView(
      children: [
        _header('화면'),
        SwitchListTile(
          title: const Text('다크 모드'),
          secondary: const Icon(Icons.dark_mode_outlined),
          value: settings.darkMode,
          onChanged: (value) => _update(settings.copyWith(darkMode: value)),
        ),
        SwitchListTile(
          title: const Text('터치 진동'),
          secondary: const Icon(Icons.vibration_rounded),
          value: settings.hapticEnabled,
          onChanged: (value) =>
              _update(settings.copyWith(hapticEnabled: value)),
        ),
        SwitchListTile(
          title: const Text('빠른 폴더 이동'),
          secondary: const Icon(Icons.folder_copy_outlined),
          value: settings.showFolderNavigation,
          onChanged: (value) =>
              _update(settings.copyWith(showFolderNavigation: value)),
        ),
        ListTile(
          leading: const Icon(Icons.text_fields_rounded),
          title: const Text('카드 글자 크기'),
          subtitle: Slider(
            value: settings.cardTextScale,
            min: .9,
            max: 1.2,
            divisions: 3,
            label: '${(settings.cardTextScale * 100).round()}%',
            onChanged: (value) => setState(
              () => widget.store.settings = settings.copyWith(
                cardTextScale: value,
              ),
            ),
            onChangeEnd: (_) => widget.onChanged(),
          ),
        ),
        _header('보안'),
        SwitchListTile(
          title: const Text('앱 잠금'),
          secondary: const Icon(Icons.lock_outline_rounded),
          value: settings.lockEnabled,
          onChanged: _toggleLock,
        ),
        SwitchListTile(
          title: const Text('생체인증'),
          secondary: const Icon(Icons.fingerprint_rounded),
          value: settings.biometricEnabled,
          onChanged: settings.lockEnabled ? _toggleBiometric : null,
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('자동 잠금'),
          trailing: DropdownButton<AutoLockDuration>(
            value: settings.autoLockDuration,
            items: AutoLockDuration.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: settings.lockEnabled
                ? (value) {
                    if (value != null) {
                      _update(settings.copyWith(autoLockDuration: value));
                    }
                  }
                : null,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.pin_outlined),
          title: const Text('PIN 변경'),
          enabled: settings.lockEnabled,
          onTap: settings.lockEnabled ? _changePin : null,
        ),
        ListTile(
          leading: const Icon(Icons.lock_clock_outlined),
          title: const Text('지금 잠금'),
          enabled: settings.lockEnabled,
          onTap: settings.lockEnabled ? widget.onLockNow : null,
        ),
        _header('데이터'),
        ListTile(
          leading: const Icon(Icons.ios_share_rounded),
          title: const Text('백업 내보내기'),
          subtitle: const Text('PIN 정보는 백업에 포함되지 않습니다.'),
          onTap: _export,
        ),
        ListTile(
          leading: const Icon(Icons.file_open_outlined),
          title: const Text('백업 불러오기'),
          onTap: _import,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            '전체 데이터 삭제',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: _deleteAll,
        ),
        _header('앱 정보'),
        const ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('Flow'),
          subtitle: Text('버전 2.0.0 (18)'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('개인정보 처리 안내'),
          onTap: _showPrivacyPolicy,
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('오픈소스 라이선스'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Flow',
            applicationVersion: '2.0.0',
          ),
        ),
        const SizedBox(height: 32),
      ],
    ),
  );
}
