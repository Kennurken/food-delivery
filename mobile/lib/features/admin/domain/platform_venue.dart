/// A tenant as the platform admin sees it: who runs it and how it trades.
class PlatformVenue {
  const PlatformVenue({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.isOpen,
    required this.planCode,
    required this.billingStatus,
    required this.rating,
    required this.ratingCount,
    required this.staffCount,
    required this.ordersTotal,
    required this.ordersWindow,
    required this.revenueTotal,
    required this.revenueWindow,
    required this.windowDays,
    this.imageUrl,
    this.owner,
    this.lastOrderAt,
    this.staff = const [],
    this.recentOrders = const [],
  });

  final int id;
  final String name;
  final String cuisine;
  final String? imageUrl;
  final bool isOpen;
  final String planCode;
  final String billingStatus;
  final double rating;
  final int ratingCount;
  final PlatformContact? owner;
  final int staffCount;
  final int ordersTotal;
  final int ordersWindow;
  final double revenueTotal;
  final double revenueWindow;
  final int windowDays;
  final DateTime? lastOrderAt;
  final List<PlatformContact> staff;
  final List<PlatformOrderRow> recentOrders;

  /// A tenant nobody can reach is a support problem waiting to happen.
  bool get hasContact => owner?.reachable ?? false;

  factory PlatformVenue.fromJson(Map<String, dynamic> json) => PlatformVenue(
    id: json['id'] as int,
    name: json['name'] as String,
    cuisine: json['cuisine'] as String? ?? '',
    imageUrl: json['image_url'] as String?,
    isOpen: json['is_open'] as bool? ?? false,
    planCode: json['plan_code'] as String? ?? '',
    billingStatus: json['billing_status'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    ratingCount: json['rating_count'] as int? ?? 0,
    owner: json['owner'] == null
        ? null
        : PlatformContact.fromJson(json['owner'] as Map<String, dynamic>),
    staffCount: json['staff_count'] as int? ?? 0,
    ordersTotal: json['orders_total'] as int? ?? 0,
    ordersWindow: json['orders_window'] as int? ?? 0,
    revenueTotal: (json['revenue_total'] as num?)?.toDouble() ?? 0,
    revenueWindow: (json['revenue_window'] as num?)?.toDouble() ?? 0,
    windowDays: json['window_days'] as int? ?? 30,
    lastOrderAt: json['last_order_at'] == null
        ? null
        : DateTime.tryParse(json['last_order_at'] as String),
    staff: (json['staff'] as List<dynamic>? ?? [])
        .map((e) => PlatformContact.fromJson(e as Map<String, dynamic>))
        .toList(),
    recentOrders: (json['recent_orders'] as List<dynamic>? ?? [])
        .map((e) => PlatformOrderRow.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PlatformContact {
  const PlatformContact({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.isActive = true,
    this.since,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;
  final DateTime? since;

  bool get reachable =>
      (phone != null && phone!.isNotEmpty) || email.isNotEmpty;

  factory PlatformContact.fromJson(Map<String, dynamic> json) =>
      PlatformContact(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        since: json['since'] == null
            ? null
            : DateTime.tryParse(json['since'] as String),
      );
}

class PlatformOrderRow {
  const PlatformOrderRow({
    required this.id,
    required this.status,
    required this.channel,
    required this.total,
    required this.payMethod,
    required this.payStatus,
    this.createdAt,
  });

  final int id;
  final String status;
  final String channel;
  final double total;
  final String payMethod;
  final String payStatus;
  final DateTime? createdAt;

  factory PlatformOrderRow.fromJson(Map<String, dynamic> json) =>
      PlatformOrderRow(
        id: json['id'] as int,
        status: json['status'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        payMethod: json['pay_method'] as String? ?? '',
        payStatus: json['pay_status'] as String? ?? '',
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );
}
