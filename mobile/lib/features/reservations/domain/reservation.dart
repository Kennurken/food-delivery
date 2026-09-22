class Reservation {
  const Reservation({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.guests,
    required this.startsAt,
    required this.durationMin,
    required this.status,
    this.userId,
    this.tableObjectId,
    this.tableName,
    this.phone,
    this.comment,
  });

  final int id;
  final int restaurantId;
  final String restaurantName;
  final int? userId;
  final int? tableObjectId;
  final String? tableName;
  final String name;
  final String? phone;
  final int guests;
  final DateTime startsAt;
  final int durationMin;
  final String status;
  final String? comment;

  bool get canCancel => status == 'requested' || status == 'confirmed';

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    id: json['id'] as int,
    restaurantId: json['restaurant_id'] as int,
    restaurantName: json['restaurant_name'] as String? ?? '',
    userId: json['user_id'] as int?,
    tableObjectId: json['table_object_id'] as int?,
    tableName: json['table_name'] as String?,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    guests: json['guests'] as int? ?? 2,
    startsAt: DateTime.parse(json['starts_at'] as String),
    durationMin: json['duration_min'] as int? ?? 90,
    status: json['status'] as String,
    comment: json['comment'] as String?,
  );
}
