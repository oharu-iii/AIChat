import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class Logger {
  static File? _logFile;
  static const String _logFileName = 'ai_chat.log';
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _maxBackupFiles = 3;
  static LogLevel _minimumLogLevel = LogLevel.info; // デフォルトのログレベル

  static void setLogLevel(LogLevel level) {
    _minimumLogLevel = level;
  }

  static Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/$_logFileName');
    
    // ログファイルの存在確認と作成
    if (!await _logFile!.exists()) {
      await _logFile!.create();
    } else {
      // ファイルサイズチェック
      await _checkAndRotateLog();
    }
  }

  static Future<void> _checkAndRotateLog() async {
    if (_logFile == null) return;

    final fileStats = await _logFile!.stat();
    if (fileStats.size > _maxFileSizeBytes) {
      // バックアップファイルをローテーション
      for (var i = _maxBackupFiles - 1; i > 0; i--) {
        final file = File('${_logFile!.path}.$i');
        final previousFile = File('${_logFile!.path}.${i - 1}');
        if (await previousFile.exists()) {
          await previousFile.rename(file.path);
        }
      }

      // 現在のログファイルを.1にリネーム
      if (await _logFile!.exists()) {
        await _logFile!.rename('${_logFile!.path}.1');
      }

      // 新しいログファイルを作成
      _logFile = File('${_logFile!.path}');
      await _logFile!.create();
    }
  }

  static Future<void> log(String message, {LogLevel level = LogLevel.info}) async {
    // ログレベルチェック
    if (level.index < _minimumLogLevel.index) return;

    if (_logFile == null) {
      await initialize();
    }

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logMessage = '[$timestamp][${level.toString().split('.').last.toUpperCase()}] $message\n';
    
    await _checkAndRotateLog();
    await _logFile!.writeAsString(logMessage, mode: FileMode.append);
    
    // エラーレベル以上のログは必ずコンソールに出力
    if (level.index >= LogLevel.error.index) {
      print('\x1B[31m$logMessage\x1B[0m'); // 赤色で出力
    } else if (level.index >= LogLevel.warning.index) {
      print('\x1B[33m$logMessage\x1B[0m'); // 黄色で出力
    } else {
      print(logMessage);
    }
  }

  static Future<void> debug(String message) async => log(message, level: LogLevel.debug);
  static Future<void> info(String message) async => log(message, level: LogLevel.info);
  static Future<void> warning(String message) async => log(message, level: LogLevel.warning);
  static Future<void> error(String message) async => log(message, level: LogLevel.error);
} 