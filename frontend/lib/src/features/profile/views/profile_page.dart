import 'package:flutter/material.dart';

import '../../../services/session_store.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/avatar_widgets.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SessionStore.instance,
      builder: (context, _) {
        final user = SessionStore.instance.user;
        return Stack(
          children: [
            BlueHeader(
              height: 160,
              title: '我',
              actions: [
                HeaderIconButton(
                  icon: Icons.qr_code_rounded,
                  onPressed: () => _showQrSheet(context),
                ),
                HeaderIconButton(
                  icon: Icons.settings_rounded,
                  filled: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ),
            WhitePanel(
              top: 124,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  _UserCard(
                    user: user,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    children: [
                      _ProfileAction(
                        icon: Icons.person_outline_rounded,
                        title: '个人资料',
                        subtitle: '头像、用户名、个人签名',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileEditPage(),
                          ),
                        ),
                      ),
                      _ProfileAction(
                        icon: Icons.security_rounded,
                        title: '账号与安全',
                        subtitle: '手机号、登录密码',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileEditPage(),
                          ),
                        ),
                      ),
                      _ProfileAction(
                        icon: Icons.notifications_none_rounded,
                        title: '消息通知',
                        subtitle: '提醒、免打扰、声音与振动',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    children: [
                      _ProfileAction(
                        icon: Icons.folder_copy_outlined,
                        title: '文件与收藏',
                        subtitle: '图片、文档、已收藏消息',
                        onTap: () {},
                      ),
                      _ProfileAction(
                        icon: Icons.palette_outlined,
                        title: '外观设置',
                        subtitle: '主题、字号、聊天背景',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ),
                      _ProfileAction(
                        icon: Icons.help_outline_rounded,
                        title: '帮助与反馈',
                        subtitle: '常见问题、意见反馈',
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showQrSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '我的二维码',
                  style: TextStyle(
                    color: Color(0xFF11131A),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: 49,
                    itemBuilder: (context, index) {
                      final active =
                          index % 2 == 0 || index % 5 == 0 || index == 17;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              active ? const Color(0xFF2478FF) : Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '扫一扫，加我为好友',
                  style: TextStyle(color: Color(0xFF858CA1), fontSize: 15),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});

  final AppUser? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.nickname ?? '未登录用户';
    final phone = user?.phone ?? '请先登录';
    final bio = user?.bio?.isNotEmpty == true ? user!.bio! : '畅聊账号';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: const Color(0x120C3A91),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120C3A91),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              UserInitialAvatar(
                name: name,
                avatarUrl: user?.avatarUrl,
                size: 78,
                showOnline: user != null,
              ),
              const SizedBox(width: 18),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF858CA1),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bio,
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
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C3A91),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 66),
          ],
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
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
      minVerticalPadding: 14,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2FF),
        child: Icon(icon, color: const Color(0xFF2478FF)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF11131A),
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
