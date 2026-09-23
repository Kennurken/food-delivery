// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class L10nRu extends L10n {
  L10nRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Food Delivery';

  @override
  String get tagline => 'Горячая еда — быстро.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get name => 'Имя';

  @override
  String get phone => 'Телефон';

  @override
  String get phoneOptional => 'Телефон (необязательно)';

  @override
  String get signIn => 'Войти';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get createAccountHint => 'Меньше минуты.';

  @override
  String get invalidEmail => 'Некорректный email';

  @override
  String minChars(int n) {
    return 'Минимум $n символов';
  }

  @override
  String get required => 'Обязательно';

  @override
  String get logOut => 'Выйти';

  @override
  String get greetingMorning => 'Доброе утро';

  @override
  String get greetingAfternoon => 'Добрый день';

  @override
  String get greetingEvening => 'Добрый вечер';

  @override
  String get greetingNight => 'Поздний вечер';

  @override
  String get searchRestaurants => 'Рестораны, блюда';

  @override
  String get all => 'Все';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get retry => 'Повторить';

  @override
  String get navHome => 'Главная';

  @override
  String get orders => 'Заказы';

  @override
  String get profile => 'Профиль';

  @override
  String get popular => 'Популярное';

  @override
  String get sortRating => 'Рейтинг';

  @override
  String get sortEta => 'Быстрее';

  @override
  String get sortFee => 'Доставка';

  @override
  String minutes(int n) {
    return '$n мин';
  }

  @override
  String deliveryFee(String fee) {
    return 'доставка $fee';
  }

  @override
  String get unavailable => 'Нет в наличии';

  @override
  String get addToCart => 'В корзину';

  @override
  String get done => 'Готово';

  @override
  String get viewCart => 'Корзина';

  @override
  String get newCartTitle => 'Начать новую корзину?';

  @override
  String get newCartBody => 'В корзине блюда из другого ресторана.';

  @override
  String get keep => 'Оставить';

  @override
  String get replace => 'Заменить';

  @override
  String get cart => 'Корзина';

  @override
  String get cartEmpty => 'Корзина пуста';

  @override
  String get cartEmptyHint => 'Добавьте что-нибудь вкусное из ресторана';

  @override
  String get deliveryAddress => 'Адрес доставки';

  @override
  String get courierComment => 'Комментарий курьеру (необязательно)';

  @override
  String get subtotal => 'Сумма';

  @override
  String get delivery => 'Доставка';

  @override
  String get total => 'Итого';

  @override
  String get placeOrder => 'Оформить заказ';

  @override
  String get enterAddress => 'Введите адрес доставки';

  @override
  String orderPlaced(int id) {
    return 'Заказ #$id оформлен';
  }

  @override
  String get keepYouPosted => 'Будем держать в курсе';

  @override
  String get myOrders => 'Мои заказы';

  @override
  String get active => 'Активные';

  @override
  String get history => 'История';

  @override
  String get noOrdersYet => 'Заказов пока нет';

  @override
  String get noOrdersHint => 'Ваши заказы появятся здесь';

  @override
  String get browseRestaurants => 'К ресторанам';

  @override
  String get orderAgain => 'Повторить';

  @override
  String get nothingToReorder => 'Из этого заказа ничего нет в меню';

  @override
  String get someItemsUnavailable => 'Некоторые блюда больше недоступны';

  @override
  String get couldNotLoad => 'Не удалось загрузить';

  @override
  String items(int n) {
    return '$n поз.';
  }

  @override
  String orderN(int id) {
    return 'Заказ #$id';
  }

  @override
  String get status => 'Статус';

  @override
  String get cancelOrder => 'Отменить заказ';

  @override
  String get callCourier => 'Позвонить курьеру';

  @override
  String get courier => 'Курьер';

  @override
  String get howWasIt => 'Как вам?';

  @override
  String get thanksForRating => 'Спасибо за оценку!';

  @override
  String get statusPending => 'Ожидает';

  @override
  String get statusConfirmed => 'Подтверждён';

  @override
  String get statusPreparing => 'Готовится';

  @override
  String get statusOnTheWay => 'В пути';

  @override
  String get statusDelivered => 'Доставлен';

  @override
  String get statusCancelled => 'Отменён';

  @override
  String get hintPending => 'Ждём подтверждения ресторана';

  @override
  String get hintConfirmed => 'Подтверждён — ищем курьера';

  @override
  String get hintPreparing => 'Кухня готовит ваш заказ';

  @override
  String get hintOnTheWay => 'Курьер уже едет';

  @override
  String get hintDelivered => 'Доставлено. Приятного аппетита!';

  @override
  String get hintCancelled => 'Заказ отменён';

  @override
  String get actionConfirm => 'Подтвердить';

  @override
  String get actionStartPreparing => 'Начать готовить';

  @override
  String get actionHandToCourier => 'Передать курьеру';

  @override
  String get actionPickedUp => 'Забрал заказ';

  @override
  String get actionMarkDelivered => 'Доставлен';

  @override
  String get actionCancel => 'Отменить';

  @override
  String get accept => 'Принять';

  @override
  String get available => 'Доступные';

  @override
  String get myDeliveries => 'Мои доставки';

  @override
  String get noOrdersWaiting => 'Нет заказов';

  @override
  String get noOrdersWaitingHint => 'Новые заказы появятся мгновенно';

  @override
  String get noActiveDeliveries => 'Нет активных доставок';

  @override
  String get noActiveDeliveriesHint => 'Примите заказ из «Доступных»';

  @override
  String get admin => 'Админ';

  @override
  String get restaurants => 'Рестораны';

  @override
  String get noOrdersAdminHint => 'Новые заказы появляются в реальном времени';

  @override
  String get open => 'открыт';

  @override
  String get closed => 'закрыт';

  @override
  String get menu => 'Меню';

  @override
  String get newItem => 'Новое блюдо';

  @override
  String get editItem => 'Редактировать';

  @override
  String get description => 'Описание';

  @override
  String get priceTenge => 'Цена, ₸';

  @override
  String get category => 'Категория';

  @override
  String get mustBePositive => 'Должно быть > 0';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String deleteItemTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get deleteItemBody =>
      'Прошлые заказы сохранят снимок; блюдо исчезнет из меню.';

  @override
  String get saved => 'Сохранено';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get addresses => 'Адреса';

  @override
  String get add => 'Добавить';

  @override
  String get noSavedAddresses => 'Нет сохранённых адресов';

  @override
  String get noSavedAddressesHint => 'Добавьте — оформление в один тап';

  @override
  String get swipeToDelete => 'Смахните влево, чтобы удалить';

  @override
  String get default_ => 'Основной';

  @override
  String get newAddress => 'Новый адрес';

  @override
  String get labelHome => 'Дом';

  @override
  String get labelWork => 'Работа';

  @override
  String get labelOther => 'Другое';

  @override
  String get addressLine => 'Улица, дом';

  @override
  String get apt => 'Кв.';

  @override
  String get entrance => 'Подъезд';

  @override
  String get floor => 'Этаж';

  @override
  String get intercom => 'Домофон';

  @override
  String get saveAddress => 'Сохранить адрес';

  @override
  String toastNewOrder(int id) {
    return 'Новый заказ #$id';
  }

  @override
  String toastReadyForPickup(int id) {
    return 'Заказ #$id готов к выдаче';
  }

  @override
  String toastCourier(String name) {
    return 'Курьер $name';
  }

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageKazakh => 'Қазақша';

  @override
  String get restaurantClosed => 'Ресторан сейчас закрыт';

  @override
  String get cancelOrderTitle => 'Отменить заказ?';

  @override
  String get cancelOrderBody =>
      'Кухня остановится, если ещё не начала готовить.';

  @override
  String get setAsDefault => 'Сделать основным';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get confirmPassword => 'Повторите новый пароль';

  @override
  String get passwordChanged => 'Пароль обновлён';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get newRestaurant => 'Новый ресторан';

  @override
  String get cuisine => 'Кухня';

  @override
  String get deliveryFeeTenge => 'Доставка, ₸';

  @override
  String get etaMinutes => 'Время, мин';

  @override
  String get noRestaurants => 'Нет ресторанов';

  @override
  String get noRestaurantsHint => 'Добавьте первый, чтобы принимать заказы';

  @override
  String get favorites => 'Избранное';

  @override
  String get addFavorite => 'Сохранить ресторан';

  @override
  String get removeFavorite => 'Убрать из избранного';

  @override
  String get floorPlan => 'План зала';

  @override
  String get noFloorPlan => 'Плана ещё нет';

  @override
  String get noFloorPlanHint =>
      'Расставьте столы, стены и зоны в масштабе реального зала.';

  @override
  String get createFloorPlan => 'Создать план';

  @override
  String get startScratch => 'С нуля';

  @override
  String get useTemplate => 'Шаблон кафе';

  @override
  String get firstFloor => '1 этаж';

  @override
  String get addFloor => 'Добавить этаж';

  @override
  String get renameFloor => 'Переименовать';

  @override
  String get duplicateFloor => 'Дублировать этаж';

  @override
  String get deleteFloor => 'Удалить этаж';

  @override
  String get previewLayout => 'Просмотр';

  @override
  String get editLayout => 'Редактор';

  @override
  String get layoutSaved => 'Сохранено';

  @override
  String get layoutSaving => 'Сохранение…';

  @override
  String get layoutUnsaved => 'Есть изменения';

  @override
  String get layoutSaveFailed => 'Не удалось сохранить';

  @override
  String get layoutSaveFailedBody =>
      'Локальные правки на месте. Повторите или продолжите.';

  @override
  String get continueEditing => 'Продолжить';

  @override
  String get snapOn => 'Привязка вкл';

  @override
  String get snapOff => 'Привязка выкл';

  @override
  String get platform => 'Платформа';

  @override
  String get tableQr => 'QR стола';

  @override
  String get copyLink => 'Скопировать ссылку';

  @override
  String get copied => 'Скопировано';

  @override
  String get dineIn => 'В зале';

  @override
  String atTable(String name) {
    return 'Стол $name';
  }

  @override
  String get signInToOrder => 'Войдите, чтобы заказать';

  @override
  String get setup => 'Запуск';

  @override
  String get setupMenu => 'Меню';

  @override
  String get setupFloor => 'План зала';

  @override
  String get setupOpen => 'Открыт для заказов';

  @override
  String get ordersToday => 'Заказов сегодня';

  @override
  String get venues => 'Рестораны';

  @override
  String get billingUnconfigured => 'Оплата подписки ещё не подключена';

  @override
  String get plan => 'Тариф';

  @override
  String get pickup => 'Самовывоз';

  @override
  String get kitchen => 'Кухня';

  @override
  String get kitchenNew => 'Новые';

  @override
  String get kitchenCooking => 'Готовят';

  @override
  String get kitchenReady => 'Готово';

  @override
  String get actionMarkReady => 'Готово';

  @override
  String get actionMarkServed => 'Подано';

  @override
  String get actionMarkCollected => 'Выдан';

  @override
  String get statusReady => 'Готово';

  @override
  String get statusServed => 'Подано';

  @override
  String get statusCollected => 'Выдан';

  @override
  String get hintConfirmedTable => 'Приняли — кухня готовит';

  @override
  String get hintConfirmedPickup => 'Приняли — готовим к самовывозу';

  @override
  String get hintReadyTable => 'Готово — принесут к столу';

  @override
  String get hintReadyPickup => 'Можно забирать в ресторане';

  @override
  String get hintServed => 'Подано. Приятного аппетита!';

  @override
  String get hintCollected => 'Забрали. Приятного аппетита!';

  @override
  String get orderNote => 'Комментарий';

  @override
  String get tableOnly =>
      'Этот ресторан принимает заказы только со стола. Сканируйте QR на столе.';

  @override
  String get pickupAt => 'Забрать в ресторане';

  @override
  String get pickAddress => 'Указать на карте';

  @override
  String get confirmAddress => 'Сюда';

  @override
  String get searchAddress => 'Улица, дом, ориентир';

  @override
  String get dropPin => 'Двиньте карту, чтобы поставить метку';

  @override
  String get locationDenied => 'Геолокация выключена. Двигайте карту сами.';

  @override
  String get noAddressHits => 'По этому запросу ничего нет';

  @override
  String get sortNear => 'Рядом';

  @override
  String get openMap => 'Карта';

  @override
  String distanceM(int m) {
    return '$m м';
  }

  @override
  String distanceKm(String km) {
    return '$km км';
  }

  @override
  String fromPrice(String price) {
    return 'от $price';
  }

  @override
  String get payCash => 'Наличные';

  @override
  String get payCard => 'Карта';

  @override
  String get payOnDelivery =>
      'Оплата курьеру или на кассе. Заказ останется неоплаченным до этого.';

  @override
  String get cardNotConnected => 'Карты не подключены. Платите наличными.';

  @override
  String get payCardHint =>
      'Оплата на странице Stripe. Тестовая карта 4242 4242 4242 4242.';

  @override
  String get payNow => 'Оплатить';

  @override
  String get waitingForCard => 'Ждём карту';

  @override
  String get paid => 'Оплачен';

  @override
  String get unpaid => 'Не оплачен';

  @override
  String get payMethod => 'Оплата';

  @override
  String get modifiers => 'Размер и добавки';

  @override
  String get addGroup => 'Добавить группу';

  @override
  String get addOption => 'Добавить опцию';

  @override
  String get optionName => 'Опция';

  @override
  String get priceDelta => 'Δ ₸';

  @override
  String get asap => 'Как можно скорее';

  @override
  String get schedule => 'Время';

  @override
  String scheduledFor(String when) {
    return 'Ко времени · $when';
  }

  @override
  String get promo => 'Промокод';

  @override
  String get applyPromo => 'Применить';

  @override
  String get discount => 'Скидка';

  @override
  String get kitchenLater => 'Позже';

  @override
  String get chat => 'Чат';

  @override
  String orderChat(int id) {
    return 'Чат · №$id';
  }

  @override
  String get chatHint => 'Сообщение';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatEmpty => 'Пока нет сообщений';

  @override
  String get chatEmptyHint => 'Кухня, курьер и вы пишете в одной ветке.';

  @override
  String get chatClosed => 'Заказ завершён. Чат только для чтения.';

  @override
  String chatPreview(String who, String body) {
    return '$who: $body';
  }

  @override
  String get bookTable => 'Забронировать стол';

  @override
  String get reservations => 'Брони';

  @override
  String get guests => 'Гости';

  @override
  String guestsCount(int n) {
    return '$n гостей';
  }

  @override
  String get pickTable => 'Стол';

  @override
  String get anyTable => 'Любой стол';

  @override
  String get book => 'Забронировать';

  @override
  String get booked => 'Стол забронирован';

  @override
  String get reserveRequested => 'Заявка';

  @override
  String get reserveConfirmed => 'Подтверждена';

  @override
  String get reserveSeated => 'Посадили';

  @override
  String get reserveCancelled => 'Отменена';

  @override
  String get reserveNoShow => 'Не пришли';

  @override
  String get cancelReservation => 'Отменить бронь';

  @override
  String get noReservations => 'Броней пока нет';

  @override
  String get noReservationsHint =>
      'Откройте ресторан и нажмите «Забронировать стол».';

  @override
  String get walkIn => 'Без записи';

  @override
  String get seatGuest => 'Посадить';

  @override
  String tableSeats(int n) {
    return '$n мест';
  }

  @override
  String get confirmReservation => 'Подтвердить';

  @override
  String get searchVenues => 'Поиск ресторанов';

  @override
  String lastDays(int n) {
    return '$n дн.';
  }

  @override
  String ordersWindow(int n) {
    return 'Заказы / $n дн.';
  }

  @override
  String get revenueWindow => 'Выручка';

  @override
  String get ordersAllTime => 'Заказов всего';

  @override
  String get revenueAllTime => 'Выручка всего';

  @override
  String get noOwnerLinked => 'Владелец не привязан';

  @override
  String get noOwnerHint => 'Добавьте его в списке сотрудников ресторана.';

  @override
  String get recentOrders => 'Последние заказы';

  @override
  String get lastOrder => 'Последний заказ';

  @override
  String get venue => 'Ресторан';

  @override
  String get directory => 'Справочник';

  @override
  String get overview => 'Обзор';

  @override
  String get staff => 'Сотрудники';

  @override
  String get rating => 'Рейтинг';

  @override
  String billingConnected(String provider) {
    return 'Оплата картой через $provider';
  }

  @override
  String deliveryDistance(String km) {
    return '$km км от кухни';
  }

  @override
  String outOfDeliveryRange(String km) {
    return 'Слишком далеко — ресторан возит до $km км.';
  }

  @override
  String get addressNeedsPin => 'Нет точки на карте — нажмите, чтобы указать';
}
