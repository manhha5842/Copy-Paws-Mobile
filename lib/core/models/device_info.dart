/// Device info model representing connected devices
class DeviceInfo {
  final String id;
  final String name;
  final String platform;
  final String? batteryLevel;
  final bool isCurrentDevice;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    this.batteryLevel,
    this.isCurrentDevice = false,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['device_id'] ?? json['id'] ?? '',
      name: json['device_name'] ?? json['name'] ?? 'Unknown Device',
      platform: json['platform'] ?? 'Unknown',
      batteryLevel: json['battery'],
      isCurrentDevice: json['is_current'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': id,
      'device_name': name,
      'platform': platform,
      'battery': batteryLevel,
      'is_current': isCurrentDevice,
    };
  }

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? platform,
    String? batteryLevel,
    bool? isCurrentDevice,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    );
  }
}
