class ModifierOption {
  const ModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.isDefault,
    required this.isAvailable,
  });

  final int id;
  final String name;
  final double priceDelta;
  final bool isDefault;
  final bool isAvailable;

  factory ModifierOption.fromJson(Map<String, dynamic> json) => ModifierOption(
    id: json['id'] as int,
    name: json['name'] as String,
    priceDelta: (json['price_delta'] as num?)?.toDouble() ?? 0,
    isDefault: json['is_default'] as bool? ?? false,
    isAvailable: json['is_available'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price_delta': priceDelta,
    'is_default': isDefault,
    'is_available': isAvailable,
  };
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.required,
    required this.minSelect,
    required this.maxSelect,
    this.options = const [],
  });

  final int id;
  final String name;
  final bool required;
  final int minSelect;
  final int maxSelect;
  final List<ModifierOption> options;

  int get need => required ? (minSelect < 1 ? 1 : minSelect) : minSelect;

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
    id: json['id'] as int,
    name: json['name'] as String,
    required: json['required'] as bool? ?? false,
    minSelect: json['min_select'] as int? ?? 0,
    maxSelect: json['max_select'] as int? ?? 1,
    options: [
      for (final o in json['options'] as List<dynamic>? ?? [])
        ModifierOption.fromJson(o as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'required': required,
    'min_select': minSelect,
    'max_select': maxSelect,
    'options': [for (final o in options) o.toJson()],
  };
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isAvailable,
    this.imageUrl,
    this.groups = const [],
  });

  final int id;
  final int restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final List<ModifierGroup> groups;

  bool get needsPicker => groups.isNotEmpty;
  bool get hasPricedOptions =>
      groups.any((g) => g.options.any((o) => o.priceDelta > 0));

  List<int> get defaultOptionIds => [
    for (final g in groups)
      for (final o in g.options)
        if (o.isDefault && o.isAvailable) o.id,
  ];

  bool accepts(Iterable<int> optionIds) {
    final wanted = optionIds.toSet();
    final known = {
      for (final g in groups)
        for (final o in g.options) o.id,
    };
    if (!wanted.every(known.contains)) return false;
    for (final g in groups) {
      final picked = [
        for (final o in g.options)
          if (wanted.contains(o.id)) o,
      ];
      if (picked.any((o) => !o.isAvailable)) return false;
      if (picked.length < g.need || picked.length > g.maxSelect) return false;
    }
    return true;
  }

  double priceWith(Iterable<int> optionIds) {
    final wanted = optionIds.toSet();
    var extra = 0.0;
    for (final g in groups) {
      for (final o in g.options) {
        if (wanted.contains(o.id)) extra += o.priceDelta;
      }
    }
    return price + extra;
  }

  List<String> optionNames(Iterable<int> optionIds) {
    final wanted = optionIds.toSet();
    return [
      for (final g in groups)
        for (final o in g.options)
          if (wanted.contains(o.id)) o.name,
    ];
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as int,
    restaurantId: json['restaurant_id'] as int,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    price: (json['price'] as num).toDouble(),
    category: json['category'] as String,
    imageUrl: json['image_url'] as String?,
    isAvailable: json['is_available'] as bool,
    groups: [
      for (final g in json['modifier_groups'] as List<dynamic>? ?? [])
        ModifierGroup.fromJson(g as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'name': name,
    'description': description,
    'price': price,
    'category': category,
    'image_url': imageUrl,
    'is_available': isAvailable,
    'modifier_groups': [for (final g in groups) g.toJson()],
  };
}
