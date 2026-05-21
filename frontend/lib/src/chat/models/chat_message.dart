class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.type = 'text',
    this.senderName,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String content;
  final String type;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: sender is Map
          ? sender['nickname'] as String?
          : json['senderName'] as String?,
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
