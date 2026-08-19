import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class PromptStore {
  PromptStore({
    required this.prompts,
    required this.folders,
    required this.settings,
  });
  static const storageKey = 'flow_store_v1';
  static const backupVersion = 3;
  static const maxImportedPrompts = 5000;
  static const maxImportedFolders = 1000;
  static const maxTagsPerPrompt = 50;
  static const maxSegmentsPerPrompt = 200;
  static const maxImagesPerPrompt = 20;
  static const maxTitleLength = 500;
  static const maxFolderNameLength = 200;
  static const maxTagLength = 100;
  static const maxSegmentLength = 200000;
  static const maxPathLength = 4096;
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
  String exportToJson({bool includeImages = false}) {
    final payload = <String, dynamic>{
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'prompts': prompts.map((item) => item.toJson()).toList(),
      'folders': folders.map((item) => item.toJson()).toList(),
      'settings': settings.toJson(),
    };
    if (includeImages) payload['images'] = _collectEmbeddedImages();
    return jsonEncode(payload);
  }

  Map<String, String> _collectEmbeddedImages() {
    final result = <String, String>{};
    for (final path in prompts.expand((prompt) => prompt.imagePaths)) {
      if (result.containsKey(path)) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        result[path] = base64Encode(file.readAsBytesSync());
      } on FileSystemException {
        // A missing attachment must not make the text backup unusable.
      }
    }
    return result;
  }

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
    _validateImportPayload(json);
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

  static void _validateImportPayload(Map<String, dynamic> json) {
    final prompts = json['prompts'] as List;
    final folders = json['folders'] as List;
    if (prompts.length > maxImportedPrompts ||
        folders.length > maxImportedFolders) {
      throw const FormatException('Backup contains too many items.');
    }

    for (final value in folders) {
      if (value is! Map) {
        throw const FormatException('Invalid folder entry.');
      }
      final folder = value.cast<String, dynamic>();
      _requireString(folder['id'], maxPathLength, 'folder id');
      _requireString(folder['name'], maxFolderNameLength, 'folder name');
    }

    for (final value in prompts) {
      if (value is! Map) {
        throw const FormatException('Invalid prompt entry.');
      }
      final prompt = value.cast<String, dynamic>();
      _requireString(prompt['id'], maxPathLength, 'prompt id');
      _requireString(prompt['title'], maxTitleLength, 'prompt title');
      if (prompt['folderId'] != null) {
        _requireString(
          prompt['folderId'],
          maxPathLength,
          'folder id',
          allowEmpty: true,
        );
      }
      _validateStringList(
        prompt['tags'],
        maxTagsPerPrompt,
        maxTagLength,
        'tags',
      );
      _validateStringList(
        prompt['imagePaths'],
        maxImagesPerPrompt,
        maxPathLength,
        'image paths',
      );

      final segments = prompt['segments'];
      if (segments is! List || segments.length > maxSegmentsPerPrompt) {
        throw const FormatException('Invalid prompt segments.');
      }
      for (final segmentValue in segments) {
        if (segmentValue is! Map) {
          throw const FormatException('Invalid prompt segment.');
        }
        _requireString(
          segmentValue['text'],
          maxSegmentLength,
          'prompt text',
          allowEmpty: true,
        );
      }
    }
  }

  static void _validateStringList(
    dynamic value,
    int maxItems,
    int maxLength,
    String field,
  ) {
    if (value == null) return;
    if (value is! List || value.length > maxItems) {
      throw FormatException('Invalid $field.');
    }
    for (final item in value) {
      _requireString(item, maxLength, field);
    }
  }

  static void _requireString(
    dynamic value,
    int maxLength,
    String field, {
    bool allowEmpty = false,
  }) {
    if (value is! String ||
        (!allowEmpty && value.isEmpty) ||
        value.length > maxLength) {
      throw FormatException('Invalid $field.');
    }
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
