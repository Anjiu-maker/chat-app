import 'package:flutter/foundation.dart';

import 'database/database_service.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatarUrl,
    this.bio,
  });

  final String id;
  final String phone;
  final String nickname;
  final String? avatarUrl;
  final String? bio;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '用户',
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'bio': bio,
    };
  }
}

class SessionStore extends ChangeNotifier {
  SessionStore._();

  static final instance = SessionStore._();

  String? _accessToken;
  AppUser? _user;

  String? get accessToken => _accessToken;
  AppUser? get user => _user;
  bool get isSignedIn => _accessToken != null && _user != null;

  Future<void> restore() async {
    if (!DatabaseService.instance.isInitialized) return;
    try {
      final row = await DatabaseService.instance.db.getSession();
      if (row == null) return;
      final token = row.accessToken;
      final userId = row.userId;
      if (token.isEmpty || userId.isEmpty) return;
      _accessToken = token;
      _user = AppUser(
        id: userId,
        phone: row.phone,
        nickname: row.nickname,
      );
      notifyListeners();
    } catch (_) {
      // 首次启动尚无 session 行时忽略
    }
  }

  Future<void> save({
    required String accessToken,
    required AppUser user,
  }) async {
    _accessToken = accessToken;
    _user = user;
    notifyListeners();

    if (!DatabaseService.instance.isInitialized) return;
    try {
      await DatabaseService.instance.db.upsertSession(
        accessToken: accessToken,
        userId: user.id,
        phone: user.phone,
        nickname: user.nickname,
      );
    } catch (_) {
      // 持久化失败不阻断登录流程
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _user = null;
    notifyListeners();

    if (!DatabaseService.instance.isInitialized) return;
    try {
      await DatabaseService.instance.db.clearSession();
    } catch (_) {
      // 清理失败不影响退出登录
    }
  }
}
