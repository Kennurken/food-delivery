/// Loyalty quote for a specific restaurant with a given subtotal.
class LoyaltyQuote {
  const LoyaltyQuote({
    required this.balance,
    required this.percent,
    required this.maxShare,
    this.usable,
  });

  final double balance;
  final double percent;
  final double maxShare;
  final double? usable;

  factory LoyaltyQuote.fromJson(Map<String, dynamic> json) => LoyaltyQuote(
    balance: (json['balance'] as num).toDouble(),
    percent: (json['percent'] as num).toDouble(),
    maxShare: (json['max_share'] as num).toDouble(),
    usable: (json['usable'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'balance': balance,
    'percent': percent,
    'max_share': maxShare,
    if (usable != null) 'usable': usable,
  };

  bool get hasUsable => usable != null && usable! > 0;
  bool get hasProgramme => percent > 0;
}

/// User's loyalty balance at a single restaurant.
class LoyaltyBalance {
  const LoyaltyBalance({
    required this.restaurantId,
    required this.restaurantName,
    required this.balance,
  });

  final int restaurantId;
  final String restaurantName;
  final double balance;

  factory LoyaltyBalance.fromJson(Map<String, dynamic> json) => LoyaltyBalance(
    restaurantId: json['restaurant_id'] as int,
    restaurantName: json['restaurant_name'] as String,
    balance: (json['balance'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'restaurant_id': restaurantId,
    'restaurant_name': restaurantName,
    'balance': balance,
  };
}
