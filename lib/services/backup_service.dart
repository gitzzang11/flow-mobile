import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../store.dart';
import 'image_attachment_service.dart';

class BackupService {
  BackupService({ImageAttachmentService? imageService})
    : imageService = imageService ?? ImageAttachmentService();

  final ImageAttachmentService imageService;
  static const maxImportBytes = 10 * 1024 * 1024;
  static const _staleBackupAge = Duration(days: 1);
  static const _backupPrefix = 'flow_backup_';

  Future<void> sharePrompt(PromptItem prompt, {Rect? origin}) async {
    final tags = prompt.tags.isEmpty
        ? ''
        : '\n\n${prompt.tags.map((tag) => '#$tag').join(' ')}';
    await SharePlus.instance.share(
      ShareParams(
        files: prompt.imagePaths
            .where((path) => File(path).existsSync())
            .map(XFile.new)
            .toList(),
        text: '[${prompt.title}]\n\n${prompt.plainText}$tags',
        subject: prompt.title,
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> exportBackup(PromptStore store, {Rect? origin}) async {
    final temp = await getTemporaryDirectory();
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final name =
        'flow_backup_${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
    final file = File('${temp.path}${Platform.pathSeparator}$name');
    try {
      await file.writeAsString(
        store.exportToJson(includeImages: true),
        encoding: utf8,
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Flow 백업',
          text: 'Flow 프롬프트 백업 파일입니다.',
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The next startup cleanup retries files still held by a share target.
      }
    }
  }

  Future<void> cleanupStaleBackups() async {
    try {
      final temp = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(_staleBackupAge);
      await for (final entity in temp.list()) {
        if (entity is! File ||
            !entity.uri.pathSegments.last.startsWith(_backupPrefix)) {
          continue;
        }
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
          }
        } on FileSystemException {
          // Best effort only; a later startup will retry.
        }
      }
    } on Object {
      // Cleanup must never prevent the app from opening.
    }
  }

  Future<String?> pickBackupJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'flow'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (picked.size > maxImportBytes) {
      throw const FormatException('Backup file is too large.');
    }
    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      final file = File(picked.path!);
      if (await file.length() > maxImportBytes) {
        throw const FormatException('Backup file is too large.');
      }
      bytes = await file.readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Empty backup file.');
    }
    if (bytes.lengthInBytes > maxImportBytes) {
      throw const FormatException('Backup file is too large.');
    }
    return imageService.restoreEmbeddedImages(utf8.decode(bytes));
  }
}
