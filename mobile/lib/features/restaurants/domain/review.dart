import '../../../core/utils/server_time.dart';

/// One written review on a venue's page. The author is already shortened by
/// the server to a first name and an initial.
class Review {
  const Review({
    required this.orderId,
    required this.rating,
    required this.text,
    required this.author,
    this.at,
    this.reply,
  });

  final int orderId;
  final int rating;
  final String text;
  final String author;
  final DateTime? at;

  /// What the venue answered, if it did.
  final String? reply;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    orderId: json['order_id'] as int,
    rating: json['rating'] as int? ?? 0,
    text: json['text'] as String? ?? '',
    author: json['author'] as String? ?? '',
    at: parseServerTime(json['at'] as String?),
    reply: json['reply'] as String?,
  );
}
