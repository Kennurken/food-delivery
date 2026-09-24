class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.isGuest = false,
    this.phone,
  });

  final int id;
  final String email;
  final String name;
  final String role;

  /// A table session created by scanning a QR: no email anyone owns and no
  /// password. Account settings mean nothing for one.
  final bool isGuest;
  final String? phone;

  bool get isAdmin => role == 'admin';
  bool get isCourier => role == 'courier';

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    email: json['email'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    isGuest: json['is_guest'] as bool? ?? false,
    phone: json['phone'] as String?,
  );
}
