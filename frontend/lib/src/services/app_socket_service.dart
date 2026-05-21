import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../chat/models/chat_message.dart';
import 'database/app_database.dart';
import 'database/database_service.dart';
import 'offline_queue_service.dart';

enum SocketConnectionState { disconnected, connecting, connected, error }

class AppSocketService {
  AppSocketService({
    required String socketUrl,
    required String accessToken,
    this.offlineQueue,
  })  : _socketUrl = socketUrl,
        _accessToken = accessToken {
    _connect();
  }

  final OfflineQueueService? offlineQueue;

  final String _socketUrl;
  final String _accessToken;
  late io.Socket _socket;
  String? _currentConversationId;

  final _conversationUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageReceivedController = StreamController<ChatMessage>.broadcast();
  final _historyReceivedController =
      StreamController<List<ChatMessage>>.broadcast();
  final _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();
  final _friendRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get conversationUpdated =>
      _conversationUpdatedController.stream;
  Stream<ChatMessage> get messageReceived => _messageReceivedController.stream;
  Stream<List<ChatMessage>> get historyReceived =>
      _historyReceivedController.stream;
  Stream<SocketConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get friendRequest =>
      _friendRequestController.stream;
  Stream<Map<String, dynamic>> get friendAccepted =>
      _friendAcceptedController.stream;

  bool get isConnected => _socket.connected;

  void _connect() {
    _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _accessToken})
          .enableAutoConnect()
          .build(),
    );

    _socket.onConnect((_) {
      _connectionStateController.add(SocketConnectionState.connected);
      if (_currentConversationId != null) {
        _socket.emit('conversation:join', {
          'conversationId': _currentConversationId,
        });
      }
      // Drain offline queue on (re)connect
      offlineQueue?.drain();
    });

    _socket.onDisconnect((_) =>
        _connectionStateController.add(SocketConnectionState.disconnected));

    _socket.onConnectError(
        (_) => _connectionStateController.add(SocketConnectionState.error));

    _socket.on('friend:request', (data) {
      if (data is Map) {
        _friendRequestController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('friend:accepted', (data) {
      if (data is Map) {
        _friendAcceptedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('conversation:updated', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        _conversationUpdatedController.add(map);
        _onConversationUpdated(map);
      }
    });

    _socket.on('message:new', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final msg = ChatMessage.fromJson(map);
        _messageReceivedController.add(msg);

        // Replace optimistic local message with server message
        final clientId = map['clientId'];
        if (clientId is String && clientId.isNotEmpty) {
          final db = _db;
          if (db != null) {
            db.deleteMessage(clientId); // remove optimistic copy
            db.markPendingSent(clientId); // remove from offline queue
          }
        }
        _persistMessage(msg, serverSeq: map['serverSeq']);
        if (msg.conversationId == _currentConversationId) {
          markRead(msg.conversationId);
        }
      }
    });

    _socket.on('conversation:history', (data) {
      final raw = (data as List<dynamic>).whereType<Map>().toList();
      final items = raw
          .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      _historyReceivedController.add(items);
      _persistMessages(raw);
    });
  }

  void _onConversationUpdated(Map<String, dynamic> data) {
    final conversationId = data['conversationId'];
    final preview = data['lastMessagePreview'];
    if (conversationId is! String) return;
    final message = data['message'];
    if (message is Map) {
      _persistMessage(
        ChatMessage.fromJson(Map<String, dynamic>.from(message)),
        serverSeq: message['serverSeq'],
      );
    }
    final isActiveConversation = conversationId == _currentConversationId;
    var unreadCount = _parseInt(data['unreadCount']);
    if (data['read'] == true) {
      unreadCount = 0;
    } else if (isActiveConversation && unreadCount != null) {
      unreadCount = 0;
    }
    final db = _db;
    if (db != null) {
      db.updateConversationRealtime(
        conversationId: conversationId,
        lastMessagePreview: preview is String ? preview : null,
        lastMessageAt: _parseOptionalTimestamp(data['lastMessageAt']),
        unreadCount: unreadCount,
        lastReadAt: _parseOptionalTimestamp(data['lastReadAt']),
      );
    }
  }

  void _persistMessage(ChatMessage msg, {dynamic serverSeq}) {
    final db = _db;
    if (db == null) return;
    db.upsertMessage(LocalMessage(
      id: msg.id,
      conversationId: msg.conversationId,
      senderId: msg.senderId,
      senderName: msg.senderName ?? '',
      content: msg.content,
      type: msg.type,
      createdAt: msg.createdAt.millisecondsSinceEpoch,
      serverSeq: _parseServerSeq(serverSeq),
    ));
  }

  void _persistMessages(List<Map> rawItems) {
    final db = _db;
    if (db == null) return;
    final rows = <LocalMessage>[];
    for (final item in rawItems) {
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(item));
      rows.add(LocalMessage(
        id: msg.id,
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        senderName: msg.senderName ?? '',
        content: msg.content,
        type: msg.type,
        createdAt: msg.createdAt.millisecondsSinceEpoch,
        serverSeq: _parseServerSeq(item['serverSeq']),
      ));
    }
    db.batchInsertMessages(rows);
  }

  int? _parseServerSeq(dynamic value) {
    return _parseInt(value);
  }

  int? _parseOptionalTimestamp(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    if (value is int) {
      return value;
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  AppDatabase? get _db {
    if (!DatabaseService.instance.isInitialized) return null;
    return DatabaseService.instance.db;
  }

  void joinConversation(String conversationId, {int? afterSeq}) {
    _currentConversationId = conversationId;
    if (_socket.connected) {
      _socket.emit('conversation:join', {
        'conversationId': conversationId,
        if (afterSeq != null) 'afterSeq': afterSeq,
      });
    }
  }

  void leaveConversation(String conversationId) {
    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
    }
    _socket.emit('conversation:leave', {'conversationId': conversationId});
  }

  void sendMessage(String conversationId, String content, {String? clientId}) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    _socket.emit('message:send', {
      'conversationId': conversationId,
      'content': trimmed,
      if (clientId != null) 'clientId': clientId,
    });
  }

  void markRead(String conversationId) {
    final db = _db;
    if (db != null) {
      db.updateConversationRealtime(
        conversationId: conversationId,
        unreadCount: 0,
        lastReadAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    _socket.emit('message:read', {'conversationId': conversationId});
  }

  void dispose() {
    _socket.dispose();
    _conversationUpdatedController.close();
    _messageReceivedController.close();
    _historyReceivedController.close();
    _connectionStateController.close();
    _friendRequestController.close();
    _friendAcceptedController.close();
  }
}
