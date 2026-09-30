from fastapi import APIRouter

from app.api.v1 import (
    admin,
    auth,
    cities,
    floor_plan,
    geo,
    hours,
    loyalty,
    me,
    orders,
    platform,
    qr,
    reservations,
    restaurants,
    reviews,
    ws,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(me.router)
api_router.include_router(loyalty.router)
api_router.include_router(hours.router)
api_router.include_router(reviews.router)
api_router.include_router(restaurants.router)
api_router.include_router(cities.router)
api_router.include_router(cities.admin_router)
api_router.include_router(orders.router)
api_router.include_router(admin.router)
api_router.include_router(floor_plan.router)
api_router.include_router(platform.router)
api_router.include_router(qr.router)
api_router.include_router(geo.router)
api_router.include_router(reservations.router)
api_router.include_router(ws.router)
