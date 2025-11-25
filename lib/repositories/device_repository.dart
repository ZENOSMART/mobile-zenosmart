import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class DeviceRepository {
  const DeviceRepository();

  Future<String> insert({
    required String uniqueData,
    String? name,
    String? deviceType,
    String? deviceTypeName,
    String? deviceTypeId,
    String? orderCode,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = const Uuid().v4();
    await db.insert('devices', {
      'id': id,
      'unique_data': uniqueData,
      'name': name,
      'device_type': deviceType,
      'device_type_name': deviceTypeName,
      'device_type_id': deviceTypeId,
      'order_code': orderCode,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    return id;
  }

  Future<String> upsert({
    required String uniqueData,
    String? name,
    String? deviceType,
    String? deviceTypeName,
    String? deviceTypeId,
    String? orderCode,
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await getByUnique(uniqueData);
    if (existing != null) {
      final id = existing['id'] as String;
      await db.update(
        'devices',
        {
          'name': name,
          'device_type': deviceType,
          'device_type_name': deviceTypeName,
          'device_type_id': deviceTypeId,
          'order_code': orderCode,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    final id = const Uuid().v4();
    await db.insert('devices', {
      'id': id,
      'unique_data': uniqueData,
      'name': name,
      'device_type': deviceType,
      'device_type_name': deviceTypeName,
      'device_type_id': deviceTypeId,
      'order_code': orderCode,
    });
    return id;
  }

  Future<Map<String, Object?>?> getByUnique(String uniqueData) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'devices',
      where: 'unique_data = ?',
      whereArgs: [uniqueData],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> listAll() async {
    final db = await AppDatabase.instance.database;
    return db.query('devices', orderBy: 'rowid DESC');
  }

  Future<List<Map<String, Object?>>> searchByName(String query) async {
    final db = await AppDatabase.instance.database;
    final q = query.trim();
    if (q.isEmpty) {
      return db.query('devices', orderBy: 'rowid DESC');
    }
    return db.query(
      'devices',
      where: 'name LIKE ?',
      whereArgs: ['%$q%'],
      orderBy: 'rowid DESC',
    );
  }

  Future<Set<String>> listAllUniqueKeys() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('devices', columns: ['unique_data']);
    return rows
        .map((e) => e['unique_data'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'devices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> deleteById(String id) async {
    final db = await AppDatabase.instance.database;
    return db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateName(String id, String name) async {
    final db = await AppDatabase.instance.database;
    return db.update(
      'devices',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
