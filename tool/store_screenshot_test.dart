// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flow/main.dart';
import 'package:flow/models.dart';
import 'package:flow/services/pin_credential_store.dart';
import 'package:flow/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadScreenshotFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('스토어 스크린샷 - 홈', (tester) async {
    _usePhoneCanvas(tester);
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('home-screen')),
      matchesGoldenFile(
        '../docs/google-play/assets/screenshots/01-home.png',
      ),
    );
  });

  testWidgets('스토어 스크린샷 - 편집', (tester) async {
    _usePhoneCanvas(tester);
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-prompt-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('prompt-title-field')),
      '제품 소개 글 작성',
    );
    await tester.enterText(
      find.byKey(const ValueKey('prompt-segment-field-0')),
      '아래 제품의 핵심 장점을 고객이 이해하기 쉬운 문장으로 정리해줘.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('prompt-editor-screen')),
      matchesGoldenFile(
        '../docs/google-play/assets/screenshots/02-editor.png',
      ),
    );
  });

  testWidgets('스토어 스크린샷 - 설정', (tester) async {
    _usePhoneCanvas(tester);
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('settings-screen')),
      matchesGoldenFile(
        '../docs/google-play/assets/screenshots/03-settings.png',
      ),
    );
  });

  testWidgets('스토어 스크린샷 - 앱 잠금', (tester) async {
    _usePhoneCanvas(tester);
    SharedPreferences.setMockInitialValues({
      PromptStore.storageKey: jsonEncode({
        'version': PromptStore.backupVersion,
        'prompts': [],
        'folders': [],
        'settings': {
          'lockEnabled': true,
          'biometricEnabled': false,
          'autoLockDuration': AutoLockDuration.oneMinute.storageValue,
        },
      }),
    });
    final pinStore = MemoryPinCredentialStore();
    await pinStore.setPin('2468');
    await tester.pumpWidget(FlowApp(pinStore: pinStore));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('lock-screen')),
      matchesGoldenFile(
        '../docs/google-play/assets/screenshots/04-lock.png',
      ),
    );
  });
}

Future<void> _loadScreenshotFonts() async {
  Future<ByteData> readFont(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  await (FontLoader('Roboto')
        ..addFont(readFont(r'C:\Windows\Fonts\malgun.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(
          readFont(
            r'C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
          ),
        ))
      .load();
}

void _usePhoneCanvas(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
