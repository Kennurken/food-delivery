import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Food Delivery'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Hot food, fast.'**
  String get tagline;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @createAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Takes less than a minute.'**
  String get createAccountHint;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @minChars.
  ///
  /// In en, this message translates to:
  /// **'Min {n} chars'**
  String minChars(int n);

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In en, this message translates to:
  /// **'Late night'**
  String get greetingNight;

  /// No description provided for @searchRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants, dishes'**
  String get searchRestaurants;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @sortRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get sortRating;

  /// No description provided for @sortEta.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get sortEta;

  /// No description provided for @sortFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get sortFee;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String minutes(int n);

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'delivery {fee}'**
  String deliveryFee(String fee);

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get viewCart;

  /// No description provided for @newCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new cart?'**
  String get newCartTitle;

  /// No description provided for @newCartBody.
  ///
  /// In en, this message translates to:
  /// **'Your cart has items from another restaurant.'**
  String get newCartBody;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartEmpty;

  /// No description provided for @cartEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add something tasty from a restaurant'**
  String get cartEmptyHint;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get deliveryAddress;

  /// No description provided for @courierComment.
  ///
  /// In en, this message translates to:
  /// **'Comment for courier (optional)'**
  String get courierComment;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get placeOrder;

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter delivery address'**
  String get enterAddress;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order #{id} placed'**
  String orderPlaced(int id);

  /// No description provided for @keepYouPosted.
  ///
  /// In en, this message translates to:
  /// **'We\'ll keep you posted'**
  String get keepYouPosted;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @noOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'Your orders will show up here'**
  String get noOrdersHint;

  /// No description provided for @browseRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Browse restaurants'**
  String get browseRestaurants;

  /// No description provided for @orderAgain.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get orderAgain;

  /// No description provided for @nothingToReorder.
  ///
  /// In en, this message translates to:
  /// **'Nothing from this order is available'**
  String get nothingToReorder;

  /// No description provided for @someItemsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some dishes are no longer available'**
  String get someItemsUnavailable;

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load'**
  String get couldNotLoad;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'{n} items'**
  String items(int n);

  /// No description provided for @orderN.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderN(int id);

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @callCourier.
  ///
  /// In en, this message translates to:
  /// **'Call courier'**
  String get callCourier;

  /// No description provided for @courier.
  ///
  /// In en, this message translates to:
  /// **'Courier'**
  String get courier;

  /// No description provided for @howWasIt.
  ///
  /// In en, this message translates to:
  /// **'How was it?'**
  String get howWasIt;

  /// No description provided for @thanksForRating.
  ///
  /// In en, this message translates to:
  /// **'Thanks for rating!'**
  String get thanksForRating;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get statusPreparing;

  /// No description provided for @statusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get statusOnTheWay;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @hintPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the restaurant to confirm'**
  String get hintPending;

  /// No description provided for @hintConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed — looking for a courier'**
  String get hintConfirmed;

  /// No description provided for @hintPreparing.
  ///
  /// In en, this message translates to:
  /// **'Kitchen is cooking your order'**
  String get hintPreparing;

  /// No description provided for @hintOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Courier is on the way'**
  String get hintOnTheWay;

  /// No description provided for @hintDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered. Enjoy!'**
  String get hintDelivered;

  /// No description provided for @hintCancelled.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled'**
  String get hintCancelled;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionStartPreparing.
  ///
  /// In en, this message translates to:
  /// **'Start preparing'**
  String get actionStartPreparing;

  /// No description provided for @actionHandToCourier.
  ///
  /// In en, this message translates to:
  /// **'Hand to courier'**
  String get actionHandToCourier;

  /// No description provided for @actionPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get actionPickedUp;

  /// No description provided for @actionMarkDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get actionMarkDelivered;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @myDeliveries.
  ///
  /// In en, this message translates to:
  /// **'My deliveries'**
  String get myDeliveries;

  /// No description provided for @noOrdersWaiting.
  ///
  /// In en, this message translates to:
  /// **'No orders waiting'**
  String get noOrdersWaiting;

  /// No description provided for @noOrdersWaitingHint.
  ///
  /// In en, this message translates to:
  /// **'New pickups appear here instantly'**
  String get noOrdersWaitingHint;

  /// No description provided for @noActiveDeliveries.
  ///
  /// In en, this message translates to:
  /// **'No active deliveries'**
  String get noActiveDeliveries;

  /// No description provided for @noActiveDeliveriesHint.
  ///
  /// In en, this message translates to:
  /// **'Accept an order from Available'**
  String get noActiveDeliveriesHint;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @restaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurants;

  /// No description provided for @noOrdersAdminHint.
  ///
  /// In en, this message translates to:
  /// **'New orders land here in real time'**
  String get noOrdersAdminHint;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'closed'**
  String get closed;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get newItem;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItem;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @priceTenge.
  ///
  /// In en, this message translates to:
  /// **'Price, ₸'**
  String get priceTenge;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @mustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be > 0'**
  String get mustBePositive;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteItemTitle(String name);

  /// No description provided for @deleteItemBody.
  ///
  /// In en, this message translates to:
  /// **'Past orders keep their snapshot; the item disappears from the menu.'**
  String get deleteItemBody;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @addresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addresses;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @noSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses'**
  String get noSavedAddresses;

  /// No description provided for @noSavedAddressesHint.
  ///
  /// In en, this message translates to:
  /// **'Add one to check out in a tap'**
  String get noSavedAddressesHint;

  /// No description provided for @swipeToDelete.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to delete'**
  String get swipeToDelete;

  /// No description provided for @default_.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default_;

  /// No description provided for @newAddress.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get newAddress;

  /// No description provided for @labelHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get labelHome;

  /// No description provided for @labelWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get labelWork;

  /// No description provided for @labelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get labelOther;

  /// No description provided for @addressLine.
  ///
  /// In en, this message translates to:
  /// **'Street, building'**
  String get addressLine;

  /// No description provided for @apt.
  ///
  /// In en, this message translates to:
  /// **'Apt'**
  String get apt;

  /// No description provided for @entrance.
  ///
  /// In en, this message translates to:
  /// **'Entrance'**
  String get entrance;

  /// No description provided for @floor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floor;

  /// No description provided for @intercom.
  ///
  /// In en, this message translates to:
  /// **'Intercom'**
  String get intercom;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get saveAddress;

  /// No description provided for @toastNewOrder.
  ///
  /// In en, this message translates to:
  /// **'New order #{id}'**
  String toastNewOrder(int id);

  /// No description provided for @toastReadyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Order #{id} ready for pickup'**
  String toastReadyForPickup(int id);

  /// No description provided for @toastCourier.
  ///
  /// In en, this message translates to:
  /// **'Courier {name}'**
  String toastCourier(String name);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageKazakh.
  ///
  /// In en, this message translates to:
  /// **'Қазақша'**
  String get languageKazakh;

  /// No description provided for @restaurantClosed.
  ///
  /// In en, this message translates to:
  /// **'This restaurant is closed'**
  String get restaurantClosed;

  /// No description provided for @cancelOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get cancelOrderTitle;

  /// No description provided for @cancelOrderBody.
  ///
  /// In en, this message translates to:
  /// **'The kitchen will stop if it hasn\'t started yet.'**
  String get cancelOrderBody;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get passwordChanged;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDoNotMatch;

  /// No description provided for @newRestaurant.
  ///
  /// In en, this message translates to:
  /// **'New restaurant'**
  String get newRestaurant;

  /// No description provided for @cuisine.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get cuisine;

  /// No description provided for @deliveryFeeTenge.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee, ₸'**
  String get deliveryFeeTenge;

  /// No description provided for @etaMinutes.
  ///
  /// In en, this message translates to:
  /// **'ETA, min'**
  String get etaMinutes;

  /// No description provided for @noRestaurants.
  ///
  /// In en, this message translates to:
  /// **'No restaurants'**
  String get noRestaurants;

  /// No description provided for @noRestaurantsHint.
  ///
  /// In en, this message translates to:
  /// **'Add one to start taking orders'**
  String get noRestaurantsHint;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get favorites;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Save restaurant'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeFavorite;

  /// No description provided for @floorPlan.
  ///
  /// In en, this message translates to:
  /// **'Floor plan'**
  String get floorPlan;

  /// No description provided for @noFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'No floor plan yet'**
  String get noFloorPlan;

  /// No description provided for @noFloorPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Place tables, walls and rooms on a scale drawing of the dining room.'**
  String get noFloorPlanHint;

  /// No description provided for @createFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'Create floor plan'**
  String get createFloorPlan;

  /// No description provided for @startScratch.
  ///
  /// In en, this message translates to:
  /// **'Start from scratch'**
  String get startScratch;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use cafe template'**
  String get useTemplate;

  /// No description provided for @firstFloor.
  ///
  /// In en, this message translates to:
  /// **'1st Floor'**
  String get firstFloor;

  /// No description provided for @addFloor.
  ///
  /// In en, this message translates to:
  /// **'Add floor'**
  String get addFloor;

  /// No description provided for @renameFloor.
  ///
  /// In en, this message translates to:
  /// **'Rename floor'**
  String get renameFloor;

  /// No description provided for @duplicateFloor.
  ///
  /// In en, this message translates to:
  /// **'Duplicate floor'**
  String get duplicateFloor;

  /// No description provided for @deleteFloor.
  ///
  /// In en, this message translates to:
  /// **'Delete floor'**
  String get deleteFloor;

  /// No description provided for @previewLayout.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLayout;

  /// No description provided for @editLayout.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editLayout;

  /// No description provided for @layoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get layoutSaved;

  /// No description provided for @layoutSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get layoutSaving;

  /// No description provided for @layoutUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get layoutUnsaved;

  /// No description provided for @layoutSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save'**
  String get layoutSaveFailed;

  /// No description provided for @layoutSaveFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your local changes are still here. Retry or keep editing.'**
  String get layoutSaveFailedBody;

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get continueEditing;

  /// No description provided for @snapOn.
  ///
  /// In en, this message translates to:
  /// **'Snap on'**
  String get snapOn;

  /// No description provided for @snapOff.
  ///
  /// In en, this message translates to:
  /// **'Snap off'**
  String get snapOff;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @tableQr.
  ///
  /// In en, this message translates to:
  /// **'Table QR'**
  String get tableQr;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @dineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine in'**
  String get dineIn;

  /// No description provided for @atTable.
  ///
  /// In en, this message translates to:
  /// **'Table {name}'**
  String atTable(String name);

  /// No description provided for @signInToOrder.
  ///
  /// In en, this message translates to:
  /// **'Sign in to order'**
  String get signInToOrder;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setup;

  /// No description provided for @setupMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get setupMenu;

  /// No description provided for @setupFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor plan'**
  String get setupFloor;

  /// No description provided for @setupOpen.
  ///
  /// In en, this message translates to:
  /// **'Open for orders'**
  String get setupOpen;

  /// No description provided for @ordersToday.
  ///
  /// In en, this message translates to:
  /// **'Orders today'**
  String get ordersToday;

  /// No description provided for @venues.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get venues;

  /// No description provided for @billingUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'Billing is not connected yet'**
  String get billingUnconfigured;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @kitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get kitchen;

  /// No description provided for @kitchenNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get kitchenNew;

  /// No description provided for @kitchenCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get kitchenCooking;

  /// No description provided for @kitchenReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get kitchenReady;

  /// No description provided for @actionMarkReady.
  ///
  /// In en, this message translates to:
  /// **'Mark ready'**
  String get actionMarkReady;

  /// No description provided for @actionMarkServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get actionMarkServed;

  /// No description provided for @actionMarkCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get actionMarkCollected;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get statusServed;

  /// No description provided for @statusCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get statusCollected;

  /// No description provided for @hintConfirmedTable.
  ///
  /// In en, this message translates to:
  /// **'Confirmed — the kitchen has your order'**
  String get hintConfirmedTable;

  /// No description provided for @hintConfirmedPickup.
  ///
  /// In en, this message translates to:
  /// **'Confirmed — getting it ready for pickup'**
  String get hintConfirmedPickup;

  /// No description provided for @hintReadyTable.
  ///
  /// In en, this message translates to:
  /// **'Ready — staff will bring it to the table'**
  String get hintReadyTable;

  /// No description provided for @hintReadyPickup.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup at the restaurant'**
  String get hintReadyPickup;

  /// No description provided for @hintServed.
  ///
  /// In en, this message translates to:
  /// **'Served. Enjoy!'**
  String get hintServed;

  /// No description provided for @hintCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected. Enjoy!'**
  String get hintCollected;

  /// No description provided for @orderNote.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get orderNote;

  /// No description provided for @tableOnly.
  ///
  /// In en, this message translates to:
  /// **'This restaurant takes table orders only. Scan the QR on your table.'**
  String get tableOnly;

  /// No description provided for @pickupAt.
  ///
  /// In en, this message translates to:
  /// **'Pickup at the restaurant'**
  String get pickupAt;

  /// No description provided for @pickAddress.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pickAddress;

  /// No description provided for @confirmAddress.
  ///
  /// In en, this message translates to:
  /// **'Deliver here'**
  String get confirmAddress;

  /// No description provided for @searchAddress.
  ///
  /// In en, this message translates to:
  /// **'Street, building, landmark'**
  String get searchAddress;

  /// No description provided for @dropPin.
  ///
  /// In en, this message translates to:
  /// **'Move the map to drop a pin'**
  String get dropPin;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is off or denied. Pan the map instead.'**
  String get locationDenied;

  /// No description provided for @noAddressHits.
  ///
  /// In en, this message translates to:
  /// **'Nothing nearby for that search'**
  String get noAddressHits;

  /// No description provided for @sortNear.
  ///
  /// In en, this message translates to:
  /// **'Near'**
  String get sortNear;

  /// No description provided for @openMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get openMap;

  /// No description provided for @distanceM.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distanceM(int m);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @fromPrice.
  ///
  /// In en, this message translates to:
  /// **'from {price}'**
  String fromPrice(String price);

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pay the courier or at the counter. The order stays unpaid until then.'**
  String get payOnDelivery;

  /// No description provided for @cardNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Card payments are not connected. Use cash.'**
  String get cardNotConnected;

  /// No description provided for @payCardHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ll pay on a Stripe page. Test card 4242 4242 4242 4242.'**
  String get payCardHint;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @waitingForCard.
  ///
  /// In en, this message translates to:
  /// **'Waiting for card'**
  String get waitingForCard;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @payMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payMethod;

  /// No description provided for @modifiers.
  ///
  /// In en, this message translates to:
  /// **'Sizes & extras'**
  String get modifiers;

  /// No description provided for @addGroup.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get addGroup;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @optionName.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get optionName;

  /// No description provided for @priceDelta.
  ///
  /// In en, this message translates to:
  /// **'Δ ₸'**
  String get priceDelta;

  /// No description provided for @asap.
  ///
  /// In en, this message translates to:
  /// **'As soon as possible'**
  String get asap;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get schedule;

  /// No description provided for @scheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled · {when}'**
  String scheduledFor(String when);

  /// No description provided for @promo.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get promo;

  /// No description provided for @applyPromo.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyPromo;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @kitchenLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get kitchenLater;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @orderChat.
  ///
  /// In en, this message translates to:
  /// **'Chat · #{id}'**
  String orderChat(int id);

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatEmpty;

  /// No description provided for @chatEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Kitchen, courier, and you share this thread.'**
  String get chatEmptyHint;

  /// No description provided for @chatClosed.
  ///
  /// In en, this message translates to:
  /// **'This order is finished. Chat is read-only.'**
  String get chatClosed;

  /// No description provided for @chatPreview.
  ///
  /// In en, this message translates to:
  /// **'{who}: {body}'**
  String chatPreview(String who, String body);

  /// No description provided for @bookTable.
  ///
  /// In en, this message translates to:
  /// **'Book a table'**
  String get bookTable;

  /// No description provided for @reservations.
  ///
  /// In en, this message translates to:
  /// **'Reservations'**
  String get reservations;

  /// No description provided for @guests.
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get guests;

  /// No description provided for @guestsCount.
  ///
  /// In en, this message translates to:
  /// **'{n} guests'**
  String guestsCount(int n);

  /// No description provided for @pickTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get pickTable;

  /// No description provided for @anyTable.
  ///
  /// In en, this message translates to:
  /// **'Any table'**
  String get anyTable;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @booked.
  ///
  /// In en, this message translates to:
  /// **'Table booked'**
  String get booked;

  /// No description provided for @reserveRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get reserveRequested;

  /// No description provided for @reserveConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get reserveConfirmed;

  /// No description provided for @reserveSeated.
  ///
  /// In en, this message translates to:
  /// **'Seated'**
  String get reserveSeated;

  /// No description provided for @reserveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get reserveCancelled;

  /// No description provided for @reserveNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get reserveNoShow;

  /// No description provided for @cancelReservation.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelReservation;

  /// No description provided for @noReservations.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get noReservations;

  /// No description provided for @noReservationsHint.
  ///
  /// In en, this message translates to:
  /// **'Open a restaurant and tap Book a table.'**
  String get noReservationsHint;

  /// No description provided for @walkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get walkIn;

  /// No description provided for @seatGuest.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get seatGuest;

  /// No description provided for @tableSeats.
  ///
  /// In en, this message translates to:
  /// **'{n} seats'**
  String tableSeats(int n);

  /// No description provided for @confirmReservation.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmReservation;

  /// No description provided for @searchVenues.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants'**
  String get searchVenues;

  /// No description provided for @lastDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String lastDays(int n);

  /// No description provided for @ordersWindow.
  ///
  /// In en, this message translates to:
  /// **'Orders / {n}d'**
  String ordersWindow(int n);

  /// No description provided for @revenueWindow.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenueWindow;

  /// No description provided for @ordersAllTime.
  ///
  /// In en, this message translates to:
  /// **'Orders, all time'**
  String get ordersAllTime;

  /// No description provided for @revenueAllTime.
  ///
  /// In en, this message translates to:
  /// **'Revenue, all time'**
  String get revenueAllTime;

  /// No description provided for @noOwnerLinked.
  ///
  /// In en, this message translates to:
  /// **'No owner linked'**
  String get noOwnerLinked;

  /// No description provided for @noOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Add one from the restaurant\'s staff list.'**
  String get noOwnerHint;

  /// No description provided for @recentOrders.
  ///
  /// In en, this message translates to:
  /// **'Recent orders'**
  String get recentOrders;

  /// No description provided for @lastOrder.
  ///
  /// In en, this message translates to:
  /// **'Last order'**
  String get lastOrder;

  /// No description provided for @venue.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get venue;

  /// No description provided for @directory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get directory;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staff;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @billingConnected.
  ///
  /// In en, this message translates to:
  /// **'Card payments via {provider}'**
  String billingConnected(String provider);

  /// No description provided for @deliveryDistance.
  ///
  /// In en, this message translates to:
  /// **'{km} km from the kitchen'**
  String deliveryDistance(String km);

  /// No description provided for @outOfDeliveryRange.
  ///
  /// In en, this message translates to:
  /// **'Too far — this restaurant delivers up to {km} km.'**
  String outOfDeliveryRange(String km);

  /// No description provided for @addressNeedsPin.
  ///
  /// In en, this message translates to:
  /// **'No map point — tap to set'**
  String get addressNeedsPin;

  /// No description provided for @handoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Handover code'**
  String get handoverTitle;

  /// No description provided for @handoverHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer for the four digits shown in their order.'**
  String get handoverHint;

  /// No description provided for @handoverCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Read it to the courier at the door'**
  String get handoverCustomerHint;

  /// No description provided for @cashCollected.
  ///
  /// In en, this message translates to:
  /// **'cash collected'**
  String get cashCollected;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'refunded'**
  String get refunded;

  /// No description provided for @kitchenBusy.
  ///
  /// In en, this message translates to:
  /// **'Kitchen full'**
  String get kitchenBusy;

  /// No description provided for @kitchenBusyHint.
  ///
  /// In en, this message translates to:
  /// **'This kitchen is at capacity. Try again in a few minutes.'**
  String get kitchenBusyHint;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @earnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get earnedLabel;

  /// No description provided for @cashToHandIn.
  ///
  /// In en, this message translates to:
  /// **'Cash to hand in'**
  String get cashToHandIn;

  /// No description provided for @cashToHandInHint.
  ///
  /// In en, this message translates to:
  /// **'You took this at the door. It belongs to the platform.'**
  String get cashToHandInHint;

  /// No description provided for @deliveriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get deliveriesLabel;

  /// No description provided for @allTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTimeLabel;

  /// No description provided for @noEarningsYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing earned yet'**
  String get noEarningsYet;

  /// No description provided for @noEarningsYetHint.
  ///
  /// In en, this message translates to:
  /// **'Close a delivery and it shows up here'**
  String get noEarningsYetHint;

  /// No description provided for @days7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get days7;

  /// No description provided for @days30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get days30;

  /// No description provided for @days90.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get days90;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @revenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenueLabel;

  /// No description provided for @ordersLabel.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersLabel;

  /// No description provided for @averageCheck.
  ///
  /// In en, this message translates to:
  /// **'Average check'**
  String get averageCheck;

  /// No description provided for @cancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledLabel;

  /// No description provided for @topDishes.
  ///
  /// In en, this message translates to:
  /// **'Top dishes'**
  String get topDishes;

  /// No description provided for @noStatsYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noStatsYet;

  /// No description provided for @noStatsYetHint.
  ///
  /// In en, this message translates to:
  /// **'Numbers appear once orders are delivered'**
  String get noStatsYetHint;

  /// No description provided for @planWindowNote.
  ///
  /// In en, this message translates to:
  /// **'Your plan shows up to {days} days'**
  String planWindowNote(int days);

  /// No description provided for @grossLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get grossLabel;

  /// No description provided for @courierPayoutsLabel.
  ///
  /// In en, this message translates to:
  /// **'Courier payouts'**
  String get courierPayoutsLabel;

  /// No description provided for @byPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'By plan'**
  String get byPlanLabel;

  /// No description provided for @topVenues.
  ///
  /// In en, this message translates to:
  /// **'Top venues'**
  String get topVenues;

  /// No description provided for @notProfitNote.
  ///
  /// In en, this message translates to:
  /// **'Gross minus payouts is not profit — commission is not modelled yet.'**
  String get notProfitNote;

  /// No description provided for @customerOrders.
  ///
  /// In en, this message translates to:
  /// **'{count} orders'**
  String customerOrders(int count);

  /// No description provided for @pickVenue.
  ///
  /// In en, this message translates to:
  /// **'Choose a venue'**
  String get pickVenue;

  /// No description provided for @stopList.
  ///
  /// In en, this message translates to:
  /// **'Stop list'**
  String get stopList;

  /// No description provided for @stopListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Everything is on sale'**
  String get stopListEmpty;

  /// No description provided for @stopListEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Dishes you stop appear here'**
  String get stopListEmptyHint;

  /// No description provided for @restoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get restoreAll;

  /// No description provided for @stopDish.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopDish;

  /// No description provided for @restoreDish.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreDish;

  /// No description provided for @venueSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get venueSettings;

  /// No description provided for @planLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planLabel;

  /// No description provided for @limitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get limitsLabel;

  /// No description provided for @featuresLabel.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get featuresLabel;

  /// No description provided for @byPlan.
  ///
  /// In en, this message translates to:
  /// **'By plan'**
  String get byPlan;

  /// No description provided for @forcedOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get forcedOn;

  /// No description provided for @forcedOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get forcedOff;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @overriddenNote.
  ///
  /// In en, this message translates to:
  /// **'Forced flags ignore the plan until you clear them.'**
  String get overriddenNote;

  /// No description provided for @billing.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billing;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// No description provided for @renewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews {date}'**
  String renewsOn(String date);

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @cancelPlan.
  ///
  /// In en, this message translates to:
  /// **'Cancel plan'**
  String get cancelPlan;

  /// No description provided for @freePlan.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freePlan;

  /// No description provided for @billingRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment failed — the card is being retried. Your venue keeps working.'**
  String get billingRetry;

  /// No description provided for @billingBlocked.
  ///
  /// In en, this message translates to:
  /// **'Subscription inactive. New orders are refused until it is restored.'**
  String get billingBlocked;

  /// No description provided for @billingOff.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are not connected on this platform yet.'**
  String get billingOff;

  /// No description provided for @cancelPlanAsk.
  ///
  /// In en, this message translates to:
  /// **'Stop renewing? The plan stays until the paid period ends, then drops to Free.'**
  String get cancelPlanAsk;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'kk':
      return L10nKk();
    case 'ru':
      return L10nRu();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
