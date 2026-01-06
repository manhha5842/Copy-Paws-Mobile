/// Clipboard item model representing a clipboard entry
class ClipboardItem {
  final String id;
  final String content;
  final DateTime timestamp;
  final String? sourceDevice;
  final String? sourceApp;
  final bool isFromHub;

  ClipboardItem({
    required this.id,
    required this.content,
    required this.timestamp,
    this.sourceDevice,
    this.sourceApp,
    this.isFromHub = false,
  });

  /// Create from JSON (received from WebSocket)
  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      id: json['clip_id'] ?? json['id'] ?? '',
      content: json['content'] ?? json['payload'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
      sourceDevice: json['source_device'],
      sourceApp: json['source_app'],
      isFromHub: json['is_from_hub'] ?? true,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'source_device': sourceDevice,
      'source_app': sourceApp,
      'is_from_hub': isFromHub,
    };
  }

  /// Get preview text (truncated)
  String get preview {
    const maxLength = 100;
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  /// Get formatted timestamp
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  ClipboardItem copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    String? sourceDevice,
    String? sourceApp,
    bool? isFromHub,
  }) {
    return ClipboardItem(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      sourceApp: sourceApp ?? this.sourceApp,
      isFromHub: isFromHub ?? this.isFromHub,
    );
  }
}
