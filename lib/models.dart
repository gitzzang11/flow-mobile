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
  newest('newest', '최신순'),
  oldest('oldest', '오래된순'),
  title('title', '이름순');

  const PromptSortMode(this.storageValue, this.label);
  final String storageValue;
  final String label;
  static PromptSortMode fromStorage(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => PromptSortMode.newest,
  );
}

enum AutoLockDuration {
  immediately('immediately', '즉시', Duration.zero),
  oneMinute('one_minute', '1분 후', Duration(minutes: 1)),
  fiveMinutes('five_minutes', '5분 후', Duration(minutes: 5)),
  never('never', '잠그지 않음', null);

  const AutoLockDuration(this.storageValue, this.label, this.duration);
  final String storageValue;
  final String label;
  final Duration? duration;
  static AutoLockDuration fromStorage(String? value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => AutoLockDuration.oneMinute,
  );
}

class PromptItem {
  const PromptItem({
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
  }) => PromptItem(
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

  factory PromptItem.fromJson(Map<String, dynamic> json) {
    DateTime date(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '') ?? DateTime.now();
    final rawSegments = json['segments'];
    return PromptItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      titleColorValue:
          (json['titleColorValue'] as num?)?.toInt() ?? AppPalette.ink.value,
      folderId: json['folderId']?.toString() ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(),
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
      segments: rawSegments is List
          ? rawSegments
                .whereType<Map>()
                .map(
                  (item) =>
                      PromptSegment.fromJson(item.cast<String, dynamic>()),
                )
                .toList()
          : const [],
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
  const PromptSegment({required this.text, required this.colorValue});
  final String text;
  final int colorValue;
  PromptSegment copyWith({String? text, int? colorValue}) => PromptSegment(
    text: text ?? this.text,
    colorValue: colorValue ?? this.colorValue,
  );
  factory PromptSegment.fromJson(Map<String, dynamic> json) => PromptSegment(
    text: json['text']?.toString() ?? '',
    colorValue: (json['colorValue'] as num?)?.toInt() ?? AppPalette.ink.value,
  );
  Map<String, dynamic> toJson() => {'text': text, 'colorValue': colorValue};
}

class FolderItem {
  const FolderItem({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  final String id;
  final String name;
  final DateTime createdAt;
  FolderItem copyWith({String? id, String? name, DateTime? createdAt}) =>
      FolderItem(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  factory FolderItem.fromJson(Map<String, dynamic> json) => FolderItem(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
  );
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
    this.favoriteColors = const [],
    this.promptSortMode = PromptSortMode.newest,
    this.customPromptOrder = const [],
    this.hapticEnabled = true,
    this.biometricEnabled = false,
    this.showFolderNavigation = true,
    this.autoLockDuration = AutoLockDuration.oneMinute,
    this.cardTextScale = 1,
    this.legacyPinCode = '',
  });
  final bool darkMode;
  final bool lockEnabled;
  final List<int> favoriteColors;
  final PromptSortMode promptSortMode;
  final List<String> customPromptOrder;
  final bool hapticEnabled;
  final bool biometricEnabled;
  final bool showFolderNavigation;
  final AutoLockDuration autoLockDuration;
  final double cardTextScale;
  final String legacyPinCode;

  AppSettings copyWith({
    bool? darkMode,
    bool? lockEnabled,
    List<int>? favoriteColors,
    PromptSortMode? promptSortMode,
    List<String>? customPromptOrder,
    bool? hapticEnabled,
    bool? biometricEnabled,
    bool? showFolderNavigation,
    AutoLockDuration? autoLockDuration,
    double? cardTextScale,
    String? legacyPinCode,
  }) => AppSettings(
    darkMode: darkMode ?? this.darkMode,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    favoriteColors: favoriteColors ?? this.favoriteColors,
    promptSortMode: promptSortMode ?? this.promptSortMode,
    customPromptOrder: customPromptOrder ?? this.customPromptOrder,
    hapticEnabled: hapticEnabled ?? this.hapticEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    showFolderNavigation: showFolderNavigation ?? this.showFolderNavigation,
    autoLockDuration: autoLockDuration ?? this.autoLockDuration,
    cardTextScale: cardTextScale ?? this.cardTextScale,
    legacyPinCode: legacyPinCode ?? this.legacyPinCode,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    darkMode: json['darkMode'] as bool? ?? false,
    lockEnabled: json['lockEnabled'] as bool? ?? false,
    favoriteColors: (json['favoriteColors'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(),
    promptSortMode: PromptSortMode.fromStorage(
      json['promptSortMode'] as String?,
    ),
    customPromptOrder: (json['customPromptOrder'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(),
    hapticEnabled: json['hapticEnabled'] as bool? ?? true,
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    showFolderNavigation: json['showFolderNavigation'] as bool? ?? true,
    autoLockDuration: AutoLockDuration.fromStorage(
      json['autoLockDuration'] as String?,
    ),
    cardTextScale: (json['cardTextScale'] as num?)?.toDouble() ?? 1,
    legacyPinCode: json['pinCode']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'darkMode': darkMode,
    'lockEnabled': lockEnabled,
    'favoriteColors': favoriteColors,
    'promptSortMode': promptSortMode.storageValue,
    'customPromptOrder': customPromptOrder,
    'hapticEnabled': hapticEnabled,
    'biometricEnabled': biometricEnabled,
    'showFolderNavigation': showFolderNavigation,
    'autoLockDuration': autoLockDuration.storageValue,
    'cardTextScale': cardTextScale,
  };
}

void triggerInteractionHaptic(AppSettings settings) {
  if (settings.hapticEnabled) HapticFeedback.lightImpact();
}
