"""What a push notification says, in the language of the phone it lands on.

A notification is read on a lock screen, before the app can translate
anything, so the server has to pick the words. Each device token remembers the
language the app was in when it registered; a token from before that, or with
no language, gets Russian — the language most people using this service read.
"""

from __future__ import annotations

LANGS = ("ru", "kk", "en")
DEFAULT = "ru"

_STATUS = {
    "ru": {
        "pending": "принят",
        "confirmed": "подтверждён",
        "preparing": "готовится",
        "on_the_way": "в пути",
        "delivered": "доставлен",
        "cancelled": "отменён",
    },
    "kk": {
        "pending": "қабылданды",
        "confirmed": "расталды",
        "preparing": "дайындалуда",
        "on_the_way": "жолда",
        "delivered": "жеткізілді",
        "cancelled": "болдырылмады",
    },
    "en": {
        "pending": "received",
        "confirmed": "confirmed",
        "preparing": "being prepared",
        "on_the_way": "on the way",
        "delivered": "delivered",
        "cancelled": "cancelled",
    },
}

# key -> lang -> (title, body). Placeholders are filled from the caller's params.
_TEXTS: dict[str, dict[str, tuple[str, str]]] = {
    "order.status": {
        "ru": ("Заказ #{order_id}", "{venue} · {status}"),
        "kk": ("Тапсырыс #{order_id}", "{venue} · {status}"),
        "en": ("Order #{order_id}", "{venue} · {status}"),
    },
    "order.chat": {
        "ru": ("Заказ #{order_id}", "{sender}: {text}"),
        "kk": ("Тапсырыс #{order_id}", "{sender}: {text}"),
        "en": ("Order #{order_id}", "{sender}: {text}"),
    },
    "order.escalation": {
        "ru": ("Заказ #{order_id}: нужен администратор", "{sender} просит подключиться к чату"),
        "kk": ("Тапсырыс #{order_id}: әкімші керек", "{sender} чатқа қосылуды сұрайды"),
        "en": ("Order #{order_id}: manager needed", "{sender} asks you to join the chat"),
    },
    "application.new": {
        "ru": ("Новая заявка ресторана", "{venue} ({cuisine}) · {contact}, {phone}"),
        "kk": ("Мейрамхананың жаңа өтінімі", "{venue} ({cuisine}) · {contact}, {phone}"),
        "en": ("New restaurant application", "{venue} ({cuisine}) · {contact}, {phone}"),
    },
    "application.approved": {
        "ru": (
            "{venue}: заявка одобрена",
            "Гости уже видят вас и могут заказывать. Бесплатный месяц начался.",
        ),
        "kk": (
            "{venue}: өтінім мақұлданды",
            "Қонақтар сізді көріп, тапсырыс бере алады. Тегін ай басталды.",
        ),
        "en": (
            "{venue}: approved",
            "Guests can now see and order from you. The free month has started.",
        ),
    },
    "application.declined": {
        "ru": ("{venue}: заявка отклонена", "{reason}"),
        "kk": ("{venue}: өтінім қабылданбады", "{reason}"),
        "en": ("{venue}: application declined", "{reason}"),
    },
}

_NO_REASON = {
    "ru": "Свяжитесь с платформой, чтобы узнать подробности.",
    "kk": "Толығырақ білу үшін платформамен байланысыңыз.",
    "en": "Contact the platform for details.",
}


def normalise(lang: str | None) -> str:
    code = (lang or "").strip().lower()[:2]
    return code if code in LANGS else DEFAULT


def render(key: str, lang: str | None, **params: object) -> tuple[str, str]:
    lang = normalise(lang)
    values = {k: "" if v is None else str(v) for k, v in params.items()}
    if "status" in values:
        values["status"] = _STATUS[lang].get(values["status"], values["status"])
    if key == "application.declined" and not values.get("reason"):
        values["reason"] = _NO_REASON[lang]
    title, body = _TEXTS[key][lang]
    return title.format(**values), body.format(**values)
