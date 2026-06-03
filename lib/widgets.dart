import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

class FolderSidebar extends StatelessWidget {
  const FolderSidebar({
    super.key,
    required this.folders,
    required this.prompts,
    required this.selectedFolderId,
    required this.onSelectFolder,
    required this.onCreateFolder,
    required this.onEditFolder,
    required this.onDeleteFolder,
  });

  final List<FolderItem> folders;
  final List<PromptItem> prompts;
  final String selectedFolderId;
  final ValueChanged<String> onSelectFolder;
  final VoidCallback onCreateFolder;
  final ValueChanged<FolderItem> onEditFolder;
  final ValueChanged<FolderItem> onDeleteFolder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF161618) : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppGradients.accent,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_copy_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '폴더',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '폴더 추가',
                    onPressed: onCreateFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    style: IconButton.styleFrom(
                      hoverColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _FolderTile(
                label: '모든 프롬프트',
                count: prompts.length,
                selected: selectedFolderId.isEmpty,
                onTap: () => onSelectFolder(''),
                settings: const AppSettings(), // Dummy/placeholder or just ignore since we don't trigger haptic here (handled in callbacks)
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final count = prompts
                        .where((p) => p.folderId == folder.id)
                        .length;
                    return _FolderTile(
                      label: folder.name,
                      count: count,
                      selected: selectedFolderId == folder.id,
                      onTap: () => onSelectFolder(folder.id),
                      settings: const AppSettings(),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
                        tooltip: '폴더 설정',
                        onSelected: (value) {
                          if (value == 'edit') onEditFolder(folder);
                          if (value == 'delete') onDeleteFolder(folder);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('이름 변경')),
                          PopupMenuItem(value: 'delete', child: Text('삭제')),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.settings,
    this.trailing,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final AppSettings settings;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final nameColor = selected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7));

    final countColor = selected
        ? (isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.5))
        : (isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4));

    final iconColor = selected
        ? scheme.primary
        : (isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4));

    final tileBg = selected
        ? (isDark ? Colors.white.withOpacity(0.08) : scheme.primary.withOpacity(0.08))
        : Colors.transparent;

    final border = Border.all(
      color: selected
          ? (isDark ? Colors.white.withOpacity(0.1) : scheme.primary.withOpacity(0.15))
          : Colors.transparent,
      width: 1.5,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.folder_open_rounded : Icons.folder_rounded,
                color: iconColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: nameColor,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '프롬프트 $count개',
                      style: TextStyle(
                        color: countColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Theme(
                  data: Theme.of(context).copyWith(
                    iconButtonTheme: IconButtonThemeData(
                      style: IconButton.styleFrom(
                        foregroundColor: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PromptToolbar extends StatelessWidget {
  const PromptToolbar({
    super.key,
    required this.searchQuery,
    required this.allTags,
    required this.selectedTags,
    required this.activeFolderLabel,
    required this.folderPromptCount,
    required this.onSearchChanged,
    required this.onToggleTag,
    this.onOpenDrawer,
  });

  final String searchQuery;
  final List<String> allTags;
  final Set<String> selectedTags;
  final String activeFolderLabel;
  final int folderPromptCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggleTag;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                if (onOpenDrawer != null) ...[
                  IconButton(
                    onPressed: onOpenDrawer,
                    icon: const Icon(Icons.menu_rounded),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: '제목으로 검색',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  searchQuery.isNotEmpty || selectedTags.isNotEmpty
                      ? '검색 결과: $folderPromptCount개'
                      : '$activeFolderLabel ($folderPromptCount)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (allTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: allTags
                      .map(
                        (tag) => FilterChip(
                          label: Text('#$tag'),
                          selected: selectedTags.contains(tag),
                          onSelected: (_) => onToggleTag(tag),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FolderQuickAccessBar extends StatelessWidget {
  const FolderQuickAccessBar({
    super.key,
    required this.folders,
    required this.prompts,
    required this.selectedFolderId,
    required this.onSelectFolder,
    this.onOpenDrawer,
  });

  final List<FolderItem> folders;
  final List<PromptItem> prompts;
  final String selectedFolderId;
  final ValueChanged<String> onSelectFolder;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          if (onOpenDrawer != null) ...[
            IconButton(
              onPressed: onOpenDrawer,
              tooltip: '폴더 열기',
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FolderQuickChip(
                  label: '전체',
                  count: prompts.length,
                  selected: selectedFolderId.isEmpty,
                  onTap: () => onSelectFolder(''),
                ),
                ...folders.map((folder) {
                  final count = prompts
                      .where((p) => p.folderId == folder.id)
                      .length;
                  return _FolderQuickChip(
                    label: folder.name,
                    count: count,
                    selected: selectedFolderId == folder.id,
                    onTap: () => onSelectFolder(folder.id),
                  );
                }),
              ],
            ),
          ),
          Container(
            width: 10,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.surface.withOpacity(0), scheme.surface],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderQuickChip extends StatelessWidget {
  const _FolderQuickChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primaryContainer,
        side: BorderSide(
          color: selected
              ? scheme.primary.withOpacity(0.25)
              : scheme.outlineVariant.withOpacity(0.35),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.prompt,
    this.isGrid = false,
    required this.folderName,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onTogglePin,
  });

  final PromptItem prompt;
  final String folderName;
  final bool isGrid;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onTogglePin;

  bool _isLocked() {
    final titleLower = prompt.title.toLowerCase();
    if (titleLower.contains('잠금') || titleLower.contains('잠긴')) {
      return true;
    }
    if (prompt.tags.any((tag) {
      final tagLower = tag.toLowerCase();
      return tagLower == '잠금' || tagLower == 'lock';
    })) {
      return true;
    }
    return false;
  }

  String _formatMonthDay(DateTime dt) {
    return '${dt.month}월 ${dt.day}일';
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  prompt.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: isDark ? Colors.white70 : Colors.black87),
                title: Text('복사', style: textStyle),
                onTap: () {
                  Navigator.pop(ctx);
                  onCopy();
                },
              ),
              ListTile(
                leading: Icon(
                  prompt.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                title: Text(prompt.isPinned ? '고정 해제' : '상단 고정', style: textStyle),
                onTap: () {
                  Navigator.pop(ctx);
                  onTogglePin();
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: isDark ? Colors.white70 : Colors.black87),
                title: Text('편집', style: textStyle),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit();
                },
              ),
              ListTile(
                leading: Icon(Icons.control_point_duplicate_rounded, color: isDark ? Colors.white70 : Colors.black87),
                title: Text('복제', style: textStyle),
                onTap: () {
                  Navigator.pop(ctx);
                  onDuplicate();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red, fontSize: 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocked = _isLocked();

    final titleColor = isDark ? Colors.white : Colors.black;
    final dateColor = isDark ? Colors.white60 : Colors.black54;

    final titleStyle = TextStyle(
      fontSize: 15.0,
      fontWeight: FontWeight.bold,
      color: titleColor,
    );

    final dateStyle = TextStyle(
      fontSize: 12.0,
      color: dateColor,
    );

    return GestureDetector(
      onTap: onCopy,
      onLongPress: () => _showActionSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: prompt.isPinned ? const EdgeInsets.only(right: 20) : EdgeInsets.zero,
                      child: isLocked
                          ? Center(
                              child: Icon(
                                Icons.lock_rounded,
                                size: 40,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                            )
                          : Align(
                              alignment: Alignment.topLeft,
                              child: Text.rich(
                                TextSpan(
                                  children: prompt.segments
                                      .map(
                                        (segment) => TextSpan(
                                          text: segment.text,
                                          style: TextStyle(
                                            color: Color(segment.colorValue),
                                            height: 1.4,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                  ),
                  if (prompt.isPinned)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              prompt.title,
              style: titleStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatMonthDay(prompt.updatedAt),
            style: dateStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}



class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.onCreatePrompt});

  final VoidCallback onCreatePrompt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_clear_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 저장된 프롬프트가 없습니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreatePrompt,
            icon: const Icon(Icons.add),
            label: const Text('첫 프롬프트 만들기'),
          ),
        ],
      ),
    );
  }
}

class PromptEditorDialog extends StatefulWidget {
  const PromptEditorDialog({
    super.key,
    required this.folders,
    this.prompt,
    this.initialFolderId = '',
    required this.favoriteColors,
    required this.onToggleFavorite,
    required this.settings,
  });

  final List<FolderItem> folders;
  final PromptItem? prompt;
  final String initialFolderId;
  final List<int> favoriteColors;
  final ValueChanged<int> onToggleFavorite;
  final AppSettings settings;

  @override
  State<PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<PromptEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _tagsController;
  late String _selectedFolderId;
  late int _titleColorValue;
  late List<PromptSegment> _segments;

  final List<Color> _presetColors = [
    const Color(0xFF111827),
    const Color(0xFF1D4ED8),
    const Color(0xFF7C3AED),
    const Color(0xFFDB2777),
    const Color(0xFFDC2626),
    const Color(0xFFEA580C),
    const Color(0xFFD97706),
    const Color(0xFF65A30D),
    const Color(0xFF059669),
    const Color(0xFF0891B2),
    const Color(0xFF0F766E),
    const Color(0xFF4F46E5),
    const Color(0xFF2563EB),
    const Color(0xFF0EA5E9),
    const Color(0xFF9333EA),
    const Color(0xFFC026D3),
    const Color(0xFFE11D48),
    const Color(0xFFB91C1C),
    const Color(0xFF9A3412),
    const Color(0xFFA16207),
    const Color(0xFF3F6212),
    const Color(0xFF166534),
    const Color(0xFF155E75),
    const Color(0xFF334155),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.prompt?.title ?? '');
    _tagsController = TextEditingController(
      text: widget.prompt?.tags.join(', ') ?? '',
    );
    _selectedFolderId = widget.prompt?.folderId ?? widget.initialFolderId;
    _titleColorValue = widget.prompt?.titleColorValue ?? AppPalette.ink.value;
    _segments =
        widget.prompt?.segments.map((s) => s.copyWith()).toList() ??
        [PromptSegment(text: '', colorValue: AppPalette.ink.value)];
  }

  void _save() {
    triggerInteractionHaptic(widget.settings);
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final now = DateTime.now();

    Navigator.pop(
      context,
      PromptItem(
        id: widget.prompt?.id ?? PromptStore.newId(),
        title: title,
        titleColorValue: _titleColorValue,
        folderId: _selectedFolderId,
        tags: tags,
        createdAt: widget.prompt?.createdAt ?? now,
        updatedAt: now,
        segments: _segments,
      ),
    );
  }

  Future<void> _pickMoreColors(int segmentIdx) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (ctx) => ColorPickerDialog(presets: _presetColors, settings: widget.settings),
    );

    if (color != null) {
      setState(() {
        _segments[segmentIdx] = _segments[segmentIdx].copyWith(
          colorValue: color.value,
        );
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.prompt == null ? '프롬프트 만들기' : '프롬프트 편집'),
          actions: [
            TextButton(
              onPressed: () {
                triggerInteractionHaptic(widget.settings);
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            FilledButton(onPressed: _save, child: const Text('저장')),
            const SizedBox(width: 16),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFolderId,
                items: [
                  const DropdownMenuItem(value: '', child: Text('폴더 없음')),
                  ...widget.folders.map(
                    (folder) => DropdownMenuItem(
                      value: folder.id,
                      child: Text(folder.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedFolderId = v ?? ''),
                decoration: const InputDecoration(labelText: '폴더'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: '태그 (쉼표로 구분)'),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    '프롬프트 내용',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      triggerInteractionHaptic(widget.settings);
                      setState(
                        () => _segments.add(
                          PromptSegment(
                            text: '',
                            colorValue: AppPalette.ink.value,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              ..._segments.asMap().entries.map((entry) {
                final idx = entry.key;
                final seg = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...AppPalette.values.map(
                                (palette) => _ColorDot(
                                  colorValue: palette.value,
                                  isSelected: seg.colorValue == palette.value,
                                  onTap: () {
                                    triggerInteractionHaptic(widget.settings);
                                    setState(
                                      () => _segments[idx] = seg.copyWith(
                                        colorValue: palette.value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (widget.favoriteColors.isNotEmpty) ...[
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.grey.withOpacity(0.3),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                ...widget.favoriteColors.map(
                                  (colorValue) => _ColorDot(
                                    colorValue: colorValue,
                                    isSelected: seg.colorValue == colorValue,
                                    onTap: () {
                                      triggerInteractionHaptic(widget.settings);
                                      setState(
                                        () => _segments[idx] = seg.copyWith(
                                          colorValue: colorValue,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              IconButton(
                                icon: const Icon(
                                  Icons.palette_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  triggerInteractionHaptic(widget.settings);
                                  _pickMoreColors(idx);
                                },
                                tooltip: '다른 색상 선택',
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  widget.favoriteColors.contains(seg.colorValue)
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 20,
                                  color:
                                      widget.favoriteColors.contains(
                                        seg.colorValue,
                                      )
                                      ? Colors.amber
                                      : null,
                                ),
                                onPressed: () {
                                  triggerInteractionHaptic(widget.settings);
                                  widget.onToggleFavorite(seg.colorValue);
                                  setState(() {});
                                },
                                tooltip: '즐겨찾기 추가',
                              ),
                              IconButton(
                                onPressed: () {
                                  triggerInteractionHaptic(widget.settings);
                                  setState(() {
                                    if (_segments.length > 1) {
                                      _segments.removeAt(idx);
                                    }
                                  });
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                tooltip: '삭제',
                              ),
                            ],
                          ),
                        ),
                        TextFormField(
                          initialValue: seg.text,
                          maxLines: null,
                          onChanged: (v) =>
                              _segments[idx] = _segments[idx].copyWith(text: v),
                          decoration: const InputDecoration(
                            hintText: '여기에 내용을 입력하세요...',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.colorValue,
    required this.isSelected,
    required this.onTap,
  });

  final int colorValue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                )
              : Border.all(color: Colors.black12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(colorValue).withOpacity(0.4),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({super.key, required this.presets, required this.settings});

  final List<Color> presets;
  final AppSettings settings;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  final TextEditingController _hexController = TextEditingController();
  Color? _customColor;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _hexController.addListener(_onHexChanged);
  }

  @override
  void dispose() {
    _hexController.removeListener(_onHexChanged);
    _hexController.dispose();
    super.dispose();
  }

  void _onHexChanged() {
    final text = _hexController.text.trim().replaceAll('#', '');
    if (text.isEmpty) {
      setState(() {
        _customColor = null;
        _errorText = null;
      });
      return;
    }

    final hexRegex = RegExp(r'^[0-9a-fA-F]{6}$');
    if (!hexRegex.hasMatch(text)) {
      setState(() {
        _customColor = null;
        _errorText = '올바른 6자리 16진수 코드를 입력하세요. (예: FF5733)';
      });
      return;
    }

    final parsedValue = int.tryParse(text, radix: 16);
    if (parsedValue != null) {
      setState(() {
        _customColor = Color(0xFF000000 | parsedValue);
        _errorText = null;
      });
    } else {
      setState(() {
        _customColor = null;
        _errorText = '유효하지 않은 색상 코드입니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text('색상 선택'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '기본 색상',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: widget.presets.length,
                itemBuilder: (ctx, idx) {
                  final color = widget.presets[idx];
                  return GestureDetector(
                    onTap: () {
                      triggerInteractionHaptic(widget.settings);
                      Navigator.pop(ctx, color);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                '사용자 정의 색상',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      maxLength: 7,
                      decoration: InputDecoration(
                        prefixText: '#',
                        labelText: '색상 코드 (HEX)',
                        hintText: 'FF5733',
                        errorText: _errorText,
                        errorMaxLines: 2,
                        counterText: '',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _customColor ?? (isDark ? Colors.grey[800] : Colors.grey[200]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 2,
                      ),
                    ),
                    child: _customColor == null
                        ? Icon(
                            Icons.question_mark_rounded,
                            size: 18,
                            color: isDark ? Colors.white30 : Colors.black26,
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            triggerInteractionHaptic(widget.settings);
            Navigator.pop(context);
          },
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _customColor == null
              ? null
              : () {
                  triggerInteractionHaptic(widget.settings);
                  Navigator.pop(context, _customColor);
                },
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.settings,
    required this.onToggleTheme,
    required this.onToggleLock,
    required this.onToggleBiometric,
    required this.onChangePin,
    required this.onLockNow,
    required this.onBackup,
    required this.onRestore,
    required this.onToggleHaptic,
  });

  final AppSettings settings;
  final ValueChanged<bool> onToggleTheme;
  final ValueChanged<bool> onToggleLock;
  final ValueChanged<bool> onToggleBiometric;
  final VoidCallback onChangePin;
  final VoidCallback onLockNow;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final ValueChanged<bool> onToggleHaptic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('다크 모드'),
            value: settings.darkMode,
            onChanged: onToggleTheme,
          ),
          SwitchListTile(
            title: const Text('터치 진동'),
            value: settings.hapticEnabled,
            onChanged: onToggleHaptic,
          ),
          SwitchListTile(
            title: const Text('앱 잠금'),
            value: settings.lockEnabled,
            onChanged: onToggleLock,
          ),
          SwitchListTile(
            title: const Text('지문 인식 잠금해제'),
            subtitle: const Text('지문 및 생체 인식을 사용하여 잠금을 해제합니다.'),
            value: settings.biometricEnabled,
            onChanged: settings.lockEnabled ? onToggleBiometric : null,
          ),
          ListTile(
            leading: const Icon(Icons.pin),
            title: const Text('PIN 변경'),
            onTap: onChangePin,
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('지금 잠금'),
            onTap: onLockNow,
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('백업 저장'),
            onTap: onBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('백업 불러오기'),
            onTap: onRestore,
          ),
        ],
      ),
    );
  }
}

class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.name,
    required this.promptCount,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final int promptCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Cover color of the folder
    final coverColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final borderColor = isSelected 
        ? scheme.primary 
        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1));
    final labelColor = isDark ? Colors.white : Colors.black;
    final countColor = isDark ? Colors.white60 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 90,
        margin: const EdgeInsets.only(right: 12),
        child: Stack(
          children: [
            // Back paper tab sticking out
            Positioned(
              top: 0,
              left: 10,
              right: 10,
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ),
            ),
            // Front cover
            Positioned.fill(
              top: 8,
              child: CustomPaint(
                painter: FolderFrontPainter(
                  color: coverColor,
                  borderColor: borderColor,
                  borderWidth: isSelected ? 2.0 : 1.0,
                ),
              ),
            ),
            // Prompt count top-left of front cover
            Positioned(
              top: 30, // folder body starts at top 8 + painter offset 20 = 28
              left: 12,
              child: Text(
                promptCount.toString(),
                style: TextStyle(
                  color: countColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Folder name bottom-left of front cover
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(
                name,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FolderFrontPainter extends CustomPainter {
  FolderFrontPainter({
    required this.color,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  final Color color;
  final Color? borderColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    const double r = 8.0;

    // Drawing folder cover with tab on left (y = 10), lower section on right (y = 20)
    path.moveTo(0, 10 + r);
    path.quadraticBezierTo(0, 10, r, 10);
    path.lineTo(w * 0.45 - r, 10);
    path.quadraticBezierTo(w * 0.45, 10, w * 0.48, 10 + r * 0.5);
    path.lineTo(w * 0.52, 20 - r * 0.5);
    path.quadraticBezierTo(w * 0.54, 20, w * 0.54 + r, 20);
    path.lineTo(w - r, 20);
    path.quadraticBezierTo(w, 20, w, 20 + r);
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    if (borderColor != null) {
      final borderPaint = Paint()
        ..color = borderColor!
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FolderFrontPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
