// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Food Delivery';

  @override
  String get tagline => 'Hot food, fast.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get createAccountHint => 'Takes less than a minute.';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String minChars(int n) {
    return 'Min $n chars';
  }

  @override
  String get required => 'Required';

  @override
  String get logOut => 'Log out';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Late night';

  @override
  String get searchRestaurants => 'Restaurants, dishes';

  @override
  String get all => 'All';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get retry => 'Retry';

  @override
  String get navHome => 'Home';

  @override
  String get orders => 'Orders';

  @override
  String get profile => 'Profile';

  @override
  String minutes(int n) {
    return '$n min';
  }

  @override
  String deliveryFee(String fee) {
    return 'delivery $fee';
  }

  @override
  String get unavailable => 'Unavailable';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get done => 'Done';

  @override
  String get viewCart => 'View cart';

  @override
  String get newCartTitle => 'Start a new cart?';

  @override
  String get newCartBody => 'Your cart has items from another restaurant.';

  @override
  String get keep => 'Keep';

  @override
  String get replace => 'Replace';

  @override
  String get cart => 'Cart';

  @override
  String get cartEmpty => 'Cart is empty';

  @override
  String get cartEmptyHint => 'Add something tasty from a restaurant';

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String get courierComment => 'Comment for courier (optional)';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get delivery => 'Delivery';

  @override
  String get total => 'Total';

  @override
  String get placeOrder => 'Place order';

  @override
  String get enterAddress => 'Enter delivery address';

  @override
  String orderPlaced(int id) {
    return 'Order #$id placed';
  }

  @override
  String get keepYouPosted => 'We\'ll keep you posted';

  @override
  String get myOrders => 'My orders';

  @override
  String get active => 'Active';

  @override
  String get history => 'History';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get noOrdersHint => 'Your orders will show up here';

  @override
  String get browseRestaurants => 'Browse restaurants';

  @override
  String get orderAgain => 'Order again';

  @override
  String get nothingToReorder => 'Nothing from this order is available';

  @override
  String get someItemsUnavailable => 'Some dishes are no longer available';

  @override
  String get couldNotLoad => 'Couldn\'t load';

  @override
  String items(int n) {
    return '$n items';
  }

  @override
  String orderN(int id) {
    return 'Order #$id';
  }

  @override
  String get status => 'Status';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get callCourier => 'Call courier';

  @override
  String get courier => 'Courier';

  @override
  String get howWasIt => 'How was it?';

  @override
  String get thanksForRating => 'Thanks for rating!';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusPreparing => 'Preparing';

  @override
  String get statusOnTheWay => 'On the way';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get hintPending => 'Waiting for the restaurant to confirm';

  @override
  String get hintConfirmed => 'Confirmed — looking for a courier';

  @override
  String get hintPreparing => 'Kitchen is cooking your order';

  @override
  String get hintOnTheWay => 'Courier is on the way';

  @override
  String get hintDelivered => 'Delivered. Enjoy!';

  @override
  String get hintCancelled => 'This order was cancelled';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionStartPreparing => 'Start preparing';

  @override
  String get actionHandToCourier => 'Hand to courier';

  @override
  String get actionMarkDelivered => 'Mark delivered';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get accept => 'Accept';

  @override
  String get available => 'Available';

  @override
  String get myDeliveries => 'My deliveries';

  @override
  String get noOrdersWaiting => 'No orders waiting';

  @override
  String get noOrdersWaitingHint => 'New pickups appear here instantly';

  @override
  String get noActiveDeliveries => 'No active deliveries';

  @override
  String get noActiveDeliveriesHint => 'Accept an order from Available';

  @override
  String get admin => 'Admin';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get noOrdersAdminHint => 'New orders land here in real time';

  @override
  String get open => 'open';

  @override
  String get closed => 'closed';

  @override
  String get menu => 'Menu';

  @override
  String get newItem => 'New item';

  @override
  String get editItem => 'Edit item';

  @override
  String get description => 'Description';

  @override
  String get priceTenge => 'Price, ₸';

  @override
  String get category => 'Category';

  @override
  String get mustBePositive => 'Must be > 0';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String deleteItemTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteItemBody =>
      'Past orders keep their snapshot; the item disappears from the menu.';

  @override
  String get saved => 'Saved';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get addresses => 'Addresses';

  @override
  String get add => 'Add';

  @override
  String get noSavedAddresses => 'No saved addresses';

  @override
  String get noSavedAddressesHint => 'Add one to check out in a tap';

  @override
  String get swipeToDelete => 'Swipe left to delete';

  @override
  String get default_ => 'Default';

  @override
  String get newAddress => 'New address';

  @override
  String get labelHome => 'Home';

  @override
  String get labelWork => 'Work';

  @override
  String get labelOther => 'Other';

  @override
  String get addressLine => 'Street, building';

  @override
  String get apt => 'Apt';

  @override
  String get entrance => 'Entrance';

  @override
  String get floor => 'Floor';

  @override
  String get intercom => 'Intercom';

  @override
  String get saveAddress => 'Save address';

  @override
  String toastNewOrder(int id) {
    return 'New order #$id';
  }

  @override
  String toastReadyForPickup(int id) {
    return 'Order #$id ready for pickup';
  }

  @override
  String toastCourier(String name) {
    return 'Courier $name';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageKazakh => 'Қазақша';

  @override
  String get restaurantClosed => 'This restaurant is closed';

  @override
  String get cancelOrderTitle => 'Cancel this order?';

  @override
  String get cancelOrderBody =>
      'The kitchen will stop if it hasn\'t started yet.';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get passwordChanged => 'Password updated';

  @override
  String get passwordsDoNotMatch => 'Passwords don\'t match';
}
