import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import 'image_viewer.dart';

class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.prompt,
    required this.textScale,
    required this.onTap,
    required this.onCopy,
    required this.onMore,
  });
  final PromptItem prompt;
  final double textScale;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${prompt.title} 프롬프트',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('prompt-card-${prompt.id}'),
          onTap: onTap,
          onLongPress: onMore,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (prompt.isPinned) ...[
                      Icon(
                        Icons.push_pin_rounded,
                        size: 15,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        prompt.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15 * textScale,
                          fontWeight: FontWeight.w700,
                          color: Color(prompt.titleColorValue),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '더보기',
                      visualDensity: VisualDensity.compact,
                      onPressed: onMore,
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                    ),
                  ],
                ),
                if (prompt.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Semantics(
                    button: true,
                    label: '첨부 이미지 ${prompt.imagePaths.length}장 보기',
                    child: InkWell(
                      key: ValueKey('prompt-card-image-${prompt.id}'),
                      onTap: () => showImageViewer(context, prompt.imagePaths),
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(prompt.imagePaths.first),
                              width: double.infinity,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 72,
                                color: scheme.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                          if (prompt.imagePaths.length > 1)
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '+${prompt.imagePaths.length - 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: RichText(
                    key: ValueKey('prompt-card-content-${prompt.id}'),
                    maxLines: prompt.imagePaths.isEmpty ? 6 : 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13 * textScale,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                      children: prompt.segments
                          .map(
                            (segment) => TextSpan(
                              text: segment.text,
                              style: TextStyle(
                                color: Color(segment.colorValue),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                if (prompt.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    prompt.tags.take(2).map((tag) => '#$tag').join('  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11 * textScale,
                      color: scheme.primary,
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${prompt.updatedAt.month}.${prompt.updatedAt.day}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: '복사',
                      visualDensity: VisualDensity.compact,
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
