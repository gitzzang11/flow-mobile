import 'dart:convert';

import 'package:flow/main.dart';
import 'package:flow/services/biometric_service.dart';
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

  testWidgets('작은 가로 화면에서도 편집기의 마지막 내용까지 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-prompt-button')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(find.text('구간 추가'));
      await tester.pump();
      await tester.tap(find.text('구간 추가'));
      await tester.pump();
    }
    final lastField = find.byKey(const ValueKey('prompt-segment-field-4'));
    final editorScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('prompt-editor-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      lastField,
      180,
      scrollable: editorScrollable,
    );
    await tester.drag(editorScrollable, const Offset(0, -160));
    await tester.pump();
    await tester.tap(lastField);
    await tester.enterText(lastField, '화면 아래쪽의 긴 프롬프트 내용');
    await tester.pump();

    expect(lastField, findsOneWidget);
    expect(find.byKey(const ValueKey('save-prompt-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면에서 프롬프트 설정창의 모든 메뉴를 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(360, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();

    final moreButton = find.byTooltip('더보기').first;
    await tester.ensureVisible(moreButton);
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    final actionList = find.byKey(const ValueKey('prompt-action-list'));
    expect(actionList, findsOneWidget);
    expect(find.text('클립보드에 복사'), findsOneWidget);
    final actionScrollable = find
        .descendant(of: actionList, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('삭제'),
      100,
      scrollable: actionScrollable,
    );
    await tester.pump();

    expect(find.text('삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('프롬프트 설정창은 내용 높이만큼만 열린다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(FlowApp(pinStore: MemoryPinCredentialStore()));
    await tester.pumpAndSettle();

    final moreButton = find.byTooltip('더보기').first;
    await tester.ensureVisible(moreButton);
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet).last;
    expect(tester.getSize(sheet).height, lessThan(620));
    expect(find.text('클립보드에 복사'), findsOneWidget);
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

  testWidgets('지문인증 취소 후 PIN 숫자 패드를 다시 활성화한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      PromptStore.storageKey: jsonEncode({
        'version': 2,
        'prompts': [],
        'folders': [],
        'settings': {
          'lockEnabled': true,
          'biometricEnabled': true,
          'autoLockDuration': 'one_minute',
        },
      }),
    });
    final pinStore = MemoryPinCredentialStore();
    await pinStore.setPin('1234');
    await tester.pumpWidget(
      FlowApp(
        pinStore: pinStore,
        biometricService: _CancelledBiometricService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('생체인증을 취소했습니다. PIN을 입력하세요.'), findsOneWidget);
    final oneButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '1'),
    );
    expect(oneButton.onPressed, isNotNull);

    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.widgetWithText(FilledButton, digit));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
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

class _CancelledBiometricService extends BiometricService {
  @override
  Future<bool> authenticate() async => false;
}
