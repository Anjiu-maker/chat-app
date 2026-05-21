import 'package:drift/drift.dart';

@DataClassName('LocalMessage')
class MessagesTable extends Table {
  TextColumn get id => text()(); // server UUID
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get senderName => text().withDefault(const Constant(''))();
  TextColumn get content => text()();
  TextColumn get type => text().withDefault(const Constant('text'))();
  IntColumn get createdAt => integer()(); // milliseconds since epoch
  IntColumn get serverSeq => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
