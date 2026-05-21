import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../services/database/database_service.dart';
import '../../../services/database/app_database.dart';
import '../../../services/session_store.dart';
import '../../../shared/widgets/app_chrome.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    this.appSocketService,
    this.conversationId = '',
    this.title = '产品设计组',
    this.subtitle,
    super.key,
  });

  final AppSocketService? appSocketService;
  final String conversationId;
  final String title;
  final String? subtitle;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <LocalMessage>[];
  final _api = ApiClient();
  StreamSubscription<List<LocalMessage>>? _dbSubscription;
  StreamSubscription<SocketConnectionState>? _connectionSubscription;
  String _status = '连接中';
  bool _historyLoaded = false;
  Timer? _historyFallbackTimer;

  @override
  void initState() {
    super.initState();
    final service = widget.appSocketService;
    if (widget.conversationId.isEmpty || service == null) {
      _status = '本地预览';
      return;
    }

    _dbSubscription = DatabaseService.instance.db
        .watchMessages(widget.conversationId)
        .listen((messages) {
      if (!mounted) return;
      final shouldScrollToLatest = _shouldScrollToLatest(messages.length);
      final wasEmpty = _messages.isEmpty;
      if (messages.isNotEmpty) {
        _historyLoaded = true;
        _historyFallbackTimer?.cancel();
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
      });
      if (shouldScrollToLatest) {
        _scrollToLatest(animated: !wasEmpty);
      }
    });

    _connectionSubscription = service.connectionState.listen((state) {
      if (!mounted) return;
      setState(() => _status = _mapState(state));
    });

    _joinConversationWithSync(service);
    _historyFallbackTimer =
        Timer(const Duration(seconds: 2), _loadHistoryFallback);
    _markRead();
  }

  Future<void> _joinConversationWithSync(AppSocketService service) async {
    final maxSeq =
        await DatabaseService.instance.db.maxServerSeq(widget.conversationId);
    if (maxSeq != null && maxSeq > 0) {
      service.joinConversation(widget.conversationId, afterSeq: maxSeq);
      return;
    }
    service.joinConversation(widget.conversationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _dbSubscription?.cancel();
    _connectionSubscription?.cancel();
    _historyFallbackTimer?.cancel();
    widget.appSocketService?.leaveConversation(widget.conversationId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle ?? _status;
    return Scaffold(
      body: PhonePageFrame(
        child: Stack(
          children: [
            BlueHeader(
              title: widget.title,
              subtitle: subtitle,
              height: 162,
              leading: HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                HeaderIconButton(icon: Icons.call_rounded, onPressed: () {}),
                HeaderIconButton(
                    icon: Icons.more_horiz_rounded, onPressed: () {}),
              ],
            ),
            WhitePanel(
              top: 142,
              child: Column(
                children: [
                  Expanded(
                    child: _messages.isEmpty
                        ? const _EmptyMessages()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe = message.senderId ==
                                  SessionStore.instance.user?.id;
                              return _MessageBubble(
                                  message: message, isMe: isMe);
                            },
                          ),
                  ),
                  _ChatInputBar(
                      controller: _controller, onSend: () => _sendMessage()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入消息内容')),
      );
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final localId = 'local_${now}_${content.hashCode.abs()}';
    final userId = SessionStore.instance.user?.id ?? 'local';
    final userName = SessionStore.instance.user?.nickname ?? '我';

    // Optimistic insert — await to ensure it exists before server echo deletes it
    await DatabaseService.instance.db.upsertMessage(LocalMessage(
      id: localId,
      conversationId: widget.conversationId,
      senderId: userId,
      senderName: userName,
      content: content,
      type: 'text',
      createdAt: now,
    ));

    final service = widget.appSocketService;
    if (service != null && service.isConnected) {
      service.sendMessage(widget.conversationId, content, clientId: localId);
    } else {
      // Offline: queue for later delivery
      DatabaseService.instance.db.enqueuePending(
        localId: localId,
        conversationId: widget.conversationId,
        content: content,
        type: 'text',
        createdAt: now,
      );
    }
    _controller.clear();
  }

  bool _shouldScrollToLatest(int nextMessageCount) {
    if (nextMessageCount == 0) return false;
    if (_messages.isEmpty || !_scrollController.hasClients) return true;
    final position = _scrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    return distanceToBottom < 160;
  }

  void _scrollToLatest({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadHistoryFallback() async {
    if (_historyLoaded || !mounted) return;
    try {
      final messages = await _api.messages(widget.conversationId);
      if (_historyLoaded || !mounted) return;
      final rows = messages
          .map((msg) => LocalMessage(
                id: msg.id,
                conversationId: msg.conversationId,
                senderId: msg.senderId,
                senderName: msg.senderName ?? '',
                content: msg.content,
                type: msg.type,
                createdAt: msg.createdAt.millisecondsSinceEpoch,
              ))
          .toList();
      _historyLoaded = true;
      await DatabaseService.instance.db.batchInsertMessages(rows);
    } catch (_) {
      // socket 和 HTTP 都失败时保持空状态。
    }
  }

  String _mapState(SocketConnectionState state) {
    return switch (state) {
      SocketConnectionState.connected => '实时在线',
      SocketConnectionState.connecting => '连接中',
      SocketConnectionState.disconnected => '连接已断开',
      SocketConnectionState.error => '连接出错',
    };
  }

  Future<void> _markRead() async {
    if (widget.conversationId.isEmpty) return;
    final service = widget.appSocketService;
    if (service != null) {
      service.markRead(widget.conversationId);
      return;
    }
    try {
      await _api.markConversationRead(widget.conversationId);
    } catch (_) {}
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '还没有消息，发一句开始聊天吧',
        style: TextStyle(color: Color(0xFF8A91A6), fontSize: 16),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final LocalMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 70 : 0,
        right: isMe ? 0 : 54,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 5),
              child: Text(
                message.senderName.isEmpty ? '成员' : message.senderName,
                style: const TextStyle(
                  color: Color(0xFF697089),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF2478FF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isMe ? null : Border.all(color: const Color(0xFFE2E7F1)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x080C3A91),
                    blurRadius: 14,
                    offset: Offset(0, 6)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF11131A),
                  fontSize: 16,
                  height: 1.42,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Color(0x10000000),
                blurRadius: 14,
                offset: Offset(0, -6)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.keyboard_voice_rounded),
              color: const Color(0xFF3C4252),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle:
                        const TextStyle(color: Color(0xFFB0B7C7), fontSize: 16),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              color: const Color(0xFF2478FF),
            ),
          ],
        ),
      ),
    );
  }
}
