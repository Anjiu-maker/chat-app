import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../features/contacts/views/contacts_page.dart';
import '../features/groups/views/groups_page.dart';
import '../features/messages/views/messages_home_page.dart';
import '../features/profile/views/profile_page.dart';
import '../services/app_socket_service.dart';
import '../services/database/database_service.dart';
import '../services/offline_queue_service.dart';
import '../services/session_store.dart';
import '../shared/widgets/app_chrome.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _messageBadge = 0;
  AppSocketService? _appSocketService;
  OfflineQueueService? _offlineQueueService;
  StreamSubscription<void>? _badgeSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessageBadge();
    final token = SessionStore.instance.accessToken;
    if (token != null) {
      _offlineQueueService = OfflineQueueService(
        onDrainMessage: (msg) async {
          if (_appSocketService == null) return false;
          _appSocketService!.sendMessage(
            msg.conversationId,
            msg.content,
            type: msg.type,
            clientId: msg.localId,
          );
          return true;
        },
      );
      _appSocketService = AppSocketService(
        socketUrl: AppConfig.socketUrl,
        accessToken: token,
        offlineQueue: _offlineQueueService,
      );
    }
    // Watch local conversations table — any change updates badge
    _badgeSubscription =
        DatabaseService.instance.db.watchConversations().listen((rows) {
      final unread = rows.fold<int>(0, (sum, c) => sum + c.unreadCount);
      if (!mounted) return;
      setState(() => _messageBadge = unread);
    });

    // Friend request notifications
    if (_appSocketService != null) {
      _appSocketService!.friendRequest.listen((data) {
        final fromName = data['fromUser']?['nickname'] ?? '新朋友';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fromName 请求添加你为好友'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () => setState(() => _index = 1), // Contacts tab
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      });

      _appSocketService!.friendAccepted.listen((data) {
        final byName = data['byUser']?['nickname'] ?? '好友';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$byName 已同意你的好友请求')),
        );
      });
    }
  }

  @override
  void dispose() {
    _badgeSubscription?.cancel();
    _offlineQueueService?.dispose();
    _appSocketService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      MessagesHomePage(appSocketService: _appSocketService),
      ContactsPage(appSocketService: _appSocketService),
      GroupsPage(appSocketService: _appSocketService),
      const ProfilePage(),
    ];

    return Scaffold(
      body: PhonePageFrame(
        child: Stack(
          children: [
            Positioned.fill(child: pages[_index]),
            Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomNav(
                index: _index,
                messageBadge: _messageBadge,
                onChanged: (value) {
                  setState(() => _index = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMessageBadge() async {
    try {
      final unread = await DatabaseService.instance.db.totalUnread();
      if (!mounted) return;
      setState(() => _messageBadge = unread);
    } catch (_) {}
  }
}
