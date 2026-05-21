import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/session_store.dart';
import '../../../shared/widgets/app_chrome.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController(text: '产品设计协作群');
  final _noticeController = TextEditingController(text: '欢迎大家加入群聊。');
  final _selected = <String, AppUser>{};
  List<AppUser> _users = const [];
  bool _loading = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _searchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _noticeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = SessionStore.instance.user;
    return Scaffold(
      body: PhonePageFrame(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFF11131A),
                        size: 34,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '发起群聊',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF11131A),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _creating ? null : _createGroup,
                      child: Text(
                        _creating ? '创建中' : '创建',
                        style: const TextStyle(
                          color: Color(0xFF2478FF),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _searchUsers(),
                  decoration: InputDecoration(
                    hintText: '搜索用户昵称或手机号',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF6F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _GroupFields(
                  nameController: _nameController,
                  noticeController: _noticeController,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                child: Row(
                  children: [
                    Text(
                      '已选择 ${_selected.length} 人',
                      style: const TextStyle(
                          color: Color(0xFF697089), fontSize: 16),
                    ),
                    const Spacer(),
                    if (currentUser != null)
                      Text(
                        '群主：${currentUser.nickname}',
                        style: const TextStyle(
                            color: Color(0xFF858CA1), fontSize: 14),
                      ),
                  ],
                ),
              ),
              const Divider(height: 8, thickness: 8, color: Color(0xFFF3F6FB)),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 92,
                          color: Color(0xFFE9EDF5),
                        ),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final selected = _selected.containsKey(user.id);
                          return _UserSelectTile(
                            user: user,
                            selected: selected,
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selected.remove(user.id);
                                } else {
                                  _selected[user.id] = user;
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchUsers() async {
    setState(() => _loading = true);
    try {
      final currentId = SessionStore.instance.user?.id;
      final users = await _api.searchUsers(_searchController.text.trim());
      if (!mounted) return;
      setState(() {
        _users = users.where((user) => user.id != currentId).toList();
      });
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    final currentUser = SessionStore.instance.user;
    if (currentUser == null) {
      _showMessage('请先登录');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请输入群名称');
      return;
    }

    setState(() => _creating = true);
    try {
      // 后端接口要求 memberIds 至少有一个 UUID；没有选人时仅包含当前用户。
      final memberIds =
          _selected.keys.isEmpty ? [currentUser.id] : _selected.keys.toList();
      await _api.createGroup(
        name: name,
        memberIds: memberIds,
        announcement: _noticeController.text.trim(),
      );
      if (!mounted) return;
      _showMessage('群聊创建成功');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GroupFields extends StatelessWidget {
  const _GroupFields({
    required this.nameController,
    required this.noticeController,
  });

  final TextEditingController nameController;
  final TextEditingController noticeController;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x120C3A91), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '群名称',
                prefixIcon: Icon(Icons.groups_rounded),
              ),
            ),
            TextField(
              controller: noticeController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '群公告',
                prefixIcon: Icon(Icons.campaign_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSelectTile extends StatelessWidget {
  const _UserSelectTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AppUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
        child: Row(
          children: [
            _UserInitialAvatar(name: user.nickname),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF11131A),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user.phone,
                    style:
                        const TextStyle(color: Color(0xFF7C8499), fontSize: 15),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF2478FF) : Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2478FF)
                      : const Color(0xFFC8CEDB),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 23)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserInitialAvatar extends StatelessWidget {
  const _UserInitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
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
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
