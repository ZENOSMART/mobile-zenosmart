import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase _instance = AppDatabase._internal();
  static AppDatabase get instance => _instance;

  static const String _dbName = 'app.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE device_type_models (
          id TEXT PRIMARY KEY,
          main_id TEXT NOT NULL UNIQUE,
          device_type_id TEXT NOT NULL,
          class_type TEXT NOT NULL,
          order_code TEXT NOT NULL UNIQUE
        );
        ''');
        await db.execute('''
        CREATE TABLE devices (
          id TEXT PRIMARY KEY,
          unique_data TEXT NOT NULL UNIQUE,
          name TEXT,
          device_type TEXT,
          device_type_name TEXT,
          device_type_id TEXT,
          order_code TEXT,
          FOREIGN KEY (device_type_id) REFERENCES device_type_models(id) ON DELETE SET NULL
        );
        ''');
        await db.execute('''
        CREATE TABLE device_detail (
          id TEXT PRIMARY KEY,
          device_id TEXT NOT NULL UNIQUE,
          uart_service_uuid TEXT,
          rx_char_uuid TEXT,
          tx_char_uuid TEXT,
          FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
        );
        ''');
        await db.execute('''
        CREATE TABLE device_channel_templates (
          id TEXT PRIMARY KEY,
          main_id TEXT NOT NULL UNIQUE,
          channel_code INTEGER,
          channel_type TEXT NOT NULL,
          data_type TEXT NOT NULL,
          data_limit_min INTEGER,
          data_limit_max INTEGER,
          data_byte_length INTEGER,
          mqtt_package_order INTEGER,
          has_sub_channel INTEGER NOT NULL DEFAULT 0,
          formula TEXT,
          en_name TEXT,
          tr_name TEXT,
          fr_name TEXT,
          ar_name TEXT,
          es_name TEXT,
          device_type_models_id TEXT NOT NULL,
          FOREIGN KEY (device_type_models_id) REFERENCES device_type_models(id) ON DELETE CASCADE
        );
        ''');
      },
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _db = null;
  }
}
