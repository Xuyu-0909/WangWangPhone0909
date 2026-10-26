import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const String startupPasscodeSettingKey = 'security.passcode';

StartupSecurityStore buildDefaultStartupSecurityStore() {
  if (kIsWeb) {
    return SharedPreferencesStartupSecurityStore();
  }
  return SqliteStartupSecurityStore();
}

abstract class StartupSecurityStore {
  Future<void> initialize();

  Future<String?> readPasscode();

  Future<void> writePasscode(String passcode);

  /// 统一以 6 位密码作为是否已设置密码的判断标准。
  Future<bool> hasPasscode() async {
    final passcode = await readPasscode();
    return passcode != null && passcode.length == 6;
  }
}

// The virtual phone's local lock follows the existing preferences storage model
// in browsers, where native SQLite and application support paths are unavailable.
class SharedPreferencesStartupSecurityStore extends StartupSecurityStore {
  @override
  Future<void> initialize() async {
    await SharedPreferences.getInstance();
  }

  @override
  Future<String?> readPasscode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(startupPasscodeSettingKey);
  }

  @override
  Future<void> writePasscode(String passcode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(startupPasscodeSettingKey, passcode);
    if (!saved) {
      throw StateError('无法保存启动密码');
    }
  }
}

class SqliteStartupSecurityStore implements StartupSecurityStore {
  Database? _database;

  /// 复用主应用数据库文件，并确保 settings 表存在，方便后续和 C++ 核心层共享配置。
  @override
  Future<void> initialize() async {
    await _openDatabase();
  }

  @override
  Future<String?> readPasscode() async {
    final database = await _openDatabase();
    final rows = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [startupPasscodeSettingKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final rawValue = rows.first['value'];
    return rawValue?.toString();
  }

  /// 使用键值表保存启动密码，保持和现有数据库 schema 一致。
  @override
  Future<void> writePasscode(String passcode) async {
    final database = await _openDatabase();
    await database.insert('settings', {
      'key': startupPasscodeSettingKey,
      'value': passcode,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> hasPasscode() async {
    final passcode = await readPasscode();
    return passcode != null && passcode.length == 6;
  }

  Future<Database> _openDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final databasePath = p.join(supportDirectory.path, 'wangwang_phone.db');
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (database, _) async {
        await _ensureSettingsTable(database);
      },
      onOpen: (database) async {
        await _ensureSettingsTable(database);
      },
    );
    return _database!;
  }

  /// settings 表只做轻量配置存储，避免首次启动因为缺表导致密码流程失效。
  Future<void> _ensureSettingsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT ''
      )
    ''');
  }
}

class MemoryStartupSecurityStore implements StartupSecurityStore {
  MemoryStartupSecurityStore({String? initialPasscode})
    : _passcode = initialPasscode;

  String? _passcode;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> readPasscode() async {
    return _passcode;
  }

  @override
  Future<void> writePasscode(String passcode) async {
    _passcode = passcode;
  }

  @override
  Future<bool> hasPasscode() async {
    final passcode = await readPasscode();
    return passcode != null && passcode.length == 6;
  }
}
