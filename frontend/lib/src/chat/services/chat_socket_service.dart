import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_message.dart';

class ChatSocketService {
  ChatSocketService({
    required this.socketUrl,
    required this.conversationId,
    required this.accessToken,
  });

  final String socketUrl;
  final String conversationId;
  final String accessToken;

  final _messages = StreamController<ChatMessage>.broadcast();
  final _history = StreamController<List<ChatMessage>>.broadcast();
  final _status = StreamController<String>.broadcast();

  late final io.Socket _socket;

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<List<ChatMessage>> get history => _history.stream;
  Stream<String> get status => _status.stream;

  void connect() {
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .disableAutoConnect()
          .build(),
    );

    _socket.onConnect((_) {
      _status.add('connected');
      _socket.emit('conversation:join', {'conversationId': conversationId});
    });

    _socket.onDisconnect((_) => _status.add('disconnected'));
    _socket.onConnectError((error) => _status.add('error: $error'));
    _socket.onError((error) => _status.add('error: $error'));

    _socket.on('conversation:history', (data) {
      final items = (data as List<dynamic>)
          .whereType<Map>()
          .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      _history.add(items);
    });

    _socket.on('message:new', (data) {
      if (data is Map) {
        _messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
      }
    });

    _socket.connect();
  }

  void send(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _socket.emit('message:send', {
      'conversationId': conversationId,
      'content': trimmed,
    });
  }

  void markRead() {
    _socket.emit('message:read', {'conversationId': conversationId});
  }

  void dispose() {
    _socket.emit('conversation:leave', {'conversationId': conversationId});
    _socket.dispose();
    _messages.close();
    _history.close();
    _status.close();
  }
}
