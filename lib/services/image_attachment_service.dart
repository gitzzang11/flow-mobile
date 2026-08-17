import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

typedef AttachmentDirectoryProvider = Future<Directory> Function();

class ImageAttachmentService {
  ImageAttachmentService({
    ImagePicker? picker,
    AttachmentDirectoryProvider? directoryProvider,
  }) : _picker = picker ?? ImagePicker(),
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final ImagePicker _picker;
  final AttachmentDirectoryProvider _directoryProvider;

  Future<List<String>> pickFromGallery() async {
    final images = await _picker.pickMultiImage(
      imageQuality: 92,
      maxWidth: 2560,
    );
    return _persist(images);
  }

  Future<List<String>> takePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
      maxWidth: 2560,
    );
    return image == null ? const [] : _persist([image]);
  }

  Future<List<String>> recoverLostImages() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return const [];
    return _persist(response.files ?? const []);
  }

  Future<List<String>> _persist(List<XFile> images) async {
    if (images.isEmpty) return const [];
    final directory = await _imagesDirectory();
    final paths = <String>[];
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final extension = _safeExtension(image.name);
      final name = '${DateTime.now().microsecondsSinceEpoch}_$index$extension';
      final target = File('${directory.path}${Platform.pathSeparator}$name');
      await image.saveTo(target.path);
      paths.add(target.path);
    }
    return paths;
  }

  Future<String> restoreEmbeddedImages(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) return rawJson;
    final json = decoded.cast<String, dynamic>();
    final rawImages = json['images'];
    if (rawImages is! Map || rawImages.isEmpty) return rawJson;
    final directory = await _imagesDirectory();
    final restored = <String, String>{};
    var index = 0;
    for (final entry in rawImages.entries) {
      try {
        final sourcePath = entry.key.toString();
        final bytes = base64Decode(entry.value.toString());
        final extension = _safeExtension(sourcePath);
        final target = File(
          '${directory.path}${Platform.pathSeparator}'
          'restored_${DateTime.now().microsecondsSinceEpoch}_${index++}$extension',
        );
        await target.writeAsBytes(bytes, flush: true);
        restored[sourcePath] = target.path;
      } on Object {
        // Ignore one corrupt image while keeping the rest of the backup usable.
      }
    }
    final prompts = json['prompts'];
    if (prompts is List) {
      for (final value in prompts.whereType<Map>()) {
        final prompt = value.cast<String, dynamic>();
        final paths = prompt['imagePaths'];
        if (paths is List) {
          prompt['imagePaths'] = paths
              .map((path) => restored[path.toString()] ?? path.toString())
              .toList();
        }
      }
    }
    return jsonEncode(json);
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths.toSet()) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Cleanup is best effort and must never block editing.
      }
    }
  }

  Future<Directory> _imagesDirectory() async {
    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}flow_images',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _safeExtension(String name) {
    final match = RegExp(
      r'\.(jpe?g|png|gif|webp|bmp|tiff?|heic|heif)$',
      caseSensitive: false,
    ).firstMatch(name);
    return match == null ? '.jpg' : match.group(0)!.toLowerCase();
  }
}
