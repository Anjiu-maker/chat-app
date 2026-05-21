import 'package:drift/drift.dart';

class SyncStateTable extends Table {
  TextColumn get id => text()(); // always 'global'
  IntColumn get lastServerSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
