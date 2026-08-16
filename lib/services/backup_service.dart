import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../store.dart';

class BackupService {
  Future<void> sharePrompt(PromptItem prompt, {Rect? origin}) async {
    final tags = prompt.tags.isEmpty
        ? ''
        : '\n\n${prompt.tags.map((tag) => '#$tag').join(' ')}';
    await SharePlus.instance.share(
      ShareParams(
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
    await file.writeAsString(store.exportToJson(), encoding: utf8, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Flow 백업',
        text: 'Flow 프롬프트 백업 파일입니다.',
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<String?> pickBackupJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'flow'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Empty backup file.');
    }
    return utf8.decode(bytes);
  }
}
