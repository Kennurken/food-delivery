class PromoQuote {
  const PromoQuote({required this.code, required this.discount});

  final String code;
  final double discount;

  factory PromoQuote.fromJson(Map<String, dynamic> json) => PromoQuote(
    code: json['code'] as String,
    discount: (json['discount'] as num).toDouble(),
  );
}
