import 'dart:convert';

import 'package:flow/models.dart';
import 'package:flow/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('백업 버전 1을 가져오고 보안 설정을 보존한다', () {
    final store = PromptStore.empty();
    store.settings = const AppSettings(
      lockEnabled: true,
      biometricEnabled: true,
    );
    store.importFromJsonString(
      jsonEncode({
        'version': 1,
        'prompts': [],
        'folders': [],
        'settings': {'darkMode': true, 'pinCode': '9999'},
      }),
    );
    expect(store.settings.darkMode, isTrue);
    expect(store.settings.lockEnabled, isTrue);
    expect(store.settings.biometricEnabled, isTrue);
  });

  test('새 백업에 PIN과 보안 자격 증명을 기록하지 않는다', () {
    final store = PromptStore.empty();
    store.settings = const AppSettings(
      lockEnabled: true,
      legacyPinCode: '1234',
    );
    final backup = store.exportToJson();
    expect(backup, isNot(contains('1234')));
    expect(backup, isNot(contains('pinCode')));
    expect(jsonDecode(backup)['version'], PromptStore.backupVersion);
  });

  test('폴더 삭제 시 프롬프트는 폴더 없음으로 이동한다', () async {
    final now = DateTime.now();
    final store = PromptStore(
      folders: [FolderItem(id: 'f', name: '업무', createdAt: now)],
      prompts: [
        PromptItem(
          id: 'p',
          title: '테스트',
          titleColorValue: AppPalette.ink.value,
          folderId: 'f',
          tags: const [],
          createdAt: now,
          updatedAt: now,
          segments: const [PromptSegment(text: '내용', colorValue: 0xFF000000)],
        ),
      ],
      settings: const AppSettings(),
    );
    await store.deleteFolder('f');
    expect(store.folders, isEmpty);
    expect(store.prompts.single.folderId, isEmpty);
  });

  test('중복 프롬프트 ID가 있는 백업을 거부한다', () {
    final now = DateTime.now().toIso8601String();
    final prompt = {
      'id': 'same',
      'title': '중복',
      'folderId': '',
      'tags': [],
      'createdAt': now,
      'updatedAt': now,
      'segments': [],
      'titleColorValue': 0xFF000000,
    };
    expect(
      () => PromptStore.empty().importFromJsonString(
        jsonEncode({
          'version': 2,
          'prompts': [prompt, prompt],
          'folders': [],
          'settings': {},
        }),
      ),
      throwsFormatException,
    );
  });
}
