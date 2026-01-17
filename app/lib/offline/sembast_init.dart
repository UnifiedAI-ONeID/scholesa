import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';

/// Global Sembast database instance
Database? _dbInstance;

/// Get the Sembast database instance (must call initSembast first)
Database get db {
  if (_dbInstance == null) {
    throw StateError('Database not initialized. Call initSembast() first.');
  }
  return _dbInstance!;
}

/// Initialize Sembast database
Future<Database> initSembast() async {
  if (_dbInstance != null) {
    return _dbInstance!;
  }

  if (kIsWeb) {
    // Use IndexedDB on web
    final factory = databaseFactoryWeb;
    _dbInstance = await factory.openDatabase('scholesa_db');
  } else {
    // Use file-based storage on mobile/desktop
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'scholesa_db.db');
    final factory = databaseFactoryIo;
    _dbInstance = await factory.openDatabase(dbPath);
  }

  return _dbInstance!;
}

/// Close database (for testing)
Future<void> closeSembast() async {
  if (_dbInstance != null) {
    await _dbInstance!.close();
    _dbInstance = null;
  }
}
