import 'package:flutter/material.dart';

import '../../../features/chat_room/views/chat_room_page.dart';
import '../../../features/create_group/views/create_group_page.dart';
import '../../../features/search/views/search_page.dart';
import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/avatar_widgets.dart';
import 'group_detail_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key, this.appSocketService});

  final AppSocketService? appSocketService;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _api = ApiClient();
  late Future<List<AppConversation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.groups();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlueHeader(
          height: 180,
          title: '群组',
          actions: [
            HeaderIconButton(
              icon: Icons.add_rounded,
              filled: true,
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGroupPage()),
                );
                _reload();
              },
            ),
          ],
        ),
        Positioned(
          top: 92,
          left: 20,
          right: 20,
          child: SoftSearchBar(
            hintText: '搜索群组',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const SearchPage(initialScope: SearchScope.groups),
              ),
            ),
          ),
        ),
        WhitePanel(
          top: 148,
          child: FutureBuilder<List<AppConversation>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _GroupState(
                  icon: Icons.cloud_off_rounded,
                  title: '群组加载失败',
                  subtitle: snapshot.error.toString(),
                  actionLabel: '重试',
                  onPressed: _reload,
                );
              }
              final groups = snapshot.data ?? const [];
              if (groups.isEmpty) {
                return _GroupState(
                  icon: Icons.group_add_rounded,
                  title: '还没有群聊',
                  subtitle: '创建一个群聊，团队消息就会出现在这里。',
                  actionLabel: '创建群聊',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupPage(),
                      ),
                    );
                    _reload();
                  },
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 20, bottom: 104),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 112,
                    color: Color(0xFFE9EDF5),
                  ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GroupListTile(
                      group: group,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              GroupDetailPage(
                                conversationId: group.id,
                                appSocketService: widget.appSocketService,
                              ),
                        ),
                      ),
                      onChatTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatRoomPage(
                            appSocketService: widget.appSocketService,
                            conversationId: group.id,
                            title: group.title,
                            subtitle: '${group.memberCount} 位成员',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _reload() {
    setState(() => _future = _api.groups());
  }
}

class _GroupListTile extends StatelessWidget {
  const _GroupListTile({
    required this.group,
    required this.onTap,
    required this.onChatTap,
  });

  final AppConversation group;
  final VoidCallback onTap;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 13, 16, 13),
        child: Row(
          children: [
            GestureDetector(
              onTap: onChatTap,
              child: GroupInitialAvatar(title: group.title, size: 68),
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
                          group.title,
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
                      const _GroupTag(),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${group.memberCount} 位成员',
                    style: const TextStyle(
                      color: Color(0xFF7C8499),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    group.lastMessagePreview ?? '暂无消息',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2478FF),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA0B3)),
          ],
        ),
      ),
    );
  }
}

class _GroupTag extends StatelessWidget {
  const _GroupTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '群',
        style: TextStyle(
          color: Color(0xFF2478FF),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GroupState extends StatelessWidget {
  const _GroupState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF9AA8C7)),
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
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF858CA1), fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
