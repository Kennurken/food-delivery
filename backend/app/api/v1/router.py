from fastapi import APIRouter

from app.api.v1 import admin, auth, floor_plan, me, orders, platform, qr, restaurants, ws

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(me.router)
api_router.include_router(restaurants.router)
api_router.include_router(orders.router)
api_router.include_router(admin.router)
api_router.include_router(floor_plan.router)
api_router.include_router(platform.router)
api_router.include_router(qr.router)
api_router.include_router(ws.router)
