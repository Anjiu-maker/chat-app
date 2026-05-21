import 'package:drift/drift.dart';

@DataClassName('LocalConversation')
class ConversationsTable extends Table {
  TextColumn get id => text()(); // server UUID
  TextColumn get type => text()(); // 'direct' | 'group'
  TextColumn get title => text()();
  TextColumn get lastMessagePreview => text().nullable()();
  IntColumn get lastMessageAt => integer().nullable()(); // ms since epoch
  IntColumn get memberCount => integer().withDefault(const Constant(0))();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get lastReadAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
