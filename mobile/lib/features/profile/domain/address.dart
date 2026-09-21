class Address {
  const Address({
    required this.id,
    required this.label,
    required this.line,
    required this.isDefault,
  });

  final int id;
  final String label;
  final String line;
  final bool isDefault;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: json['id'] as int,
    label: json['label'] as String,
    line: json['line'] as String,
    isDefault: json['is_default'] as bool,
  );
}
