/// Content types for clipboard items
enum ClipboardContentType { text, image, file }

/// Extension to convert content type to/from string
extension ClipboardContentTypeX on ClipboardContentType {
  String get value {
    switch (this) {
      case ClipboardContentType.text:
        return 'text';
      case ClipboardContentType.image:
        return 'image';
      case ClipboardContentType.file:
        return 'file';
    }
  }

  static ClipboardContentType fromString(String? value) {
    switch (value) {
      case 'image':
        return ClipboardContentType.image;
      case 'file':
        return ClipboardContentType.file;
      case 'text':
      default:
        return ClipboardContentType.text;
    }
  }
}

/// Clipboard item model representing a clipboard entry
class ClipboardItem {
  final String id;
  final String
  content; // For text: actual content, for image: base64 or file path
  final DateTime timestamp;
  final String? sourceDevice;
  final String? sourceApp;
  final bool isFromHub;
  final ClipboardContentType contentType;
  final String? mimeType; // For images: 'image/png', 'image/jpeg', etc.
  final int? contentSize; // Size in bytes (useful for images)
  final String? thumbnailPath; // Local path to thumbnail (for images)

  ClipboardItem({
    required this.id,
    required this.content,
    required this.timestamp,
    this.sourceDevice,
    this.sourceApp,
    this.isFromHub = false,
    this.contentType = ClipboardContentType.text,
    this.mimeType,
    this.contentSize,
    this.thumbnailPath,
  });

  /// Check if this is an image item
  bool get isImage => contentType == ClipboardContentType.image;

  /// Check if this is a text item
  bool get isText => contentType == ClipboardContentType.text;

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
      contentType: ClipboardContentTypeX.fromString(
        json['content_type'] as String?,
      ),
      mimeType: json['mime_type'] as String?,
      contentSize: json['content_size'] as int?,
      thumbnailPath: json['thumbnail_path'] as String?,
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
      'content_type': contentType.value,
      'mime_type': mimeType,
      'content_size': contentSize,
      'thumbnail_path': thumbnailPath,
    };
  }

  /// Get preview text (truncated) - for text content
  String get preview {
    if (isImage) {
      return '📷 Image${contentSize != null ? ' (${_formatBytes(contentSize!)})' : ''}';
    }
    const maxLength = 100;
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  /// Format bytes to human readable
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    ClipboardContentType? contentType,
    String? mimeType,
    int? contentSize,
    String? thumbnailPath,
  }) {
    return ClipboardItem(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      sourceApp: sourceApp ?? this.sourceApp,
      isFromHub: isFromHub ?? this.isFromHub,
      contentType: contentType ?? this.contentType,
      mimeType: mimeType ?? this.mimeType,
      contentSize: contentSize ?? this.contentSize,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
