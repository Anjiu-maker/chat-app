import 'package:flutter/material.dart';

import '../../../features/search/views/search_page.dart';
import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/avatar_widgets.dart';
import 'contact_detail_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, this.appSocketService});

  final AppSocketService? appSocketService;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabController;
  late Future<List<AppContact>> _contactFuture;
  late Future<List<AppFriendRequest>> _incomingFuture;
  late Future<List<AppFriendRequest>> _outgoingFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _contactFuture = _api.contacts();
    _incomingFuture = _api.incomingRequests();
    _outgoingFuture = _api.outgoingRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _contactFuture = _api.contacts();
      _incomingFuture = _api.incomingRequests();
      _outgoingFuture = _api.outgoingRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BlueHeader(
          height: 180,
          title: '联系人',
        ),
        Positioned(
          top: 92,
          left: 20,
          right: 20,
          child: SoftSearchBar(
            hintText: '搜索并添加联系人',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SearchPage(initialScope: SearchScope.contacts, appSocketService: widget.appSocketService),
                ),
              );
              _reload();
            },
          ),
        ),
        WhitePanel(
          top: 148,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2478FF),
                unselectedLabelColor: const Color(0xFF6F7484),
                indicatorColor: const Color(0xFF2478FF),
                labelStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: '好友'),
                  Tab(text: '好友请求'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ContactsList(
                      future: _contactFuture,
                      onReload: _reload,
                      appSocketService: widget.appSocketService,
                    ),
                    _RequestsList(
                      incomingFuture: _incomingFuture,
                      outgoingFuture: _outgoingFuture,
                      onReload: _reload,
                      appSocketService: widget.appSocketService,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.future,
    required this.onReload,
    this.appSocketService,
  });

  final Future<List<AppContact>> future;
  final VoidCallback onReload;
  final AppSocketService? appSocketService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppContact>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ContactState(
            icon: Icons.cloud_off_rounded,
            title: '联系人加载失败',
            subtitle: snapshot.error.toString(),
            actionLabel: '重试',
            onPressed: onReload,
          );
        }
        final contacts = snapshot.data ?? const [];
        if (contacts.isEmpty) {
          return _ContactState(
            icon: Icons.person_add_alt_1_rounded,
            title: '还没有好友',
            subtitle: '通过手机号或昵称搜索用户，先加好友再发起单聊。',
            actionLabel: '添加好友',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SearchPage(initialScope: SearchScope.contacts, appSocketService: appSocketService),
                ),
              );
              onReload();
            },
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onReload(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 20, bottom: 110),
            itemCount: contacts.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 96, color: Color(0xFFE9EDF5)),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return _ContactTile(
                contact: contact,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContactDetailPage(contact: contact, appSocketService: appSocketService),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RequestsList extends StatefulWidget {
  const _RequestsList({
    required this.incomingFuture,
    required this.outgoingFuture,
    required this.onReload,
    this.appSocketService,
  });

  final Future<List<AppFriendRequest>> incomingFuture;
  final Future<List<AppFriendRequest>> outgoingFuture;
  final VoidCallback onReload;
  final AppSocketService? appSocketService;

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  final _api = ApiClient();
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppFriendRequest>>(
      future: widget.incomingFuture,
      builder: (context, incomingSnap) {
        return FutureBuilder<List<AppFriendRequest>>(
          future: widget.outgoingFuture,
          builder: (context, outgoingSnap) {
            final loading =
                incomingSnap.connectionState == ConnectionState.waiting ||
                    outgoingSnap.connectionState == ConnectionState.waiting;
            if (loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final incoming = incomingSnap.data ?? const [];
            final outgoing = outgoingSnap.data ?? const [];

            if (incoming.isEmpty && outgoing.isEmpty) {
              return _ContactState(
                icon: Icons.people_outline_rounded,
                title: '暂无好友请求',
                subtitle: '通过搜索添加好友，对方会收到你的好友请求。',
                actionLabel: '添加好友',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchPage(initialScope: SearchScope.contacts, appSocketService: widget.appSocketService),
                    ),
                  );
                  widget.onReload();
                },
              );
            }

            return RefreshIndicator(
              onRefresh: () async => widget.onReload(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 20, bottom: 110),
                children: [
                  if (incoming.isNotEmpty) ...[
                    const _SectionHeader(title: '收到的请求'),
                    ...incoming.map((req) => _IncomingRequestTile(
                          request: req,
                          onAccept: () => _accept(req),
                          onReject: () => _reject(req),
                          processing: _processing,
                        )),
                  ],
                  if (outgoing.isNotEmpty) ...[
                    const _SectionHeader(title: '发出的请求'),
                    ...outgoing.map((req) => _OutgoingRequestTile(
                          request: req,
                          onCancel: () => _cancel(req),
                        )),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _accept(AppFriendRequest request) async {
    setState(() => _processing = true);
    try {
      await _api.acceptRequest(request.id);
      widget.onReload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject(AppFriendRequest request) async {
    setState(() => _processing = true);
    try {
      await _api.rejectRequest(request.id);
      widget.onReload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cancel(AppFriendRequest request) async {
    try {
      await _api.cancelRequest(request.id);
      widget.onReload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
      child: Text(
        title,
        style: const TextStyle(
            color: Color(0xFF858CA1),
            fontSize: 14,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _IncomingRequestTile extends StatelessWidget {
  const _IncomingRequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.processing,
  });

  final AppFriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final user = request.fromUser;
    final message = request.message;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
      child: Row(
        children: [
          UserInitialAvatar(name: user.nickname, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  style: const TextStyle(
                      color: Color(0xFF11131A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFF7C8499), fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          if (!processing) ...[
            TextButton(
              onPressed: onReject,
              child:
                  const Text('拒绝', style: TextStyle(color: Color(0xFF858CA1))),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAccept,
              child: const Text('同意'),
            ),
          ] else
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _OutgoingRequestTile extends StatelessWidget {
  const _OutgoingRequestTile({
    required this.request,
    required this.onCancel,
  });

  final AppFriendRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final user = request.toUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
      child: Row(
        children: [
          UserInitialAvatar(name: user?.nickname ?? '?', size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.nickname ?? '未知用户',
                  style: const TextStyle(
                      color: Color(0xFF11131A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  '等待对方同意',
                  style: TextStyle(color: Color(0xFF858CA1), fontSize: 14),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text('撤回', style: TextStyle(color: Color(0xFF858CA1))),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final AppContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = contact.displayName;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 14, 12),
        child: Row(
          children: [
            UserInitialAvatar(name: name, size: 58),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF11131A),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    contact.user.phone,
                    style:
                        const TextStyle(color: Color(0xFF7C8499), fontSize: 15),
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

class _ContactState extends StatelessWidget {
  const _ContactState({
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
