import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class DeviceTypeModelsRepository {
  const DeviceTypeModelsRepository();

  Future<String> insert({
    required String mainId,
    required String deviceTypeId,
    required String classType,
    required String orderCode,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = const Uuid().v4();
    await db.insert('device_type_models', {
      'id': id,
      'main_id': mainId,
      'device_type_id': deviceTypeId,
      'class_type': classType,
      'order_code': orderCode,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    return id;
  }

  Future<String> upsert({
    required String mainId,
    required String deviceTypeId,
    required String classType,
    required String orderCode,
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await getByOrderCode(orderCode);
    if (existing != null) {
      final id = existing['id'] as String;
      await db.update(
        'device_type_models',
        {
          'main_id': mainId,
          'device_type_id': deviceTypeId,
          'class_type': classType,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    final id = const Uuid().v4();
    await db.insert('device_type_models', {
      'id': id,
      'main_id': mainId,
      'device_type_id': deviceTypeId,
      'class_type': classType,
      'order_code': orderCode,
    });
    return id;
  }

  Future<Map<String, Object?>?> getByOrderCode(String orderCode) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'device_type_models',
      where: 'order_code = ?',
      whereArgs: [orderCode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'device_type_models',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Object?>?> getByDeviceTypeId(String deviceTypeId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'device_type_models',
      where: 'device_type_id = ?',
      whereArgs: [deviceTypeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> listAll() async {
    final db = await AppDatabase.instance.database;
    return db.query('device_type_models');
  }

  Future<int> deleteById(String id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('device_type_models', where: 'id = ?', whereArgs: [id]);
  }
}
