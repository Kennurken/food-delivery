/// Where a push leads, worked out from its `data` payload alone.
///
/// Kept free of Firebase and Flutter so it can be unit-tested. FCM data values
/// are always strings; anything unrecognised opens nothing and the app just
/// comes to the front.
library;

/// A push as the app sees it, without Firebase types.
class PushMessage {
  const PushMessage({required this.data, this.title, this.body});

  final Map<String, dynamic> data;
  final String? title;
  final String? body;
}

/// What the push is about. Older servers send status pushes with no `cause`,
/// so an order id on its own still means a status change.
String? pushCause(Map<String, dynamic> data) {
  final cause = data['cause'];
  if (cause is String && cause.isNotEmpty) return cause;
  return _id(data['order_id']) != null ? 'status' : null;
}

/// The screen a tap on this push opens, or null to just open the app.
String? routeForPush(Map<String, dynamic> data) {
  final order = _id(data['order_id']);
  final venue = _id(data['restaurant_id']);
  return switch (pushCause(data)) {
    'status' when order != null => '/orders/$order',
    // A manager called into a conversation is needed in that conversation.
    'chat' || 'escalation' when order != null => '/chat/$order',
    // The tab lists every pending application, so no id is needed to land.
    'application' => '/admin?tab=applications',
    'approval' when venue != null => '/admin/restaurants/$venue',
    _ => null,
  };
}

/// Whether a push that arrives while the app is open gets its own banner.
///
/// Status changes and chat lines reach an open app over the live socket as
/// well, and LiveEventsListener already decides per role which of those are
/// worth a banner. Showing the push too would announce one event twice.
bool showsInForeground(Map<String, dynamic> data) => switch (pushCause(data)) {
  'escalation' || 'application' || 'approval' => true,
  _ => false,
};

int? _id(Object? raw) {
  final id = switch (raw) {
    final int v => v,
    final String s => int.tryParse(s.trim()),
    _ => null,
  };
  return id != null && id > 0 ? id : null;
}
