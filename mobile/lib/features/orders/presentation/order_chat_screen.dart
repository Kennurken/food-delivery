import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/order_events.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/order_repository.dart';
import '../domain/chat_message.dart';

class OrderChatScreen extends ConsumerStatefulWidget {
  const OrderChatScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _rows = <ChatMessage>[];
  var _loading = true;
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(orderRepositoryProvider)
          .messages(widget.orderId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  void _ingest(ChatMessage msg) {
    if (_rows.any((m) => m.id == msg.id)) return;
    setState(() => _rows = [..._rows, msg]);
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await ref
          .read(orderRepositoryProvider)
          .sendMessage(widget.orderId, body);
      _input.clear();
      Haptics.tap();
      if (mounted) _ingest(msg);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final me = ref.watch(authControllerProvider).value?.id;
    final order = ref.watch(orderLiveProvider(widget.orderId)).value;
    final closed = order?.status.isFinal ?? false;
    ref.listen(orderEventsProvider, (_, next) {
      final evt = next.value;
      if (evt == null || !evt.isChat || evt.id != widget.orderId) return;
      final raw = evt.chat;
      if (raw == null) return;
      _ingest(ChatMessage.fromJson(raw));
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.orderChat(widget.orderId)),
            if (order != null)
              Text(
                order.restaurantName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? EmptyState(
                    icon: Icons.wifi_off,
                    title: t.couldNotLoad,
                    hint: _error,
                    action: FilledButton.tonal(
                      onPressed: _reload,
                      child: Text(t.retry),
                    ),
                  )
                : _rows.isEmpty
                ? EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: t.chatEmpty,
                    hint: t.chatEmptyHint,
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: _rows.length,
                    itemBuilder: (_, i) {
                      final msg = _rows[_rows.length - 1 - i];
                      return _Bubble(
                        msg: msg,
                        mine: me != null && msg.userId == me,
                      );
                    },
                  ),
          ),
          if (closed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  t.chatClosed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: t.chatHint,
                          filled: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      tooltip: t.chatSend,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.mine});

  final ChatMessage msg;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final time = _clock(msg.createdAt);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Text(
                      msg.senderName,
                      style: text.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    msg.body,
                    style: text.bodyMedium?.copyWith(color: fg, height: 1.35),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: text.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
