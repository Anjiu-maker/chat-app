import 'package:drift/drift.dart';

import 'database_connection.dart';
import 'tables/conversation_table.dart';
import 'tables/message_table.dart';
import 'tables/pending_message_table.dart';
import 'tables/session_table.dart';
import 'tables/sync_state_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    SessionTable,
    SyncStateTable,
    ConversationsTable,
    MessagesTable,
    PendingMessagesTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDatabase());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          if (details.wasCreated) {
            await into(sessionTable).insert(
              const SessionTableCompanion(
                id: Value('1'),
                accessToken: Value(''),
                userId: Value(''),
                phone: Value(''),
                nickname: Value(''),
              ),
            );
            await into(syncStateTable).insert(
              const SyncStateTableCompanion(id: Value('global')),
            );
          }
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(conversationsTable);
            await m.createTable(messagesTable);
          }
          if (from < 3) {
            await m.createTable(pendingMessagesTable);
          }
        },
      );

  // ── Session ──

  Future<SessionTableData?> getSession() =>
      (select(sessionTable)..limit(1)).getSingleOrNull();

  Future<void> upsertSession({
    required String accessToken,
    required String userId,
    required String phone,
    required String nickname,
  }) async {
    await into(sessionTable).insertOnConflictUpdate(
      SessionTableCompanion(
        id: const Value('1'),
        accessToken: Value(accessToken),
        userId: Value(userId),
        phone: Value(phone),
        nickname: Value(nickname),
      ),
    );
  }

  Future<void> clearSession() async {
    await update(sessionTable).write(
      const SessionTableCompanion(
        accessToken: Value(''),
        userId: Value(''),
        phone: Value(''),
        nickname: Value(''),
      ),
    );
  }

  // ── Sync state ──

  Future<int> getLastServerSeq() async {
    final row = await (selectOnly(syncStateTable)..limit(1)).getSingleOrNull();
    return row?.read(syncStateTable.lastServerSeq) ?? 0;
  }

  Future<void> updateLastServerSeq(int seq) async {
    await into(syncStateTable).insertOnConflictUpdate(
      SyncStateTableCompanion(
        id: const Value('global'),
        lastServerSeq: Value(seq),
      ),
    );
  }

  // ── Conversations ──

  Stream<List<LocalConversation>> watchConversations() {
    return (select(conversationsTable)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastMessageAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<int> totalUnread() async {
    final row = await (selectOnly(conversationsTable)
          ..addColumns([conversationsTable.unreadCount.sum()])
          ..limit(1))
        .getSingleOrNull();
    return row?.read(conversationsTable.unreadCount.sum()) ?? 0;
  }

  Future<void> upsertConversation(LocalConversation row) async {
    await into(conversationsTable).insertOnConflictUpdate(
      ConversationsTableCompanion(
        id: Value(row.id),
        type: Value(row.type),
        title: Value(row.title),
        lastMessagePreview: Value(row.lastMessagePreview),
        lastMessageAt: Value(row.lastMessageAt),
        memberCount: Value(row.memberCount),
        unreadCount: Value(row.unreadCount),
        lastReadAt: Value(row.lastReadAt),
      ),
    );
  }

  Future<List<LocalConversation>> allConversations() {
    return (select(conversationsTable)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastMessageAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<void> upsertConversationsFromApi(
      List<Map<String, dynamic>> items) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        conversationsTable,
        items.map((item) {
          final type = item['type'] as String? ?? 'group';
          final lastMessageAtStr = item['lastMessageAt'] as String?;
          final settings = item['settings'];
          final lastReadAtStr =
              settings is Map ? settings['lastReadAt'] as String? : null;
          return ConversationsTableCompanion(
            id: Value(item['id'] as String? ?? ''),
            type: Value(type),
            title: Value((item['title'] as String?) ?? '未命名会话'),
            lastMessagePreview: Value(item['lastMessagePreview'] as String?),
            lastMessageAt: Value(lastMessageAtStr != null
                ? DateTime.tryParse(lastMessageAtStr)?.millisecondsSinceEpoch
                : null),
            memberCount: Value((item['memberCount'] as int?) ?? 0),
            unreadCount: Value((item['unreadCount'] as int?) ?? 0),
            lastReadAt: Value(lastReadAtStr != null
                ? DateTime.tryParse(lastReadAtStr)?.millisecondsSinceEpoch
                : null),
          );
        }),
      );
    });
  }

  Future<void> updateConversationPreview(
      {required String conversationId,
      required String lastMessagePreview,
      required int lastMessageAt}) async {
    await (update(conversationsTable)
          ..where((t) => t.id.equals(conversationId)))
        .write(
      ConversationsTableCompanion(
        lastMessagePreview: Value(lastMessagePreview),
        lastMessageAt: Value(lastMessageAt),
      ),
    );
  }

  // ── Messages ──

  Stream<List<LocalMessage>> watchMessages(String conversationId) {
    return (select(messagesTable)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<int?> maxServerSeq(String conversationId) async {
    final row = await (selectOnly(messagesTable)
          ..addColumns([messagesTable.serverSeq.max()])
          ..where(messagesTable.conversationId.equals(conversationId))
          ..limit(1))
        .getSingleOrNull();
    return row?.read(messagesTable.serverSeq.max());
  }

  Future<bool> hasMessages(String conversationId) async {
    final count = await (selectOnly(messagesTable)
          ..addColumns([countAll()])
          ..where(messagesTable.conversationId.equals(conversationId)))
        .map((row) => row.read(countAll()) ?? 0)
        .getSingle();
    return count > 0;
  }

  Future<void> upsertMessage(LocalMessage row) async {
    await into(messagesTable).insertOnConflictUpdate(
      MessagesTableCompanion(
        id: Value(row.id),
        conversationId: Value(row.conversationId),
        senderId: Value(row.senderId),
        senderName: Value(row.senderName),
        content: Value(row.content),
        type: Value(row.type),
        createdAt: Value(row.createdAt),
        serverSeq: Value(row.serverSeq),
      ),
    );
  }

  Future<void> deleteMessage(String id) async {
    await (delete(messagesTable)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LocalMessage>> allMessages() {
    return (select(messagesTable)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<void> batchInsertMessages(List<LocalMessage> messages) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        messagesTable,
        messages.map((msg) => MessagesTableCompanion(
              id: Value(msg.id),
              conversationId: Value(msg.conversationId),
              senderId: Value(msg.senderId),
              senderName: Value(msg.senderName),
              content: Value(msg.content),
              type: Value(msg.type),
              createdAt: Value(msg.createdAt),
              serverSeq: Value(msg.serverSeq),
            )),
      );
    });
  }

  Future<ChatHistorySnapshot> chatHistorySnapshot() async {
    final conversations = await allConversations();
    final messages = await allMessages();
    return ChatHistorySnapshot(
      conversations: conversations,
      messages: messages,
    );
  }

  Future<void> importChatHistory({
    required List<LocalConversation> conversations,
    required List<LocalMessage> messages,
  }) async {
    await transaction(() async {
      if (conversations.isNotEmpty) {
        await batch((batch) {
          batch.insertAllOnConflictUpdate(
            conversationsTable,
            conversations.map((row) => ConversationsTableCompanion(
                  id: Value(row.id),
                  type: Value(row.type),
                  title: Value(row.title),
                  lastMessagePreview: Value(row.lastMessagePreview),
                  lastMessageAt: Value(row.lastMessageAt),
                  memberCount: Value(row.memberCount),
                  unreadCount: Value(row.unreadCount),
                  lastReadAt: Value(row.lastReadAt),
                )),
          );
        });
      }

      if (messages.isNotEmpty) {
        await batchInsertMessages(messages);
      }
    });
  }

  // ── Pending messages (offline queue) ──

  Future<void> enqueuePending({
    required String localId,
    required String conversationId,
    required String content,
    required String type,
    required int createdAt,
  }) async {
    await into(pendingMessagesTable).insert(
      PendingMessagesTableCompanion(
        localId: Value(localId),
        conversationId: Value(conversationId),
        content: Value(content),
        type: Value(type),
        createdAt: Value(createdAt),
        status: const Value('pending'),
      ),
    );
  }

  Future<List<PendingMessage>> drainPendingMessages() async {
    final rows = await (select(pendingMessagesTable)
          ..where((t) => t.status.equals('pending')))
        .get();
    return rows;
  }

  Future<void> markPendingSending(String localId) async {
    await (update(pendingMessagesTable)
          ..where((t) => t.localId.equals(localId)))
        .write(const PendingMessagesTableCompanion(status: Value('sending')));
  }

  Future<void> markPendingSent(String localId) async {
    await (delete(pendingMessagesTable)
          ..where((t) => t.localId.equals(localId)))
        .go();
  }

  Future<void> markPendingFailed(String localId) async {
    await (update(pendingMessagesTable)
          ..where((t) => t.localId.equals(localId)))
        .write(const PendingMessagesTableCompanion(status: Value('failed')));
  }

  Stream<List<PendingMessage>> watchPending() {
    return (select(pendingMessagesTable)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }
}

class ChatHistorySnapshot {
  const ChatHistorySnapshot({
    required this.conversations,
    required this.messages,
  });

  final List<LocalConversation> conversations;
  final List<LocalMessage> messages;

  int get conversationCount => conversations.length;
  int get messageCount => messages.length;
}

QueryExecutor _openDatabase() => openConnection();
