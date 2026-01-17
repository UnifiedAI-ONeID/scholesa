import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'queued_op_model.dart';

/// Global Isar instance
Isar? _isarInstance;

/// Get the Isar instance (must call initIsar first)
Isar get isar {
  if (_isarInstance == null) {
    throw StateError('Isar not initialized. Call initIsar() first.');
  }
  return _isarInstance!;
}

/// Initialize Isar database
Future<Isar> initIsar() async {
  if (_isarInstance != null) {
    return _isarInstance!;
  }

  final dir = await getApplicationDocumentsDirectory();
  
  _isarInstance = await Isar.open(
    <CollectionSchema<dynamic>>[QueuedOpModelSchema],
    directory: dir.path,
    name: 'scholesa_db',
  );

  return _isarInstance!;
}

/// Close Isar (for testing)
Future<void> closeIsar() async {
  if (_isarInstance != null) {
    await _isarInstance!.close();
    _isarInstance = null;
  }
}
