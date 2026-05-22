import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../services/database/app_database.dart';
import '../../../services/database/database_service.dart';
import '../../../services/session_store.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../widgets/gallery_picker_sheet.dart';

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
                  icon: Icons.more_horiz_rounded,
                  onPressed: () {},
                ),
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
                                message: message,
                                isMe: isMe,
                              );
                            },
                          ),
                  ),
                  _ChatInputBar(
                    controller: _controller,
                    onSend: () => _sendMessage(),
                    onPickImage: _pickImage,
                    onEmoji: _insertEmoji,
                    onPickFile: _pickFile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({
    String? content,
    String type = 'text',
    String? fileId,
  }) async {
    final messageContent = (content ?? _controller.text).trim();
    if (messageContent.isEmpty) {
      _showSnack('请输入消息内容');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final localId = 'local_${now}_${messageContent.hashCode.abs()}';
    final userId = SessionStore.instance.user?.id ?? 'local';
    final userName = SessionStore.instance.user?.nickname ?? '我';

    await DatabaseService.instance.db.upsertMessage(
      LocalMessage(
        id: localId,
        conversationId: widget.conversationId,
        senderId: userId,
        senderName: userName,
        content: messageContent,
        type: type,
        createdAt: now,
      ),
    );

    final service = widget.appSocketService;
    if (service != null && service.isConnected) {
      service.sendMessage(
        widget.conversationId,
        messageContent,
        type: type,
        fileId: fileId,
        clientId: localId,
      );
    } else {
      await DatabaseService.instance.db.enqueuePending(
        localId: localId,
        conversationId: widget.conversationId,
        content: messageContent,
        type: type,
        createdAt: now,
      );
    }

    if (content == null) {
      _controller.clear();
    }
  }

  Future<void> _pickImage() async {
    final file = await showGalleryPickerSheet(context);
    if (file == null) return;
    await _uploadAndSendFile(
      file: file,
      fallbackName: file.path.split(Platform.pathSeparator).last,
      messageType: 'image',
      failedMessage: '图片发送失败',
    );
  }

  Future<void> _pickFile() async {
    await _pickAndSendFile(
      type: FileType.any,
      messageType: 'file',
      emptyMessage: '未选择文件',
      failedMessage: '文件发送失败',
    );
  }

  Future<void> _pickAndSendFile({
    required FileType type,
    required String messageType,
    required String emptyMessage,
    required String failedMessage,
  }) async {
    try {
      final result = await FilePicker.pickFiles(type: type);
      final picked = result?.files.single;
      final path = picked?.path;
      if (picked == null || path == null) {
        _showSnack(emptyMessage);
        return;
      }

      await _uploadAndSendFile(
        file: File(path),
        fallbackName: picked.name,
        messageType: messageType,
        failedMessage: failedMessage,
      );
    } catch (_) {
      _showSnack(failedMessage);
    }
  }

  Future<void> _uploadAndSendFile({
    required File file,
    required String fallbackName,
    required String messageType,
    required String failedMessage,
  }) async {
    try {
      final uploaded = await _api.uploadFile(file);
      final url = uploaded['url'] as String? ?? '';
      final name = uploaded['originalName'] as String? ?? fallbackName;
      final id = uploaded['id'] as String?;
      final content = messageType == 'image' ? url : '$name\n$url';
      await _sendMessage(content: content, type: messageType, fileId: id);
    } catch (_) {
      _showSnack(failedMessage);
    }
  }

  void _insertEmoji() {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    const emoji = '😊';
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
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
          .map(
            (msg) => LocalMessage(
              id: msg.id,
              conversationId: msg.conversationId,
              senderId: msg.senderId,
              senderName: msg.senderName ?? '',
              content: msg.content,
              type: msg.type,
              createdAt: msg.createdAt.millisecondsSinceEpoch,
            ),
          )
          .toList();
      _historyLoaded = true;
      await DatabaseService.instance.db.batchInsertMessages(rows);
    } catch (_) {
      // Socket 和 HTTP 都失败时保持当前空状态。
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: _MessageContent(message: message, isMe: isMe),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.isMe});

  final LocalMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (message.type == 'image' && message.content.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          message.content,
          width: 190,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _PlainMessageText(text: message.content, isMe: isMe),
        ),
      );
    }

    if (message.type == 'file') {
      final parts = message.content.split('\n');
      final name = parts.first;
      final url = parts.length > 1 ? parts.last : '';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            color: isMe ? Colors.white : const Color(0xFF2478FF),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF11131A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (url.isNotEmpty)
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : const Color(0xFF697089),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return _PlainMessageText(text: message.content, isMe: isMe);
  }
}

class _PlainMessageText extends StatelessWidget {
  const _PlainMessageText({required this.text, required this.isMe});

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: isMe ? Colors.white : const Color(0xFF11131A),
        fontSize: 16,
        height: 1.42,
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onEmoji,
    required this.onPickFile,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onEmoji;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 14,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB0B7C7),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InputToolButton(
                  icon: Icons.image_outlined,
                  label: '图片',
                  onTap: onPickImage,
                ),
                const SizedBox(width: 8),
                _InputToolButton(
                  icon: Icons.emoji_emotions_outlined,
                  label: '表情',
                  onTap: onEmoji,
                ),
                const SizedBox(width: 8),
                _InputToolButton(
                  icon: Icons.attach_file_rounded,
                  label: '文件',
                  onTap: onPickFile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputToolButton extends StatelessWidget {
  const _InputToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: 38,
            child: Icon(icon, color: const Color(0xFF3C4252), size: 24),
          ),
        ),
      ),
    );
  }
}
