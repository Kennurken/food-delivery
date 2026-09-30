from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status

from app.core.events import hub
from app.core.sessions import user_for_token
from app.db.session import SessionLocal

router = APIRouter(tags=["ws"])


@router.websocket("/ws")
async def order_events(ws: WebSocket, token: str = Query()) -> None:
    """Server -> client stream of `order.updated` events. Auth via ?token= (browsers can't set headers)."""
    with SessionLocal() as db:
        user = user_for_token(db, token)
    if not user:
        await ws.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await hub.connect(user.id, ws)
    try:
        while True:
            # Client sends nothing meaningful; this just keeps the socket alive and detects close.
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        hub.disconnect(user.id, ws)
