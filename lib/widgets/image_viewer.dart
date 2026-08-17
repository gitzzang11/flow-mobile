import 'dart:io';

import 'package:flutter/material.dart';

Future<void> showImageViewer(
  BuildContext context,
  List<String> imagePaths, {
  int initialIndex = 0,
}) {
  if (imagePaths.isEmpty) return Future.value();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          ImageViewerScreen(imagePaths: imagePaths, initialIndex: initialIndex),
    ),
  );
}

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('image-viewer-screen'),
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} / ${widget.imagePaths.length}'),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.imagePaths.length,
      onPageChanged: (value) => setState(() => _index = value),
      itemBuilder: (context, index) => Semantics(
        label: '첨부 이미지 ${index + 1}',
        image: true,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(widget.imagePaths[index]),
              key: ValueKey('viewer-image-$index'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.white70),
                  SizedBox(height: 8),
                  Text(
                    '이미지를 표시할 수 없습니다.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
