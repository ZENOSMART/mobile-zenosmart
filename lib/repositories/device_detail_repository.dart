import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class DeviceDetailRepository {
  const DeviceDetailRepository();

  Future<String> insert({
    required String deviceId,
    String? uartServiceUuid,
    String? rxCharUuid,
    String? txCharUuid,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = const Uuid().v4();
    final payload = <String, Object?>{'id': id, 'device_id': deviceId};
    if (uartServiceUuid != null) {
      payload['uart_service_uuid'] = uartServiceUuid;
    }
    if (rxCharUuid != null) {
      payload['rx_char_uuid'] = rxCharUuid;
    }
    if (txCharUuid != null) {
      payload['tx_char_uuid'] = txCharUuid;
    }
    await db.insert(
      'device_detail',
      payload,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return id;
  }

  Future<String> upsert({
    required String deviceId,
    String? uartServiceUuid,
    String? rxCharUuid,
    String? txCharUuid,
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await getByDeviceId(deviceId);
    if (existing != null) {
      final id = existing['id'] as String;
      // Sadece null olmayan değerleri güncelle, null değerler gönderildiğinde mevcut değerleri koru
      final updateValues = <String, Object?>{};
      if (uartServiceUuid != null) {
        updateValues['uart_service_uuid'] = uartServiceUuid;
      }
      if (rxCharUuid != null) {
        updateValues['rx_char_uuid'] = rxCharUuid;
      }
      if (txCharUuid != null) {
        updateValues['tx_char_uuid'] = txCharUuid;
      }
      // Eğer güncellenecek değer varsa güncelle
      if (updateValues.isNotEmpty) {
        await db.update(
          'device_detail',
          updateValues,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
    final id = const Uuid().v4();
    final insertPayload = <String, Object?>{
      'id': id,
      'device_id': deviceId,
    };
    // Sadece null olmayan değerleri ekle
    if (uartServiceUuid != null) {
      insertPayload['uart_service_uuid'] = uartServiceUuid;
    }
    if (rxCharUuid != null) {
      insertPayload['rx_char_uuid'] = rxCharUuid;
    }
    if (txCharUuid != null) {
      insertPayload['tx_char_uuid'] = txCharUuid;
    }
    await db.insert('device_detail', insertPayload);
    return id;
  }

  Future<Map<String, Object?>?> getByDeviceId(String deviceId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'device_detail',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> deleteById(String id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('device_detail', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByDeviceId(String deviceId) async {
    final db = await AppDatabase.instance.database;
    return db.delete(
      'device_detail',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }
}
