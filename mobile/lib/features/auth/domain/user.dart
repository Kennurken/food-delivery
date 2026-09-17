class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
  });

  final int id;
  final String email;
  final String name;
  final String role;
  final String? phone;

  bool get isAdmin => role == 'admin';
  bool get isCourier => role == 'courier';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String?,
      );
}
