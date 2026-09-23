/// A courier's wallet.
///
/// [earned] is what the platform owes the courier. [cashHeld] is the opposite
/// direction — money from cash orders that is still in the courier's pocket.
/// They are never added together; a single figure would mean nothing.
class CourierEarnings {
  const CourierEarnings({
    required this.days,
    required this.deliveries,
    required this.earned,
    required this.cashHeld,
    required this.earnedAllTime,
    required this.deliveriesAllTime,
    required this.byDay,
  });

  final int days;
  final int deliveries;
  final double earned;
  final double cashHeld;
  final double earnedAllTime;
  final int deliveriesAllTime;
  final List<EarningsDay> byDay;

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  factory CourierEarnings.fromJson(Map<String, dynamic> json) {
    final raw = (json['by_day'] as List?) ?? const [];
    return CourierEarnings(
      days: (json['days'] as num?)?.toInt() ?? 0,
      deliveries: (json['deliveries'] as num?)?.toInt() ?? 0,
      earned: _num(json['earned']),
      cashHeld: _num(json['cash_held']),
      earnedAllTime: _num(json['earned_all_time']),
      deliveriesAllTime: (json['deliveries_all_time'] as num?)?.toInt() ?? 0,
      byDay: raw
          .map((e) => EarningsDay.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// Biggest day in the window, used to scale the bars. Never zero, so the
  /// chart cannot divide by it.
  double get peakDay {
    var peak = 0.0;
    for (final day in byDay) {
      if (day.earned > peak) peak = day.earned;
    }
    return peak == 0 ? 1 : peak;
  }
}

class EarningsDay {
  const EarningsDay({
    required this.day,
    required this.deliveries,
    required this.earned,
  });

  final String day;
  final int deliveries;
  final double earned;

  factory EarningsDay.fromJson(Map<String, dynamic> json) => EarningsDay(
    day: json['day'] as String? ?? '',
    deliveries: (json['deliveries'] as num?)?.toInt() ?? 0,
    earned: (json['earned'] as num?)?.toDouble() ?? 0,
  );

  /// `2026-09-23` -> `23.09`. The year is noise on a seven-day chart.
  String get shortLabel {
    final parts = day.split('-');
    return parts.length == 3 ? '${parts[2]}.${parts[1]}' : day;
  }
}
