import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class DeviceChannelTemplatesRepository {
  const DeviceChannelTemplatesRepository();

  Future<String> insert({
    required String mainId,
    int? channelCode,
    required String channelType,
    required String dataType,
    int? dataLimitMin,
    int? dataLimitMax,
    int? dataByteLenght,
    int? mqttPackageOrder,
    required bool hasSubChannel,
    Map<String, Object>? formula,
    String? enName,
    String? trName,
    String? frName,
    String? arName,
    String? esName,
    required String deviceTypeModelsId,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = const Uuid().v4();
    await db.insert('device_channel_templates', {
      'id': id,
      'main_id': mainId,
      'channel_code': channelCode,
      'channel_type': channelType,
      'data_type': dataType,
      'data_limit_min': dataLimitMin,
      'data_limit_max': dataLimitMax,
      'data_byte_length': dataByteLenght,
      'mqtt_package_order': mqttPackageOrder,
      'has_sub_channel': hasSubChannel ? 1 : 0,
      'formula': formula != null ? jsonEncode(formula) : null,
      'en_name': enName,
      'tr_name': trName,
      'fr_name': frName,
      'ar_name': arName,
      'es_name': esName,
      'device_type_models_id': deviceTypeModelsId,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    return id;
  }

  Future<String> upsert({
    required String id,
    int? channelCode,
    required String channelType,
    required String dataType,
    int? dataLimitMin,
    int? dataLimitMax,
    int? dataByteLenght,
    int? mqttPackageOrder,
    required bool hasSubChannel,
    Map<String, Object>? formula,
    String? enName,
    String? trName,
    String? frName,
    String? arName,
    String? esName,
    required String deviceTypeModelsId,
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await getById(id);
    if (existing != null) {
      await db.update(
        'device_channel_templates',
        {
          'channel_code': channelCode,
          'channel_type': channelType,
          'data_type': dataType,
          'data_limit_min': dataLimitMin,
          'data_limit_max': dataLimitMax,
          'data_byte_length': dataByteLenght,
          'mqtt_package_order': mqttPackageOrder,
          'has_sub_channel': hasSubChannel ? 1 : 0,
          'formula': formula != null ? jsonEncode(formula) : null,
          'en_name': enName,
          'tr_name': trName,
          'fr_name': frName,
          'ar_name': arName,
          'es_name': esName,
          'device_type_models_id': deviceTypeModelsId,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    await db.insert('device_channel_templates', {
      'id': id,
      'channel_code': channelCode,
      'channel_type': channelType,
      'data_type': dataType,
      'data_limit_min': dataLimitMin,
      'data_limit_max': dataLimitMax,
      'data_byte_length': dataByteLenght,
      'mqtt_package_order': mqttPackageOrder,
      'has_sub_channel': hasSubChannel ? 1 : 0,
      'formula': formula != null ? jsonEncode(formula) : null,
      'en_name': enName,
      'tr_name': trName,
      'fr_name': frName,
      'ar_name': arName,
      'es_name': esName,
      'device_type_models_id': deviceTypeModelsId,
    });
    return id;
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'device_channel_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> getByChannelType(
    String channelType,
  ) async {
    final db = await AppDatabase.instance.database;
    return db.query(
      'device_channel_templates',
      where: 'channel_type = ?',
      whereArgs: [channelType],
    );
  }

  Future<List<Map<String, Object?>>> getByDeviceTypeModelsId(
    String deviceTypeModelsId,
  ) async {
    final db = await AppDatabase.instance.database;
    return db.query(
      'device_channel_templates',
      where: 'device_type_models_id = ?',
      whereArgs: [deviceTypeModelsId],
    );
  }

  /// DeviceId'den W kanallarını mqtt_package_order'a göre artan sırada getirir
  Future<List<Map<String, Object?>>> getWriteChannelsByDeviceId(
    String deviceId,
  ) async {
    final db = await AppDatabase.instance.database;

    // JOIN ile device -> device_type_models -> device_channel_templates
    // channelType='W' olanları çek ve mqtt_package_order'a göre sırala
    final result = await db.rawQuery(
      '''
      SELECT dct.* 
      FROM device_channel_templates dct
      INNER JOIN device_type_models dtm ON dct.device_type_models_id = dtm.id
      INNER JOIN devices d ON d.order_code = dtm.order_code
      WHERE d.id = ? AND dct.channel_type = 'W'
      ORDER BY dct.mqtt_package_order ASC
    ''',
      [deviceId],
    );

    return result;
  }

  Future<List<Map<String, Object?>>> listAll() async {
    final db = await AppDatabase.instance.database;
    return db.query('device_channel_templates');
  }

  Future<int> deleteById(String id) async {
    final db = await AppDatabase.instance.database;
    return db.delete(
      'device_channel_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper: formula'yı Map olarak parse et
  Map<String, Object>? parseFormula(Map<String, Object?> row) {
    final formulaStr = row['formula'] as String?;
    if (formulaStr == null || formulaStr.isEmpty) return null;
    try {
      return Map<String, Object>.from(jsonDecode(formulaStr) as Map);
    } catch (_) {
      return null;
    }
  }
}
