import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/chat_room/views/chat_room_page.dart';
import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../services/session_store.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/state_views.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    this.initialScope = SearchScope.all,
    this.appSocketService,
    super.key,
  });

  final SearchScope initialScope;
  final AppSocketService? appSocketService;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

enum SearchScope { all, contacts, groups, messages }

class _SearchPageState extends State<SearchPage> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _users = <AppUser>[];
  final _contactUserIds = <String>{};
  late SearchScope _scope = widget.initialScope;
  Timer? _debounce;
  bool _loading = false;
  String _query = '';
  String? _error;

  bool get _shouldSearchUsers =>
      _scope == SearchScope.all || _scope == SearchScope.contacts;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageFrame(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left_rounded, size: 34),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: _onQueryChanged,
                        decoration: InputDecoration(
                          hintText: '搜索手机号或昵称',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF4F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0x552478FF)),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SearchTabs(
                scope: _scope,
                onChanged: (scope) {
                  setState(() => _scope = scope);
                  _searchUsers();
                },
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_shouldSearchUsers) {
      return const EmptyStateView(
        icon: Icons.search_rounded,
        title: '当前先支持用户搜索',
        message: '群组和聊天记录搜索会在接入更多真实数据后继续补上。',
      );
    }

    if (_query.trim().isEmpty) {
      return const _SearchSuggestions();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return EmptyStateView(
        icon: Icons.cloud_off_rounded,
        title: '搜索失败',
        message: _error!,
      );
    }

    if (_users.isEmpty) {
      return const EmptyStateView(
        icon: Icons.person_search_rounded,
        title: '没有找到用户',
        message: '换个手机号或昵称试试看。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 68,
        color: Color(0xFFE9EDF5),
      ),
      itemBuilder: (context, index) {
        final user = _users[index];
        final isContact = _contactUserIds.contains(user.id);
        return _UserResultTile(
          user: user,
          isContact: isContact,
          onSendRequest: () => _sendFriendRequest(user),
          onStartChat: () => _startDirectChat(user),
        );
      },
    );
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _searchUsers);
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _api.contacts();
      if (!mounted) return;
      setState(() {
        _contactUserIds
          ..clear()
          ..addAll(contacts.map((contact) => contact.user.id));
      });
    } catch (_) {
      // 联系人状态只影响按钮文案，失败时不阻塞用户搜索。
    }
  }

  Future<void> _searchUsers() async {
    if (!_shouldSearchUsers || _query.trim().isEmpty) {
      setState(() {
        _users.clear();
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentId = SessionStore.instance.user?.id;
      final users = await _api.searchUsers(_query.trim());
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(users.where((user) => user.id != currentId));
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendFriendRequest(AppUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.sendFriendRequest(user.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已发送好友请求给 ${user.nickname}')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _startDirectChat(AppUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final conversation = await _api.createDirectConversation(user.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            appSocketService: widget.appSocketService,
            conversationId: conversation.id,
            title: user.nickname,
            subtitle: '单聊',
          ),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _SearchTabs extends StatelessWidget {
  const _SearchTabs({
    required this.scope,
    required this.onChanged,
  });

  final SearchScope scope;
  final ValueChanged<SearchScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _SearchTab(
            label: '全部',
            value: SearchScope.all,
            current: scope,
            onChanged: onChanged,
          ),
          _SearchTab(
            label: '联系人',
            value: SearchScope.contacts,
            current: scope,
            onChanged: onChanged,
          ),
          _SearchTab(
            label: '群组',
            value: SearchScope.groups,
            current: scope,
            onChanged: onChanged,
          ),
          _SearchTab(
            label: '消息',
            value: SearchScope.messages,
            current: scope,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.label,
    required this.value,
    required this.current,
    required this.onChanged,
  });

  final String label;
  final SearchScope value;
  final SearchScope current;
  final ValueChanged<SearchScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF2478FF) : const Color(0xFF697089),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: const [
        Text(
          '单聊需要先加好友',
          style: TextStyle(
            color: Color(0xFF11131A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        _ScopeHint(
          icon: Icons.person_search_rounded,
          label: '搜索用户',
          detail: '输入对方手机号或昵称，找到后先点击“加好友”。',
        ),
        _ScopeHint(
          icon: Icons.chat_bubble_rounded,
          label: '好友可单聊',
          detail: '添加成功后按钮会变成“发消息”，再进入单聊。',
        ),
      ],
    );
  }
}

class _ScopeHint extends StatelessWidget {
  const _ScopeHint({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2FF),
        child: Icon(icon, color: const Color(0xFF2478FF)),
      ),
      title: Text(label),
      subtitle: Text(detail),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.user,
    required this.isContact,
    required this.onSendRequest,
    required this.onStartChat,
  });

  final AppUser user;
  final bool isContact;
  final VoidCallback onSendRequest;
  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _InitialAvatar(name: user.nickname),
      title: Text(
        user.nickname,
        style: const TextStyle(
          color: Color(0xFF11131A),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(user.phone),
      trailing: FilledButton.icon(
        onPressed: isContact ? onStartChat : onSendRequest,
        icon: Icon(
          isContact ? Icons.chat_bubble_rounded : Icons.person_add_rounded,
          size: 18,
        ),
        label: Text(isContact ? '发消息' : '加好友'),
      ),
      onTap: isContact ? onStartChat : onSendRequest,
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6AA5FF), Color(0xFF185CF2)],
        ),
      ),
      child: Text(
        name.isEmpty ? '用' : name.substring(0, 1),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}
