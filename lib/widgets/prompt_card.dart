import 'package:flutter/material.dart';
import '../models.dart';

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
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    prompt.plainText,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13 * textScale,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
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
