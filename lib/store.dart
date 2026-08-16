import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class PromptStore {
  PromptStore({
    required this.prompts,
    required this.folders,
    required this.settings,
  });
  static const storageKey = 'flow_store_v1';
  static const backupVersion = 2;
  List<PromptItem> prompts;
  List<FolderItem> folders;
  AppSettings settings;

  static Future<PromptStore> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null || raw.isEmpty) return PromptStore.empty();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? PromptStore.fromJson(decoded.cast<String, dynamic>())
          : PromptStore.empty();
    } on Object {
      return PromptStore.empty();
    }
  }

  factory PromptStore.empty() =>
      PromptStore(prompts: [], folders: [], settings: const AppSettings());
  factory PromptStore.fromJson(Map<String, dynamic> json) => PromptStore(
    prompts: _readPrompts(json['prompts']),
    folders: _readFolders(json['folders']),
    settings: AppSettings.fromJson(
      json['settings'] is Map
          ? (json['settings'] as Map).cast<String, dynamic>()
          : const {},
    ),
  );

  static List<PromptItem> _readPrompts(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => PromptItem.fromJson(item.cast<String, dynamic>()))
            .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
            .toList()
      : [];
  static List<FolderItem> _readFolders(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => FolderItem.fromJson(item.cast<String, dynamic>()))
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList()
      : [];

  Future<void> persist() async => (await SharedPreferences.getInstance())
      .setString(storageKey, exportToJson());
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
  String exportToJson() => jsonEncode({
    'version': backupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'prompts': prompts.map((item) => item.toJson()).toList(),
    'folders': folders.map((item) => item.toJson()).toList(),
    'settings': settings.toJson(),
  });

  void importFromJsonString(
    String rawJson, {
    bool preserveDeviceSecurity = true,
  }) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Backup root must be a JSON object.');
    }
    final json = decoded.cast<String, dynamic>();
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > backupVersion) {
      throw const FormatException('Unsupported backup version.');
    }
    if (json['prompts'] is! List || json['folders'] is! List) {
      throw const FormatException('Backup is missing prompt or folder lists.');
    }
    final imported = PromptStore.fromJson(json);
    final ids = <String>{};
    for (final prompt in imported.prompts) {
      if (!ids.add(prompt.id)) {
        throw const FormatException('Backup contains duplicate prompt IDs.');
      }
    }
    final folderIds = imported.folders.map((item) => item.id).toSet();
    prompts = imported.prompts
        .map(
          (item) => folderIds.contains(item.folderId)
              ? item
              : item.copyWith(folderId: ''),
        )
        .toList();
    folders = imported.folders;
    settings = preserveDeviceSecurity
        ? imported.settings.copyWith(
            lockEnabled: settings.lockEnabled,
            biometricEnabled: settings.biometricEnabled,
            autoLockDuration: settings.autoLockDuration,
            legacyPinCode: settings.legacyPinCode,
          )
        : imported.settings.copyWith(
            lockEnabled: false,
            biometricEnabled: false,
            legacyPinCode: '',
          );
  }

  Future<void> savePrompt(PromptItem prompt) async {
    final index = prompts.indexWhere((item) => item.id == prompt.id);
    if (index < 0) {
      prompts.add(prompt);
    } else {
      prompts[index] = prompt;
    }
    await persist();
  }

  Future<int> deletePrompt(String id) async {
    final index = prompts.indexWhere((item) => item.id == id);
    if (index >= 0) {
      prompts.removeAt(index);
      await persist();
    }
    return index;
  }

  Future<void> restorePrompt(PromptItem prompt, int index) async {
    if (prompts.any((item) => item.id == prompt.id)) return;
    prompts.insert(index.clamp(0, prompts.length), prompt);
    await persist();
  }

  Future<void> deleteFolder(String id) async {
    folders.removeWhere((item) => item.id == id);
    prompts = prompts
        .map((item) => item.folderId == id ? item.copyWith(folderId: '') : item)
        .toList();
    await persist();
  }

  Future<void> reorderFolders(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = folders.removeAt(oldIndex);
    folders.insert(newIndex, item);
    await persist();
  }
}
