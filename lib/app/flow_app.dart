import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../screens/home_screen.dart';
import '../screens/lock_screen.dart';
import '../services/backup_service.dart';
import '../services/biometric_service.dart';
import '../services/pin_credential_store.dart';
import '../store.dart';
import '../theme.dart';

class FlowApp extends StatefulWidget {
  const FlowApp({
    super.key,
    this.pinStore,
    this.biometricService,
    this.backupService,
  });
  final PinCredentialStore? pinStore;
  final BiometricService? biometricService;
  final BackupService? backupService;
  @override
  State<FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<FlowApp> with WidgetsBindingObserver {
  bool _loading = true;
  bool _unlocked = false;
  DateTime? _backgroundedAt;
  bool _externalActivityActive = false;
  late PromptStore _store;
  late final PinCredentialStore _pinStore;
  late final BiometricService _biometricService;
  late final BackupService _backupService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pinStore = widget.pinStore ?? SecurePinCredentialStore();
    _biometricService = widget.biometricService ?? BiometricService();
    _backupService = widget.backupService ?? BackupService();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_loading || !_store.settings.lockEnabled) return;
    if (_externalActivityActive) {
      _backgroundedAt = null;
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final leftAt = _backgroundedAt;
      _backgroundedAt = null;
      final duration = _store.settings.autoLockDuration.duration;
      if (leftAt != null &&
          duration != null &&
          DateTime.now().difference(leftAt) >= duration) {
        _handleRelock();
      }
    }
  }

  Future<void> _bootstrap() async {
    unawaited(_backupService.cleanupStaleBackups());
    final prefs = await SharedPreferences.getInstance();
    final firstRun = !prefs.containsKey(PromptStore.storageKey);
    _store = await PromptStore.load();
    final legacyPin = _store.settings.legacyPinCode;
    var hasSecurePin = await _pinStore.hasPin();
    if (!hasSecurePin && legacyPin.isNotEmpty) {
      try {
        await _pinStore.setPin(legacyPin);
        hasSecurePin = await _pinStore.verifyPin(legacyPin);
        if (hasSecurePin) {
          _store.settings = _store.settings.copyWith(legacyPinCode: '');
          await _store.persist();
        }
      } on Object {
        hasSecurePin = false;
      }
    }
    if (_store.settings.lockEnabled && !hasSecurePin) {
      _store.settings = _store.settings.copyWith(
        lockEnabled: false,
        biometricEnabled: false,
        legacyPinCode: '',
      );
      await _store.persist();
    }
    if (firstRun) {
      _seedFirstRunData();
      await _store.persist();
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _unlocked = !_store.settings.lockEnabled;
    });
  }

  void _seedFirstRunData() {
    final now = DateTime.now();
    final folder = FolderItem(
      id: PromptStore.newId(),
      name: '빠른 시작',
      createdAt: now,
    );
    _store.folders.add(folder);
    _store.prompts.addAll([
      PromptItem(
        id: PromptStore.newId(),
        title: '랜딩 페이지 카피라이팅',
        titleColorValue: AppPalette.ink.value,
        folderId: folder.id,
        tags: const ['마케팅', '카피'],
        createdAt: now,
        updatedAt: now,
        segments: const [
          PromptSegment(
            text: '다음 제품의 전환율이 높은 랜딩 페이지 카피를 작성해줘. ',
            colorValue: 0xFF183153,
          ),
          PromptSegment(text: '[제품 이름]', colorValue: 0xFFE85D5D),
          PromptSegment(
            text: ' 대상 고객을 위한 핵심 문구를 만들어줘.',
            colorValue: 0xFF183153,
          ),
        ],
      ),
      PromptItem(
        id: PromptStore.newId(),
        title: '회의록 요약 프롬프트',
        titleColorValue: AppPalette.ink.value,
        folderId: '',
        tags: const ['업무', '요약'],
        createdAt: now,
        updatedAt: now,
        segments: const [
          PromptSegment(
            text: '다음 회의록을 액션 아이템, 담당자, 마감 일정 중심으로 요약해줘. ',
            colorValue: 0xFF183153,
          ),
          PromptSegment(text: '[회의 내용]', colorValue: 0xFFF59E0B),
        ],
      ),
    ]);
  }

  void _handleUnlock() {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _unlocked = true);
  }

  void _handleRelock() {
    if (!mounted || _loading || !_store.settings.lockEnabled) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _unlocked = false);
  }

  void _setExternalActivity(bool active) {
    _externalActivityActive = active;
    if (!active) _backgroundedAt = null;
  }

  Future<void> _saveStore() async {
    await _store.persist();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = _loading ? const AppSettings() : _store.settings;
    const seed = Color(0xFF0F766E);
    return MaterialApp(
      title: 'Flow',
      debugShowCheckedModeBanner: false,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: buildTheme(Brightness.light, seed),
      darkTheme: buildTheme(Brightness.dark, seed),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : settings.lockEnabled && !_unlocked
          ? LockScreen(
              settings: settings,
              pinStore: _pinStore,
              biometricService: _biometricService,
              onUnlock: _handleUnlock,
              onExternalActivityChanged: _setExternalActivity,
            )
          : HomeScreen(
              store: _store,
              pinStore: _pinStore,
              biometricService: _biometricService,
              backupService: _backupService,
              onStoreChanged: _saveStore,
              onRequireRelock: _handleRelock,
              onExternalActivityChanged: _setExternalActivity,
            ),
    );
  }
}
