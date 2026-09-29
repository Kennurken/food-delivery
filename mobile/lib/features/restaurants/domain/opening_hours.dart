/// One stretch of a weekday when the kitchen takes orders, on the venue's
/// own clock. `closes` not after `opens` runs past midnight; equal ends mean
/// round the clock.
class OpeningStretch {
  const OpeningStretch({
    required this.weekday,
    required this.opens,
    required this.closes,
  });

  /// 0 = Monday … 6 = Sunday (the API's numbering, not Dart's 1–7).
  final int weekday;

  /// "HH:MM".
  final String opens;
  final String closes;

  bool get overnight => closes.compareTo(opens) <= 0;

  factory OpeningStretch.fromJson(Map<String, dynamic> json) => OpeningStretch(
    weekday: json['weekday'] as int,
    opens: json['opens'] as String,
    closes: json['closes'] as String,
  );

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'opens': opens,
    'closes': closes,
  };
}
