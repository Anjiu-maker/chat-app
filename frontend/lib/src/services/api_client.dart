import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../chat/models/chat_message.dart';
import '../config/app_config.dart';
import 'session_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AppConversation {
  const AppConversation({
    required this.id,
    required this.type,
    required this.title,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.memberCount = 0,
    this.unreadCount = 0,
  });

  final String id;
  final String type;
  final String title;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int memberCount;
  final int unreadCount;

  bool get isDirect => type == 'direct';
  bool get isGroup => type == 'group';

  factory AppConversation.fromJson(Map<String, dynamic> json) {
    final members = (json['members'] as List?) ?? const [];
    final currentUserId = SessionStore.instance.user?.id;
    String? directTitle;

    for (final member in members.whereType<Map>()) {
      final user = member['user'];
      if (user is Map && user['id'] != currentUserId) {
        directTitle = user['nickname'] as String?;
        break;
      }
    }

    return AppConversation(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'group',
      title: json['title'] as String? ?? directTitle ?? '未命名会话',
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageAt: DateTime.tryParse(json['lastMessageAt'] as String? ?? ''),
      memberCount: json['memberCount'] as int? ?? members.length,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}

class AppFriendRequest {
  const AppFriendRequest({
    required this.id,
    required this.fromUser,
    required this.createdAt,
    this.toUser,
    this.message,
  });

  final String id;
  final AppUser fromUser;
  final AppUser? toUser;
  final String? message;
  final DateTime? createdAt;

  factory AppFriendRequest.fromJson(Map<String, dynamic> json) {
    return AppFriendRequest(
      id: json['id'] as String? ?? '',
      fromUser: AppUser.fromJson(
          (json['fromUser'] as Map?)?.cast<String, dynamic>() ?? {}),
      toUser: json['toUser'] != null
          ? AppUser.fromJson((json['toUser'] as Map).cast<String, dynamic>())
          : null,
      message: json['message'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class AppContact {
  const AppContact({
    required this.id,
    required this.user,
    this.remark,
    this.tag,
  });

  final String id;
  final AppUser user;
  final String? remark;
  final String? tag;

  String get displayName =>
      remark?.isNotEmpty == true ? remark! : user.nickname;

  factory AppContact.fromJson(Map<String, dynamic> json) {
    return AppContact(
      id: json['id'] as String? ?? '',
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      remark: json['remark'] as String?,
      tag: json['tag'] as String?,
    );
  }
}

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> sendCode({
    required String phone,
    required String scene,
  }) {
    return _post('/auth/send-code', {'phone': phone, 'scene': scene},
        auth: false);
  }

  Future<void> register({
    required String phone,
    required String code,
    required String nickname,
    required String password,
  }) async {
    final data = await _post(
      '/auth/register',
      {
        'phone': phone,
        'code': code,
        'nickname': nickname,
        'password': password,
      },
      auth: false,
    );
    await _saveAuthPayload(data);
  }

  Future<void> login({
    required String phone,
    required String password,
  }) async {
    final data = await _post(
      '/auth/login',
      {'phone': phone, 'password': password},
      auth: false,
    );
    await _saveAuthPayload(data);
  }

  Future<void> loginByCode({
    required String phone,
    required String code,
  }) async {
    final data = await _post(
      '/auth/login/code',
      {'phone': phone, 'code': code},
      auth: false,
    );
    await _saveAuthPayload(data);
  }

  Future<List<AppUser>> searchUsers(String keyword) async {
    final data = await _get('/users/search', {'q': keyword});
    return (data as List)
        .whereType<Map>()
        .map((item) => AppUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AppUser> me() async {
    final data = await _get('/users/me');
    final user = AppUser.fromJson(data as Map<String, dynamic>);
    await _saveUser(user);
    return user;
  }

  Future<AppUser> updateMe({
    String? nickname,
    String? avatarUrl,
    String? bio,
  }) async {
    final data = await _patch('/users/me', {
      if (nickname != null) 'nickname': nickname,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (bio != null) 'bio': bio,
    });
    final user = AppUser.fromJson(data);
    await _saveUser(user);
    return user;
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _patch('/users/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<List<AppContact>> contacts() async {
    final data = await _get('/contacts');
    return (data as List)
        .whereType<Map>()
        .map((item) => AppContact.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ── Friend requests ──

  Future<AppFriendRequest> sendFriendRequest(String toUserId,
      {String? message}) async {
    final data = await _post('/contacts/requests',
        {'toUserId': toUserId, if (message != null) 'message': message});
    return AppFriendRequest.fromJson(data);
  }

  Future<List<AppFriendRequest>> incomingRequests() async {
    final data = await _get('/contacts/requests/incoming');
    return (data as List)
        .whereType<Map>()
        .map((item) =>
            AppFriendRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<AppFriendRequest>> outgoingRequests() async {
    final data = await _get('/contacts/requests/outgoing');
    return (data as List)
        .whereType<Map>()
        .map((item) =>
            AppFriendRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> acceptRequest(String requestId) async {
    await _post('/contacts/requests/$requestId/accept', {});
  }

  Future<void> rejectRequest(String requestId) async {
    await _post('/contacts/requests/$requestId/reject', {});
  }

  Future<void> cancelRequest(String requestId) async {
    await _delete('/contacts/requests/$requestId');
  }

  Future<List<AppConversation>> conversations() async {
    final data = await _get('/conversations');
    return (data as List)
        .whereType<Map>()
        .map(
            (item) => AppConversation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AppConversation> conversationDetail(String conversationId) async {
    final data = await _get('/conversations/$conversationId');
    return AppConversation.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AppConversation>> groups() async {
    final data = await _get('/groups');
    return (data as List)
        .whereType<Map>()
        .map(
            (item) => AppConversation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AppConversation> createGroup({
    required String name,
    required List<String> memberIds,
    String? announcement,
  }) async {
    final data = await _post('/groups', {
      'name': name,
      'memberIds': memberIds,
      'announcement': announcement,
    });
    return AppConversation.fromJson(data);
  }

  Future<AppConversation> createDirectConversation(String targetUserId) async {
    final data = await _post('/conversations/direct', {
      'targetUserId': targetUserId,
    });
    return AppConversation.fromJson(data);
  }

  Future<List<ChatMessage>> messages(String conversationId) async {
    final data = await _get('/conversations/$conversationId/messages');
    return (data as List)
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ChatMessage>> messagesSync(
    String conversationId, {
    int afterSeq = 0,
  }) async {
    final data = await _get(
      '/conversations/$conversationId/messages/sync',
      {'afterSeq': afterSeq.toString()},
    );
    return (data as List)
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> markConversationRead(String conversationId) async {
    await _post('/conversations/$conversationId/read', {});
  }

  Future<Map<String, dynamic>> uploadFile(File file) async {
    final token = SessionStore.instance.accessToken;
    if (token == null) {
      throw ApiException('请先登录');
    }

    final request = http.MultipartRequest('POST', _uri('/files/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return _decodeResponse(response.statusCode, body) as Map<String, dynamic>;
  }

  Future<AppUser> uploadAvatar(File file) async {
    final token = SessionStore.instance.accessToken;
    if (token == null) {
      throw ApiException('请先登录');
    }

    final request = http.MultipartRequest('POST', _uri('/users/me/avatar'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('avatar', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final user = AppUser.fromJson(
      _decodeResponse(response.statusCode, body) as Map<String, dynamic>,
    );
    await _saveUser(user);
    return user;
  }

  Future<AppUser> uploadAvatarBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = SessionStore.instance.accessToken;
    if (token == null) {
      throw ApiException('请先登录');
    }

    final request = http.MultipartRequest('POST', _uri('/users/me/avatar'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: filename.isEmpty ? 'avatar.png' : filename,
        ),
      );
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final user = AppUser.fromJson(
      _decodeResponse(response.statusCode, body) as Map<String, dynamic>,
    );
    await _saveUser(user);
    return user;
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final response =
        await _httpClient.get(_uri(path, query), headers: _headers());
    return _decodeResponse(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decodeResponse(response.statusCode, response.body)
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient.patch(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response.statusCode, response.body)
        as Map<String, dynamic>;
  }

  Future<dynamic> _delete(String path) async {
    final response = await _httpClient.delete(_uri(path), headers: _headers());
    return _decodeResponse(response.statusCode, response.body);
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = {'Content-Type': 'application/json'};
    final token = SessionStore.instance.accessToken;
    if (auth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decodeResponse(int statusCode, String body) {
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    final message =
        decoded is Map ? decoded['message']?.toString() ?? '请求失败' : '请求失败';
    throw ApiException(message, statusCode: statusCode);
  }

  Future<void> _saveAuthPayload(Map<String, dynamic> data) {
    return SessionStore.instance.save(
      accessToken: data['accessToken'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<void> _saveUser(AppUser user) {
    final token = SessionStore.instance.accessToken;
    if (token == null) {
      throw ApiException('请先登录');
    }
    return SessionStore.instance.save(accessToken: token, user: user);
  }
}
