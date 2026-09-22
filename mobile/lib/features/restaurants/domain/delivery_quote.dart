/// What the ride to this door costs, quoted before the customer pays.
class DeliveryQuote {
  const DeliveryQuote({
    required this.fee,
    required this.baseFee,
    required this.perKm,
    required this.freeKm,
    required this.outOfRange,
    this.distanceKm,
    this.maxKm,
    this.precise = true,
  });

  final double fee;
  final double baseFee;
  final double perKm;
  final double freeKm;
  final double? distanceKm;
  final double? maxKm;
  final bool outOfRange;

  /// False when the server could not trust the point it was given — a text
  /// address that geocoded badly. The cart then shows the base fee, not a guess.
  final bool precise;

  /// Only worth explaining when distance actually moved the price.
  bool get isMetered => perKm > 0 && distanceKm != null && precise;

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) => DeliveryQuote(
    fee: (json['fee'] as num?)?.toDouble() ?? 0,
    baseFee: (json['base_fee'] as num?)?.toDouble() ?? 0,
    perKm: (json['per_km'] as num?)?.toDouble() ?? 0,
    freeKm: (json['free_km'] as num?)?.toDouble() ?? 0,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    maxKm: (json['max_km'] as num?)?.toDouble(),
    outOfRange: json['out_of_range'] as bool? ?? false,
    precise: json['precise'] as bool? ?? true,
  );
}
