import 'package:flutter/widgets.dart';

import '../../features/orders/domain/order.dart';
import '../../features/profile/domain/address.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  L10n get l10n => L10n.of(this);
}

/// Domain enums stay locale-free; UI text lives here.
extension OrderStatusL10n on OrderStatus {
  String label(L10n t) => switch (this) {
    OrderStatus.pending => t.statusPending,
    OrderStatus.confirmed => t.statusConfirmed,
    OrderStatus.preparing => t.statusPreparing,
    OrderStatus.onTheWay => t.statusOnTheWay,
    OrderStatus.delivered => t.statusDelivered,
    OrderStatus.cancelled => t.statusCancelled,
  };

  String hint(L10n t) => switch (this) {
    OrderStatus.pending => t.hintPending,
    OrderStatus.confirmed => t.hintConfirmed,
    OrderStatus.preparing => t.hintPreparing,
    OrderStatus.onTheWay => t.hintOnTheWay,
    OrderStatus.delivered => t.hintDelivered,
    OrderStatus.cancelled => t.hintCancelled,
  };

  /// Label for the action that moves an order *to* this status.
  String actionLabel(L10n t) => switch (this) {
    OrderStatus.confirmed => t.actionConfirm,
    OrderStatus.preparing => t.actionStartPreparing,
    OrderStatus.onTheWay => t.actionHandToCourier,
    OrderStatus.delivered => t.actionMarkDelivered,
    OrderStatus.cancelled => t.actionCancel,
    OrderStatus.pending => t.statusPending,
  };
}

extension OrderChannelL10n on Order {
  String statusLabel(L10n t) => switch ((channel, status)) {
    ('qr_table', OrderStatus.onTheWay) ||
    ('pickup', OrderStatus.onTheWay) => t.statusReady,
    ('qr_table', OrderStatus.delivered) => t.statusServed,
    ('pickup', OrderStatus.delivered) => t.statusCollected,
    _ => status.label(t),
  };

  String statusHint(L10n t) => switch ((channel, status)) {
    ('qr_table', OrderStatus.confirmed) => t.hintConfirmedTable,
    ('pickup', OrderStatus.confirmed) => t.hintConfirmedPickup,
    ('qr_table', OrderStatus.onTheWay) => t.hintReadyTable,
    ('pickup', OrderStatus.onTheWay) => t.hintReadyPickup,
    ('qr_table', OrderStatus.delivered) => t.hintServed,
    ('pickup', OrderStatus.delivered) => t.hintCollected,
    _ => status.hint(t),
  };

  String nextActionLabel(OrderStatus next, L10n t) => switch ((channel, next)) {
    (final c, OrderStatus.onTheWay) when c != 'delivery' => t.actionMarkReady,
    ('qr_table', OrderStatus.delivered) => t.actionMarkServed,
    ('pickup', OrderStatus.delivered) => t.actionMarkCollected,
    _ => next.actionLabel(t),
  };

  String channelLabel(L10n t) => switch (channel) {
    'qr_table' => t.dineIn,
    'pickup' => t.pickup,
    _ => t.delivery,
  };
}

extension AddressL10n on Address {
  String display(L10n t) => formatAddress(
    line,
    apt: apt,
    entrance: entrance,
    floor: floor,
    intercom: intercom,
    aptLabel: t.apt,
    entranceLabel: t.entrance,
    floorLabel: t.floor,
    intercomLabel: t.intercom,
  );
}
