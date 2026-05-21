import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/chat_room/views/chat_room_page.dart';
import '../../../features/create_group/views/create_group_page.dart';
import '../../../features/search/views/search_page.dart';
import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../services/database/database_service.dart';
import '../../../services/database/app_database.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/avatar_widgets.dart';

enum _ConversationFilter { all, direct, group }

class MessagesHomePage extends StatefulWidget {
  const MessagesHomePage({super.key, this.appSocketService});

  final AppSocketService? appSocketService;

  @override
  State<MessagesHomePage> createState() => _MessagesHomePageState();
}

class _MessagesHomePageState extends State<MessagesHomePage> {
  final _api = ApiClient();
  StreamSubscription<List<LocalConversation>>? _dbSubscription;
  List<LocalConversation> _conversations = const [];
  _ConversationFilter _filter = _ConversationFilter.all;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _seedAndWatch();
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _seedAndWatch() async {
    final db = DatabaseService.instance.db;

    // Start watching local DB — any change auto-updates the UI
    _dbSubscription = db.watchConversations().listen((rows) {
      if (!mounted) return;
      setState(() {
        _conversations = rows;
        _initialLoading = false;
      });
    });

    // Seed local DB from API on first load (cold start)
    try {
      final apiConversations = await _api.conversations();
      await db.upsertConversationsFromApi(apiConversations
          .map((c) => {
                'id': c.id,
                'type': c.type,
                'title': c.title,
                'lastMessagePreview': c.lastMessagePreview,
                'lastMessageAt': c.lastMessageAt?.toIso8601String(),
                'memberCount': c.memberCount,
                'unreadCount': c.unreadCount,
                'settings': null,
              })
          .toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final apiConversations = await _api.conversations();
      await DatabaseService.instance.db.upsertConversationsFromApi(
        apiConversations
            .map((c) => {
                  'id': c.id,
                  'type': c.type,
                  'title': c.title,
                  'lastMessagePreview': c.lastMessagePreview,
                  'lastMessageAt': c.lastMessageAt?.toIso8601String(),
                  'memberCount': c.memberCount,
                  'unreadCount': c.unreadCount,
                  'settings': null,
                })
            .toList(),
      );
    } catch (_) {}
  }

  List<LocalConversation> _visibleConversations() {
    return switch (_filter) {
      _ConversationFilter.all => _conversations,
      _ConversationFilter.direct =>
        _conversations.where((c) => c.type == 'direct').toList(),
      _ConversationFilter.group =>
        _conversations.where((c) => c.type == 'group').toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlueHeader(
          height: 180,
          title: '畅聊',
          actions: [
            HeaderIconButton(
              icon: Icons.add_rounded,
              filled: true,
              onPressed: () => _openStartChatSheet(context),
            ),
          ],
        ),
        Positioned(
          top: 92,
          left: 20,
          right: 20,
          child: SoftSearchBar(
            hintText: '搜索联系11人或群组',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
          ),
        ),
        WhitePanel(
          top: 148,
          child: Column(
            children: [
              const SizedBox(height: 12),
              _MessageTabs(
                filter: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              Expanded(
                child: _initialLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: _buildConversationList(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationList() {
    final conversations = _visibleConversations();
    if (conversations.isEmpty) {
      return _MessageState(
        icon: Icons.add_comment_rounded,
        title: '还没有会话',
        subtitle: '可以先找好友发起单聊，也可以创建一个群聊。',
        actionLabel: '发起聊天',
        onPressed: () => _openStartChatSheet(context),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 112),
      itemCount: conversations.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 106, color: Color(0xFFE9EDF5)),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _ConversationTile(
          conversation: conversation,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatRoomPage(
                appSocketService: widget.appSocketService,
                conversationId: conversation.id,
                title: conversation.title,
                subtitle: conversation.type == 'group'
                    ? '${conversation.memberCount} 位成员'
                    : '单聊',
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStartChatSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '发起聊天',
                  style: TextStyle(
                    color: Color(0xFF11131A),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _StartChatAction(
                  icon: Icons.person_search_rounded,
                  title: '发起单聊',
                  subtitle: '搜索或选择好友，进入一对一聊天',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchPage(
                          initialScope: SearchScope.contacts,
                        ),
                      ),
                    );
                    _refresh();
                  },
                ),
                _StartChatAction(
                  icon: Icons.group_add_rounded,
                  title: '发起群聊',
                  subtitle: '选择多个成员，创建群聊会话',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupPage(),
                      ),
                    );
                    _refresh();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageTabs extends StatelessWidget {
  const _MessageTabs({required this.filter, required this.onChanged});

  final _ConversationFilter filter;
  final ValueChanged<_ConversationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Row(
        children: [
          _MessageTabItem(
            icon: Icons.chat_bubble_rounded,
            label: '全部',
            active: filter == _ConversationFilter.all,
            onTap: () => onChanged(_ConversationFilter.all),
          ),
          _MessageTabItem(
            icon: Icons.person_rounded,
            label: '单聊',
            active: filter == _ConversationFilter.direct,
            onTap: () => onChanged(_ConversationFilter.direct),
          ),
          _MessageTabItem(
            icon: Icons.groups_rounded,
            label: '群聊',
            active: filter == _ConversationFilter.group,
            onTap: () => onChanged(_ConversationFilter.group),
          ),
        ],
      ),
    );
  }
}

class _MessageTabItem extends StatelessWidget {
  const _MessageTabItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2478FF) : const Color(0xFF6F7484);
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 34,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(color: const Color(0xFFDDE8FF))
                  : Border.all(color: Colors.transparent),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x0A2478FF),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartChatAction extends StatelessWidget {
  const _StartChatAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2FF),
        child: Icon(icon, color: const Color(0xFF2478FF)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final LocalConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.type == 'group';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
        child: Row(
          children: [
            isGroup
                ? const SystemAvatar(
                    icon: Icons.groups_rounded,
                    colors: [Color(0xFF6AA5FF), Color(0xFF185CF2)],
                  )
                : const SystemAvatar(
                    icon: Icons.person_rounded,
                    colors: [Color(0xFF6FDD7C), Color(0xFF2CAF49)],
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF11131A),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      _ModeTag(
                        label: isGroup ? '群' : '单',
                        color: isGroup
                            ? const Color(0xFF2478FF)
                            : const Color(0xFF2CAF49),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    conversation.lastMessagePreview ?? '点击进入聊天',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF7C8499), fontSize: 16, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(conversation.lastMessageAt),
              style: const TextStyle(color: Color(0xFF858CA1), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int? epochMs) {
    if (epochMs == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 54, color: const Color(0xFF9AA8C7)),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF11131A),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF858CA1), fontSize: 15),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}
