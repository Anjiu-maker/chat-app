import 'package:flutter/material.dart';

import '../../../features/chat_room/views/chat_room_page.dart';
import '../../../services/api_client.dart';
import '../../../services/app_socket_service.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/avatar_widgets.dart';

class ContactDetailPage extends StatefulWidget {
  const ContactDetailPage({
    required this.contact,
    this.appSocketService,
    super.key,
  });

  final AppContact contact;
  final AppSocketService? appSocketService;

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final _api = ApiClient();
  bool _startingChat = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageFrame(
        child: Stack(
          children: [
            BlueHeader(
              title: '联系人详情',
              height: 172,
              leading: HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                HeaderIconButton(
                  icon: Icons.more_horiz_rounded,
                  onPressed: () {},
                ),
              ],
            ),
            WhitePanel(
              top: 130,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                children: [
                  _ProfileHeader(contact: widget.contact),
                  const SizedBox(height: 18),
                  _InfoCard(contact: widget.contact),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _startingChat ? null : _startDirectChat,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2478FF),
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _startingChat
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.chat_bubble_rounded),
                          label: const Text('发消息'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2478FF),
                            minimumSize: const Size.fromHeight(54),
                            side: const BorderSide(color: Color(0xFF2478FF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('语音通话'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDirectChat() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _startingChat = true);
    try {
      final conversation =
          await _api.createDirectConversation(widget.contact.user.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            appSocketService: widget.appSocketService,
            conversationId: conversation.id,
            title: widget.contact.displayName,
            subtitle: '单聊',
          ),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.contact});

  final AppContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C3A91),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          UserInitialAvatar(name: contact.displayName, size: 76),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
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
                  contact.user.nickname,
                  style: const TextStyle(
                    color: Color(0xFF2478FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  contact.user.bio?.isNotEmpty == true
                      ? contact.user.bio!
                      : contact.user.phone,
                  style: const TextStyle(
                    color: Color(0xFF7C8499),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.contact});

  final AppContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C3A91),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(label: '畅聊号', value: 'chat_${contact.user.id}'),
          const Divider(height: 1, indent: 20),
          _InfoRow(label: '手机号', value: contact.user.phone),
          const Divider(height: 1, indent: 20),
          _InfoRow(label: '标签', value: contact.tag ?? '好友'),
          const Divider(height: 1, indent: 20),
          _InfoRow(label: '备注', value: contact.remark ?? '点击添加备注'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF858CA1), fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF11131A), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
