import 'package:flutter/material.dart';

import '../../../../core/models/clipboard_item.dart';

/// List of incoming clipboard items from hub
class IncomingClipsList extends StatelessWidget {
  final List<ClipboardItem> clips;
  final Function(String clipId) onCopy;
  final Function(String clipId)? onDelete;

  const IncomingClipsList({
    super.key,
    required this.clips,
    required this.onCopy,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (clips.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clips.length,
      itemBuilder: (context, index) {
        final clip = clips[index];
        return _ClipItem(
          clip: clip,
          onCopy: () => onCopy(clip.id),
          onDelete: onDelete != null ? () => onDelete!(clip.id) : null,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade600),
          const SizedBox(height: 12),
          Text(
            'No incoming clips',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'Clips from desktop will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ClipItem extends StatelessWidget {
  final ClipboardItem clip;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  const _ClipItem({required this.clip, required this.onCopy, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with time and source
              Row(
                children: [
                  if (clip.sourceDevice != null) ...[
                    Icon(Icons.computer, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      clip.sourceDevice!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    clip.formattedTime,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Content preview
              Text(
                clip.preview,
                style: const TextStyle(fontSize: 15),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Copy button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
