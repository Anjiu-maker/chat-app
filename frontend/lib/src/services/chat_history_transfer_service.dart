import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database/app_database.dart';
import 'database/database_service.dart';

class ChatHistoryTransferService {
  ChatHistoryTransferService({AppDatabase? database})
      : _db = database ?? DatabaseService.instance.db;

  static const _format = 'chat_app_history_backup';
  static const _version = 1;

  final AppDatabase _db;

  Future<ChatHistorySummary> summary() async {
    final snapshot = await _db.chatHistorySnapshot();
    return ChatHistorySummary(
      conversationCount: snapshot.conversationCount,
      messageCount: snapshot.messageCount,
    );
  }

  Future<ChatHistoryExportResult> exportAndShare() async {
    final snapshot = await _db.chatHistorySnapshot();
    final payload = <String, dynamic>{
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'conversationCount': snapshot.conversationCount,
      'messageCount': snapshot.messageCount,
      'conversations': snapshot.conversations.map(_conversationToJson).toList(),
      'messages': snapshot.messages.map(_messageToJson).toList(),
    };

    final directory = await getApplicationDocumentsDirectory();
    final backupDirectory =
        Directory(p.join(directory.path, 'chat_history_backups'));
    await backupDirectory.create(recursive: true);

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '-');
    final file = File(p.join(
      backupDirectory.path,
      'chat-history-$timestamp.chatbackup',
    ));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: '畅聊聊天记录备份',
      text: '畅聊聊天记录备份',
    );

    return ChatHistoryExportResult(
      path: file.path,
      conversationCount: snapshot.conversationCount,
      messageCount: snapshot.messageCount,
    );
  }

  Future<ChatHistoryImportResult?> importFromPicker() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['chatbackup', 'json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw const FormatException('无法读取备份文件');
    }

    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确');
    }
    final backup = Map<String, dynamic>.from(decoded);
    if (backup['format'] != _format || backup['version'] != _version) {
      throw const FormatException('不支持的聊天记录备份文件');
    }

    final conversations = _readList(backup, 'conversations')
        .map(_conversationFromJson)
        .toList(growable: false);
    final messages = _readList(backup, 'messages')
        .map(_messageFromJson)
        .toList(growable: false);

    final conversationIds = conversations.map((item) => item.id).toSet();
    for (final message in messages) {
      if (!conversationIds.contains(message.conversationId)) {
        throw const FormatException('备份文件里的消息缺少对应会话');
      }
    }

    await _db.importChatHistory(
      conversations: conversations,
      messages: messages,
    );

    return ChatHistoryImportResult(
      conversationCount: conversations.length,
      messageCount: messages.length,
      fileName: file.name,
    );
  }

  Map<String, dynamic> _conversationToJson(LocalConversation row) {
    return {
      'id': row.id,
      'type': row.type,
      'title': row.title,
      'lastMessagePreview': row.lastMessagePreview,
      'lastMessageAt': row.lastMessageAt,
      'memberCount': row.memberCount,
      'unreadCount': row.unreadCount,
      'lastReadAt': row.lastReadAt,
    };
  }

  Map<String, dynamic> _messageToJson(LocalMessage row) {
    return {
      'id': row.id,
      'conversationId': row.conversationId,
      'senderId': row.senderId,
      'senderName': row.senderName,
      'content': row.content,
      'type': row.type,
      'createdAt': row.createdAt,
      'serverSeq': row.serverSeq,
    };
  }

  LocalConversation _conversationFromJson(Map<String, dynamic> json) {
    return LocalConversation(
      id: _requiredString(json, 'id'),
      type: _string(json, 'type', fallback: 'group'),
      title: _string(json, 'title', fallback: '未命名会话'),
      lastMessagePreview: _nullableString(json, 'lastMessagePreview'),
      lastMessageAt: _nullableInt(json, 'lastMessageAt'),
      memberCount: _int(json, 'memberCount'),
      unreadCount: _int(json, 'unreadCount'),
      lastReadAt: _nullableInt(json, 'lastReadAt'),
    );
  }

  LocalMessage _messageFromJson(Map<String, dynamic> json) {
    return LocalMessage(
      id: _requiredString(json, 'id'),
      conversationId: _requiredString(json, 'conversationId'),
      senderId: _requiredString(json, 'senderId'),
      senderName: _string(json, 'senderName'),
      content: _requiredString(json, 'content'),
      type: _string(json, 'type', fallback: 'text'),
      createdAt: _requiredInt(json, 'createdAt'),
      serverSeq: _nullableInt(json, 'serverSeq'),
    );
  }

  List<Map<String, dynamic>> _readList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List) {
      throw FormatException('备份文件缺少 $key');
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('备份文件缺少 $key');
  }

  String _string(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) {
    final value = json[key];
    return value is String ? value : fallback;
  }

  String? _nullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? value : null;
  }

  int _requiredInt(Map<String, dynamic> json, String key) {
    final value = _nullableInt(json, key);
    if (value != null) return value;
    throw FormatException('备份文件缺少 $key');
  }

  int _int(Map<String, dynamic> json, String key, {int fallback = 0}) {
    return _nullableInt(json, key) ?? fallback;
  }

  int? _nullableInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

class ChatHistorySummary {
  const ChatHistorySummary({
    required this.conversationCount,
    required this.messageCount,
  });

  final int conversationCount;
  final int messageCount;
}

class ChatHistoryExportResult extends ChatHistorySummary {
  const ChatHistoryExportResult({
    required this.path,
    required super.conversationCount,
    required super.messageCount,
  });

  final String path;
}

class ChatHistoryImportResult extends ChatHistorySummary {
  const ChatHistoryImportResult({
    required this.fileName,
    required super.conversationCount,
    required super.messageCount,
  });

  final String fileName;
}
