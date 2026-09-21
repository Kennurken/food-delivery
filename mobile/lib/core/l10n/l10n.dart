import 'package:flutter/widgets.dart';

import '../../features/orders/domain/order.dart';
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
