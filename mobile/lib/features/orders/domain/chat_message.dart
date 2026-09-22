class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.userId,
  });

  final int id;
  final int orderId;
  final int? userId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    orderId: json['order_id'] as int,
    userId: json['user_id'] as int?,
    senderName: json['sender_name'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
