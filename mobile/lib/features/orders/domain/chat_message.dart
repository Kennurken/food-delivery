import '../../../core/utils/server_time.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.userId,
    this.kind = 'text',
  });

  final int id;
  final int orderId;
  final int? userId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  /// 'escalation' is the thread saying staff called the manager in.
  final String kind;

  bool get isEscalation => kind == 'escalation';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    orderId: json['order_id'] as int,
    userId: json['user_id'] as int?,
    senderName: json['sender_name'] as String? ?? '',
    body: json['body'] as String? ?? '',
    kind: json['kind'] as String? ?? 'text',
    createdAt:
        parseServerTime(json['created_at'] as String?) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
