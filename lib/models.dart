import 'package:flutter/services.dart';

enum AppPalette {
  ink(0xFF183153),
  coral(0xFFE85D5D),
  sky(0xFF3B82F6),
  amber(0xFFF59E0B),
  mint(0xFF10B981),
  violet(0xFF8B5CF6);

  const AppPalette(this.value);
  final int value;
}

enum PromptSortMode {
  newest('newest'),
  oldest('oldest'),
  title('title');

  const PromptSortMode(this.storageValue);

  final String storageValue;

  static PromptSortMode fromStorage(String? value) {
    return PromptSortMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => PromptSortMode.newest,
    );
  }
}

enum PromptViewMode {
  list('list'),
  grid('grid');

  const PromptViewMode(this.storageValue);

  final String storageValue;

  static PromptViewMode fromStorage(String? value) {
    return PromptViewMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => PromptViewMode.list,
    );
  }
}

class PromptItem {
  PromptItem({
    required this.id,
    required this.title,
    required this.titleColorValue,
    required this.folderId,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.segments,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final int titleColorValue;
  final String folderId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PromptSegment> segments;
  final bool isPinned;

  String get plainText => segments.map((segment) => segment.text).join();

  PromptItem copyWith({
    String? id,
    String? title,
    int? titleColorValue,
    String? folderId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PromptSegment>? segments,
    bool? isPinned,
  }) {
    return PromptItem(
      id: id ?? this.id,
      title: title ?? this.title,
      titleColorValue: titleColorValue ?? this.titleColorValue,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      segments: segments ?? this.segments,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory PromptItem.fromJson(Map<String, dynamic> json) {
    return PromptItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleColorValue: json['titleColorValue'] as int? ?? AppPalette.ink.value,
      folderId: json['folderId'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      segments: (json['segments'] as List<dynamic>? ?? [])
          .map((item) => PromptSegment.fromJson(item as Map<String, dynamic>))
          .toList(),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'titleColorValue': titleColorValue,
    'folderId': folderId,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'segments': segments.map((item) => item.toJson()).toList(),
    'isPinned': isPinned,
  };
}

class PromptSegment {
  PromptSegment({required this.text, required this.colorValue});

  final String text;
  final int colorValue;

  PromptSegment copyWith({String? text, int? colorValue}) {
    return PromptSegment(
      text: text ?? this.text,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  factory PromptSegment.fromJson(Map<String, dynamic> json) {
    return PromptSegment(
      text: json['text'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? AppPalette.ink.value,
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'colorValue': colorValue};
}

class FolderItem {
  FolderItem({required this.id, required this.name, required this.createdAt});

  final String id;
  final String name;
  final DateTime createdAt;

  FolderItem copyWith({String? id, String? name, DateTime? createdAt}) {
    return FolderItem(
      // Added const for better performance
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };
}

class AppSettings {
  const AppSettings({
    this.darkMode = false,
    this.lockEnabled = false,
    this.pinCode = '',
    this.favoriteColors = const [],
    this.promptSortMode = PromptSortMode.newest,
    this.promptViewMode = PromptViewMode.grid,
    this.customPromptOrder = const [],
    this.hapticEnabled = true,
    this.biometricEnabled = false,
  });

  final bool darkMode;
  final bool lockEnabled;
  final String pinCode;
  final List<int> favoriteColors;
  final PromptSortMode promptSortMode;
  final PromptViewMode promptViewMode;
  final List<String> customPromptOrder;
  final bool hapticEnabled;
  final bool biometricEnabled;

  AppSettings copyWith({
    bool? darkMode,
    bool? lockEnabled,
    String? pinCode,
    List<int>? favoriteColors,
    PromptSortMode? promptSortMode,
    PromptViewMode? promptViewMode,
    List<String>? customPromptOrder,
    bool? hapticEnabled,
    bool? biometricEnabled,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      pinCode: pinCode ?? this.pinCode,
      favoriteColors: favoriteColors ?? this.favoriteColors,
      promptSortMode: promptSortMode ?? this.promptSortMode,
      promptViewMode: promptViewMode ?? this.promptViewMode,
      customPromptOrder: customPromptOrder ?? this.customPromptOrder,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    darkMode: json['darkMode'] as bool? ?? false,
    lockEnabled: json['lockEnabled'] as bool? ?? false,
    pinCode: json['pinCode'] as String? ?? '',
    favoriteColors: (json['favoriteColors'] as List<dynamic>? ?? [])
        .cast<int>(),
    promptSortMode: PromptSortMode.fromStorage(
      json['promptSortMode'] as String?,
    ),
    promptViewMode: PromptViewMode.fromStorage(
      json['promptViewMode'] as String?,
    ),
    customPromptOrder: (json['customPromptOrder'] as List<dynamic>? ?? [])
        .cast<String>(),
    hapticEnabled: json['hapticEnabled'] as bool? ?? true,
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'darkMode': darkMode,
    'lockEnabled': lockEnabled,
    'pinCode': pinCode,
    'favoriteColors': favoriteColors,
    'promptSortMode': promptSortMode.storageValue,
    'promptViewMode': promptViewMode.storageValue,
    'customPromptOrder': customPromptOrder,
    'hapticEnabled': hapticEnabled,
    'biometricEnabled': biometricEnabled,
  };
}

void triggerInteractionHaptic(AppSettings settings) {
  if (settings.hapticEnabled) {
    HapticFeedback.lightImpact();
  }
}

