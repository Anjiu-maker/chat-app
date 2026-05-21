import 'app_database.dart';

class DatabaseService {
  DatabaseService._();

  static final instance = DatabaseService._();

  AppDatabase? _db;

  AppDatabase get db {
    final d = _db;
    if (d == null) {
      throw StateError('DatabaseService not initialized — call initialize() first');
    }
    return d;
  }

  bool get isInitialized => _db != null;

  Future<void> initialize() async {
    if (_db != null) return;
    _db = AppDatabase();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
