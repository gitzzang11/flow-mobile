import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';

class FolderManagementScreen extends StatefulWidget {
  const FolderManagementScreen({
    super.key,
    required this.store,
    required this.onChanged,
    required this.selectedFolderId,
  });
  final PromptStore store;
  final Future<void> Function() onChanged;
  final String selectedFolderId;
  @override
  State<FolderManagementScreen> createState() => _FolderManagementScreenState();
}

class _FolderManagementScreenState extends State<FolderManagementScreen> {
  Future<String?> _nameDialog({FolderItem? folder}) async {
    final controller = TextEditingController(text: folder?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(folder == null ? '새 폴더' : '폴더 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '폴더 이름',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _create() async {
    final name = await _nameDialog();
    if (name == null) return;
    setState(
      () => widget.store.folders.add(
        FolderItem(
          id: PromptStore.newId(),
          name: name,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await widget.onChanged();
  }

  Future<void> _edit(FolderItem folder) async {
    final name = await _nameDialog(folder: folder);
    if (name == null) return;
    final index = widget.store.folders.indexWhere(
      (item) => item.id == folder.id,
    );
    if (index >= 0) {
      setState(() => widget.store.folders[index] = folder.copyWith(name: name));
    }
    await widget.onChanged();
  }

  Future<void> _delete(FolderItem folder) async {
    final count = widget.store.prompts
        .where((prompt) => prompt.folderId == folder.id)
        .length;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('폴더를 삭제할까요?'),
            content: Text(
              '“${folder.name}” 폴더 안의 프롬프트 $count개는 삭제되지 않고 전체 프롬프트로 이동합니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.store.deleteFolder(folder.id);
    if (mounted) setState(() {});
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('폴더 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('새 폴더'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('전체 프롬프트'),
              subtitle: Text('${widget.store.prompts.length}개'),
              selected: widget.selectedFolderId.isEmpty,
              onTap: () => Navigator.pop(context, ''),
            ),
            const Divider(height: 1),
            Expanded(
              child: widget.store.folders.isEmpty
                  ? const Center(child: Text('아직 폴더가 없습니다.'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: widget.store.folders.length,
                      onReorder: (oldIndex, newIndex) async {
                        await widget.store.reorderFolders(oldIndex, newIndex);
                        if (mounted) setState(() {});
                        await widget.onChanged();
                      },
                      itemBuilder: (context, index) {
                        final folder = widget.store.folders[index];
                        final count = widget.store.prompts
                            .where((prompt) => prompt.folderId == folder.id)
                            .length;
                        return ListTile(
                          key: ValueKey(folder.id),
                          leading: const Icon(Icons.folder_rounded),
                          title: Text(folder.name),
                          subtitle: Text('프롬프트 $count개'),
                          selected: widget.selectedFolderId == folder.id,
                          onTap: () => Navigator.pop(context, folder.id),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => value == 'edit'
                                ? _edit(folder)
                                : _delete(folder),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('이름 변경'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline),
                                  title: Text('삭제'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
