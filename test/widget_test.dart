import 'dart:convert';

import 'package:flow/main.dart';
import 'package:flow/services/pin_credential_store.dart';
import 'package:flow/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('모바일 홈과 반응형 프롬프트 그리드를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-prompt-button')), findsOneWidget);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    expect(grid.gridDelegate, isA<SliverGridDelegateWithMaxCrossAxisExtent>());
  });

  testWidgets('새 프롬프트 편집기를 전체 화면으로 연다', (tester) async {
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-prompt-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('prompt-editor-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('prompt-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-prompt-button')), findsOneWidget);
  });

  testWidgets('설정 화면을 전체 화면으로 연다', (tester) async {
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-screen')), findsOneWidget);
    expect(find.text('앱 잠금'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('백업 내보내기'), 300);
    expect(find.text('백업 내보내기'), findsOneWidget);
  });

  testWidgets('기존 평문 PIN을 이전하고 잠금을 해제한다', (tester) async {
    final now = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      PromptStore.storageKey: jsonEncode({
        'version': 1,
        'prompts': [],
        'folders': [],
        'settings': {
          'lockEnabled': true,
          'pinCode': '1234',
          'biometricEnabled': false,
        },
        'exportedAt': now,
      }),
    });
    final pinStore = MemoryPinCredentialStore();
    await tester.pumpWidget(FlowApp(pinStore: pinStore));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.widgetWithText(FilledButton, digit));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);

    final saved = (await SharedPreferences.getInstance()).getString(
      PromptStore.storageKey,
    )!;
    expect(saved, isNot(contains('pinCode')));
  });

  testWidgets('백그라운드 복귀 시 자동 잠금을 적용한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      PromptStore.storageKey: jsonEncode({
        'version': 2,
        'prompts': [],
        'folders': [],
        'settings': {
          'lockEnabled': true,
          'biometricEnabled': false,
          'autoLockDuration': 'immediately',
        },
      }),
    });
    final pinStore = MemoryPinCredentialStore();
    await pinStore.setPin('1234');
    await tester.pumpWidget(FlowApp(pinStore: pinStore));
    await tester.pumpAndSettle();
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.widgetWithText(FilledButton, digit));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
  });
}
