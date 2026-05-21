import 'dart:async';

import 'database/app_database.dart';
import 'database/database_service.dart';

class OfflineQueueService {
  OfflineQueueService({required this.onDrainMessage});

  /// Called for each pending message when draining the queue. The callee
  /// should emit the message to the socket. Returns the localId so the
  /// caller can match the server response.
  final Future<bool> Function(PendingMessage msg) onDrainMessage;

  StreamSubscription<List<PendingMessage>>? _pendingSubscription;

  void start() {
    _pendingSubscription =
        DatabaseService.instance.db.watchPending().listen((_) {});
  }

  /// Enqueue a message for later delivery.
  Future<String> enqueue({
    required String conversationId,
    required String content,
    required String type,
  }) async {
    final localId = _generateLocalId();
    await DatabaseService.instance.db.enqueuePending(
      localId: localId,
      conversationId: conversationId,
      content: content,
      type: type,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    return localId;
  }

  /// Drain all pending messages — called when socket connects.
  Future<void> drain() async {
    final pending =
        await DatabaseService.instance.db.drainPendingMessages();
    for (final msg in pending) {
      await DatabaseService.instance.db.markPendingSending(msg.localId);
      try {
        final sent = await onDrainMessage(msg);
        if (sent) {
          await DatabaseService.instance.db.markPendingSent(msg.localId);
        } else {
          await DatabaseService.instance.db.markPendingFailed(msg.localId);
        }
      } catch (_) {
        await DatabaseService.instance.db.markPendingFailed(msg.localId);
      }
    }
  }

  /// Called when the server confirms a message (echoes clientId back).
  Future<void> onServerConfirmed(String clientId) async {
    await DatabaseService.instance.db.markPendingSent(clientId);
  }

  void dispose() {
    _pendingSubscription?.cancel();
  }

  String _generateLocalId() {
    return 'local_${DateTime.now().microsecondsSinceEpoch}_'
        '${(DateTime.now().millisecondsSinceEpoch % 10000)}';
  }
}
