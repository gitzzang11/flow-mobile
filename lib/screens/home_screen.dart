import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/backup_service.dart';
import '../services/biometric_service.dart';
import '../services/pin_credential_store.dart';
import '../store.dart';
import '../widgets/app_toast.dart';
import '../widgets/prompt_card.dart';
import 'folder_management_screen.dart';
import 'prompt_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.pinStore,
    required this.biometricService,
    required this.backupService,
    required this.onStoreChanged,
    required this.onRequireRelock,
    required this.onExternalActivityChanged,
  });
  final PromptStore store;
  final PinCredentialStore pinStore;
  final BiometricService biometricService;
  final BackupService backupService;
  final Future<void> Function() onStoreChanged;
  final VoidCallback onRequireRelock;
  final ValueChanged<bool> onExternalActivityChanged;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFolderId = '';
  String _search = '';
  bool _searching = false;
  final _selectedTags = <String>{};
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  PromptStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<PromptItem> get _visiblePrompts {
    final query = _search.trim().toLowerCase();
    final result = store.prompts.where((prompt) {
      final folderMatches =
          _selectedFolderId.isEmpty || prompt.folderId == _selectedFolderId;
      final queryMatches =
          query.isEmpty ||
          prompt.title.toLowerCase().contains(query) ||
          prompt.plainText.toLowerCase().contains(query) ||
          prompt.tags.any((tag) => tag.toLowerCase().contains(query));
      final tagsMatch = _selectedTags.every(prompt.tags.contains);
      return folderMatches && queryMatches && tagsMatch;
    }).toList();
    int compare(PromptItem a, PromptItem b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      switch (store.settings.promptSortMode) {
        case PromptSortMode.newest:
          return b.updatedAt.compareTo(a.updatedAt);
        case PromptSortMode.oldest:
          return a.updatedAt.compareTo(b.updatedAt);
        case PromptSortMode.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    }

    result.sort(compare);
    return result;
  }

  String get _folderTitle {
    if (_selectedFolderId.isEmpty) return '전체 프롬프트';
    for (final folder in store.folders) {
      if (folder.id == _selectedFolderId) return folder.name;
    }
    return '전체 프롬프트';
  }

  Future<void> _openEditor([PromptItem? prompt]) async {
    final result = await Navigator.push<PromptItem>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PromptEditorScreen(
          folders: store.folders,
          settings: store.settings,
          initialFolderId: _selectedFolderId,
          prompt: prompt,
          onFavoriteColorsChanged: (colors) {
            store.settings = store.settings.copyWith(favoriteColors: colors);
            widget.onStoreChanged();
          },
        ),
      ),
    );
    if (result == null) return;
    await store.savePrompt(result);
    await widget.onStoreChanged();
    if (mounted) setState(() {});
  }

  Future<void> _copy(PromptItem prompt) async {
    await Clipboard.setData(ClipboardData(text: prompt.plainText));
    if (mounted) showAppToast(context, '클립보드에 복사했습니다.');
  }

  Rect _shareOrigin() {
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  Future<void> _share(PromptItem prompt) async {
    widget.onExternalActivityChanged(true);
    try {
      await widget.backupService.sharePrompt(prompt, origin: _shareOrigin());
    } on Object {
      if (mounted) showAppToast(context, '프롬프트를 공유하지 못했습니다.', error: true);
    } finally {
      widget.onExternalActivityChanged(false);
    }
  }

  Future<void> _togglePin(PromptItem prompt) async {
    await store.savePrompt(
      prompt.copyWith(isPinned: !prompt.isPinned, updatedAt: DateTime.now()),
    );
    await widget.onStoreChanged();
    if (mounted) setState(() {});
  }

  Future<void> _duplicate(PromptItem prompt) async {
    final now = DateTime.now();
    await store.savePrompt(
      prompt.copyWith(
        id: PromptStore.newId(),
        title: '${prompt.title} (복사본)',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      ),
    );
    await widget.onStoreChanged();
    if (mounted) {
      setState(() {});
      showAppToast(context, '프롬프트를 복제했습니다.');
    }
  }

  Future<void> _move(PromptItem prompt) async {
    final folderId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '다른 폴더로 이동',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('폴더 없음'),
              onTap: () => Navigator.pop(context, ''),
            ),
            ...store.folders.map(
              (folder) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                trailing: prompt.folderId == folder.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, folder.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (folderId == null || folderId == prompt.folderId) return;
    await store.savePrompt(
      prompt.copyWith(folderId: folderId, updatedAt: DateTime.now()),
    );
    await widget.onStoreChanged();
    if (mounted) setState(() {});
  }

  Future<void> _delete(PromptItem prompt) async {
    final index = await store.deletePrompt(prompt.id);
    if (index < 0 || !mounted) return;
    setState(() {});
    showAppToast(
      context,
      '“${prompt.title}”을 삭제했습니다.',
      duration: const Duration(seconds: 5),
      actionLabel: '되돌리기',
      onAction: () async {
        await store.restorePrompt(prompt, index);
        await widget.onStoreChanged();
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _showActions(PromptItem prompt) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(
                prompt.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('클립보드에 복사'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copy(prompt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('공유'),
              onTap: () {
                Navigator.pop(sheetContext);
                _share(prompt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('편집'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openEditor(prompt);
              },
            ),
            ListTile(
              leading: Icon(
                prompt.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
              ),
              title: Text(prompt.isPinned ? '상단 고정 해제' : '상단 고정'),
              onTap: () {
                Navigator.pop(sheetContext);
                _togglePin(prompt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('다른 폴더로 이동'),
              onTap: () {
                Navigator.pop(sheetContext);
                _move(prompt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('복제'),
              onTap: () {
                Navigator.pop(sheetContext);
                _duplicate(prompt);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '삭제',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _delete(prompt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageFolders() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => FolderManagementScreen(
          store: store,
          onChanged: widget.onStoreChanged,
          selectedFolderId: _selectedFolderId,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (selected != null) _selectedFolderId = selected;
      if (_selectedFolderId.isNotEmpty &&
          !store.folders.any((folder) => folder.id == _selectedFolderId)) {
        _selectedFolderId = '';
      }
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          store: store,
          pinStore: widget.pinStore,
          biometricService: widget.biometricService,
          backupService: widget.backupService,
          onChanged: widget.onStoreChanged,
          onLockNow: () {
            Navigator.pop(context);
            widget.onRequireRelock();
          },
          onExternalActivityChanged: widget.onExternalActivityChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _startSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _search = '';
      _searchController.clear();
      _selectedTags.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompts = _visiblePrompts;
    final tags = store.prompts.expand((prompt) => prompt.tags).toSet().toList()
      ..sort();
    return Scaffold(
      key: const ValueKey('home-screen'),
      appBar: AppBar(
        leading: _searching
            ? IconButton(
                tooltip: '검색 닫기',
                onPressed: _closeSearch,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : IconButton(
                tooltip: '폴더 관리',
                onPressed: _manageFolders,
                icon: const Icon(Icons.folder_copy_outlined),
              ),
        title: _searching
            ? TextField(
                key: const ValueKey('prompt-search-field'),
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (value) => setState(() => _search = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '제목, 내용, 태그 검색',
                  border: InputBorder.none,
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _search = '';
                              _selectedTags.clear();
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              )
            : Text(
                _folderTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
        actions: _searching
            ? null
            : [
                IconButton(
                  tooltip: '검색',
                  onPressed: _startSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: '설정',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('new-prompt-button'),
        tooltip: '새 프롬프트',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (store.settings.showFolderNavigation)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 58,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FolderChip(
                        label: '전체',
                        count: store.prompts.length,
                        selected: _selectedFolderId.isEmpty,
                        onTap: () => setState(() => _selectedFolderId = ''),
                      ),
                      ...store.folders.map(
                        (folder) => _FolderChip(
                          label: folder.name,
                          count: store.prompts
                              .where((prompt) => prompt.folderId == folder.id)
                              .length,
                          selected: _selectedFolderId == folder.id,
                          onTap: () =>
                              setState(() => _selectedFolderId = folder.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${prompts.length}개의 프롬프트',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    PopupMenuButton<PromptSortMode>(
                      tooltip: '정렬',
                      initialValue: store.settings.promptSortMode,
                      onSelected: (mode) async {
                        store.settings = store.settings.copyWith(
                          promptSortMode: mode,
                        );
                        await widget.onStoreChanged();
                        if (mounted) setState(() {});
                      },
                      itemBuilder: (context) => PromptSortMode.values
                          .map(
                            (mode) => PopupMenuItem(
                              value: mode,
                              child: Row(
                                children: [
                                  if (mode == store.settings.promptSortMode)
                                    const Icon(Icons.check_rounded, size: 18)
                                  else
                                    const SizedBox(width: 18),
                                  const SizedBox(width: 8),
                                  Text(mode.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            const Icon(Icons.sort_rounded, size: 18),
                            const SizedBox(width: 6),
                            Text(store.settings.promptSortMode.label),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_searching && tags.isNotEmpty)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tags
                        .map(
                          (tag) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('#$tag'),
                              selected: _selectedTags.contains(tag),
                              onSelected: (_) => setState(() {
                                _selectedTags.contains(tag)
                                    ? _selectedTags.remove(tag)
                                    : _selectedTags.add(tag);
                              }),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            if (prompts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onCreate: () => _openEditor()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .76,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final prompt = prompts[index];
                    return PromptCard(
                      prompt: prompt,
                      textScale: store.settings.cardTextScale,
                      onTap: () => _openEditor(prompt),
                      onCopy: () => _copy(prompt),
                      onMore: () => _showActions(prompt),
                    );
                  }, childCount: prompts.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text('$label  $count'),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '프롬프트가 없습니다',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '자주 사용하는 프롬프트를 만들어 빠르게 복사하고 공유하세요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('첫 프롬프트 만들기'),
          ),
        ],
      ),
    ),
  );
}
