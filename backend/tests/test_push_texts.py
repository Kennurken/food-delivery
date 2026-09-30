"""Push texts in the language of the phone they land on."""

import pytest

from app.core import push, push_texts
from app.db.session import SessionLocal
from app.models.device import DeviceToken


class TestRendering:
    def test_a_status_is_worded_per_language(self):
        assert push_texts.render("order.status", "ru", order_id=5, venue="Bao", status="on_the_way") == (
            "Заказ #5",
            "Bao · в пути",
        )
        assert push_texts.render("order.status", "kk", order_id=5, venue="Bao", status="delivered")[1] == (
            "Bao · жеткізілді"
        )
        assert push_texts.render("order.status", "en", order_id=5, venue="Bao", status="preparing")[1] == (
            "Bao · being prepared"
        )

    @pytest.mark.parametrize("lang", [None, "", "de", "RU-ru"])
    def test_unknown_or_missing_language_falls_back_to_russian(self, lang):
        title, _ = push_texts.render("order.chat", lang, order_id=1, sender="A", text="hi")

        assert title == "Заказ #1"

    def test_a_decline_without_a_reason_says_whom_to_ask(self):
        _, body = push_texts.render("application.declined", "kk", venue="X", reason=None)

        assert "платформамен" in body

    def test_every_key_exists_in_every_language(self):
        for key, per_lang in push_texts._TEXTS.items():
            assert set(per_lang) == set(push_texts.LANGS), key


class TestFanout:
    @pytest.fixture
    def sent(self, monkeypatch):
        calls = []

        def fake(tokens, *, title, body, data):
            calls.append((sorted(tokens), title, body))
            return len(tokens), []

        monkeypatch.setattr(push, "_deliver", fake)
        return calls

    def test_each_device_gets_its_own_language(self, client, sent):
        with SessionLocal() as db:
            for token, lang in (("tok-ru-1", "ru"), ("tok-kk-1", "kk"), ("tok-old-1", None)):
                db.add(DeviceToken(user_id=3, token=token, platform="android", lang=lang))
            db.commit()
            n = push.fanout(
                db, {3}, key="order.status", params={"order_id": 9, "venue": "Bao", "status": "delivered"}
            )
            db.query(DeviceToken).filter(DeviceToken.token.like("tok-%-1")).delete(
                synchronize_session=False
            )
            db.commit()

        by_title = {title: tokens for tokens, title, _ in sent}
        assert n == 3
        assert by_title["Тапсырыс #9"] == ["tok-kk-1"]
        assert sorted(by_title["Заказ #9"]) == ["tok-old-1", "tok-ru-1"]


def test_the_app_can_register_its_language(client, auth):
    r = client.put(
        "/api/v1/me/devices",
        json={"token": "lang-test-token-123", "platform": "android", "lang": "kk"},
        headers=auth,
    )
    assert r.status_code == 204
    with SessionLocal() as db:
        row = db.query(DeviceToken).filter_by(token="lang-test-token-123").one()
        assert row.lang == "kk"
        db.delete(row)
        db.commit()


def test_a_language_it_does_not_know_is_refused(client, auth):
    r = client.put(
        "/api/v1/me/devices",
        json={"token": "lang-test-token-456", "platform": "android", "lang": "de"},
        headers=auth,
    )
    assert r.status_code == 422
