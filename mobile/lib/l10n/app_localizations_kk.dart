// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class L10nKk extends L10n {
  L10nKk([String locale = 'kk']) : super(locale);

  @override
  String get appName => 'Food Delivery';

  @override
  String get tagline => 'Ыстық тағам — тез.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Құпиясөз';

  @override
  String get name => 'Аты';

  @override
  String get phone => 'Телефон';

  @override
  String get phoneOptional => 'Телефон (міндетті емес)';

  @override
  String get signIn => 'Кіру';

  @override
  String get signUp => 'Тіркелу';

  @override
  String get createAccount => 'Аккаунт ашу';

  @override
  String get createAccountHint => 'Бір минуттан аз.';

  @override
  String get invalidEmail => 'Email қате';

  @override
  String minChars(int n) {
    return 'Кемінде $n таңба';
  }

  @override
  String get required => 'Міндетті';

  @override
  String get logOut => 'Шығу';

  @override
  String get greetingMorning => 'Қайырлы таң';

  @override
  String get greetingAfternoon => 'Қайырлы күн';

  @override
  String get greetingEvening => 'Қайырлы кеш';

  @override
  String get greetingNight => 'Түнгі уақыт';

  @override
  String get searchRestaurants => 'Мейрамхана, тағам';

  @override
  String get all => 'Барлығы';

  @override
  String get nothingFound => 'Ештеңе табылмады';

  @override
  String get retry => 'Қайталау';

  @override
  String get navHome => 'Басты';

  @override
  String get orders => 'Тапсырыстар';

  @override
  String get profile => 'Профиль';

  @override
  String get popular => 'Танымал';

  @override
  String get sortRating => 'Рейтинг';

  @override
  String get sortEta => 'Тезірек';

  @override
  String get sortFee => 'Жеткізу';

  @override
  String minutes(int n) {
    return '$n мин';
  }

  @override
  String deliveryFee(String fee) {
    return 'жеткізу $fee';
  }

  @override
  String get unavailable => 'Жоқ';

  @override
  String get addToCart => 'Себетке';

  @override
  String get done => 'Дайын';

  @override
  String get viewCart => 'Себет';

  @override
  String get newCartTitle => 'Жаңа себет бастау?';

  @override
  String get newCartBody => 'Себетте басқа мейрамхананың тағамдары бар.';

  @override
  String get keep => 'Қалдыру';

  @override
  String get replace => 'Ауыстыру';

  @override
  String get cart => 'Себет';

  @override
  String get cartEmpty => 'Себет бос';

  @override
  String get cartEmptyHint => 'Мейрамханадан дәмді нәрсе қосыңыз';

  @override
  String get deliveryAddress => 'Жеткізу мекенжайы';

  @override
  String get courierComment => 'Курьерге түсініктеме (міндетті емес)';

  @override
  String get subtotal => 'Сомасы';

  @override
  String get delivery => 'Жеткізу';

  @override
  String get total => 'Барлығы';

  @override
  String get placeOrder => 'Тапсырыс беру';

  @override
  String get enterAddress => 'Мекенжайды енгізіңіз';

  @override
  String orderPlaced(int id) {
    return '#$id тапсырысы қабылданды';
  }

  @override
  String get keepYouPosted => 'Хабарлап отырамыз';

  @override
  String get myOrders => 'Менің тапсырыстарым';

  @override
  String get active => 'Белсенді';

  @override
  String get history => 'Тарих';

  @override
  String get noOrdersYet => 'Тапсырыстар әзірге жоқ';

  @override
  String get noOrdersHint => 'Тапсырыстарыңыз осында көрінеді';

  @override
  String get browseRestaurants => 'Мейрамханаларға';

  @override
  String get orderAgain => 'Тағы бір рет';

  @override
  String get nothingToReorder => 'Бұл тапсырыстағы тағамдар мәзірде жоқ';

  @override
  String get someItemsUnavailable => 'Кейбір тағамдар енді жоқ';

  @override
  String get couldNotLoad => 'Жүктеу мүмкін болмады';

  @override
  String items(int n) {
    return '$n поз.';
  }

  @override
  String orderN(int id) {
    return 'Тапсырыс #$id';
  }

  @override
  String get status => 'Күйі';

  @override
  String get cancelOrder => 'Тапсырысты болдырмау';

  @override
  String get callCourier => 'Курьерге қоңырау шалу';

  @override
  String get courier => 'Курьер';

  @override
  String get howWasIt => 'Қалай болды?';

  @override
  String get thanksForRating => 'Бағалағаныңызға рахмет!';

  @override
  String get statusPending => 'Күтуде';

  @override
  String get statusConfirmed => 'Расталды';

  @override
  String get statusPreparing => 'Дайындалуда';

  @override
  String get statusOnTheWay => 'Жолда';

  @override
  String get statusDelivered => 'Жеткізілді';

  @override
  String get statusCancelled => 'Болдырылмады';

  @override
  String get hintPending => 'Мейрамхананың растауын күтудеміз';

  @override
  String get hintConfirmed => 'Расталды — курьер іздеудеміз';

  @override
  String get hintPreparing => 'Асхана тапсырысыңызды дайындауда';

  @override
  String get hintOnTheWay => 'Курьер жолда';

  @override
  String get hintDelivered => 'Жеткізілді. Ас болсын!';

  @override
  String get hintCancelled => 'Тапсырыс болдырылмады';

  @override
  String get actionConfirm => 'Растау';

  @override
  String get actionStartPreparing => 'Дайындауды бастау';

  @override
  String get actionHandToCourier => 'Курьерге беру';

  @override
  String get actionMarkDelivered => 'Жеткізілді';

  @override
  String get actionCancel => 'Болдырмау';

  @override
  String get accept => 'Қабылдау';

  @override
  String get available => 'Қолжетімді';

  @override
  String get myDeliveries => 'Менің жеткізулерім';

  @override
  String get noOrdersWaiting => 'Тапсырыстар жоқ';

  @override
  String get noOrdersWaitingHint => 'Жаңа тапсырыстар бірден көрінеді';

  @override
  String get noActiveDeliveries => 'Белсенді жеткізулер жоқ';

  @override
  String get noActiveDeliveriesHint =>
      '«Қолжетімді» ішінен тапсырыс қабылдаңыз';

  @override
  String get admin => 'Әкімші';

  @override
  String get restaurants => 'Мейрамханалар';

  @override
  String get noOrdersAdminHint => 'Жаңа тапсырыстар нақты уақытта көрінеді';

  @override
  String get open => 'ашық';

  @override
  String get closed => 'жабық';

  @override
  String get menu => 'Мәзір';

  @override
  String get newItem => 'Жаңа тағам';

  @override
  String get editItem => 'Өңдеу';

  @override
  String get description => 'Сипаттама';

  @override
  String get priceTenge => 'Бағасы, ₸';

  @override
  String get category => 'Санат';

  @override
  String get mustBePositive => '0-ден үлкен болуы керек';

  @override
  String get save => 'Сақтау';

  @override
  String get cancel => 'Болдырмау';

  @override
  String get delete => 'Жою';

  @override
  String deleteItemTitle(String name) {
    return '«$name» жою керек пе?';
  }

  @override
  String get deleteItemBody =>
      'Өткен тапсырыстар сақталады; тағам мәзірден жоғалады.';

  @override
  String get saved => 'Сақталды';

  @override
  String get saveChanges => 'Өзгерістерді сақтау';

  @override
  String get addresses => 'Мекенжайлар';

  @override
  String get add => 'Қосу';

  @override
  String get noSavedAddresses => 'Сақталған мекенжайлар жоқ';

  @override
  String get noSavedAddressesHint => 'Қосыңыз — бір басумен рәсімдеу';

  @override
  String get swipeToDelete => 'Жою үшін солға сырғытыңыз';

  @override
  String get default_ => 'Негізгі';

  @override
  String get newAddress => 'Жаңа мекенжай';

  @override
  String get labelHome => 'Үй';

  @override
  String get labelWork => 'Жұмыс';

  @override
  String get labelOther => 'Басқа';

  @override
  String get addressLine => 'Көше, үй';

  @override
  String get apt => 'Пәтер';

  @override
  String get entrance => 'Кіреберіс';

  @override
  String get floor => 'Қабат';

  @override
  String get intercom => 'Домофон';

  @override
  String get saveAddress => 'Мекенжайды сақтау';

  @override
  String toastNewOrder(int id) {
    return 'Жаңа тапсырыс #$id';
  }

  @override
  String toastReadyForPickup(int id) {
    return '#$id тапсырысы алуға дайын';
  }

  @override
  String toastCourier(String name) {
    return 'Курьер $name';
  }

  @override
  String get language => 'Тіл';

  @override
  String get languageSystem => 'Жүйелік';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageKazakh => 'Қазақша';

  @override
  String get restaurantClosed => 'Мейрамхана қазір жабық';

  @override
  String get cancelOrderTitle => 'Тапсырысты болдырмау керек пе?';

  @override
  String get cancelOrderBody => 'Ас үй әлі бастамаса, тоқтайды.';

  @override
  String get setAsDefault => 'Негізгі ету';

  @override
  String get changePassword => 'Құпиясөзді өзгерту';

  @override
  String get currentPassword => 'Қазіргі құпиясөз';

  @override
  String get newPassword => 'Жаңа құпиясөз';

  @override
  String get confirmPassword => 'Жаңа құпиясөзді қайталаңыз';

  @override
  String get passwordChanged => 'Құпиясөз жаңартылды';

  @override
  String get passwordsDoNotMatch => 'Құпиясөздер сәйкес емес';

  @override
  String get newRestaurant => 'Жаңа мейрамхана';

  @override
  String get cuisine => 'Ас';

  @override
  String get deliveryFeeTenge => 'Жеткізу, ₸';

  @override
  String get etaMinutes => 'Уақыт, мин';

  @override
  String get noRestaurants => 'Мейрамхана жоқ';

  @override
  String get noRestaurantsHint => 'Тапсырыс қабылдау үшін біреуін қосыңыз';

  @override
  String get favorites => 'Таңдаулы';

  @override
  String get addFavorite => 'Мейрамхананы сақтау';

  @override
  String get removeFavorite => 'Таңдаулыдан алу';

  @override
  String get floorPlan => 'Зал жоспары';

  @override
  String get noFloorPlan => 'Жоспар жоқ';

  @override
  String get noFloorPlanHint =>
      'Үстелдер, қабырғалар және аймақтарды нақты масштабта орналастырыңыз.';

  @override
  String get createFloorPlan => 'Жоспар құру';

  @override
  String get startScratch => 'Нөлден';

  @override
  String get useTemplate => 'Кафе үлгісі';

  @override
  String get firstFloor => '1-қабат';

  @override
  String get addFloor => 'Қабат қосу';

  @override
  String get renameFloor => 'Атын өзгерту';

  @override
  String get duplicateFloor => 'Қабатты көшіру';

  @override
  String get deleteFloor => 'Қабатты жою';

  @override
  String get previewLayout => 'Қарау';

  @override
  String get editLayout => 'Өңдеу';

  @override
  String get layoutSaved => 'Сақталды';

  @override
  String get layoutSaving => 'Сақталуда…';

  @override
  String get layoutUnsaved => 'Сақталмаған';

  @override
  String get layoutSaveFailed => 'Сақталмады';

  @override
  String get layoutSaveFailedBody =>
      'Жергілікті өзгерістер қалды. Қайталаңыз немесе жалғастырыңыз.';

  @override
  String get continueEditing => 'Жалғастыру';

  @override
  String get snapOn => 'Жабысу қосулы';

  @override
  String get snapOff => 'Жабысу өшірулі';
}
