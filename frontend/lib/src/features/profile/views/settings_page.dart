import 'package:flutter/material.dart';

import '../../../shared/widgets/app_chrome.dart';
import 'chat_history_management_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notification = true;
  bool _sound = true;
  bool _darkMode = false;
  bool _autoDownload = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageFrame(
        child: Stack(
          children: [
            BlueHeader(
              title: '设置',
              height: 166,
              leading: HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            WhitePanel(
              top: 124,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                children: [
                  _SettingsGroup(
                    children: [
                      _SwitchItem(
                        icon: Icons.notifications_none_rounded,
                        title: '新消息通知',
                        value: _notification,
                        onChanged: (value) =>
                            setState(() => _notification = value),
                      ),
                      _SwitchItem(
                        icon: Icons.volume_up_outlined,
                        title: '声音提醒',
                        value: _sound,
                        onChanged: (value) => setState(() => _sound = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    children: [
                      _SwitchItem(
                        icon: Icons.dark_mode_outlined,
                        title: '深色模式',
                        value: _darkMode,
                        onChanged: (value) => setState(() => _darkMode = value),
                      ),
                      _SwitchItem(
                        icon: Icons.download_for_offline_outlined,
                        title: 'Wi-Fi 自动下载文件',
                        value: _autoDownload,
                        onChanged: (value) =>
                            setState(() => _autoDownload = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    children: [
                      const _PlainItem(
                        icon: Icons.devices_rounded,
                        title: '登录设备管理',
                        trailing: '3 台设备',
                      ),
                      _PlainItem(
                        icon: Icons.backup_rounded,
                        title: '聊天记录管理',
                        trailing: '导入/导出',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChatHistoryManagementPage(),
                          ),
                        ),
                      ),
                      const _PlainItem(
                        icon: Icons.storage_rounded,
                        title: '存储空间',
                        trailing: '1.8 GB',
                      ),
                      const _PlainItem(
                        icon: Icons.privacy_tip_outlined,
                        title: '隐私与权限',
                        trailing: '',
                      ),
                      const _PlainItem(
                        icon: Icons.info_outline_rounded,
                        title: '关于畅聊',
                        trailing: 'v0.1.0',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF3B42),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '退出登录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 66),
          ],
        ],
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2FF),
        child: Icon(icon, color: const Color(0xFF2478FF)),
      ),
      title: Text(title),
      trailing: Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF2478FF),
        onChanged: onChanged,
      ),
    );
  }
}

class _PlainItem extends StatelessWidget {
  const _PlainItem({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2FF),
        child: Icon(icon, color: const Color(0xFF2478FF)),
      ),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing.isNotEmpty)
            Text(
              trailing,
              style: const TextStyle(color: Color(0xFF858CA1)),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
