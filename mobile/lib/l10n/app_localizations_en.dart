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
  String get popular => 'Popular';

  @override
  String get sortRating => 'Rating';

  @override
  String get sortEta => 'Fastest';

  @override
  String get sortFee => 'Fee';

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
  String get actionPickedUp => 'Picked up';

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

  @override
  String get newRestaurant => 'New restaurant';

  @override
  String get cuisine => 'Cuisine';

  @override
  String get deliveryFeeTenge => 'Delivery fee, ₸';

  @override
  String get etaMinutes => 'ETA, min';

  @override
  String get noRestaurants => 'No restaurants';

  @override
  String get noRestaurantsHint => 'Add one to start taking orders';

  @override
  String get favorites => 'Saved';

  @override
  String get addFavorite => 'Save restaurant';

  @override
  String get removeFavorite => 'Remove from saved';

  @override
  String get floorPlan => 'Floor plan';

  @override
  String get noFloorPlan => 'No floor plan yet';

  @override
  String get noFloorPlanHint =>
      'Place tables, walls and rooms on a scale drawing of the dining room.';

  @override
  String get createFloorPlan => 'Create floor plan';

  @override
  String get startScratch => 'Start from scratch';

  @override
  String get useTemplate => 'Use cafe template';

  @override
  String get firstFloor => '1st Floor';

  @override
  String get addFloor => 'Add floor';

  @override
  String get renameFloor => 'Rename floor';

  @override
  String get duplicateFloor => 'Duplicate floor';

  @override
  String get deleteFloor => 'Delete floor';

  @override
  String get previewLayout => 'Preview';

  @override
  String get editLayout => 'Edit';

  @override
  String get layoutSaved => 'Saved';

  @override
  String get layoutSaving => 'Saving…';

  @override
  String get layoutUnsaved => 'Unsaved changes';

  @override
  String get layoutSaveFailed => 'Unable to save';

  @override
  String get layoutSaveFailedBody =>
      'Your local changes are still here. Retry or keep editing.';

  @override
  String get continueEditing => 'Continue editing';

  @override
  String get snapOn => 'Snap on';

  @override
  String get snapOff => 'Snap off';

  @override
  String get platform => 'Platform';

  @override
  String get tableQr => 'Table QR';

  @override
  String get copyLink => 'Copy link';

  @override
  String get copied => 'Copied';

  @override
  String get dineIn => 'Dine in';

  @override
  String atTable(String name) {
    return 'Table $name';
  }

  @override
  String get signInToOrder => 'Sign in to order';

  @override
  String get setup => 'Setup';

  @override
  String get setupMenu => 'Menu';

  @override
  String get setupFloor => 'Floor plan';

  @override
  String get setupOpen => 'Open for orders';

  @override
  String get ordersToday => 'Orders today';

  @override
  String get venues => 'Restaurants';

  @override
  String get billingUnconfigured => 'Billing is not connected yet';

  @override
  String get plan => 'Plan';

  @override
  String get pickup => 'Pickup';

  @override
  String get kitchen => 'Kitchen';

  @override
  String get kitchenNew => 'New';

  @override
  String get kitchenCooking => 'Cooking';

  @override
  String get kitchenReady => 'Ready';

  @override
  String get actionMarkReady => 'Mark ready';

  @override
  String get actionMarkServed => 'Served';

  @override
  String get actionMarkCollected => 'Collected';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusServed => 'Served';

  @override
  String get statusCollected => 'Collected';

  @override
  String get hintConfirmedTable => 'Confirmed — the kitchen has your order';

  @override
  String get hintConfirmedPickup => 'Confirmed — getting it ready for pickup';

  @override
  String get hintReadyTable => 'Ready — staff will bring it to the table';

  @override
  String get hintReadyPickup => 'Ready for pickup at the restaurant';

  @override
  String get hintServed => 'Served. Enjoy!';

  @override
  String get hintCollected => 'Collected. Enjoy!';

  @override
  String get orderNote => 'Comment';

  @override
  String get tableOnly =>
      'This restaurant takes table orders only. Scan the QR on your table.';

  @override
  String get pickupAt => 'Pickup at the restaurant';

  @override
  String get pickAddress => 'Pick on map';

  @override
  String get confirmAddress => 'Deliver here';

  @override
  String get searchAddress => 'Street, building, landmark';

  @override
  String get dropPin => 'Move the map to drop a pin';

  @override
  String get locationDenied =>
      'Location is off or denied. Pan the map instead.';

  @override
  String get noAddressHits => 'Nothing nearby for that search';

  @override
  String get sortNear => 'Near';

  @override
  String get openMap => 'Map';

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String fromPrice(String price) {
    return 'from $price';
  }

  @override
  String get payCash => 'Cash';

  @override
  String get payCard => 'Card';

  @override
  String get payOnDelivery =>
      'Pay the courier or at the counter. The order stays unpaid until then.';

  @override
  String get cardNotConnected => 'Card payments are not connected. Use cash.';

  @override
  String get payCardHint =>
      'You\'ll pay on a Stripe page. Test card 4242 4242 4242 4242.';

  @override
  String get payNow => 'Pay now';

  @override
  String get waitingForCard => 'Waiting for card';

  @override
  String get paid => 'Paid';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get payMethod => 'Payment';

  @override
  String get modifiers => 'Sizes & extras';

  @override
  String get addGroup => 'Add group';

  @override
  String get addOption => 'Add option';

  @override
  String get optionName => 'Option';

  @override
  String get priceDelta => 'Δ ₸';

  @override
  String get asap => 'As soon as possible';

  @override
  String get schedule => 'Time';

  @override
  String scheduledFor(String when) {
    return 'Scheduled · $when';
  }

  @override
  String get promo => 'Promo code';

  @override
  String get applyPromo => 'Apply';

  @override
  String get discount => 'Discount';

  @override
  String get kitchenLater => 'Later';

  @override
  String get chat => 'Chat';

  @override
  String orderChat(int id) {
    return 'Chat · #$id';
  }

  @override
  String get chatHint => 'Message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatEmpty => 'No messages yet';

  @override
  String get chatEmptyHint => 'Kitchen, courier, and you share this thread.';

  @override
  String get chatClosed => 'This order is finished. Chat is read-only.';

  @override
  String chatPreview(String who, String body) {
    return '$who: $body';
  }

  @override
  String get bookTable => 'Book a table';

  @override
  String get reservations => 'Reservations';

  @override
  String get guests => 'Guests';

  @override
  String guestsCount(int n) {
    return '$n guests';
  }

  @override
  String get pickTable => 'Table';

  @override
  String get anyTable => 'Any table';

  @override
  String get book => 'Book';

  @override
  String get booked => 'Table booked';

  @override
  String get reserveRequested => 'Requested';

  @override
  String get reserveConfirmed => 'Confirmed';

  @override
  String get reserveSeated => 'Seated';

  @override
  String get reserveCancelled => 'Cancelled';

  @override
  String get reserveNoShow => 'No-show';

  @override
  String get cancelReservation => 'Cancel booking';

  @override
  String get noReservations => 'No bookings yet';

  @override
  String get noReservationsHint => 'Open a restaurant and tap Book a table.';

  @override
  String get walkIn => 'Walk-in';

  @override
  String get seatGuest => 'Seat';

  @override
  String tableSeats(int n) {
    return '$n seats';
  }

  @override
  String get confirmReservation => 'Confirm';

  @override
  String get searchVenues => 'Search restaurants';

  @override
  String lastDays(int n) {
    return '$n days';
  }

  @override
  String ordersWindow(int n) {
    return 'Orders / ${n}d';
  }

  @override
  String get revenueWindow => 'Revenue';

  @override
  String get ordersAllTime => 'Orders, all time';

  @override
  String get revenueAllTime => 'Revenue, all time';

  @override
  String get noOwnerLinked => 'No owner linked';

  @override
  String get noOwnerHint => 'Add one from the restaurant\'s staff list.';

  @override
  String get recentOrders => 'Recent orders';

  @override
  String get lastOrder => 'Last order';

  @override
  String get venue => 'Restaurant';

  @override
  String get directory => 'Directory';

  @override
  String get overview => 'Overview';

  @override
  String get staff => 'Staff';

  @override
  String get rating => 'Rating';

  @override
  String billingConnected(String provider) {
    return 'Card payments via $provider';
  }

  @override
  String deliveryDistance(String km) {
    return '$km km from the kitchen';
  }

  @override
  String outOfDeliveryRange(String km) {
    return 'Too far — this restaurant delivers up to $km km.';
  }
}
