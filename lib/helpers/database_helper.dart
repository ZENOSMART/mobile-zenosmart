import '../database/database.dart';

class DatabaseHelper {
  static Future<List<Map<String, dynamic>>> getDeviceChannels(
    String deviceId,
  ) async {
    final db = await AppDatabase.instance.database;
    return await db.rawQuery(
      '''
      SELECT dct.* 
      FROM device_channel_templates dct
      INNER JOIN devices d ON d.device_type_id = dct.device_type_models_id
      WHERE d.id = ? AND dct.channel_type = 'R'
      ORDER BY dct.mqtt_package_order
    ''',
      [deviceId],
    );
  }
}
