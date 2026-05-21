import 'package:drift/drift.dart';

@DataClassName('PendingMessage')
class PendingMessagesTable extends Table {
  TextColumn get localId => text()(); // client-generated UUID
  TextColumn get conversationId => text()();
  TextColumn get content => text()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  IntColumn get createdAt => integer()(); // ms since epoch
  TextColumn get status => text().withDefault(const Constant('pending'))();
  // 'pending' | 'sending' | 'failed'

  @override
  Set<Column> get primaryKey => {localId};
}
