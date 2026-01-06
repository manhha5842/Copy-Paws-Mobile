/// Hub info model representing the connected desktop hub
class HubInfo {
  final String id;
  final String name;
  final String endpoint; // ws://ip:port
  final String? ip;
  final int? port;
  final DateTime? lastConnected;
  final bool isPaired;

  HubInfo({
    required this.id,
    required this.name,
    required this.endpoint,
    this.ip,
    this.port,
    this.lastConnected,
    this.isPaired = false,
  });

  factory HubInfo.fromJson(Map<String, dynamic> json) {
    return HubInfo(
      id: json['hub_id'] ?? json['id'] ?? '',
      name: json['hub_name'] ?? json['name'] ?? 'Unknown Hub',
      endpoint: json['endpoint'] ?? '',
      ip: json['ip'],
      port: json['port'],
      lastConnected: json['last_connected'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_connected'] as int)
          : null,
      isPaired: json['is_paired'] ?? false,
    );
  }

  factory HubInfo.fromQRData(String qrData) {
    // Parse QR data format: copypaws://pair?ip=xxx&port=xxx&token=xxx&name=xxx
    final uri = Uri.parse(qrData);
    final params = uri.queryParameters;

    return HubInfo(
      id: params['id'] ?? '',
      name: params['name'] ?? 'Desktop Hub',
      endpoint: 'ws://${params['ip']}:${params['port']}',
      ip: params['ip'],
      port: int.tryParse(params['port'] ?? ''),
      isPaired: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hub_id': id,
      'hub_name': name,
      'endpoint': endpoint,
      'ip': ip,
      'port': port,
      'last_connected': lastConnected?.millisecondsSinceEpoch,
      'is_paired': isPaired,
    };
  }

  HubInfo copyWith({
    String? id,
    String? name,
    String? endpoint,
    String? ip,
    int? port,
    DateTime? lastConnected,
    bool? isPaired,
  }) {
    return HubInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      lastConnected: lastConnected ?? this.lastConnected,
      isPaired: isPaired ?? this.isPaired,
    );
  }
}
