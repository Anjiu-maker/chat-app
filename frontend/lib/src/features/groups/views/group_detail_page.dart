import 'package:flutter/material.dart';

import '../../../features/chat_room/views/chat_room_page.dart';
import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/avatar_widgets.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    required this.conversationId,
    this.appSocketService,
    super.key,
  });

  final String conversationId;
  final AppSocketService? appSocketService;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _api = ApiClient();
  late Future<AppConversation> _future;
  bool _mute = false;
  bool _pin = false;
  bool _save = true;

  @override
  void initState() {
    super.initState();
    _future = _api.conversationDetail(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageFrame(
        child: Stack(
          children: [
            BlueHeader(
              title: '群聊详情',
              height: 168,
              leading: HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            WhitePanel(
              top: 126,
              child: FutureBuilder<AppConversation>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final group = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                    children: [
                      _GroupSummaryCard(
                        group: group,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomPage(
                              appSocketService: widget.appSocketService,
                              conversationId: group.id,
                              title: group.title,
                              subtitle: '${group.memberCount} 位成员',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MembersCard(count: group.memberCount),
                      const SizedBox(height: 14),
                      _SettingsCard(
                        mute: _mute,
                        pin: _pin,
                        save: _save,
                        onMuteChanged: (value) =>
                            setState(() => _mute = value),
                        onPinChanged: (value) => setState(() => _pin = value),
                        onSaveChanged: (value) =>
                            setState(() => _save = value),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0C3A91),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GroupSummaryCard extends StatelessWidget {
  const _GroupSummaryCard({
    required this.group,
    required this.onTap,
  });

  final AppConversation group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            GroupInitialAvatar(title: group.title, size: 82),
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
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _GroupTag(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${group.memberCount} 位成员',
                    style:
                        const TextStyle(color: Color(0xFF858CA1), fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.lastMessagePreview ?? '暂无消息',
                    style:
                        const TextStyle(color: Color(0xFF858CA1), fontSize: 16),
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

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFF2478FF), size: 28),
          const SizedBox(width: 14),
          Text(
            '群成员（$count 人）',
            style: const TextStyle(
              color: Color(0xFF11131A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.mute,
    required this.pin,
    required this.save,
    required this.onMuteChanged,
    required this.onPinChanged,
    required this.onSaveChanged,
  });

  final bool mute;
  final bool pin;
  final bool save;
  final ValueChanged<bool> onMuteChanged;
  final ValueChanged<bool> onPinChanged;
  final ValueChanged<bool> onSaveChanged;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        children: [
          _SwitchRow(
            icon: Icons.dark_mode_rounded,
            label: '消息免打扰',
            value: mute,
            onChanged: onMuteChanged,
          ),
          const Divider(height: 1, indent: 48),
          _SwitchRow(
            icon: Icons.push_pin_rounded,
            label: '置顶聊天',
            value: pin,
            onChanged: onPinChanged,
          ),
          const Divider(height: 1, indent: 48),
          _SwitchRow(
            icon: Icons.bookmark_rounded,
            label: '保存到通讯录',
            value: save,
            onChanged: onSaveChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2478FF), size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF11131A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2478FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _GroupTag extends StatelessWidget {
  const _GroupTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '群',
        style: TextStyle(
          color: Color(0xFF2478FF),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
