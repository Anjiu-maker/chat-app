import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/chat_history_transfer_service.dart';
import '../../../shared/widgets/app_chrome.dart';

class ChatHistoryManagementPage extends StatefulWidget {
  const ChatHistoryManagementPage({super.key});

  @override
  State<ChatHistoryManagementPage> createState() =>
      _ChatHistoryManagementPageState();
}

class _ChatHistoryManagementPageState extends State<ChatHistoryManagementPage> {
  final _service = ChatHistoryTransferService();
  late Future<ChatHistorySummary> _summaryFuture;
  String? _busyAction;

  bool get _isBusy => _busyAction != null;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _service.summary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageFrame(
        child: Stack(
          children: [
            BlueHeader(
              title: '聊天记录管理',
              subtitle: '导入与导出',
              height: 178,
              leading: HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            WhitePanel(
              top: 132,
              child: FutureBuilder<ChatHistorySummary>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  final summary = snapshot.data;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                    children: [
                      _SummaryCard(
                        conversationCount: summary?.conversationCount,
                        messageCount: summary?.messageCount,
                        loading:
                            snapshot.connectionState != ConnectionState.done,
                      ),
                      const SizedBox(height: 16),
                      _ActionPanel(
                        busyAction: _busyAction,
                        onExport: _exportHistory,
                        onImport: _importHistory,
                      ),
                      const SizedBox(height: 16),
                      const _NoticePanel(),
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

  Future<void> _exportHistory() async {
    if (_isBusy) return;
    setState(() => _busyAction = 'export');
    try {
      final result = await _service.exportAndShare();
      if (!mounted) return;
      _showMessage(
        '已导出 ${result.conversationCount} 个会话、${result.messageCount} 条消息',
      );
      _refreshSummary();
    } catch (error) {
      if (!mounted) return;
      _showMessage('导出失败：${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _importHistory() async {
    if (_isBusy) return;
    final confirmed = await _confirmImport();
    if (confirmed != true) return;

    setState(() => _busyAction = 'import');
    try {
      final result = await _service.importFromPicker();
      if (!mounted || result == null) return;
      _showMessage(
        '已导入 ${result.conversationCount} 个会话、${result.messageCount} 条消息',
      );
      _refreshSummary();
    } catch (error) {
      if (!mounted) return;
      _showMessage('导入失败：${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<bool?> _confirmImport() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入聊天记录'),
          content: const Text('导入会合并到当前本机记录，相同会话和消息会自动去重。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('选择文件'),
            ),
          ],
        );
      },
    );
  }

  void _refreshSummary() {
    setState(() {
      _summaryFuture = _service.summary();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _errorText(Object error) {
    if (error is FormatException) return error.message;
    return error.toString();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.conversationCount,
    required this.messageCount,
    required this.loading,
  });

  final int? conversationCount;
  final int? messageCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3ECFF)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(
              Icons.forum_rounded,
              color: Color(0xFF2478FF),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: '会话',
                    value: loading ? '--' : '${conversationCount ?? 0}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryMetric(
                    label: '消息',
                    value: loading ? '--' : '${messageCount ?? 0}',
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

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF11131A),
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF858CA1),
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.busyAction,
    required this.onExport,
    required this.onImport,
  });

  final String? busyAction;
  final FutureOr<void> Function() onExport;
  final FutureOr<void> Function() onImport;

  bool get _isBusy => busyAction != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          _TransferButton(
            icon: Icons.ios_share_rounded,
            title: '导出到其它手机',
            subtitle: '生成备份文件并打开系统分享',
            loading: busyAction == 'export',
            onPressed: _isBusy ? null : onExport,
          ),
          const Divider(height: 22),
          _TransferButton(
            icon: Icons.drive_folder_upload_rounded,
            title: '从其它手机导入',
            subtitle: '选择 .chatbackup 或 JSON 备份',
            loading: busyAction == 'import',
            onPressed: _isBusy ? null : onImport,
          ),
        ],
      ),
    );
  }
}

class _TransferButton extends StatelessWidget {
  const _TransferButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final FutureOr<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading || onPressed == null ? null : () => onPressed!(),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FF),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Icon(icon, color: const Color(0xFF2478FF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF11131A),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF858CA1),
                        fontSize: 13,
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

class _NoticePanel extends StatelessWidget {
  const _NoticePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE3B5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFFE08A00)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '备份只包含本机已缓存的会话和消息，不包含登录凭证。',
              style: TextStyle(
                color: Color(0xFF7A4D00),
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
