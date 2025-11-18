import 'package:flutter/material.dart';

enum DeviceType {
  zenopixSpecialBox(
    serialId: '6E400001-B5A3-F393-E0A9-E50E24DCCAA0',
    displayName: 'Zenopix Custom Box v1.0',
    icon: Icons.lightbulb_outline,
    imageAssetPath: 'assets/devices/special_box.png',
  ),
  zenopixWateringModule(
    serialId: '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
    displayName: 'Zenopix Watering Module v1.0',
    icon: Icons.water_drop,
    imageAssetPath: 'assets/devices/watering_module.png',
  );

  final String serialId;
  final String displayName;
  final IconData icon;
  final String imageAssetPath;

  const DeviceType({
    required this.serialId,
    required this.displayName,
    required this.icon,
    required this.imageAssetPath,
  });

  // Tüm seri numaralarını liste olarak döndür
  static List<String> getAllSerialIds() {
    return DeviceType.values.map((e) => e.serialId).toList();
  }

  // Belirli bir seri numarasına göre tip bul
  static DeviceType? findBySerialId(String serialId) {
    try {
      return DeviceType.values.firstWhere((e) => e.serialId == serialId);
    } catch (e) {
      return null;
    }
  }

  static String? displayNameBySerial(String? serialId) {
    if (serialId == null) return null;
    return findBySerialId(serialId)?.displayName;
  }

  // Yalnızca advertise edilen servis UUID'lerine göre eşleşme kontrolü
  static bool matchesByServiceUuid({
    required String? targetUuid,
    List<String> advertisedServiceUuids = const [],
  }) {
    if (targetUuid == null || targetUuid.isEmpty) return false;
    final target = targetUuid.toUpperCase();
    return advertisedServiceUuids.any((s) => s.toUpperCase() == target);
  }
}

extension DeviceTypeExtension on DeviceType {
  static DeviceType? findByTypeName(String? typeName) {
    if (typeName == null) return null;
    final normalized = typeName.trim();
    if (normalized.isEmpty) return null;
    try {
      return DeviceType.values.firstWhere(
        (e) =>
            e.name.toLowerCase() == normalized.toLowerCase() ||
            e.displayName.toLowerCase() == normalized.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static String formatDisplayName(String? typeName) {
    final type = findByTypeName(typeName);
    if (type != null) return type.displayName;
    return typeName == null || typeName.trim().isEmpty ? '-' : typeName;
  }

  static IconData? iconFor(String? typeName) {
    if (typeName == null) return null;
    final type =
        findByTypeName(typeName) ?? DeviceType.findBySerialId(typeName);
    return type?.icon;
  }

  static String? imagePathFor(String? typeName) {
    if (typeName == null) return null;
    final type =
        findByTypeName(typeName) ?? DeviceType.findBySerialId(typeName);
    return type?.imageAssetPath;
  }
}

class DeviceTypeInfo {
  final String typeName;
  final String serialId;
  final String displayName;
  final IconData icon;
  final String imageAssetPath;

  DeviceTypeInfo({
    required this.typeName,
    required this.serialId,
    required this.displayName,
    required this.icon,
    required this.imageAssetPath,
  });

  factory DeviceTypeInfo.fromDeviceType(DeviceType type) {
    return DeviceTypeInfo(
      typeName: type.name,
      serialId: type.serialId,
      displayName: type.displayName,
      icon: type.icon,
      imageAssetPath: type.imageAssetPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'typeName': typeName,
      'serialId': serialId,
      'displayName': displayName,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'iconMatchTextDirection': icon.matchTextDirection,
      'imageAssetPath': imageAssetPath,
    };
  }

  factory DeviceTypeInfo.fromMap(Map<String, dynamic> map) {
    return DeviceTypeInfo(
      typeName: map['typeName'] as String,
      serialId: map['serialId'] as String,
      displayName: map['displayName'] as String,
      icon: IconData(
        map['iconCodePoint'] as int,
        fontFamily: map['iconFontFamily'] as String?,
        fontPackage: map['iconFontPackage'] as String?,
        matchTextDirection: map['iconMatchTextDirection'] as bool? ?? false,
      ),
      imageAssetPath: map['imageAssetPath'] as String,
    );
  }
}
