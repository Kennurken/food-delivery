"""In-process WebSocket hub. One server instance only — swap for Redis pub/sub when scaling out."""

import asyncio
import logging
from collections import defaultdict
from typing import Any

from fastapi import WebSocket

log = logging.getLogger(__name__)


class OrderHub:
    def __init__(self) -> None:
        self._by_user: dict[int, set[WebSocket]] = defaultdict(set)
        self._loop: asyncio.AbstractEventLoop | None = None

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    async def connect(self, user_id: int, ws: WebSocket) -> None:
        await ws.accept()
        self._by_user[user_id].add(ws)

    def disconnect(self, user_id: int, ws: WebSocket) -> None:
        self._by_user[user_id].discard(ws)
        if not self._by_user[user_id]:
            del self._by_user[user_id]

    async def send(self, user_ids: set[int], payload: dict[str, Any]) -> None:
        dead: list[tuple[int, WebSocket]] = []
        for uid in user_ids:
            for ws in list(self._by_user.get(uid, ())):
                try:
                    await ws.send_json(payload)
                except Exception:  # noqa: BLE001 — any send failure means socket is gone
                    dead.append((uid, ws))
        for uid, ws in dead:
            self.disconnect(uid, ws)

    def publish_threadsafe(self, user_ids: set[int], payload: dict[str, Any]) -> None:
        """Call from sync (threadpool) endpoints."""
        if self._loop is None or not user_ids:
            return
        asyncio.run_coroutine_threadsafe(self.send(user_ids, payload), self._loop)


hub = OrderHub()
