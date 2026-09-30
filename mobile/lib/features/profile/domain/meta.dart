/// What the platform says about itself: where its legal texts live and how to
/// reach a person. Public, because someone locked out of their account is
/// exactly who needs the support contact.
class Meta {
  const Meta({
    required this.privacyUrl,
    required this.termsUrl,
    this.supportEmail,
    this.supportPhone,
  });

  final String? supportEmail;
  final String? supportPhone;
  final String privacyUrl;
  final String termsUrl;

  /// False when the platform has not configured any contact: then there is
  /// nothing to offer, and a "Support" row that does nothing is worse than none.
  bool get hasSupport => supportEmail != null || supportPhone != null;

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    supportEmail: _blankToNull(json['support_email']),
    supportPhone: _blankToNull(json['support_phone']),
    privacyUrl: json['privacy_url'] as String? ?? '',
    termsUrl: json['terms_url'] as String? ?? '',
  );

  // An empty string from an unset env var is still "not configured".
  static String? _blankToNull(Object? v) {
    final s = (v as String?)?.trim();
    return s == null || s.isEmpty ? null : s;
  }
}
