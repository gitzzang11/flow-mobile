import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class FlowShell extends StatefulWidget {
  const FlowShell({
    super.key,
    required this.store,
    required this.onStoreChanged,
    required this.onRequireRelock,
  });

  final PromptStore store;
  final Future<void> Function() onStoreChanged;
  final VoidCallback onRequireRelock;

  @override
  State<FlowShell> createState() => _FlowShellState();
}

class _FlowShellState extends State<FlowShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedFolderId = '';
  String _searchQuery = '';
  bool _isSearching = false;
  final _selectedTags = <String>{};
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PromptItem> get _filteredPrompts {
    final filtered = widget.store.prompts.where((p) {
      final folderMatch =
          _selectedFolderId.isEmpty || p.folderId == _selectedFolderId;
      final query = _searchQuery.toLowerCase();
      final searchMatch =
          p.title.toLowerCase().contains(query) ||
          p.plainText.toLowerCase().contains(query) ||
          p.tags.any((tag) => tag.toLowerCase().contains(query));
      final tagMatch =
          _selectedTags.isEmpty ||
          _selectedTags.every((tag) => p.tags.contains(tag));
      return folderMatch && searchMatch && tagMatch;
    }).toList();

    return _sortPrompts(filtered, mode: widget.store.settings.promptSortMode);
  }

  String get _sortModeLabel {
    switch (widget.store.settings.promptSortMode) {
      case PromptSortMode.newest:
        return '최신순';
      case PromptSortMode.oldest:
        return '오래된순';
      case PromptSortMode.title:
        return '이름순';
    }
  }

  List<PromptItem> _sortPrompts(
    List<PromptItem> prompts, {
    required PromptSortMode mode,
  }) {
    switch (mode) {
      case PromptSortMode.newest:
        return List<PromptItem>.from(prompts)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case PromptSortMode.oldest:
        return List<PromptItem>.from(prompts)
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case PromptSortMode.title:
        return List<PromptItem>.from(prompts)..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
  }

  Future<void> _persistSettings(AppSettings nextSettings) async {
    setState(() {
      widget.store.settings = nextSettings;
    });
    await widget.onStoreChanged();
  }

  Future<void> _changeSortMode(PromptSortMode mode) async {
    await _persistSettings(widget.store.settings.copyWith(promptSortMode: mode));
  }

  Widget _buildPromptCard({
    required PromptItem prompt,
    required int index,
    required int totalCount,
    bool isGrid = false,
  }) {
    final folderName = prompt.folderId.isEmpty
        ? '폴더 없음'
        : widget.store.folders
              .firstWhere(
                (f) => f.id == prompt.folderId,
                orElse: () => FolderItem(
                  id: '',
                  name: '폴더 없음',
                  createdAt: DateTime.now(),
                ),
              )
              .name;

    return PromptCard(
      key: ValueKey(prompt.id),
      prompt: prompt,
      isGrid: isGrid,
      folderName: folderName,
      onCopy: () => _copy(prompt),
      onEdit: () => _openEditor(existing: prompt),
      onDelete: () => _deletePrompt(prompt),
      onDuplicate: () => _duplicatePrompt(prompt),
      onTogglePin: () => _togglePinPrompt(prompt),
    );
  }

  Future<void> _togglePinPrompt(PromptItem p) async {
    setState(() {
      final idx = widget.store.prompts.indexWhere((item) => item.id == p.id);
      if (idx >= 0) {
        widget.store.prompts[idx] = p.copyWith(isPinned: !p.isPinned);
      }
    });
    await widget.onStoreChanged();
  }

  Future<void> _openEditor({PromptItem? existing}) async {
    final result = await showDialog<PromptItem>(
      context: context,
      builder: (ctx) => PromptEditorDialog(
        folders: widget.store.folders,
        prompt: existing,
        initialFolderId: existing == null
            ? _selectedFolderId
            : existing.folderId,
        favoriteColors: widget.store.settings.favoriteColors,
        onToggleFavorite: (color) {
          final favorites = List<int>.from(
            widget.store.settings.favoriteColors,
          );
          if (favorites.contains(color)) {
            favorites.remove(color);
          } else {
            favorites.add(color);
          }
          widget.store.settings = widget.store.settings.copyWith(
            favoriteColors: favorites,
          );
          widget.onStoreChanged();
        },
        settings: widget.store.settings,
      ),
    );
    if (result == null) return;

    setState(() {
      final idx = widget.store.prompts.indexWhere((p) => p.id == result.id);
      if (idx >= 0) {
        widget.store.prompts[idx] = result;
      } else {
        widget.store.prompts.add(result);
      }
    });
    await widget.onStoreChanged();
  }

  Future<void> _deletePrompt(PromptItem p) async {
    setState(() {
      widget.store.prompts.removeWhere((item) => item.id == p.id);
    });
    await widget.onStoreChanged();
  }

  Future<void> _duplicatePrompt(PromptItem p) async {
    final newPrompt = p.copyWith(
      id: PromptStore.newId(),
      title: '${p.title} (복사본)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      widget.store.prompts.add(newPrompt);
    });
    await widget.onStoreChanged();
  }

  Future<void> _showFolderDialog({FolderItem? folder}) async {
    final controller = TextEditingController(text: folder?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(folder == null ? '폴더 생성' : '폴더 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '폴더 이름',
            hintText: '내 업무용 프롬프트',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              triggerInteractionHaptic(widget.store.settings);
              Navigator.pop(ctx);
            },
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              triggerInteractionHaptic(widget.store.settings);
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (folder == null) {
          widget.store.folders.add(
            FolderItem(
              id: PromptStore.newId(),
              name: result,
              createdAt: DateTime.now(),
            ),
          );
        } else {
          final idx = widget.store.folders.indexWhere((f) => f.id == folder.id);
          if (idx != -1) {
            widget.store.folders[idx] = folder.copyWith(name: result);
          }
        }
      });
      await widget.onStoreChanged();
    }
  }

  Future<void> _deleteFolder(FolderItem folder) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('폴더 삭제'),
            content: Text(
              '${folder.name} 폴더를 삭제할까요? 폴더 안의 프롬프트는 "폴더 없음"으로 이동됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      widget.store.folders.removeWhere((f) => f.id == folder.id);
      for (var i = 0; i < widget.store.prompts.length; i++) {
        if (widget.store.prompts[i].folderId == folder.id) {
          widget.store.prompts[i] = widget.store.prompts[i].copyWith(
            folderId: '',
          );
        }
      }
      if (_selectedFolderId == folder.id) {
        _selectedFolderId = '';
      }
    });
    await widget.onStoreChanged();
  }

  Future<void> _copy(PromptItem p) async {
    triggerInteractionHaptic(widget.store.settings);
    await Clipboard.setData(ClipboardData(text: p.plainText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('클립보드에 복사되었습니다.')));
  }

  Future<String?> _showPinDialog({required String title}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('4자리 PIN을 입력하세요.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '****',
                  counterText: '',
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              triggerInteractionHaptic(widget.store.settings);
              Navigator.pop(ctx);
            },
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length == 4) {
                triggerInteractionHaptic(widget.store.settings);
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleBackup() async {
    triggerInteractionHaptic(widget.store.settings);
    try {
      final backupBytes = Uint8List.fromList(
        utf8.encode(widget.store.exportToJson()),
      );
      final fileName =
          'flow_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: '백업 파일 저장',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: backupBytes,
      );

      if (result == null) return;
      _showMessage('백업 파일이 저장되었습니다.');
    } catch (e) {
      _showMessage('백업 저장 중 오류가 발생했습니다.');
    }
  }

  Future<void> _handleRestore() async {
    triggerInteractionHaptic(widget.store.settings);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('데이터 불러오기'),
            content: const Text('현재 데이터는 백업 파일 내용으로 교체됩니다. 계속할까요?'),
            actions: [
              TextButton(
                onPressed: () {
                  triggerInteractionHaptic(widget.store.settings);
                  Navigator.pop(ctx, false);
                },
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  triggerInteractionHaptic(widget.store.settings);
                  Navigator.pop(ctx, true);
                },
                child: const Text('불러오기'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final backupBytes = result.files.single.bytes;
      if (backupBytes == null || backupBytes.isEmpty) {
        throw const FormatException('Empty backup file');
      }

      final jsonString = utf8.decode(backupBytes);
      setState(() {
        widget.store.importFromJsonString(jsonString);
      });

      await widget.onStoreChanged();
      _showMessage('백업 파일을 불러왔습니다.');
    } on FormatException {
      _showMessage('백업 파일 형식이 올바르지 않습니다.');
    } catch (e) {
      _showMessage('백업 파일을 불러오는 중 오류가 발생했습니다.');
    }
  }

  void _openSettings() {
    triggerInteractionHaptic(widget.store.settings);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SettingsSheet(
            settings: widget.store.settings,
            onToggleTheme: (v) {
              triggerInteractionHaptic(widget.store.settings);
              widget.store.settings = widget.store.settings.copyWith(darkMode: v);
              widget.onStoreChanged();
              setSheetState(() {});
            },
            onToggleLock: (v) async {
              triggerInteractionHaptic(widget.store.settings);
              if (v && widget.store.settings.pinCode.isEmpty) {
                Navigator.pop(ctx);
                final pin = await _showPinDialog(title: 'PIN 설정');
                if (pin != null) {
                  widget.store.settings = widget.store.settings.copyWith(
                    lockEnabled: true,
                    pinCode: pin,
                  );
                  await widget.onStoreChanged();
                }
              } else {
                widget.store.settings = widget.store.settings.copyWith(
                  lockEnabled: v,
                  biometricEnabled: v ? widget.store.settings.biometricEnabled : false,
                );
                await widget.onStoreChanged();
                setSheetState(() {});
              }
            },
            onToggleBiometric: (v) async {
              triggerInteractionHaptic(widget.store.settings);
              if (v) {
                final localAuth = LocalAuthentication();
                try {
                  final isSupported = await localAuth.isDeviceSupported();
                  final canCheck = await localAuth.canCheckBiometrics;
                  if (!isSupported || !canCheck) {
                    _showMessage('이 기기는 지문 및 생체 인증을 지원하지 않거나 설정되어 있지 않습니다.');
                    return;
                  }
                  final authenticated = await localAuth.authenticate(
                    localizedReason: '지문 인식 잠금해제를 설정하기 위해 인증해주세요.',
                    biometricOnly: true,
                    persistAcrossBackgrounding: true,
                  );
                  if (!authenticated) {
                    return;
                  }
                } catch (e) {
                  _showMessage('생체 인증 설정 중 오류가 발생했습니다: $e');
                  return;
                }
              }
              widget.store.settings = widget.store.settings.copyWith(biometricEnabled: v);
              await widget.onStoreChanged();
              setSheetState(() {});
            },
            onChangePin: () async {
              triggerInteractionHaptic(widget.store.settings);
              Navigator.pop(ctx);
              final pin = await _showPinDialog(title: 'PIN 변경');
              if (pin != null) {
                widget.store.settings = widget.store.settings.copyWith(
                  pinCode: pin,
                );
                await widget.onStoreChanged();
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('PIN이 변경되었습니다.')));
                }
              }
            },
            onLockNow: () {
              triggerInteractionHaptic(widget.store.settings);
              Navigator.pop(ctx);
              widget.onRequireRelock();
            },
            onBackup: _handleBackup,
            onRestore: _handleRestore,
            onToggleHaptic: (v) {
              if (v) {
                HapticFeedback.lightImpact();
              }
              widget.store.settings = widget.store.settings.copyWith(hapticEnabled: v);
              widget.onStoreChanged();
              setSheetState(() {});
            },
          );
        },
      ),
    );
  }

  String _getMonthGroupName(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month) {
      return '이번 달';
    } else if (date.year == now.year) {
      return '${date.month}월';
    } else {
      return '${date.year}년 ${date.month}월';
    }
  }

  Widget _buildFoldersHorizontalList() {
    final folders = widget.store.folders;
    final prompts = widget.store.prompts;

    return SizedBox(
      height: 110,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: folders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return FolderCard(
              name: '전체',
              promptCount: prompts.length,
              isSelected: _selectedFolderId.isEmpty,
              onTap: () {
                triggerInteractionHaptic(widget.store.settings);
                setState(() {
                  _selectedFolderId = '';
                });
              },
            );
          }

          final folder = folders[index - 1];
          final count = prompts.where((p) => p.folderId == folder.id).length;

          return FolderCard(
            name: folder.name,
            promptCount: count,
            isSelected: _selectedFolderId == folder.id,
            onTap: () {
              triggerInteractionHaptic(widget.store.settings);
              setState(() {
                if (_selectedFolderId == folder.id) {
                  _selectedFolderId = '';
                } else {
                  _selectedFolderId = folder.id;
                }
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 900;
    final prompts = _filteredPrompts;
    final visibleTags = _searchQuery.isEmpty
        ? const <String>[]
        : (widget.store.prompts
              .expand((p) => p.tags)
              .where(
                (tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toSet()
              .toList()
            ..sort());

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pinnedPrompts = prompts.where((p) => p.isPinned).toList();
    final regularPrompts = prompts.where((p) => !p.isPinned).toList();

    // Group prompts by month
    final monthGroups = <String, List<PromptItem>>{};
    for (final prompt in regularPrompts) {
      final groupName = _getMonthGroupName(prompt.updatedAt);
      monthGroups.putIfAbsent(groupName, () => []).add(prompt);
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        titleSpacing: 16,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  triggerInteractionHaptic(widget.store.settings);
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                    _selectedTags.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: isWide
                    ? null
                    : () {
                        triggerInteractionHaptic(widget.store.settings);
                        _scaffoldKey.currentState?.openDrawer();
                      },
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() {
                  _searchQuery = value;
                  if (_searchQuery.isEmpty) {
                    _selectedTags.clear();
                  }
                }),
                decoration: InputDecoration(
                  hintText: '제목, 태그, 내용 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedTags.clear();
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              )
            : const Text(
                '폴더',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
        actions: _isSearching
            ? []
            : [
                IconButton(
                  onPressed: () {
                    triggerInteractionHaptic(widget.store.settings);
                    setState(() {
                      _isSearching = true;
                    });
                  },
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: '설정',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
      ),
      drawer: isWide
            ? null
            : Drawer(
                width: 280,
                child: FolderSidebar(
                  folders: widget.store.folders,
                  prompts: widget.store.prompts,
                  selectedFolderId: _selectedFolderId,
                  onSelectFolder: (id) {
                    triggerInteractionHaptic(widget.store.settings);
                    setState(() => _selectedFolderId = id);
                  },
                  onCreateFolder: () {
                    triggerInteractionHaptic(widget.store.settings);
                    _showFolderDialog();
                  },
                  onEditFolder: (f) {
                    triggerInteractionHaptic(widget.store.settings);
                    _showFolderDialog(folder: f);
                  },
                  onDeleteFolder: (f) {
                    triggerInteractionHaptic(widget.store.settings);
                    _deleteFolder(f);
                  },
                ),
              ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: 280,
              child: FolderSidebar(
                folders: widget.store.folders,
                prompts: widget.store.prompts,
                selectedFolderId: _selectedFolderId,
                onSelectFolder: (id) {
                  triggerInteractionHaptic(widget.store.settings);
                  setState(() => _selectedFolderId = id);
                },
                onCreateFolder: () {
                  triggerInteractionHaptic(widget.store.settings);
                  _showFolderDialog();
                },
                onEditFolder: (f) {
                  triggerInteractionHaptic(widget.store.settings);
                  _showFolderDialog(folder: f);
                },
                onDeleteFolder: (f) {
                  triggerInteractionHaptic(widget.store.settings);
                  _deleteFolder(f);
                },
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const columnCount = 2;
                const crossAxisSpacing = 16.0;
                const mainAxisSpacing = 16.0;
                const padding = 16.0;
                final totalSpacing = (columnCount - 1) * crossAxisSpacing + padding * 2;
                final itemWidth = (constraints.maxWidth - totalSpacing) / columnCount;
                final mainAxisExtent = itemWidth + 60.0;

                return CustomScrollView(
                  slivers: [
                    // Horizontal folders list
                    SliverToBoxAdapter(
                      child: _buildFoldersHorizontalList(),
                    ),

                    // Sorting controls (layout toggle removed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<PromptSortMode>(
                            tooltip: '정렬',
                            onSelected: (mode) {
                              triggerInteractionHaptic(widget.store.settings);
                              _changeSortMode(mode);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: PromptSortMode.newest,
                                child: Text('최신순'),
                              ),
                              PopupMenuItem(
                                value: PromptSortMode.oldest,
                                child: Text('오래된순'),
                              ),
                              PopupMenuItem(
                                value: PromptSortMode.title,
                                child: Text('이름순'),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withOpacity(0.22),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sort_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_sortModeLabel),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_searchQuery.isNotEmpty && visibleTags.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: visibleTags
                                  .map(
                                    (tag) => FilterChip(
                                      label: Text('#$tag'),
                                      selected: _selectedTags.contains(tag),
                                      onSelected: (_) => setState(
                                        () => _selectedTags.contains(tag)
                                            ? _selectedTags.remove(tag)
                                            : _selectedTags.add(tag),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),

                    if (prompts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateCard(onCreatePrompt: () => _openEditor()),
                      )
                    else ...[
                      if (pinnedPrompts.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '고정된 프롬프트',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: mainAxisSpacing,
                              crossAxisSpacing: crossAxisSpacing,
                              mainAxisExtent: mainAxisExtent,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, idx) {
                                final prompt = pinnedPrompts[idx];
                                final overallIdx = prompts.indexOf(prompt);
                                return _buildPromptCard(
                                  prompt: prompt,
                                  index: overallIdx,
                                  totalCount: prompts.length,
                                  isGrid: true,
                                );
                              },
                              childCount: pinnedPrompts.length,
                            ),
                          ),
                        ),
                      ],
                      for (final entry in monthGroups.entries) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: mainAxisSpacing,
                              crossAxisSpacing: crossAxisSpacing,
                              mainAxisExtent: mainAxisExtent,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, idx) {
                                final prompt = entry.value[idx];
                                final overallIdx = prompts.indexOf(prompt);
                                return _buildPromptCard(
                                  prompt: prompt,
                                  index: overallIdx,
                                  totalCount: prompts.length,
                                  isGrid: true,
                                );
                              },
                              childCount: entry.value.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          triggerInteractionHaptic(widget.store.settings);
          _openEditor();
        },
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
        foregroundColor: isDark ? Colors.white : Colors.black,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class ShakeCurve extends Curve {
  const ShakeCurve({this.count = 3.0});
  final double count;

  @override
  double transformInternal(double t) {
    return math.sin(t * count * 2 * math.pi);
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.pin, required this.onUnlock, required this.settings});

  final String pin;
  final VoidCallback onUnlock;
  final AppSettings settings;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _isUnlocking = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  int _failedAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _countdownTimer;
  bool _loadingState = true;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: const ShakeCurve(count: 3.0),
      ),
    );
    _loadLockoutState().then((_) {
      if (widget.settings.lockEnabled && widget.settings.biometricEnabled && _lockoutSecondsRemaining == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithBiometrics();
        });
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shakeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLockoutState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutMillis = prefs.getInt('lockscreen_lockout_until') ?? 0;
      final failed = prefs.getInt('lockscreen_failed_attempts') ?? 0;

      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutMillis);
      final now = DateTime.now();

      if (mounted) {
        setState(() {
          _failedAttempts = failed;
          _loadingState = false;
          if (lockoutTime.isAfter(now)) {
            final diffSeconds = lockoutTime.difference(now).inSeconds;
            if (diffSeconds > 0) {
              _startLockoutCountdown(diffSeconds);
            } else {
              _clearFailedAttempts();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingState = false;
        });
      }
    }
  }

  void _startLockoutCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _lockoutSecondsRemaining = seconds;
      _error = '10회 실패로 잠금해제가 제한됩니다. ($_lockoutSecondsRemaining초 후 재시도)';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_lockoutSecondsRemaining > 1) {
          _lockoutSecondsRemaining--;
          _error = '10회 실패로 잠금해제가 제한됩니다. ($_lockoutSecondsRemaining초 후 재시도)';
        } else {
          _lockoutSecondsRemaining = 0;
          _countdownTimer?.cancel();
          _clearFailedAttempts();
          _error = null;
          _pinController.clear();
        }
      });
    });
  }

  Future<void> _incrementFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts++;
    await prefs.setInt('lockscreen_failed_attempts', _failedAttempts);

    if (_failedAttempts >= 10) {
      final now = DateTime.now();
      final lockoutTime = now.add(const Duration(minutes: 1));
      await prefs.setInt('lockscreen_lockout_until', lockoutTime.millisecondsSinceEpoch);
      _startLockoutCountdown(60);
    }
  }

  Future<void> _clearFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = 0;
    _lockoutSecondsRemaining = 0;
    await prefs.remove('lockscreen_failed_attempts');
    await prefs.remove('lockscreen_lockout_until');
  }

  Future<void> _authenticateWithBiometrics({bool isManual = false}) async {
    if (_isUnlocking || _lockoutSecondsRemaining > 0 || _loadingState) return;

    final localAuth = LocalAuthentication();
    try {
      final isSupported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;
      if (!isSupported || !canCheck) {
        if (isManual) {
          setState(() {
            _error = '생체 인증을 사용할 수 없거나 설정되어 있지 않습니다.';
          });
        }
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: '앱 잠금을 해제하려면 생체 인증을 해주세요.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        if (!mounted) return;
        setState(() {
          _error = null;
          _isUnlocking = true;
        });
        await _clearFailedAttempts();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onUnlock();
        });
      }
    } catch (e) {
      if (isManual) {
        setState(() {
          _error = '생체 인증 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  Future<void> _check() async {
    triggerInteractionHaptic(widget.settings);
    if (_isUnlocking || _lockoutSecondsRemaining > 0 || _loadingState) return;

    FocusScope.of(context).unfocus();
    final input = _pinController.text.trim();

    if (input == widget.pin) {
      setState(() {
        _error = null;
        _isUnlocking = true;
      });
      await _clearFailedAttempts();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onUnlock();
      });
      return;
    }

    // Wrong PIN
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0.0);

    await _incrementFailedAttempts();

    if (mounted) {
      setState(() {
        if (_failedAttempts >= 10) {
          // Lockout is active, countdown handles error text update.
        } else {
          _error = 'PIN이 일치하지 않습니다. (시도 횟수: $_failedAttempts/10)';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLockedOut = _lockoutSecondsRemaining > 0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLockedOut
                              ? Icons.lock_clock_outlined
                              : Icons.lock_person_outlined,
                          size: 80,
                          color: isLockedOut
                              ? Colors.redAccent
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isLockedOut ? '잠금 해제 제한됨' : '잠금 해제',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isLockedOut ? Colors.redAccent : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          enabled: !_isUnlocking && !isLockedOut && !_loadingState,
                          decoration: InputDecoration(
                            errorText: _error,
                            counterText: '',
                            prefixIcon: isLockedOut
                                ? const Icon(Icons.timer, color: Colors.redAccent)
                                : null,
                            suffixIcon: (widget.settings.biometricEnabled && !isLockedOut)
                                ? IconButton(
                                    icon: Icon(
                                      Icons.fingerprint,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: () => _authenticateWithBiometrics(isManual: true),
                                    tooltip: '생체 인증 사용',
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _check(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (_isUnlocking || isLockedOut || _loadingState) ? null : _check,
                            child: _isUnlocking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('확인'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
