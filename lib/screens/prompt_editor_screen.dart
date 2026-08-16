import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';

class PromptEditorScreen extends StatefulWidget {
  const PromptEditorScreen({
    super.key,
    required this.folders,
    required this.settings,
    required this.initialFolderId,
    required this.onFavoriteColorsChanged,
    this.prompt,
  });
  final List<FolderItem> folders;
  final AppSettings settings;
  final String initialFolderId;
  final PromptItem? prompt;
  final ValueChanged<List<int>> onFavoriteColorsChanged;

  @override
  State<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends State<PromptEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _tags;
  late final List<TextEditingController> _segments;
  late final List<int> _colors;
  late String _folderId;
  late String _initialSignature;
  final _formKey = GlobalKey<FormState>();

  int get _defaultColor => widget.settings.darkMode
      ? Colors.white.toARGB32()
      : Colors.black.toARGB32();

  @override
  void initState() {
    super.initState();
    final prompt = widget.prompt;
    _title = TextEditingController(text: prompt?.title ?? '');
    _tags = TextEditingController(text: prompt?.tags.join(', ') ?? '');
    _folderId = prompt?.folderId ?? widget.initialFolderId;
    final source = prompt?.segments.isNotEmpty == true
        ? prompt!.segments
        : [PromptSegment(text: '', colorValue: _defaultColor)];
    _segments = source
        .map((item) => TextEditingController(text: item.text))
        .toList();
    _colors = source.map((item) => item.colorValue).toList();
    _initialSignature = _signature;
  }

  String get _signature => [
    _title.text,
    _tags.text,
    _folderId,
    for (var i = 0; i < _segments.length; i++)
      '${_colors[i]}:${_segments[i].text}',
  ].join('\u0001');
  bool get _isDirty => _signature != _initialSignature;

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    for (final controller in _segments) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('변경사항을 버릴까요?'),
            content: const Text('저장하지 않은 내용은 복구할 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('계속 편집'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('나가기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  List<String> _parseTags() {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in _tags.text.split(',')) {
      final tag = raw.trim().replaceFirst(RegExp(r'^#'), '');
      if (tag.isNotEmpty && seen.add(tag.toLowerCase())) result.add(tag);
    }
    return result;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    final existing = widget.prompt;
    Navigator.pop(
      context,
      PromptItem(
        id: existing?.id ?? PromptStore.newId(),
        title: _title.text.trim(),
        titleColorValue: existing?.titleColorValue ?? _defaultColor,
        folderId: _folderId,
        tags: _parseTags(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        segments: [
          for (var i = 0; i < _segments.length; i++)
            PromptSegment(text: _segments[i].text, colorValue: _colors[i]),
        ],
        isPinned: existing?.isPinned ?? false,
      ),
    );
  }

  Future<void> _pickColor(int index) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _MobileColorPicker(
        initialColor: _colors[index],
        favoriteColors: widget.settings.favoriteColors,
      ),
    );
    if (result != null) setState(() => _colors[index] = result);
  }

  void _toggleFavorite(int color) {
    final colors = [...widget.settings.favoriteColors];
    colors.contains(color) ? colors.remove(color) : colors.add(color);
    widget.onFavoriteColorsChanged(colors);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) navigator.pop();
      },
      child: Scaffold(
        key: const ValueKey('prompt-editor-screen'),
        appBar: AppBar(
          leading: IconButton(
            tooltip: '닫기',
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmDiscard() && mounted) navigator.pop();
            },
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(widget.prompt == null ? '프롬프트 만들기' : '프롬프트 편집'),
          actions: [
            TextButton(
              key: const ValueKey('save-prompt-button'),
              onPressed: _save,
              child: const Text(
                '저장',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                TextFormField(
                  key: const ValueKey('prompt-title-field'),
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? '제목을 입력하세요.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.folders.any((folder) => folder.id == _folderId)
                      ? _folderId
                      : '',
                  decoration: const InputDecoration(
                    labelText: '폴더',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('폴더 없음')),
                    ...widget.folders.map(
                      (folder) => DropdownMenuItem(
                        value: folder.id,
                        child: Text(folder.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _folderId = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tags,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '태그',
                    hintText: '업무, 요약',
                    prefixIcon: Icon(Icons.tag_rounded),
                    helperText: '쉼표로 구분하세요.',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '프롬프트 내용',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _segments.add(TextEditingController());
                        _colors.add(_defaultColor);
                      }),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('구간 추가'),
                    ),
                  ],
                ),
                for (var index = 0; index < _segments.length; index++)
                  Card(
                    margin: const EdgeInsets.only(top: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => _pickColor(index),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CircleAvatar(
                                    radius: 13,
                                    backgroundColor: Color(_colors[index]),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _pickColor(index),
                                child: const Text('글자색'),
                              ),
                              IconButton(
                                tooltip:
                                    widget.settings.favoriteColors.contains(
                                      _colors[index],
                                    )
                                    ? '즐겨찾기 해제'
                                    : '즐겨찾기 추가',
                                onPressed: () =>
                                    _toggleFavorite(_colors[index]),
                                icon: Icon(
                                  widget.settings.favoriteColors.contains(
                                        _colors[index],
                                      )
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color:
                                      widget.settings.favoriteColors.contains(
                                        _colors[index],
                                      )
                                      ? Colors.amber
                                      : null,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: '구간 삭제',
                                onPressed: _segments.length == 1
                                    ? null
                                    : () => setState(() {
                                        _segments.removeAt(index).dispose();
                                        _colors.removeAt(index);
                                      }),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                          TextField(
                            controller: _segments[index],
                            minLines: 4,
                            maxLines: null,
                            style: TextStyle(color: Color(_colors[index])),
                            decoration: const InputDecoration(
                              hintText: '여기에 프롬프트 내용을 입력하세요.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileColorPicker extends StatefulWidget {
  const _MobileColorPicker({
    required this.initialColor,
    required this.favoriteColors,
  });
  final int initialColor;
  final List<int> favoriteColors;
  @override
  State<_MobileColorPicker> createState() => _MobileColorPickerState();
}

class _MobileColorPickerState extends State<_MobileColorPicker> {
  late int _selected;
  late final TextEditingController _hex;
  String? _error;
  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
    _hex = TextEditingController(
      text: _selected.toRadixString(16).substring(2).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _parseHex(String value) {
    final cleaned = value.replaceAll('#', '');
    final parsed = int.tryParse(cleaned, radix: 16);
    setState(() {
      _error = cleaned.length == 6 && parsed != null
          ? null
          : '6자리 HEX 값을 입력하세요.';
      if (_error == null) _selected = 0xFF000000 | parsed!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = <int>{
      ...AppPalette.values.map((item) => item.value),
      ...widget.favoriteColors,
    }.toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '색상 선택',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: colors
                  .map(
                    (color) => InkWell(
                      onTap: () => setState(() {
                        _selected = color;
                        _hex.text = color
                            .toRadixString(16)
                            .substring(2)
                            .toUpperCase();
                      }),
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selected == color
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _hex,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              ],
              onChanged: _parseHex,
              decoration: InputDecoration(
                labelText: 'HEX',
                prefixText: '#',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _error == null
                    ? () => Navigator.pop(context, _selected)
                    : null,
                child: const Text('적용'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
