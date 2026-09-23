/// A venue's own numbers.
///
/// [revenue] only counts tickets that genuinely earned — delivered, and either
/// the cash was taken or the card cleared. [orders] counts every ticket opened,
/// so the two are deliberately different and must not be read as one figure.
class VenueStats {
  const VenueStats({
    required this.days,
    required this.windowLimit,
    required this.orders,
    required this.revenue,
    required this.averageCheck,
    required this.cancelled,
    required this.cancelRate,
    required this.byDay,
    required this.topDishes,
    required this.byChannel,
    required this.byPayMethod,
  });

  final int days;

  /// How far back this plan may look. A shorter window than asked for is the
  /// plan talking, not an error.
  final int windowLimit;
  final int orders;
  final double revenue;
  final double averageCheck;
  final int cancelled;
  final double cancelRate;
  final List<StatsDay> byDay;
  final List<DishRow> topDishes;
  final Map<String, int> byChannel;
  final Map<String, int> byPayMethod;

  static double _money(Object? v) => (v as num?)?.toDouble() ?? 0;
  static int _count(Object? v) => (v as num?)?.toInt() ?? 0;

  static Map<String, int> _counts(Object? raw) {
    final map = (raw as Map?) ?? const {};
    return {
      for (final entry in map.entries)
        entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
    };
  }

  factory VenueStats.fromJson(Map<String, dynamic> json) => VenueStats(
    days: _count(json['days']),
    windowLimit: _count(json['window_limit']),
    orders: _count(json['orders']),
    revenue: _money(json['revenue']),
    averageCheck: _money(json['average_check']),
    cancelled: _count(json['cancelled']),
    cancelRate: _money(json['cancel_rate']),
    byDay: ((json['by_day'] as List?) ?? const [])
        .map((e) => StatsDay.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    topDishes: ((json['top_dishes'] as List?) ?? const [])
        .map((e) => DishRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    byChannel: _counts(json['by_channel']),
    byPayMethod: _counts(json['by_pay_method']),
  );

  /// Biggest day in the window. Never zero, so a chart cannot divide by it.
  double get peakDay {
    var peak = 0.0;
    for (final day in byDay) {
      if (day.revenue > peak) peak = day.revenue;
    }
    return peak == 0 ? 1 : peak;
  }
}

class StatsDay {
  const StatsDay({
    required this.day,
    required this.orders,
    required this.revenue,
  });

  final String day;
  final int orders;
  final double revenue;

  factory StatsDay.fromJson(Map<String, dynamic> json) => StatsDay(
    day: json['day'] as String? ?? '',
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
  );

  /// `2026-09-23` -> `23.09`. The year is noise on a short chart.
  String get shortLabel {
    final parts = day.split('-');
    return parts.length == 3 ? '${parts[2]}.${parts[1]}' : day;
  }
}

class DishRow {
  const DishRow({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final double revenue;

  factory DishRow.fromJson(Map<String, dynamic> json) => DishRow(
    name: json['name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
  );
}

class VenueCustomer {
  const VenueCustomer({
    required this.userId,
    required this.name,
    required this.phone,
    required this.orders,
    required this.spent,
    required this.lastOrderAt,
  });

  final int userId;
  final String name;
  final String? phone;
  final int orders;
  final double spent;
  final DateTime? lastOrderAt;

  factory VenueCustomer.fromJson(Map<String, dynamic> json) => VenueCustomer(
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    spent: (json['spent'] as num?)?.toDouble() ?? 0,
    lastOrderAt: DateTime.tryParse(json['last_order_at'] as String? ?? ''),
  );
}

/// Platform-wide money. [gross] and [courierPayouts] run in opposite
/// directions and their difference is not profit — commission is not modelled.
class PlatformRevenue {
  const PlatformRevenue({
    required this.days,
    required this.orders,
    required this.gross,
    required this.courierPayouts,
    required this.byDay,
    required this.byPlan,
    required this.topRestaurants,
  });

  final int days;
  final int orders;
  final double gross;
  final double courierPayouts;
  final List<StatsDay> byDay;
  final List<PlanSlice> byPlan;
  final List<VenueSlice> topRestaurants;

  factory PlatformRevenue.fromJson(Map<String, dynamic> json) =>
      PlatformRevenue(
        days: (json['days'] as num?)?.toInt() ?? 0,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
        gross: (json['gross'] as num?)?.toDouble() ?? 0,
        courierPayouts: (json['courier_payouts'] as num?)?.toDouble() ?? 0,
        byDay: ((json['by_day'] as List?) ?? const [])
            .map(
              (e) => StatsDay.fromJson({
                'day': (e as Map)['day'],
                'orders': e['orders'],
                'revenue': e['gross'],
              }),
            )
            .toList(growable: false),
        byPlan: ((json['by_plan'] as List?) ?? const [])
            .map((e) => PlanSlice.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        topRestaurants: ((json['top_restaurants'] as List?) ?? const [])
            .map((e) => VenueSlice.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  double get peakDay {
    var peak = 0.0;
    for (final day in byDay) {
      if (day.revenue > peak) peak = day.revenue;
    }
    return peak == 0 ? 1 : peak;
  }
}

class PlanSlice {
  const PlanSlice({
    required this.planCode,
    required this.restaurants,
    required this.gross,
  });

  final String planCode;
  final int restaurants;
  final double gross;

  factory PlanSlice.fromJson(Map<String, dynamic> json) => PlanSlice(
    planCode: json['plan_code'] as String? ?? '',
    restaurants: (json['restaurants'] as num?)?.toInt() ?? 0,
    gross: (json['gross'] as num?)?.toDouble() ?? 0,
  );
}

class VenueSlice {
  const VenueSlice({
    required this.id,
    required this.name,
    required this.orders,
    required this.gross,
  });

  final int id;
  final String name;
  final int orders;
  final double gross;

  factory VenueSlice.fromJson(Map<String, dynamic> json) => VenueSlice(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    gross: (json['gross'] as num?)?.toDouble() ?? 0,
  );
}
