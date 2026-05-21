import 'package:drift/drift.dart';

class SessionTable extends Table {
  TextColumn get id => text()(); // always '1'
  TextColumn get accessToken => text().withDefault(const Constant(''))();
  TextColumn get userId => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get nickname => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  TextColumn get bio => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
